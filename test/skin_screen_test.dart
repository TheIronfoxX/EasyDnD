// Tests de la pantalla de apariencia (Etapa 6b): entrada desde la
// bienvenida y el HUD, cambio de modo, presets, picker HSV y
// persistencia a través del SkinController real.
//
// Igual que el resto de los tests de UI del rework, tocan la pantalla
// como lo haría el jugador y verifican el efecto en el tema y en prefs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/core/theme/accent_presets.dart';
import 'package:easydnd/core/theme/app_theme.dart';
import 'package:easydnd/core/theme/font_presets.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/state/character_store.dart';
import 'package:easydnd/state/skin_controller.dart';

import 'fakes/test_fichas.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<CharacterStore> bootStore() async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    return store;
  }

  Future<SkinController> bootSkin() async {
    final prefs = await SharedPreferences.getInstance();
    final skin = SkinController(prefs);
    await skin.init();
    return skin;
  }

  Future<void> pumpApp(
    WidgetTester tester,
    CharacterStore store,
    SkinController skin,
  ) async {
    await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
    await tester.pumpAndSettle();
  }

  /// Abre Apariencia desde la bienvenida (roster vacío).
  Future<void> openFromWelcome(
    WidgetTester tester,
    CharacterStore store,
  ) async {
    final skin = await bootSkin();
    await pumpApp(tester, store, skin);
    await tester.tap(find.byTooltip('Apariencia'));
    await tester.pumpAndSettle();
  }

  group('entrada', () {
    testWidgets('la bienvenida abre Apariencia', (tester) async {
      final store = await bootStore();
      await openFromWelcome(tester, store);

      expect(find.text('Apariencia'), findsOneWidget);
      expect(find.text('Modo'), findsOneWidget);
      expect(find.text('Color de acento'), findsOneWidget);
      expect(find.text('Tipografía'), findsOneWidget);
    });

    testWidgets('el menú del HUD abre Apariencia', (tester) async {
      final store = await bootStore();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));

      final skin = await bootSkin();
      await pumpApp(tester, store, skin);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apariencia'));
      await tester.pumpAndSettle();

      expect(find.text('Color de acento'), findsOneWidget);
    });
  });

  group('cambios de skin', () {
    testWidgets('el modo claro se aplica y se persiste', (tester) async {
      final store = await bootStore();
      final skin = await bootSkin();
      await pumpApp(tester, store, skin);
      await tester.tap(find.byTooltip('Apariencia'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();

      expect(skin.isDarkMode, isFalse);
      final context = tester.element(find.text('Color de acento'));
      expect(Theme.of(context).brightness, Brightness.light);

      final restarted = await bootSkin();
      expect(restarted.isDarkMode, isFalse);
      expect(restarted.themeMode, ThemeMode.light);
    });

    testWidgets('un preset cambia el acento del tema y se persiste', (
      tester,
    ) async {
      final store = await bootStore();
      final skin = await bootSkin();
      await pumpApp(tester, store, skin);
      await tester.tap(find.byTooltip('Apariencia'));
      await tester.pumpAndSettle();

      final preset = AccentPresets.all.firstWhere((p) => p.label == 'Arcana');
      await tester.tap(find.byTooltip('Arcana'));
      await tester.pumpAndSettle();

      expect(skin.accentColor, preset.color);
      final context = tester.element(find.text('Color de acento'));
      expect(Theme.of(context).colorScheme.primary, preset.color);

      final restarted = await bootSkin();
      expect(restarted.accentColor, preset.color);
    });

    testWidgets('el picker HSV aplica un color libre', (tester) async {
      final store = await bootStore();
      final skin = await bootSkin();
      await pumpApp(tester, store, skin);
      await tester.tap(find.byTooltip('Apariencia'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Elegir color personalizado'));
      await tester.pumpAndSettle();
      expect(find.text('Color personalizado'), findsOneWidget);

      // Arrastrar el tono alcanza para salir del sepia inicial.
      await tester.drag(find.byType(Slider).first, const Offset(120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar este color'));
      await tester.pumpAndSettle();

      expect(skin.accentColor, isNot(AppTheme.defaultAccent));
      final context = tester.element(find.text('Color de acento'));
      expect(Theme.of(context).colorScheme.primary, skin.accentColor);
      expect(find.text('Cambiar color personalizado'), findsOneWidget);
    });

    testWidgets('la tipografía elegida se aplica y se persiste', (
      tester,
    ) async {
      final store = await bootStore();
      final skin = await bootSkin();
      await pumpApp(tester, store, skin);
      await tester.tap(find.byTooltip('Apariencia'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Diario'));
      await tester.tap(find.text('Diario'));
      await tester.pumpAndSettle();

      expect(skin.fontPreset.id, FontPresets.journal.id);
      final context = tester.element(find.text('Diario'));
      final textTheme = Theme.of(context).textTheme;
      expect(textTheme.titleLarge?.fontFamily, 'serif');
      expect(textTheme.bodyMedium?.fontFamily, isNot('serif'));

      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Diario'),
      );
      expect(chip.selected, isTrue);

      final restarted = await bootSkin();
      expect(restarted.fontPreset.id, FontPresets.journal.id);
      expect(restarted.themeData.textTheme.titleLarge?.fontFamily, 'serif');
    });
  });
}
