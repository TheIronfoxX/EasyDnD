// Controlador del skin de la app (Etapa 6): acento + modo claro/oscuro
// + tipografía.
//
// Es el equivalente rework de ThemeNotifier de la app vieja, pero
// separado del árbol de widgets: main() lo inicializa antes de pintar y
// EasyDnDApp lo escucha para reconstruir MaterialApp.
//
// Persistencia con claves propias (`easydnd.skin.*`) y migración de las
// claves legacy (`accent_color_argb` / `is_dark_mode`) en el primer
// arranque: el jugador que venía de la app vieja conserva su acento y su
// modo. Las claves viejas NO se borran (misma política que el roster).

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/font_presets.dart';
import '../core/theme/theme_presets.dart';

class SkinController extends ChangeNotifier {
  SkinController(this._prefs);

  /// Claves nuevas del rework.
  static const String accentKey = 'easydnd.skin.accent.v1';
  static const String darkModeKey = 'easydnd.skin.dark.v1';
  static const String fontKey = 'easydnd.skin.font.v1';

  /// Último tema OSCURO elegido (id de [AppThemePreset]). El modo claro
  /// no se guarda acá: es [darkModeKey] en false, y siempre es Pergamino.
  static const String themeKey = 'easydnd.skin.theme.v1';

  /// Claves de la app vieja, solo para migrar una vez.
  static const String legacyAccentKey = 'accent_color_argb';
  static const String legacyDarkModeKey = 'is_dark_mode';

  final SharedPreferences _prefs;

  /// Acento elegido a mano por el jugador. `null` = usar el acento de
  /// firma del tema activo.
  Color? _customAccent;
  AppThemePreset _darkPreset = AppThemePreset.defaultDark;
  bool _isDarkMode = true; // la app siempre arrancó en oscuro
  FontPreset _fontPreset = FontPresets.defaultPreset;
  bool _isReady = false;

  /// Acento efectivo: el propio del jugador o, si no eligió ninguno, el
  /// de firma del tema activo.
  Color get accentColor => _customAccent ?? themePreset.accent;

  /// true si el jugador pisó el acento de firma con un color propio.
  bool get hasCustomAccent => _customAccent != null;

  /// Tema activo: Pergamino en modo claro, el oscuro elegido si no.
  AppThemePreset get themePreset =>
      _isDarkMode ? _darkPreset : AppThemePreset.defaultLight;

  /// Tema oscuro al que vuelve el toggle claro/oscuro.
  AppThemePreset get darkPreset => _darkPreset;
  bool get isDarkMode => _isDarkMode;
  FontPreset get fontPreset => _fontPreset;
  bool get isReady => _isReady;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Tema resuelto para el modo actual. Lo usan tests y pantallas que
  /// necesiten un ThemeData sin pasar por MaterialApp.
  ThemeData get themeData => _isDarkMode ? darkTheme : lightTheme;

  /// Tema del modo claro (Pergamino) con el acento y la tipografía
  /// actuales. Es el `theme` del MaterialApp.
  ThemeData get lightTheme =>
      AppTheme.light(accent: _customAccent, fontPreset: _fontPreset);

  /// Tema del modo oscuro (el preset oscuro elegido). Es el `darkTheme`
  /// del MaterialApp.
  ThemeData get darkTheme => AppTheme.dark(
    preset: _darkPreset,
    accent: _customAccent,
    fontPreset: _fontPreset,
  );

  /// Recupera acento, modo y tipografía guardados. Idempotente, como el
  /// init del CharacterStore.
  Future<void> init() async {
    if (_isReady) return;

    final storedAccent = _prefs.getInt(accentKey);
    final legacyAccent = _prefs.getInt(legacyAccentKey);
    if (storedAccent != null) {
      _customAccent = Color(storedAccent);
    } else if (legacyAccent != null) {
      _customAccent = Color(legacyAccent);
      await _prefs.setInt(accentKey, legacyAccent);
    }

    final storedMode = _prefs.getBool(darkModeKey);
    final legacyMode = _prefs.getBool(legacyDarkModeKey);
    if (storedMode != null) {
      _isDarkMode = storedMode;
    } else if (legacyMode != null) {
      _isDarkMode = legacyMode;
      await _prefs.setBool(darkModeKey, legacyMode);
    }

    // Un id de tema desconocido (build futuro) o uno claro guardado por
    // error cae al oscuro de fábrica: el toggle siempre tiene a dónde ir.
    final storedTheme = AppThemePreset.byId(_prefs.getString(themeKey));
    if (storedTheme != null && storedTheme.isDark) _darkPreset = storedTheme;

    // byId cae al preset por defecto si no hay nada guardado o si el id
    // es de una versión futura que este build no conoce.
    _fontPreset = FontPresets.byId(_prefs.getString(fontKey));

    _isReady = true;
    notifyListeners();
  }

  /// Cambia el acento y lo persiste. Mismo color = no-op (ni notifica).
  Future<void> setAccentColor(Color color) async {
    if (accentColor == color) return;
    _customAccent = color;
    notifyListeners();
    await _prefs.setInt(accentKey, color.toARGB32());
  }

  /// Vuelve al acento de firma del tema activo.
  Future<void> clearCustomAccent() async {
    if (_customAccent == null) return;
    _customAccent = null;
    notifyListeners();
    await _prefs.remove(accentKey);
  }

  /// Elige un tema del catálogo y lo persiste. Un tema oscuro pasa a ser
  /// el destino del toggle; Pergamino es simplemente "modo claro". Elegir
  /// un tema restaura su acento de firma: quien quiera otro color lo
  /// vuelve a elegir en Apariencia.
  Future<void> setThemePreset(AppThemePreset preset) async {
    if (themePreset == preset && _customAccent == null) return;
    final hadAccent = _customAccent != null;
    _customAccent = null;
    _isDarkMode = preset.isDark;
    if (preset.isDark) _darkPreset = preset;
    notifyListeners();
    await _prefs.setBool(darkModeKey, _isDarkMode);
    if (preset.isDark) await _prefs.setString(themeKey, preset.id);
    if (hadAccent) await _prefs.remove(accentKey);
  }

  /// Fija el modo claro/oscuro y lo persiste. Mismo valor = no-op.
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    await _prefs.setBool(darkModeKey, value);
  }

  /// Cambia la tipografía y la persiste. Mismo preset = no-op.
  Future<void> setFontPreset(FontPreset preset) async {
    if (_fontPreset.id == preset.id) return;
    _fontPreset = preset;
    notifyListeners();
    await _prefs.setString(fontKey, preset.id);
  }

  Future<void> toggleThemeMode() => setDarkMode(!_isDarkMode);
}
