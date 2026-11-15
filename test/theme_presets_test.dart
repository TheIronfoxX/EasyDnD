// Sistema multi-tema (rework estético): catálogo de cinco temas,
// TacticalPalette, persistencia y contrato con el modo claro/oscuro.
//
// El contrato que se verifica acá: "Pergamino" ES el modo claro, los
// otros cuatro son oscuros, y el toggle de siempre alterna entre
// Pergamino y el último tema oscuro elegido.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/core/theme/app_palette.dart';
import 'package:easydnd/core/theme/app_theme.dart';
import 'package:easydnd/core/theme/app_theme_colors.dart';
import 'package:easydnd/core/theme/tactical_palette.dart';
import 'package:easydnd/core/theme/theme_presets.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/state/character_store.dart';
import 'package:easydnd/state/skin_controller.dart';

import 'fakes/test_fichas.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Controlador nuevo sobre el mismo almacenamiento: "reiniciar la app".
  Future<SkinController> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final skin = SkinController(prefs);
    await skin.init();
    return skin;
  }

  Future<CharacterStore> bootStore() async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    return store;
  }

  group('catálogo', () {
    test('son cinco temas con id único: uno claro y cuatro oscuros', () {
      expect(AppThemePreset.values, hasLength(5));
      expect(
        AppThemePreset.values.map((p) => p.id).toSet(),
        hasLength(AppThemePreset.values.length),
      );
      expect(AppThemePreset.values.where((p) => !p.isDark), [
        AppThemePreset.pergamino,
      ]);
      expect(AppThemePreset.defaultDark, AppThemePreset.grimorio);
      expect(AppThemePreset.defaultLight, AppThemePreset.pergamino);
    });

    test('Grimorio y Pergamino son las paletas oscura y clara de fábrica', () {
      expect(AppThemePreset.grimorio.palette, AppPalette.dark);
      expect(AppThemePreset.grimorio.accent, AppTheme.defaultAccent);
      expect(AppThemePreset.pergamino.palette, AppPalette.light);
    });

    test('cada tema arma un ThemeData con su paleta y su TacticalPalette', () {
      for (final preset in AppThemePreset.values) {
        final theme = AppTheme.build(preset: preset);
        final colors = theme.extension<AppThemeColors>()!;
        final tactical = theme.extension<TacticalPalette>()!;

        expect(theme.brightness, preset.brightness, reason: preset.id);
        expect(theme.scaffoldBackgroundColor, preset.palette.background);
        expect(theme.colorScheme.primary, preset.accent);
        expect(colors.surface, preset.palette.surface);
        expect(tactical, same(preset.tactical));

        // Los cinco roles de juego se distinguen entre sí dentro del tema.
        final roles = {
          tactical.weapon,
          tactical.spell,
          tactical.ability,
          tactical.heal,
          tactical.damage,
        };
        expect(roles, hasLength(5), reason: preset.id);
      }
    });

    test('alto contraste: tinta y roles legibles sobre la superficie', () {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance();
        final lb = b.computeLuminance();
        final hi = la > lb ? la : lb;
        final lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final preset in AppThemePreset.values) {
        final surface = preset.palette.surface;
        final t = preset.tactical;
        expect(
          contrast(preset.palette.textPrimary, surface),
          greaterThan(7),
          reason: '${preset.id}: textPrimary',
        );
        expect(
          contrast(preset.palette.textSecondary, surface),
          greaterThan(4.5),
          reason: '${preset.id}: textSecondary',
        );
        for (final role in [
          preset.accent,
          t.weapon,
          t.spell,
          t.ability,
          t.heal,
          t.damage,
        ]) {
          expect(
            contrast(role, surface),
            greaterThan(4),
            reason: '${preset.id}: $role',
          );
        }
      }
    });

    test('TacticalPalette interpola y copia como ThemeExtension', () {
      final a = AppThemePreset.grimorio.tactical;
      final b = AppThemePreset.forjaArcana.tactical;

      expect(a.lerp(b, 0).spell, a.spell);
      expect(a.lerp(b, 1).spell, b.spell);
      expect(a.lerp(b, 0.5).spell, Color.lerp(a.spell, b.spell, 0.5));
      expect(a.lerp(null, 0.5), same(a));
      expect(a.copyWith(heal: b.heal).heal, b.heal);
      expect(a.copyWith(heal: b.heal).weapon, a.weapon);
      expect(a.headerGradient.colors, [a.headerStart, a.headerEnd]);
    });

    test('byId resuelve ids conocidos y devuelve null con el resto', () {
      expect(AppThemePreset.byId('forja_arcana'), AppThemePreset.forjaArcana);
      expect(AppThemePreset.byId('no-existe'), isNull);
      expect(AppThemePreset.byId(null), isNull);
    });
  });

  group('SkinController', () {
    test('arranca en Grimorio', () async {
      final skin = await boot();
      expect(skin.themePreset, AppThemePreset.grimorio);
      expect(skin.isDarkMode, isTrue);
      expect(skin.hasCustomAccent, isFalse);
    });

    test('recorre los cinco temas y el ThemeData los sigue', () async {
      final skin = await boot();

      for (final preset in AppThemePreset.values) {
        await skin.setThemePreset(preset);

        expect(skin.themePreset, preset);
        expect(skin.isDarkMode, preset.isDark);
        expect(skin.accentColor, preset.accent);
        expect(
          skin.themeData.scaffoldBackgroundColor,
          preset.palette.background,
        );
        expect(
          skin.themeData.extension<TacticalPalette>(),
          same(preset.tactical),
        );
      }
    });

    test('cada tema elegido sobrevive al reinicio', () async {
      for (final preset in AppThemePreset.values) {
        final first = await boot();
        await first.setThemePreset(preset);

        final second = await boot();
        expect(second.themePreset, preset, reason: preset.id);
        expect(second.themeData.brightness, preset.brightness);
      }
    });

    test('el toggle alterna entre Pergamino y el tema oscuro activo', () async {
      final skin = await boot();
      await skin.setThemePreset(AppThemePreset.sangreYHierro);

      await skin.toggleThemeMode();
      expect(skin.isDarkMode, isFalse);
      expect(skin.themeMode, ThemeMode.light);
      expect(skin.themePreset, AppThemePreset.pergamino);
      expect(
        skin.themeData.scaffoldBackgroundColor,
        AppPalette.light.background,
      );
      // El oscuro elegido queda recordado mientras se está en claro.
      expect(skin.darkPreset, AppThemePreset.sangreYHierro);

      await skin.toggleThemeMode();
      expect(skin.isDarkMode, isTrue);
      expect(skin.themePreset, AppThemePreset.sangreYHierro);

      // Y también a través de un reinicio hecho en modo claro.
      await skin.setDarkMode(false);
      final restarted = await boot();
      expect(restarted.themePreset, AppThemePreset.pergamino);
      await restarted.setDarkMode(true);
      expect(restarted.themePreset, AppThemePreset.sangreYHierro);
    });

    test('elegir Pergamino equivale a pasar a modo claro', () async {
      final skin = await boot();
      await skin.setThemePreset(AppThemePreset.sendaSilvestre);
      await skin.setThemePreset(AppThemePreset.pergamino);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SkinController.darkModeKey), isFalse);
      // Pergamino no pisa el oscuro guardado.
      expect(
        prefs.getString(SkinController.themeKey),
        AppThemePreset.sendaSilvestre.id,
      );
    });

    test(
      'un acento propio manda sobre el de firma en cualquier tema',
      () async {
        final skin = await boot();
        const custom = Color(0xFF7C4DFF);
        await skin.setAccentColor(custom);

        expect(skin.hasCustomAccent, isTrue);
        await skin.setDarkMode(false);
        expect(skin.themeData.colorScheme.primary, custom);
        await skin.setDarkMode(true);
        expect(skin.themeData.colorScheme.primary, custom);

        // Elegir un tema restaura su acento de firma (y lo persiste).
        await skin.setThemePreset(AppThemePreset.forjaArcana);
        expect(skin.hasCustomAccent, isFalse);
        expect(skin.accentColor, AppThemePreset.forjaArcana.accent);

        final restarted = await boot();
        expect(restarted.accentColor, AppThemePreset.forjaArcana.accent);
      },
    );

    test('clearCustomAccent vuelve al acento de firma', () async {
      final skin = await boot();
      await skin.setAccentColor(const Color(0xFF7C4DFF));
      await skin.clearCustomAccent();

      expect(skin.accentColor, AppThemePreset.grimorio.accent);
      expect((await boot()).hasCustomAccent, isFalse);
    });

    test('un id de tema desconocido o claro cae a Grimorio', () async {
      SharedPreferences.setMockInitialValues({
        SkinController.themeKey: 'tema-del-futuro',
      });
      expect((await boot()).themePreset, AppThemePreset.grimorio);

      SharedPreferences.setMockInitialValues({
        SkinController.themeKey: AppThemePreset.pergamino.id,
      });
      final skin = await boot();
      expect(skin.isDarkMode, isTrue);
      expect(skin.darkPreset, AppThemePreset.grimorio);
    });

    test('reelegir el tema activo no notifica', () async {
      final skin = await boot();
      await skin.setThemePreset(AppThemePreset.forjaArcana);

      var notifications = 0;
      skin.addListener(() => notifications++);
      await skin.setThemePreset(AppThemePreset.forjaArcana);
      expect(notifications, 0);
    });
  });

  group('selector visual', () {
    Future<SkinController> pumpApp(
      WidgetTester tester,
      CharacterStore store,
    ) async {
      final skin = await boot();
      await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
      await tester.pumpAndSettle();
      return skin;
    }

    Finder swatch(AppThemePreset preset) =>
        find.byKey(ValueKey('theme-swatch-${preset.id}'));

    testWidgets('la bienvenida abre el selector y recorre los cinco temas', (
      tester,
    ) async {
      final store = await bootStore();
      final skin = await pumpApp(tester, store);

      await tester.tap(find.byTooltip('Temas'));
      await tester.pumpAndSettle();

      for (final preset in AppThemePreset.values) {
        expect(swatch(preset), findsOneWidget);
      }

      for (final preset in AppThemePreset.values.reversed) {
        await tester.tap(swatch(preset));
        await tester.pumpAndSettle();

        expect(skin.themePreset, preset);
        final theme = Theme.of(tester.element(find.text('EasyDnD')));
        expect(theme.brightness, preset.brightness);
        expect(theme.scaffoldBackgroundColor, preset.palette.background);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('theme-active-label')))
              .data,
          preset.label,
        );
      }
    });

    testWidgets('el menú del HUD abre el selector y el tema se persiste', (
      tester,
    ) async {
      final store = await bootStore();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      final skin = await pumpApp(tester, store);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temas'));
      await tester.pumpAndSettle();

      await tester.tap(swatch(AppThemePreset.sendaSilvestre));
      await tester.pumpAndSettle();

      expect(skin.themePreset, AppThemePreset.sendaSilvestre);
      final context = tester.element(find.text('Rook'));
      expect(
        context.tactical.spell,
        AppThemePreset.sendaSilvestre.tactical.spell,
      );
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        AppPalette.wild.background,
      );

      final restarted = await boot();
      expect(restarted.themePreset, AppThemePreset.sendaSilvestre);
    });

    testWidgets('Apariencia: el tema y el modo claro/oscuro conviven', (
      tester,
    ) async {
      final store = await bootStore();
      final skin = await pumpApp(tester, store);

      await tester.tap(find.byTooltip('Apariencia'));
      await tester.pumpAndSettle();

      await tester.tap(swatch(AppThemePreset.forjaArcana));
      await tester.pumpAndSettle();
      expect(skin.themePreset, AppThemePreset.forjaArcana);

      // El toggle de siempre lleva a Pergamino…
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      expect(skin.themePreset, AppThemePreset.pergamino);
      expect(
        Theme.of(tester.element(find.text('Apariencia'))).brightness,
        Brightness.light,
      );

      // …y de vuelta al oscuro que estaba activo.
      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();
      expect(skin.themePreset, AppThemePreset.forjaArcana);
      expect(
        Theme.of(
          tester.element(find.text('Apariencia')),
        ).scaffoldBackgroundColor,
        AppPalette.forge.background,
      );
    });
  });
}
