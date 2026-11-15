// Pasada de modo claro (cierre de la Etapa 6).
//
// No es un test de cada color: verifica que las pantallas clave se
// construyan con la paleta clara (sin restos del tema oscuro) y que se
// pueda navegar el HUD y el editor sin excepciones. La cobertura fina
// de cada tab ya vive en sus propios tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/core/theme/app_palette.dart';
import 'package:easydnd/core/theme/app_theme_colors.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/state/character_store.dart';
import 'package:easydnd/state/skin_controller.dart';

import 'fakes/test_fichas.dart';

void main() {
  setUp(() {
    // El modo claro se guarda como cualquier preferencia del skin.
    SharedPreferences.setMockInitialValues({SkinController.darkModeKey: false});
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

  Future<SkinController> pumpApp(
    WidgetTester tester,
    CharacterStore store,
  ) async {
    final skin = await bootSkin();
    await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
    await tester.pumpAndSettle();
    return skin;
  }

  testWidgets('el HUD completo se ve con la paleta clara', (tester) async {
    final store = await bootStore();
    store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
    await pumpApp(tester, store);

    final context = tester.element(find.text('Rook'));
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppPalette.light.background);
    expect(theme.cardTheme.color, AppPalette.light.surface);
    expect(context.appColors.background, AppPalette.light.background);
    expect(context.appColors.textPrimary, AppPalette.light.textPrimary);

    // Los tres tabs del HUD usan el mismo tema y no rompen al pintarse.
    await tester.tap(find.text('Ficha'));
    await tester.pumpAndSettle();
    expect(find.text('Atributos'), findsOneWidget);

    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();
    expect(find.text('Armas'), findsOneWidget);
  });

  testWidgets('bienvenida y editor respetan el modo claro', (tester) async {
    final store = await bootStore();
    await pumpApp(tester, store);

    var context = tester.element(find.text('EasyDnD'));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      AppPalette.light.background,
    );

    await tester.tap(find.text('Ficha en blanco'));
    await tester.pumpAndSettle();

    context = tester.element(find.text('Nueva ficha'));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      AppPalette.light.background,
    );
    expect(context.appColors.background, AppPalette.light.background);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importar desde Nivel20'));
    await tester.pumpAndSettle();
    context = tester.element(find.text('Importar ficha'));
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
