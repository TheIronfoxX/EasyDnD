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

class SkinController extends ChangeNotifier {
  SkinController(this._prefs);

  /// Claves nuevas del rework.
  static const String accentKey = 'easydnd.skin.accent.v1';
  static const String darkModeKey = 'easydnd.skin.dark.v1';
  static const String fontKey = 'easydnd.skin.font.v1';

  /// Claves de la app vieja, solo para migrar una vez.
  static const String legacyAccentKey = 'accent_color_argb';
  static const String legacyDarkModeKey = 'is_dark_mode';

  final SharedPreferences _prefs;

  Color _accentColor = AppTheme.defaultAccent;
  bool _isDarkMode = true; // la app siempre arrancó en oscuro
  FontPreset _fontPreset = FontPresets.defaultPreset;
  bool _isReady = false;

  Color get accentColor => _accentColor;
  bool get isDarkMode => _isDarkMode;
  FontPreset get fontPreset => _fontPreset;
  bool get isReady => _isReady;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Tema resuelto para el modo actual. Lo usan tests y pantallas que
  /// necesiten un ThemeData sin pasar por MaterialApp.
  ThemeData get themeData => AppTheme.build(
    brightness: _isDarkMode ? Brightness.dark : Brightness.light,
    accent: _accentColor,
    fontPreset: _fontPreset,
  );

  /// Recupera acento, modo y tipografía guardados. Idempotente, como el
  /// init del CharacterStore.
  Future<void> init() async {
    if (_isReady) return;

    final storedAccent = _prefs.getInt(accentKey);
    final legacyAccent = _prefs.getInt(legacyAccentKey);
    if (storedAccent != null) {
      _accentColor = Color(storedAccent);
    } else if (legacyAccent != null) {
      _accentColor = Color(legacyAccent);
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

    // byId cae al preset por defecto si no hay nada guardado o si el id
    // es de una versión futura que este build no conoce.
    _fontPreset = FontPresets.byId(_prefs.getString(fontKey));

    _isReady = true;
    notifyListeners();
  }

  /// Cambia el acento y lo persiste. Mismo color = no-op (ni notifica).
  Future<void> setAccentColor(Color color) async {
    if (_accentColor == color) return;
    _accentColor = color;
    notifyListeners();
    await _prefs.setInt(accentKey, color.toARGB32());
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
