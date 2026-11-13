// Tests de la pestaña Inventario (Etapa 5d).
//
// Se pumpea la pestaña sola contra el store real: armas con cantidad y
// cargas, objetos mundanos, bolsa y compañeros. Los ajustes de cantidad
// y PG de mascota son las únicas mutaciones del HUD en esta pestaña;
// editar/borrar sigue siendo cosa del editor.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/core/theme/app_theme.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/features/hud/hud_inventory_tab.dart';
import 'package:easydnd/state/character_store.dart';

import 'fakes/test_fichas.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<CharacterStore> bootWith(CharacterModel character) async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    store.addCharacter(character);
    return store;
  }

  Future<void> pumpInventory(WidgetTester tester, CharacterStore store) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<CharacterStore>.value(
        value: store,
        // El shell del HUD ya escucha el store; acá lo hacemos con un
        // Consumer para que los ajustes se reflejen sin la AppBar.
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Consumer<CharacterStore>(
              builder: (_, current, __) =>
                  HudInventoryTab(character: current.activeCharacter!),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('contenido del inventario', () {
    testWidgets('muestra armas, objetos, bolsa y compañeros', (tester) async {
      final store = await bootWith(
        buildCharacter(id: 'char_inv', name: 'Rook'),
      );
      await pumpInventory(tester, store);

      // Armas: resumen mecánico, cantidad y cargas.
      expect(find.text('Armas'), findsOneWidget);
      expect(find.text('Espada Larga'), findsOneWidget);
      expect(find.text('Ataque +5 · 1d8+3 cortante'), findsOneWidget);
      expect(find.text('3/3 cargas'), findsOneWidget);

      // Objetos mundanos con su descripción y cantidad.
      expect(find.text('Objetos'), findsOneWidget);
      expect(find.text('Cuerda'), findsOneWidget);
      expect(find.text('10 metros'), findsOneWidget);

      // La ficha de prueba tiene un arma y un objeto, ambos ×1.
      expect(find.text('×1'), findsNWidgets(2));

      // Bolsa con los tres stacks y la equivalencia en oro.
      expect(find.text('Bolsa'), findsOneWidget);
      expect(find.text('Oro'), findsOneWidget);
      expect(find.text('10 po'), findsOneWidget);
      expect(find.text('Plata'), findsOneWidget);
      expect(find.text('5 pp'), findsOneWidget);
      expect(find.text('Cobre'), findsOneWidget);
      expect(find.text('2 pc'), findsOneWidget);
      expect(find.text('Equivale a 10.52 po'), findsOneWidget);

      // Compañeros con PG y CA.
      expect(find.text('Compañeros'), findsOneWidget);
      expect(find.text('Lobo'), findsOneWidget);
      expect(find.text('bestia · CA 12'), findsOneWidget);
      expect(find.text('5/10 PG'), findsOneWidget);
    });

    testWidgets('un arma única no muestra el stepper de cantidad', (
      tester,
    ) async {
      final store = await bootWith(
        buildCharacter(
          id: 'char_unique',
          name: 'Rook',
          weaponIsUnique: true,
          weaponQuantity: 5,
        ),
      );
      await pumpInventory(tester, store);

      expect(find.text('Única'), findsOneWidget);
      expect(find.text('×5'), findsNothing);
      expect(find.byTooltip('Sumar una copia de Espada Larga'), findsNothing);
    });

    testWidgets('sin equipo muestra estados vacíos, no errores', (
      tester,
    ) async {
      final character = buildCharacter(id: 'char_empty', name: 'Rook');
      character.inventory.weapons.clear();
      character.inventory.mundaneItems.clear();
      character.companions.clear();
      character.purse
        ..gold = 0
        ..silver = 0
        ..copper = 0;

      final store = await bootWith(character);
      await pumpInventory(tester, store);

      expect(find.text('La ficha no trae armas.'), findsOneWidget);
      expect(find.text('La ficha no trae objetos.'), findsOneWidget);
      expect(find.text('La ficha no trae compañeros.'), findsOneWidget);
      expect(find.text('Equivale a 0 po'), findsOneWidget);
    });
  });

  group('ajustes de mesa', () {
    testWidgets('las copias de un arma suben y bajan', (tester) async {
      final store = await bootWith(
        buildCharacter(id: 'char_qty', name: 'Rook'),
      );
      await pumpInventory(tester, store);

      expect(find.text('×1'), findsNWidgets(2)); // arma y objeto

      await tester.tap(find.byTooltip('Sumar una copia de Espada Larga'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.inventory.weapons.single.quantity, 2);
      expect(find.text('×2'), findsOneWidget);

      await tester.tap(find.byTooltip('Restar una copia de Espada Larga'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.inventory.weapons.single.quantity, 1);
      expect(find.text('×1'), findsNWidgets(2));
    });

    testWidgets('las unidades de un objeto mundano se ajustan', (tester) async {
      final store = await bootWith(
        buildCharacter(id: 'char_item', name: 'Rook'),
      );
      await pumpInventory(tester, store);

      await tester.tap(find.byTooltip('Sumar una unidad de Cuerda'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.inventory.mundaneItems.single.quantity, 2);
      expect(find.text('×2'), findsOneWidget);

      await tester.tap(find.byTooltip('Restar una unidad de Cuerda'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.inventory.mundaneItems.single.quantity, 1);
    });

    testWidgets('los PG del compañero se curan y se descuentan', (
      tester,
    ) async {
      final store = await bootWith(
        buildCharacter(id: 'char_pet', name: 'Rook'),
      );
      await pumpInventory(tester, store);

      await tester.tap(find.byTooltip('Curar 1 PG a Lobo'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.companions.single.currentHp, 6);
      expect(find.text('6/10 PG'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar 1 PG a Lobo'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.companions.single.currentHp, 5);
      expect(find.text('5/10 PG'), findsOneWidget);
    });

    testWidgets('un compañero sin PG es apoyo invulnerable', (tester) async {
      final character = buildCharacter(id: 'char_familiar', name: 'Rook');
      character.companions.add(
        Companion(name: 'Cuervo', type: 'familiar', hasHp: false, ac: 11),
      );

      final store = await bootWith(character);
      await pumpInventory(tester, store);

      expect(
        find.text('familiar · Apoyo invulnerable · CA 11'),
        findsOneWidget,
      );
      expect(find.byTooltip('Curar 1 PG a Cuervo'), findsNothing);
    });
  });
}
