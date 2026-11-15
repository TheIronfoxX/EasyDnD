// Tests de cierre del HUD (Etapa 5e).
//
// Dos focos, los que no cubren los tests de cada pestaña:
//   1. Eliminar una ficha desde el menú, con confirmación y con el
//      roster vacío como estado final real (vuelve la bienvenida).
//   2. Integración entre tabs y con el almacenamiento: lo que se muta
//      en Combate o Inventario sigue ahí al cambiar de pestaña, al
//      cambiar de personaje y al reiniciar la app.

import 'package:flutter/material.dart';
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

  /// Levanta un store sobre los prefs mockeados. Llamarlo de nuevo
  /// dentro de un test simula "reiniciar la app": mismo almacenamiento,
  /// estado fresco.
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

  Future<void> openMenu(WidgetTester tester, String action) async {
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  Future<void> openDeleteDialog(WidgetTester tester) =>
      openMenu(tester, 'Eliminar ficha');

  Future<void> applyDamage(WidgetTester tester, int amount) async {
    await tester.tap(find.text('Daño'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '$amount');
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar daño'));
    await tester.pumpAndSettle();
  }

  group('eliminar ficha desde el menú', () {
    testWidgets('cancelar deja el roster intacto', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await openDeleteDialog(tester);

      expect(find.text('Eliminar ficha'), findsOneWidget);
      expect(find.textContaining('"Rook"'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(store.roster, hasLength(1));
      expect(store.activeCharacter!.basicInfo.name, 'Rook');
      expect(find.text('Combate'), findsOneWidget);
    });

    testWidgets('confirmar borra la activa y cae en la anterior', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      store.addCharacter(buildCharacter(id: 'char_mira', name: 'Mira'));
      await pumpApp(tester, store);

      // Mira es la activa (la última agregada).
      expect(store.activeIndex, 1);
      expect(find.text('Mira'), findsOneWidget);

      await openDeleteDialog(tester);
      expect(find.textContaining('"Mira"'), findsOneWidget);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(store.roster, hasLength(1));
      expect(store.activeCharacter!.basicInfo.name, 'Rook');
      expect(find.text('Rook'), findsOneWidget);
      expect(find.text('Mira'), findsNothing);
      expect(find.text('Ficha de Mira eliminada.'), findsOneWidget);
    });

    testWidgets('borrar la última vuelve a la bienvenida', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);
      expect(find.text('Combate'), findsOneWidget);

      await openDeleteDialog(tester);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(store.roster, isEmpty);
      expect(store.activeCharacter, isNull);
      expect(find.text('Importar desde Nivel20'), findsOneWidget);
      expect(find.text('Combate'), findsNothing);
      // En la bienvenida el aviso de borrado sobra.
      expect(find.text('Ficha de Rook eliminada.'), findsNothing);
    });
  });

  group('coherencia entre tabs', () {
    testWidgets('el daño aplicado en Combate sigue al cambiar de tab', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(
        buildCharacter(id: 'char_rook', name: 'Rook', hpCurrent: 20),
      );
      await pumpApp(tester, store);

      await applyDamage(tester, 5);
      expect(store.activeCharacter!.basicInfo.currentHp, 15);
      expect(find.text('15'), findsOneWidget);

      await tester.tap(find.text('Ficha'));
      await tester.pumpAndSettle();
      expect(find.text('Atributos'), findsOneWidget);

      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();
      expect(find.text('Armas'), findsOneWidget);

      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('las cantidades del inventario sobreviven al cambio de tab', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sumar una copia de Espada Larga'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.inventory.weapons.single.quantity, 2);
      expect(find.text('×2'), findsOneWidget);

      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();

      expect(find.text('×2'), findsOneWidget);
      expect(store.activeCharacter!.inventory.weapons.single.quantity, 2);
    });

    testWidgets('cambiar de ficha muestra el inventario de la nueva', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(
        buildCharacter(id: 'char_rook', name: 'Rook', weaponQuantity: 1),
      );
      store.addCharacter(
        buildCharacter(id: 'char_mira', name: 'Mira', weaponQuantity: 4),
      );
      await pumpApp(tester, store);

      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();
      expect(find.text('×4'), findsOneWidget);

      await tester.tap(find.byTooltip('Cambiar de personaje'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rook'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.basicInfo.name, 'Rook');
      expect(find.text('×1'), findsNWidgets(2)); // arma y objeto
      expect(find.text('×4'), findsNothing);
    });
  });

  group('persistencia', () {
    testWidgets('los cambios de combate e inventario sobreviven a reiniciar', (
      tester,
    ) async {
      final first = await boot();
      first.addCharacter(
        buildCharacter(id: 'char_rook', name: 'Rook', hpCurrent: 20),
      );
      await pumpApp(tester, first);

      await applyDamage(tester, 5);

      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sumar una copia de Espada Larga'));
      await tester.pumpAndSettle();

      // Deja terminar las escrituras fire-and-forget del store.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );

      final second = await boot();
      expect(second.roster, hasLength(1));
      expect(second.activeCharacter!.basicInfo.currentHp, 15);
      expect(second.activeCharacter!.inventory.weapons.single.quantity, 2);

      await pumpApp(tester, second);
      await tester.tap(find.text('Combate'));
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);

      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();
      expect(find.text('×2'), findsOneWidget);
    });
  });
}
