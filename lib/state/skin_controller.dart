// Controlador del skin de la app (Etapa 6): acento + modo claro/oscuro
// + tipografía + temas propios del editor.
//
// Temas propios: el jugador guarda varios [CustomTheme] con nombre. Cada
// modo (claro/oscuro) recuerda un tema propio activo; si lo hay, manda
// sobre el tema del catálogo de ese modo. El catálogo sigue existiendo
// (se elige desde un menú escondido en Mis temas) y es el destino cuando
// no hay tema propio activo.
//
// Es el equivalente rework de ThemeNotifier de la app vieja, pero
// separado del árbol de widgets: main() lo inicializa antes de pintar y
// EasyDnDApp lo escucha para reconstruir MaterialApp.
//
// Persistencia con claves propias (`easydnd.skin.*`) y migración de las
// claves legacy (`accent_color_argb` / `is_dark_mode`) en el primer
// arranque: el jugador que venía de la app vieja conserva su acento y su
// modo. Las claves viejas NO se borran (misma política que el roster).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/clean_theme.dart';
import '../core/theme/custom_theme.dart';
import '../core/theme/font_presets.dart';
import '../core/theme/theme_presets.dart';

class SkinController extends ChangeNotifier {
  SkinController(this._prefs);

  /// Claves nuevas del rework.
  static const String accentKey = 'easydnd.skin.accent.v1';
  static const String darkModeKey = 'easydnd.skin.dark.v1';
  static const String fontKey = 'easydnd.skin.font.v1';
  static const String compactKey = 'easydnd.skin.compact.v1';
  static const String tabletKey = 'easydnd.skin.tablet.v1';

  /// Forma elegida en Ajustes (id de [CleanThemeStyle]); ausente = Limpio.
  static const String styleKey = 'easydnd.skin.style.v1';

  /// Color secundario elegido (ARGB); ausente = recomendación automática.
  static const String secondaryKey = 'easydnd.skin.secondary.v1';

  /// Último tema OSCURO elegido (id de [AppThemePreset]). El modo
  /// claro/oscuro en sí es [darkModeKey].
  static const String themeKey = 'easydnd.skin.theme.v1';

  /// Último tema CLARO elegido; ausente = Pergamino.
  static const String lightThemeKey = 'easydnd.skin.theme.light.v1';

  /// Temas propios: lista de JSON (uno por tema).
  static const String customThemesKey = 'easydnd.skin.custom_themes.v1';

  /// Id del tema propio activo en modo oscuro / claro (ausente = catálogo).
  static const String darkCustomKey = 'easydnd.skin.custom.dark.v1';
  static const String lightCustomKey = 'easydnd.skin.custom.light.v1';

  /// Modo del editor de temas: sencillo (por defecto) o avanzado.
  static const String simpleEditorKey = 'easydnd.skin.editor.simple.v1';

  /// Claves de la app vieja, solo para migrar una vez.
  static const String legacyAccentKey = 'accent_color_argb';
  static const String legacyDarkModeKey = 'is_dark_mode';

  final SharedPreferences _prefs;

  /// Acento elegido a mano por el jugador. `null` = usar el acento de
  /// firma del tema activo.
  Color? _customAccent;
  AppThemePreset _darkPreset = AppThemePreset.defaultDark;
  AppThemePreset _lightPreset = AppThemePreset.defaultLight;
  bool _isDarkMode = true; // la app siempre arrancó en oscuro
  CleanThemeStyle _style = CleanThemeStyle.defaultStyle;
  Color? _customSecondary;
  FontPreset _fontPreset = FontPresets.defaultPreset;
  bool _isReady = false;

  final List<CustomTheme> _customThemes = [];
  String? _darkCustomId;
  String? _lightCustomId;

  /// Temas propios guardados, en el orden en que se crearon.
  List<CustomTheme> get customThemes => List.unmodifiable(_customThemes);

