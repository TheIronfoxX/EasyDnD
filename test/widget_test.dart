// Test de humo del arranque (Etapa 5) y del skin (Etapa 6): la app pasa
// por el estado de carga del store y, con el roster vacío, cae en la
// bienvenida. El HUD con fichas se prueba en hud_shell_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/state/character_store.dart';
import 'package:easydnd/state/skin_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SkinController> bootSkin() async {
    final prefs = await SharedPreferences.getInstance();
    final skin = SkinController(prefs);
    await skin.init();
    return skin;
  }

  testWidgets('mientras el store carga muestra el splash, después la '
      'bienvenida', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    final skin = await bootSkin();

    await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Importar desde Nivel20'), findsNothing);

    await store.init();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('EasyDnD'), findsOneWidget);
    expect(find.text('Importar desde Nivel20'), findsOneWidget);
    expect(find.text('Ficha en blanco'), findsOneWidget);
  });

  testWidgets('el modo y el acento guardados se aplican al arrancar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SkinController.accentKey: 0xFF00AEEF,
      SkinController.darkModeKey: false,
    });

    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    final skin = await bootSkin();
    await store.init();

    await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.theme!.colorScheme.primary, const Color(0xFF00AEEF));

    final context = tester.element(find.text('EasyDnD'));
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('cambiar el skin reconstruye la app sin reiniciar', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    final skin = await bootSkin();
    await store.init();

    await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('EasyDnD'))).brightness,
      Brightness.dark,
    );

    await skin.setDarkMode(false);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('EasyDnD'))).brightness,
      Brightness.light,
    );

    await skin.setAccentColor(const Color(0xFF7C4DFF));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('EasyDnD'))).colorScheme.primary,
      const Color(0xFF7C4DFF),
    );
  });
}
