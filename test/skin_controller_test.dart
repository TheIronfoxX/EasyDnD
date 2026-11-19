// Tests del SkinController y del tema (Etapa 6a).
//
// Cubren lo que no se ve en un widget test: valores iniciales, migración
// de las preferencias de la app vieja, persistencia entre reinicios,
// notificaciones y que el ThemeData resultante use la paleta semántica.

import 'package:flutter/material.dart';
import 'package:easydnd/core/theme/clean_shape.dart';
import 'package:easydnd/core/theme/clean_theme.dart';
import 'package:easydnd/core/theme/tactical_theme_tokens.dart';
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

    test('el tema limpio lee en Inter y titula en mono', () async {
      final skin = await boot();
      final textTheme = skin.themeData.textTheme;

      expect(textTheme.titleLarge?.fontFamily, AppFonts.inter);
      expect(textTheme.labelSmall?.fontFamily, AppFonts.inter);
      expect(textTheme.titleMedium?.fontFamily, AppFonts.inter);
      expect(textTheme.bodyMedium?.fontFamily, AppFonts.inter);
    });

    test('el ThemeData sale de la paleta y del acento', () async {
      final skin = await boot();
      final theme = skin.themeData;
      final colors = theme.extension<AppThemeColors>()!;

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppTheme.defaultAccent);
      expect(theme.scaffoldBackgroundColor, CleanTheme.darkPalette.background);
      expect(colors.background, CleanTheme.darkPalette.background);
      expect(colors.surface, CleanTheme.darkPalette.surface);
      expect(colors.textPrimary, CleanTheme.darkPalette.textPrimary);
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

  group('tema limpio', () {
    test('tarjetas, hojas y diálogos sin borde ni versalitas', () async {
      final skin = await boot();
      final theme = skin.themeData;

      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder?;
      expect(cardShape?.side, BorderSide.none);
      final sheetShape =
          theme.bottomSheetTheme.shape as RoundedRectangleBorder?;
      expect(sheetShape?.side, BorderSide.none);
      expect(theme.textTheme.titleLarge?.letterSpacing, 0);
      expect(
        theme.extension<TacticalThemeTokens>()!.cards.doubleBorder,
        isFalse,
      );
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
        CleanTheme.lightPalette.background,
      );
    });

    test(
      'la tipografía elegida se guarda aunque el tema limpio use Inter',
      () async {
        final first = await boot();
        await first.setFontPreset(FontPresets.console);

        final second = await boot();
        expect(second.fontPreset.id, FontPresets.console.id);
        expect(
          second.themeData.textTheme.bodyMedium?.fontFamily,
          AppFonts.inter,
        );
      },
    );

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

      expect(colors.background, CleanTheme.darkPalette.background);
      expect(colors.border, CleanTheme.darkPalette.border);
      expect(colors.textSecondary, CleanTheme.darkPalette.textSecondary);
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

  group('temas de Ajustes', () {
    test('arranca en Limpio', () async {
      final skin = await boot();
      expect(skin.themeStyle, CleanThemeStyle.limpio);
    });

    test('la forma no toca colores ni fondo, y persiste', () async {
      final skin = await boot();
      await skin.setAccentColor(const Color(0xFF00AEEF));
      await skin.setThemeStyle(CleanThemeStyle.grimorio);

      expect(skin.accentColor, const Color(0xFF00AEEF));
      expect(
        skin.darkTheme.scaffoldBackgroundColor,
        CleanTheme.darkPalette.background,
      );
      expect(
        skin.lightTheme.scaffoldBackgroundColor,
        CleanTheme.lightPalette.background,
      );

      final again = await boot();
      expect(again.themeStyle, CleanThemeStyle.grimorio);
    });

    test(
      'secundario: automático sigue al principal, elegido persiste',
      () async {
        final skin = await boot();
        expect(skin.hasCustomSecondary, isFalse);
        expect(
          skin.secondaryColor,
          SecondaryColors.auto(skin.accentColor, Brightness.dark),
        );
        expect(skin.themeData.colorScheme.secondary, skin.secondaryColor);

        await skin.setAccentColor(const Color(0xFF00AEEF));
        expect(
          skin.secondaryColor,
          SecondaryColors.auto(const Color(0xFF00AEEF), Brightness.dark),
        );

        await skin.setSecondaryColor(const Color(0xFF7C4DFF));
        final again = await boot();
        expect(again.secondaryColor, const Color(0xFF7C4DFF));
        expect(
          again.themeData.extension<TacticalThemeTokens>()!.spell,
          const Color(0xFF7C4DFF),
        );

        await again.clearCustomSecondary();
        expect(again.hasCustomSecondary, isFalse);
      },
    );

    test('las recomendaciones son distintas entre sí y del principal', () {
      const primary = Color(0xFFE5242C);
      final recs = SecondaryColors.recommend(primary, Brightness.dark);
      expect(recs, hasLength(5));
      expect(recs.map((r) => r.color).toSet(), hasLength(5));
      expect(recs.every((r) => r.color != primary), isTrue);
    });

    test('el fondo sigue liso en todos los temas', () {
      for (final style in CleanThemeStyle.values) {
        for (final b in Brightness.values) {
          final t = AppTheme.clean(brightness: b, style: style);
          expect(
            t.extension<TacticalThemeTokens>()!.background.patternOpacity,
            0,
          );
        }
      }
    });

    test('cada tema trae su silueta', () {
      CleanShape shapeOf(CleanThemeStyle s) => AppTheme.clean(
        brightness: Brightness.dark,
        style: s,
      ).extension<CleanShape>()!;

      final limpio = shapeOf(CleanThemeStyle.limpio);
      final grimorio = shapeOf(CleanThemeStyle.grimorio);
      final escarcha = shapeOf(CleanThemeStyle.escarcha);
      expect(limpio.r(16), 16);
      expect(limpio.outline, isNull);
      expect(grimorio.r(16), lessThan(limpio.r(16)));
      expect(grimorio.outline, isNotNull);
      expect(escarcha.surface(16), isA<BeveledRectangleBorder>());
    });

    test('un id desconocido cae a Limpio', () {
      expect(CleanThemeStyle.byId('nope'), CleanThemeStyle.limpio);
    });
  });
}
