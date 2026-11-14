// Tests del SkinController y del tema (Etapa 6a).
//
// Cubren lo que no se ve en un widget test: valores iniciales, migración
// de las preferencias de la app vieja, persistencia entre reinicios,
// notificaciones y que el ThemeData resultante use la paleta semántica.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/core/theme/app_fonts.dart';
import 'package:easydnd/core/theme/app_palette.dart';
import 'package:easydnd/core/theme/app_theme.dart';
import 'package:easydnd/core/theme/app_theme_colors.dart';
import 'package:easydnd/core/theme/font_presets.dart';
import 'package:easydnd/state/skin_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Crea un controlador sobre los prefs mockeados. Llamarlo de nuevo
  /// simula "reiniciar la app": mismo almacenamiento, estado fresco.
  Future<SkinController> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final skin = SkinController(prefs);
    await skin.init();
    return skin;
  }

  group('valores iniciales', () {
    test('arranca en oscuro con el sepia de la app vieja', () async {
      final skin = await boot();

      expect(skin.isReady, isTrue);
      expect(skin.isDarkMode, isTrue);
      expect(skin.themeMode, ThemeMode.dark);
      expect(skin.accentColor, AppTheme.defaultAccent);
      expect(skin.fontPreset.id, FontPresets.defaultPreset.id);
    });

    test('la tipografía por defecto es "Diario"', () async {
      final skin = await boot();
      final textTheme = skin.themeData.textTheme;

      expect(skin.fontPreset.id, FontPresets.journal.id);
      expect(textTheme.titleLarge?.fontFamily, AppFonts.cinzel);
      expect(textTheme.bodyMedium?.fontFamily, AppFonts.inter);
    });

    test('el ThemeData sale de la paleta y del acento', () async {
      final skin = await boot();
      final theme = skin.themeData;
      final colors = theme.extension<AppThemeColors>()!;

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppTheme.defaultAccent);
      expect(theme.scaffoldBackgroundColor, AppPalette.dark.background);
      expect(colors.background, AppPalette.dark.background);
      expect(colors.surface, AppPalette.dark.surface);
      expect(colors.textPrimary, AppPalette.dark.textPrimary);
    });

    test('init es idempotente', () async {
      final skin = await boot();
      var notifications = 0;
      skin.addListener(() => notifications++);

      await skin.init();
      expect(notifications, 0);
    });

    test('onPrimary se resuelve por contraste, no por el seed', () {
      final darkAccent = AppTheme.dark(accent: const Color(0xFF0A0E17));
      expect(darkAccent.colorScheme.onPrimary, Colors.white);

      final lightAccent = AppTheme.dark(accent: const Color(0xFFFFF59D));
      expect(lightAccent.colorScheme.onPrimary, Colors.black);
    });
  });

  group('persistencia', () {
    test('el acento sobrevive a reiniciar', () async {
      final first = await boot();
      await first.setAccentColor(const Color(0xFF00AEEF));

      final second = await boot();
      expect(second.accentColor, const Color(0xFF00AEEF));
      expect(second.themeData.colorScheme.primary, const Color(0xFF00AEEF));
    });

    test('el modo claro sobrevive a reiniciar', () async {
      final first = await boot();
      await first.setDarkMode(false);

      final second = await boot();
      expect(second.isDarkMode, isFalse);
      expect(second.themeMode, ThemeMode.light);
      expect(second.themeData.brightness, Brightness.light);
      expect(
        second.themeData.scaffoldBackgroundColor,
        AppPalette.light.background,
      );
    });

    test('la tipografía sobrevive a reiniciar', () async {
      final first = await boot();
      await first.setFontPreset(FontPresets.console);

      expect(
        first.themeData.textTheme.titleLarge?.fontFamily,
        AppFonts.jetBrainsMono,
      );
      expect(
        first.themeData.textTheme.bodyMedium?.fontFamily,
        AppFonts.jetBrainsMono,
      );

      final second = await boot();
      expect(second.fontPreset.id, FontPresets.console.id);
      expect(
        second.themeData.textTheme.titleLarge?.fontFamily,
        AppFonts.jetBrainsMono,
      );
      expect(
        second.themeData.textTheme.bodyMedium?.fontFamily,
        AppFonts.jetBrainsMono,
      );
    });

    test('un id de tipografía desconocido cae al preset por defecto', () async {
      SharedPreferences.setMockInitialValues({
        SkinController.fontKey: 'tipografia-del-futuro',
      });

      final skin = await boot();
      expect(skin.fontPreset.id, FontPresets.defaultPreset.id);
    });

    test('migra las claves de la app vieja en el primer arranque', () async {
      SharedPreferences.setMockInitialValues({
        SkinController.legacyAccentKey: 0xFF00AEEF,
        SkinController.legacyDarkModeKey: false,
      });

      final skin = await boot();
      expect(skin.accentColor, const Color(0xFF00AEEF));
      expect(skin.isDarkMode, isFalse);

      // La migración no borra lo viejo, pero deja fijadas las claves
      // nuevas para que el próximo arranque no vuelva a migrar.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(SkinController.legacyAccentKey), 0xFF00AEEF);
      expect(prefs.getBool(SkinController.legacyDarkModeKey), isFalse);
      expect(prefs.getInt(SkinController.accentKey), 0xFF00AEEF);
      expect(prefs.getBool(SkinController.darkModeKey), isFalse);
    });

    test('las claves nuevas ganan sobre las legacy', () async {
      SharedPreferences.setMockInitialValues({
        SkinController.accentKey: 0xFF7C4DFF,
        SkinController.darkModeKey: true,
        SkinController.legacyAccentKey: 0xFF00FF00,
        SkinController.legacyDarkModeKey: false,
      });

      final skin = await boot();
      expect(skin.accentColor, const Color(0xFF7C4DFF));
      expect(skin.isDarkMode, isTrue);
    });
  });

  group('notificaciones', () {
    test('setAccentColor notifica y no repite el mismo color', () async {
      final skin = await boot();
      var notifications = 0;
      skin.addListener(() => notifications++);

      await skin.setAccentColor(const Color(0xFF7C4DFF));
      expect(notifications, 1);

      await skin.setAccentColor(const Color(0xFF7C4DFF));
      expect(notifications, 1);
    });

    test('toggleThemeMode alterna y no repite el mismo modo', () async {
      final skin = await boot();
      var notifications = 0;
      skin.addListener(() => notifications++);

      await skin.toggleThemeMode();
      expect(skin.isDarkMode, isFalse);
      expect(notifications, 1);

      await skin.toggleThemeMode();
      expect(skin.isDarkMode, isTrue);
      expect(notifications, 2);

      await skin.setDarkMode(true);
      expect(notifications, 2);
    });

    test('setFontPreset notifica y no repite el mismo preset', () async {
      final skin = await boot();
      var notifications = 0;
      skin.addListener(() => notifications++);

      await skin.setFontPreset(FontPresets.console);
      expect(notifications, 1);
      expect(
        skin.themeData.textTheme.bodyMedium?.fontFamily,
        AppFonts.jetBrainsMono,
      );

      await skin.setFontPreset(FontPresets.console);
      expect(notifications, 1);
    });
  });

  group('AppThemeColors', () {
    testWidgets('context.appColors expone la paleta del tema activo', (
      tester,
    ) async {
      final skin = await boot();
      late AppThemeColors colors;

      await tester.pumpWidget(
        MaterialApp(
          theme: skin.themeData,
          home: Builder(
            builder: (context) {
              colors = context.appColors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(colors.background, AppPalette.dark.background);
      expect(colors.border, AppPalette.dark.border);
      expect(colors.textSecondary, AppPalette.dark.textSecondary);
    });

    test('lerp interpola todos los roles', () async {
      final dark = AppThemeColors.fromPalette(AppPalette.dark);
      final light = AppThemeColors.fromPalette(AppPalette.light);

      final mid = dark.lerp(light, 0.5);
      expect(
        mid.background,
        Color.lerp(
          AppPalette.dark.background,
          AppPalette.light.background,
          0.5,
        ),
      );
      expect(
        mid.copyWith(surface: AppPalette.dark.surface).surface,
        AppPalette.dark.surface,
      );
    });
  });
}
