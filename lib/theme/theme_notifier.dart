import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'app_theme_extension.dart';

/// Controla el color de acento libre (elegido con el HsvColorPickerDialog)
/// Y el modo claro/oscuro, y persiste ambos en SharedPreferences.
///
/// Fase 5: el fondo YA NO es fijo. En modo oscuro sigue siendo exactamente
/// AppColors.background (nada cambia ahí); en modo claro pasa a la paleta
/// light* de AppColors. Quien decide cuál usar es _isDarkMode, guardado
/// igual que el acento para que sobreviva a reinicios de la app.
/// Nada de const: el ThemeData completo se reconstruye cada vez que
/// cambia el acento O el modo.
class ThemeNotifier extends ChangeNotifier {
  static const _accentColorPrefsKey = 'accent_color_argb';
  static const _darkModePrefsKey = 'is_dark_mode';

  Color _accentColor = AppColors.defaultAccent;
  bool _isDarkMode = true; // por defecto seguimos arrancando en oscuro, como hasta ahora
  bool _isReady = false;

  Color get accentColor => _accentColor;
  bool get isDarkMode => _isDarkMode;
  bool get isReady => _isReady;

  // Getters de color "resueltos": devuelven la variante oscura o clara
  // según el modo activo. Úsalos en vez de AppColors.xxx directamente en
  // cualquier widget que deba respetar el modo claro (p. ej. el diálogo
  // del selector de color).
  Color get backgroundColor => _isDarkMode ? AppColors.background : AppColors.lightBackground;
  Color get surfaceColor => _isDarkMode ? AppColors.surface : AppColors.lightSurface;
  Color get surfaceLightColor => _isDarkMode ? AppColors.surfaceLight : AppColors.lightSurfaceLight;
  Color get borderColor => _isDarkMode ? AppColors.border : AppColors.lightBorder;
  Color get textPrimaryColor => _isDarkMode ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get textSecondaryColor => _isDarkMode ? AppColors.textSecondary : AppColors.lightTextSecondary;

  /// Se llama una vez al arrancar la app, antes de pintar el HUD real,
  /// para recuperar el acento y el modo guardados en la sesión anterior.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final storedColor = prefs.getInt(_accentColorPrefsKey);
    if (storedColor != null) {
      _accentColor = Color(storedColor);
    }
    // Si nunca se ha guardado el modo, se queda en el default (true = oscuro),
    // así que el comportamiento actual no cambia para usuarios existentes.
    _isDarkMode = prefs.getBool(_darkModePrefsKey) ?? true;
    _isReady = true;
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // Guardamos el entero ARGB de 32 bits del color. Si tu SDK de Flutter
    // marca `.value` como deprecado y prefieres `.toARGB32()`, son
    // equivalentes: cambia esta línea sin tocar nada más.
    await prefs.setInt(_accentColorPrefsKey, color.value);
  }

  /// Alterna entre modo oscuro y claro y lo persiste. Al notificar,
  /// cualquier widget que escuche ThemeNotifier (incluido MaterialApp con
  /// `themeData`) se reconstruye con la nueva paleta.
  Future<void> toggleThemeMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModePrefsKey, _isDarkMode);
  }

  /// Por si prefieres fijar el modo directamente (p. ej. desde un Switch
  /// en vez de un botón que alterna) en lugar de togglear.
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModePrefsKey, _isDarkMode);
  }

  ThemeData get themeData {
    return ThemeData(
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: 'serif',
      colorScheme: (_isDarkMode ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: _accentColor,
        secondary: _accentColor,
        surface: surfaceColor,
        onSurface: textPrimaryColor,
        error: AppColors.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: _accentColor,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: _accentColor.withOpacity(0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? _accentColor : textSecondaryColor);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? _accentColor : textSecondaryColor,
            fontSize: 12,
            fontFamily: 'serif',
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          );
        }),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: textPrimaryColor, fontFamily: 'serif'),
        bodySmall: TextStyle(color: textSecondaryColor, fontFamily: 'serif'),
        titleLarge: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontFamily: 'serif'),
      ),
      // Esto es lo que hace posible `context.appColors.xxx` en cualquier
      // widget de la app: queda colgado del ThemeData, así que se
      // reconstruye solo cuando MaterialApp recibe un themeData nuevo.
      extensions: [
        AppThemeColors(
          background: backgroundColor,
          surface: surfaceColor,
          surfaceLight: surfaceLightColor,
          border: borderColor,
          textPrimary: textPrimaryColor,
          textSecondary: textSecondaryColor,
        ),
      ],
      useMaterial3: true,
    );
  }
}