  CustomTheme? _customById(String? id) {
    if (id == null) return null;
    for (final t in _customThemes) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Tema propio activo en el modo actual, o null si manda el catálogo.
  CustomTheme? get activeCustomTheme =>
      _customById(_isDarkMode ? _darkCustomId : _lightCustomId);

  /// Nombre del tema que se está viendo (propio o del catálogo).
  String get activeThemeName => activeCustomTheme?.name ?? themePreset.label;

  /// Vista compacta del HUD: menos secciones y controles más densos.
  bool _compactHud = false;
  bool get compactHud => _compactHud;

  /// Layout adaptable del HUD (riel lateral y paneles en pantallas
  /// anchas). Apagarlo fuerza el layout de teléfono a cualquier ancho,
  /// útil para depurar. Activo por defecto.
  bool _tabletMode = true;
  bool get tabletMode => _tabletMode;

  /// El editor de temas abre en modo sencillo salvo que el jugador haya
  /// elegido el avanzado la última vez.
  bool _simpleThemeEditor = true;
  bool get simpleThemeEditor => _simpleThemeEditor;

  /// Forma de Ajustes (una de las tres de [CleanThemeStyle]).
  CleanThemeStyle get themeStyle => _style;

  /// Color principal efectivo: el propio del jugador o el de fábrica.
  Color get accentColor => _customAccent ?? AppTheme.defaultAccent;

  Brightness get _brightness =>
      _isDarkMode ? Brightness.dark : Brightness.light;

  /// Color secundario efectivo: el elegido o la recomendación automática
  /// para el principal en el modo actual.
  Color get secondaryColor =>
      _customSecondary ?? SecondaryColors.auto(accentColor, _brightness);

  /// true si el jugador eligió un secundario (no el automático).
  bool get hasCustomSecondary => _customSecondary != null;

  /// Recomendaciones de secundario para el principal y el modo actuales.
  List<({String label, Color color})> get secondaryRecommendations =>
      SecondaryColors.recommend(accentColor, _brightness);

  /// true si el jugador pisó el acento de firma con un color propio.
  bool get hasCustomAccent => _customAccent != null;

  /// Tema activo: el claro elegido en modo claro, el oscuro elegido si no.
  AppThemePreset get themePreset => _isDarkMode ? _darkPreset : _lightPreset;

  /// Tema oscuro al que vuelve el toggle claro/oscuro.
  AppThemePreset get darkPreset => _darkPreset;

  /// Tema claro al que vuelve el toggle claro/oscuro.
  AppThemePreset get lightPreset => _lightPreset;
  bool get isDarkMode => _isDarkMode;
  FontPreset get fontPreset => _fontPreset;
  bool get isReady => _isReady;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Tema resuelto para el modo actual. Lo usan tests y pantallas que
  /// necesiten un ThemeData sin pasar por MaterialApp.
  ThemeData get themeData => _isDarkMode ? darkTheme : lightTheme;

  /// Tema del modo claro. Desde el rework para novatos la app tiene un
  /// único diseño limpio ([AppTheme.clean]) vestido con uno de tres
  /// temas: el jugador elige tema, acento y claro/oscuro. Presets y temas
  /// propios siguen guardados pero ya no construyen el tema (ADR-0007).
  ThemeData get lightTheme => AppTheme.clean(
    brightness: Brightness.light,
    accent: _customAccent,
    secondary: _customSecondary,
    style: _style,
  );

  /// Tema del modo oscuro (mismo diseño limpio).
  ThemeData get darkTheme => AppTheme.clean(
    brightness: Brightness.dark,
    accent: _customAccent,
    secondary: _customSecondary,
    style: _style,
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
    final storedLight = AppThemePreset.byId(_prefs.getString(lightThemeKey));
    if (storedLight != null && !storedLight.isDark) _lightPreset = storedLight;

    // byId cae al preset por defecto si no hay nada guardado o si el id
    // es de una versión futura que este build no conoce.
    _fontPreset = FontPresets.byId(_prefs.getString(fontKey));

    // Temas propios: un JSON roto se salta, no tumba el arranque.
    for (final raw in _prefs.getStringList(customThemesKey) ?? const []) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _customThemes.add(CustomTheme.fromJson(decoded));
        }
      } catch (_) {
        // Entrada corrupta: se ignora.
      }
    }
    final darkCustom = _customById(_prefs.getString(darkCustomKey));
    if (darkCustom != null && darkCustom.isDark) _darkCustomId = darkCustom.id;
    final lightCustom = _customById(_prefs.getString(lightCustomKey));
    if (lightCustom != null && !lightCustom.isDark) {
      _lightCustomId = lightCustom.id;
    }

    _style = CleanThemeStyle.byId(_prefs.getString(styleKey));
    final storedSecondary = _prefs.getInt(secondaryKey);
    if (storedSecondary != null) _customSecondary = Color(storedSecondary);

    _compactHud = _prefs.getBool(compactKey) ?? false;
    _tabletMode = _prefs.getBool(tabletKey) ?? true;
    _simpleThemeEditor = _prefs.getBool(simpleEditorKey) ?? true;

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

  /// Elige un tema del catálogo y lo persiste. Cada tema pasa a ser el
  /// destino del toggle de su modo (claro u oscuro). Elegir
  /// un tema restaura su acento y su tipografía de firma: quien quiera otro
  /// color o fuente los vuelve a elegir en Apariencia.
  Future<void> setThemePreset(AppThemePreset preset) async {
    final signatureFont = FontPresets.byId(preset.fontPresetId);
    if (themePreset == preset &&
        activeCustomTheme == null &&
        _customAccent == null &&
        _fontPreset.id == signatureFont.id) {
      return;
    }
    final hadAccent = _customAccent != null;
    final fontChanged = _fontPreset.id != signatureFont.id;
    _customAccent = null;
    _fontPreset = signatureFont;
    _isDarkMode = preset.isDark;
    if (preset.isDark) {
      _darkPreset = preset;
    } else {
      _lightPreset = preset;
    }
    // Elegir del catálogo apaga el tema propio de ese modo.
    if (preset.isDark) {
      _darkCustomId = null;
    } else {
      _lightCustomId = null;
    }
    notifyListeners();
    await _prefs.setBool(darkModeKey, _isDarkMode);
    await _prefs.setString(preset.isDark ? themeKey : lightThemeKey, preset.id);
    await _prefs.remove(preset.isDark ? darkCustomKey : lightCustomKey);
    if (hadAccent) await _prefs.remove(accentKey);
    if (fontChanged) await _prefs.setString(fontKey, signatureFont.id);
  }

  /// Elige una de las tres formas de Ajustes y la persiste. No toca los
  /// colores.
  Future<void> setThemeStyle(CleanThemeStyle style) async {
    if (_style == style) return;
    _style = style;
    notifyListeners();
    await _prefs.setString(styleKey, style.id);
  }

  /// Fija el color secundario y lo persiste. Mismo color = no-op.
  Future<void> setSecondaryColor(Color color) async {
    if (_customSecondary == color) return;
    _customSecondary = color;
    notifyListeners();
    await _prefs.setInt(secondaryKey, color.toARGB32());
  }

  /// Vuelve al secundario automático (sigue al principal).
  Future<void> clearCustomSecondary() async {
    if (_customSecondary == null) return;
    _customSecondary = null;
    notifyListeners();
    await _prefs.remove(secondaryKey);
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

  /// Activa o desactiva la vista compacta del HUD y la persiste.
  Future<void> setCompactHud(bool value) async {
    if (_compactHud == value) return;
    _compactHud = value;
    notifyListeners();
    await _prefs.setBool(compactKey, value);
  }

  /// Activa o desactiva el modo tablet (layout adaptable) y lo persiste.
  Future<void> setTabletMode(bool value) async {
    if (_tabletMode == value) return;
    _tabletMode = value;
    notifyListeners();
    await _prefs.setBool(tabletKey, value);
  }

  Future<void> toggleThemeMode() => setDarkMode(!_isDarkMode);

  /// Recuerda el modo del editor de temas (sencillo / avanzado).
  Future<void> setSimpleThemeEditor(bool value) async {
    if (_simpleThemeEditor == value) return;
    _simpleThemeEditor = value;
    notifyListeners();
    await _prefs.setBool(simpleEditorKey, value);
  }

  // -------------------------------------------------------------------
  // Temas propios.
  // -------------------------------------------------------------------

  String _newId() => 'custom_${DateTime.now().microsecondsSinceEpoch}';

  /// Borrador de tema nuevo copiando el aspecto que se ve ahora (tema
  /// propio activo o el del catálogo). No se guarda hasta [saveCustomTheme].
  CustomTheme draftFromActive({String? name}) {
    final active = activeCustomTheme;
    final id = _newId();
    final base = active != null
        ? active.copyWith(id: id)
        : CustomTheme.fromPreset(themePreset, id: id);
    // El acento propio de Apariencia, si lo hay, pasa a ser el del tema.
    final accent = _customAccent;
    return base.copyWith(
      name: name ?? 'Mi tema ${_customThemes.length + 1}',
      fontPresetId: _fontPreset.id,
      tactical: accent == null ? null : base.tactical.copyWith(primary: accent),
    );
  }

  /// Guarda (alta o edición) un tema propio. Con [activate] queda activo
  /// en su modo. Si cambió de claro a oscuro (o al revés) y estaba
  /// activo, se mueve al modo nuevo.
  Future<void> saveCustomTheme(
    CustomTheme theme, {
    bool activate = true,
  }) async {
    final index = _customThemes.indexWhere((t) => t.id == theme.id);
    final wasActive = _darkCustomId == theme.id || _lightCustomId == theme.id;
    if (index >= 0) {
      _customThemes[index] = theme;
    } else {
      _customThemes.add(theme);
    }
    if (_darkCustomId == theme.id && !theme.isDark) _darkCustomId = null;
    if (_lightCustomId == theme.id && theme.isDark) _lightCustomId = null;
    await _persistCustomThemes();
    if (activate || wasActive) {
      await activateCustomTheme(theme.id);
    } else {
      notifyListeners();
      await _persistCustomSlots();
    }
  }

  /// Activa un tema propio: pasa a su modo, aplica su tipografía de firma
  /// y descarta el acento suelto de Apariencia (el tema trae el suyo).
  Future<void> activateCustomTheme(String id) async {
    final theme = _customById(id);
    if (theme == null) return;
    if (theme.isDark) {
      _darkCustomId = id;
    } else {
      _lightCustomId = id;
    }
    _isDarkMode = theme.isDark;
    final hadAccent = _customAccent != null;
    _customAccent = null;
    _fontPreset = FontPresets.byId(theme.fontPresetId);
    notifyListeners();
    await _prefs.setBool(darkModeKey, _isDarkMode);
    await _prefs.setString(fontKey, _fontPreset.id);
    if (hadAccent) await _prefs.remove(accentKey);
    await _persistCustomSlots();
  }

  /// Copia un tema propio con otro nombre (no lo activa).
  Future<CustomTheme?> duplicateCustomTheme(String id) async {
    final source = _customById(id);
    if (source == null) return null;
    final copy = source.copyWith(id: _newId(), name: '${source.name} (copia)');
    _customThemes.add(copy);
    notifyListeners();
    await _persistCustomThemes();
    return copy;
  }

  /// Borra un tema propio. Si estaba activo, su modo vuelve al catálogo.
  Future<void> deleteCustomTheme(String id) async {
    final before = _customThemes.length;
    _customThemes.removeWhere((t) => t.id == id);
    if (_customThemes.length == before) return;
    if (_darkCustomId == id) _darkCustomId = null;
    if (_lightCustomId == id) _lightCustomId = null;
    notifyListeners();
    await _persistCustomThemes();
    await _persistCustomSlots();
  }

  Future<void> _persistCustomThemes() => _prefs.setStringList(customThemesKey, [
    for (final t in _customThemes) jsonEncode(t.toJson()),
  ]);

  Future<void> _persistCustomSlots() async {
    final dark = _darkCustomId;
    final light = _lightCustomId;
    if (dark == null) {
      await _prefs.remove(darkCustomKey);
    } else {
      await _prefs.setString(darkCustomKey, dark);
    }
    if (light == null) {
      await _prefs.remove(lightCustomKey);
    } else {
      await _prefs.setString(lightCustomKey, light);
    }
  }
}
