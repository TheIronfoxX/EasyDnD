// Temas propios: modelo (JSON fiel), SkinController (guardar, activar,
// persistir, borrar) y editor (crear, guardar, descartar).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:easydnd/features/hud/welcome_screen.dart';
import 'package:easydnd/features/skin/my_themes_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/core/theme/custom_theme.dart';
import 'package:easydnd/core/theme/tactical_theme_tokens.dart';
import 'package:easydnd/core/theme/theme_presets.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/state/character_store.dart';
import 'package:easydnd/state/skin_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<SkinController> boot() async {
    final skin = SkinController(await SharedPreferences.getInstance());
    await skin.init();
    return skin;
  }

  group('modelo', () {
    test('cada tema del catálogo sobrevive a JSON sin perder nada', () {
      for (final preset in AppThemePreset.values) {
        final custom = CustomTheme.fromPreset(preset, id: 'x');
        final json = custom.toJson();
        final again = CustomTheme.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        );
        expect(again.toJson(), json, reason: preset.id);
      }
    });

    test('las esquinas asimétricas se conservan', () {
      const spec = ShapeSpec(
        kind: ShapeKind.beveled,
        topLeft: 2,
        topRight: 14,
        bottomRight: 6,
        bottomLeft: 0,
      );
      expect(ShapeSpec.fromBorder(spec.toBorder()), spec);
      expect(ShapeSpec.fromJson(spec.toJson(), const ShapeSpec()), spec);
    });

    test('withBackground deduce el brillo y da textos legibles', () {
      final base = CustomTheme.fromPreset(AppThemePreset.grimorio, id: 'x');

      final light = base.withBackground(const Color(0xFFF2EEE4));
      expect(light.isDark, isFalse);
      expect(light.palette.background, const Color(0xFFF2EEE4));
      expect(
        light.palette.textPrimary.computeLuminance(),
        lessThan(0.1),
        reason: 'texto oscuro sobre fondo claro',
      );
      expect(
        light.palette.surface.computeLuminance(),
        lessThan(const Color(0xFFF2EEE4).computeLuminance()),
      );

      final dark = base.withBackground(const Color(0xFF101828));
      expect(dark.isDark, isTrue);
      expect(dark.palette.textPrimary.computeLuminance(), greaterThan(0.6));
      expect(
        dark.palette.surface.computeLuminance(),
        greaterThan(const Color(0xFF101828).computeLuminance()),
      );
    });

    test('withRoundness toca las tres formas y respeta la píldora', () {
      final base = CustomTheme.fromPreset(AppThemePreset.grimorio, id: 'x');
      final round = base.withRoundness(20);
      expect(round.roundness, 20);
      expect(ShapeSpec.fromBorder(round.tactical.buttonShape).topLeft, 20);
      expect(ShapeSpec.fromBorder(round.tactical.insetShape).topLeft, 15);

      final pill = base.copyWith(
        tactical: base.tactical.copyWith(buttonShape: const StadiumBorder()),
      );
      expect(pill.withRoundness(4).tactical.buttonShape, isA<StadiumBorder>());
    });

    test('un JSON vacío o roto cae a los valores de fábrica', () {
      final dark = CustomTheme.fromJson({});
      expect(dark.isDark, isTrue);
      expect(
        dark.palette.background,
        AppThemePreset.defaultDark.palette.background,
      );
      expect(dark.name, 'Mi tema');

      final light = CustomTheme.fromJson({
        'brightness': 'light',
        'pip': 'nope',
        'colors': {'spell': 'rojo'},
      });
      expect(light.isDark, isFalse);
      expect(
        light.tactical.pipShape,
        AppThemePreset.defaultLight.tactical.pipShape,
      );
      expect(light.tactical.spell, AppThemePreset.defaultLight.tactical.spell);
    });
  });

  group('SkinController', () {
    test('un tema propio claro y otro oscuro conviven con el toggle', () async {
      final skin = await boot();
      final dark = skin.draftFromActive(name: 'Noche');
      await skin.saveCustomTheme(dark);
      final light = dark.copyWith(
        id: 'claro',
        name: 'Día',
        brightness: Brightness.light,
      );
      await skin.saveCustomTheme(light);
      expect(skin.isDarkMode, isFalse);
      expect(skin.activeCustomTheme?.name, 'Día');

      await skin.setDarkMode(true);
      expect(skin.activeCustomTheme?.name, 'Noche');
    });

    test('cambiar el brillo de un tema activo lo mueve de modo', () async {
      final skin = await boot();
      final theme = skin.draftFromActive(name: 'Mutable');
      await skin.saveCustomTheme(theme);
      await skin.saveCustomTheme(theme.copyWith(brightness: Brightness.light));

      expect(skin.isDarkMode, isFalse);
      expect(skin.activeCustomTheme?.id, theme.id);
      await skin.setDarkMode(true);
      expect(skin.activeCustomTheme, isNull);
    });

    test('elegir del catálogo o borrar el tema vuelve al preset', () async {
      final skin = await boot();
      final theme = skin.draftFromActive();
      await skin.saveCustomTheme(theme);

      await skin.setThemePreset(AppThemePreset.escarcha);
      expect(skin.activeCustomTheme, isNull);
      expect(skin.themePreset, AppThemePreset.escarcha);

      await skin.activateCustomTheme(theme.id);
      expect(skin.activeCustomTheme?.id, theme.id);
      await skin.deleteCustomTheme(theme.id);
      expect(skin.customThemes, isEmpty);
      expect(skin.activeCustomTheme, isNull);
      expect(skin.themePreset, AppThemePreset.escarcha);
    });

    test('duplicar crea una copia independiente', () async {
      final skin = await boot();
      final theme = skin.draftFromActive(name: 'Base');
      await skin.saveCustomTheme(theme);
      final copy = await skin.duplicateCustomTheme(theme.id);

      expect(skin.customThemes, hasLength(2));
      expect(copy!.name, 'Base (copia)');
      expect(copy.id, isNot(theme.id));
      expect(skin.activeCustomTheme?.id, theme.id);
    });

    test('una entrada corrupta se salta sin tumbar el arranque', () async {
      final good = CustomTheme.fromPreset(AppThemePreset.grimorio, id: 'ok');
      SharedPreferences.setMockInitialValues({
        SkinController.customThemesKey: ['{roto', jsonEncode(good.toJson())],
        SkinController.darkCustomKey: 'ok',
      });
      final skin = await boot();
      expect(skin.customThemes.map((t) => t.id), ['ok']);
      expect(skin.activeCustomTheme?.id, 'ok');
    });
  });

  group('editor', () {
    Future<SkinController> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prefs = await SharedPreferences.getInstance();
      final store = CharacterStore(RosterRepository(prefs));
      await store.init();
      final skin = SkinController(prefs);
      await skin.init();
      await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
      await tester.pumpAndSettle();
      // Mis temas ya no tiene entrada en la app: se abre a mano.
      Navigator.of(
        tester.element(find.byType(WelcomeScreen)),
      ).push(MaterialPageRoute<void>(builder: (_) => const MyThemesScreen()));
      await tester.pumpAndSettle();
      return skin;
    }

    testWidgets('crear, cambiar el modo y guardar deja el tema activo', (
      tester,
    ) async {
      final skin = await pumpApp(tester);
      expect(find.textContaining('Todavía no tienes temas'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('new-theme')));
      await tester.pumpAndSettle();
      expect(find.text('Editar tema'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('theme-name')), 'Alba');
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-theme')));
      await tester.pumpAndSettle();

      expect(find.text('Alba'), findsOneWidget);
      expect(skin.activeCustomTheme?.name, 'Alba');
      expect(skin.isDarkMode, isFalse);
      expect(
        Theme.of(tester.element(find.text('Alba'))).brightness,
        Brightness.light,
      );
    });

    testWidgets('salir con cambios pide confirmación y no guarda', (
      tester,
    ) async {
      final skin = await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('new-theme')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('theme-name')), 'Nada');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar cambios?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discard-theme')));
      await tester.pumpAndSettle();

      expect(find.text('Mis temas'), findsOneWidget);
      expect(skin.customThemes, isEmpty);
    });

    testWidgets('el modo sencillo cambia pips y el modo se recuerda', (
      tester,
    ) async {
      final skin = await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('new-theme')));
      await tester.pumpAndSettle();

      // Abre en sencillo por defecto.
      expect(skin.simpleThemeEditor, isTrue);
      expect(find.byKey(const ValueKey('theme-editor-simple')), findsOneWidget);
      expect(find.text('Formas y bordes'), findsNothing);

      final star = find.byKey(const ValueKey('simple-pip-star'));
      await tester.scrollUntilVisible(
        star,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('theme-editor-simple')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(star);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Avanzado'));
      await tester.pumpAndSettle();
      expect(skin.simpleThemeEditor, isFalse);
      expect(find.text('Formas y bordes'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('save-theme')));
      await tester.pumpAndSettle();
      expect(skin.activeCustomTheme!.tactical.pipShape, PipShape.star);

      final restarted = await boot();
      expect(restarted.simpleThemeEditor, isFalse);
    });

    testWidgets('las secciones del editor se despliegan y editan', (
      tester,
    ) async {
      final skin = await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('new-theme')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avanzado'));
      await tester.pumpAndSettle();

      final list = find.byKey(const ValueKey('theme-editor-list'));
      Future<void> open(String section) async {
        await tester.scrollUntilVisible(
          find.text(section),
          200,
          scrollable: find
              .descendant(of: list, matching: find.byType(Scrollable))
              .first,
        );
        await tester.tap(find.text(section));
        await tester.pumpAndSettle();
      }

      await open('Tarjetas');
      await tester.tap(find.text('Doble filete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-theme')));
      await tester.pumpAndSettle();

      final saved = skin.activeCustomTheme!;
      expect(
        saved.tactical.cards.doubleBorder,
        !AppThemePreset.defaultDark.tactical.cards.doubleBorder,
      );
    });
  });
}
