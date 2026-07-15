import 'package:flutter/material.dart';

/// Colores "de fase" (background/surface/border/textPrimary/textSecondary)
/// empaquetados como ThemeExtension. La ventaja frente a leerlos de
/// ThemeNotifier directamente: cualquier widget bajo MaterialApp los
/// obtiene con `context.appColors.xxx` usando Theme.of(context), que ya
/// se reconstruye solo cuando ThemeNotifier notifica un cambio — sin
/// tener que importar `provider` ni AppColors en cada archivo de UI.
///
/// AppColors.danger y AppColors.success NO están aquí a propósito: son
/// iguales en ambos modos, así que seguir usando AppColors.danger /
/// AppColors.success directamente sigue siendo correcto.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceLight,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

/// Azúcar sintáctico: `context.appColors.textSecondary` en vez de
/// `Theme.of(context).extension<AppThemeColors>()!.textSecondary`.
extension AppThemeColorsX on BuildContext {
  AppThemeColors get appColors => Theme.of(this).extension<AppThemeColors>()!;
}
