// Tests del shell del HUD (Etapa 5): bienvenida, identidad de la ficha
// activa, tabs, selector de roster, menú de mantenimiento y borrado.
//
// Los cuerpos de los tabs se prueban en hud_dashboard_test.dart,
// hud_actions_test.dart, hud_inventory_test.dart y hud_sheet_tab_test.dart;
// acá se vigila la navegación y que las acciones del shell muevan el
// store sin duplicar ni perder fichas.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/state/character_store.dart';
import 'package:easydnd/state/skin_controller.dart';

import 'fakes/test_fichas.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<CharacterStore> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    return store;
  }

  Future<void> pumpApp(WidgetTester tester, CharacterStore store) async {
    final prefs = await SharedPreferences.getInstance();
    final skin = SkinController(prefs);
    await skin.init();
    await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
    await tester.pumpAndSettle();
  }

  group('bienvenida', () {
    testWidgets('las dos vías de alta abren sus pantallas', (tester) async {
      final store = await boot();
      await pumpApp(tester, store);

      expect(find.text('EasyDnD'), findsOneWidget);
      expect(find.textContaining('funciona sin conexión'), findsOneWidget);

      await tester.tap(find.text('Ficha en blanco'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva ficha'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Importar desde Nivel20'));
      await tester.pumpAndSettle();
      expect(find.text('Importar ficha'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Ficha en blanco'), findsOneWidget);
    });
  });

  group('shell del HUD', () {
    testWidgets('muestra identidad, tabs y cambia de sección', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      // AppBar: iniciales, nombre y raza · clase.
      expect(find.text('R'), findsOneWidget);
      expect(find.text('Rook'), findsOneWidget);
      expect(find.text('Humano · Guerrero 5'), findsOneWidget);
      expect(find.text('Combate'), findsOneWidget);
      expect(find.text('Ficha'), findsOneWidget);
      expect(find.text('Inventario'), findsOneWidget);

      // Tab inicial: el tablero de combate (5b).
      expect(find.text('Vida'), findsOneWidget);
      expect(find.text('Turno'), findsOneWidget);

      await tester.tap(find.text('Ficha'));
      await tester.pumpAndSettle();
      expect(find.text('Atributos'), findsOneWidget);
      expect(find.text('Vida'), findsNothing);

      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();
      expect(find.text('Armas'), findsOneWidget);
      expect(find.text('Bolsa'), findsOneWidget);
    });

    testWidgets('el selector de roster cambia el personaje activo', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      store.addCharacter(buildCharacter(id: 'char_mira', name: 'Mira'));
      await pumpApp(tester, store);

      // La última ficha agregada queda activa.
      expect(store.activeIndex, 1);
      expect(find.text('Mira'), findsOneWidget);

      await tester.tap(find.byTooltip('Cambiar de personaje'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rook'));
      await tester.pumpAndSettle();

      expect(store.activeIndex, 0);
      expect(find.text('Rook'), findsOneWidget);
      expect(find.text('Mira'), findsNothing);
      // Cambiar de personaje no toca el roster.
      expect(store.roster, hasLength(2));
    });

    testWidgets('el menú abre el editor y la corrección con IA', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar ficha'));
      await tester.pumpAndSettle();
      expect(find.text('Editar a Rook'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Corregir con IA'));
      await tester.pumpAndSettle();
      expect(find.text('Corregir ficha con IA'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ficha en blanco'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva ficha'), findsOneWidget);
    });

    testWidgets('borrar la última ficha vuelve a la bienvenida', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);
      expect(find.text('Combate'), findsOneWidget);

      store.deleteCharacter(0);
      await tester.pumpAndSettle();

      expect(find.text('Importar desde Nivel20'), findsOneWidget);
      expect(find.text('Combate'), findsNothing);
    });
  });
}
