// Tests de la pestaña Inventario (Etapa 5d).
//
// Se pumpea la pestaña sola contra el store real: armas con cantidad y
// cargas, objetos mundanos y bolsa. Los ajustes de cantidad
// y PG de mascota son las únicas mutaciones del HUD en esta pestaña;
// editar/borrar sigue siendo cosa del editor.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/core/theme/app_theme.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/state/character_store.dart';

import 'fakes/backpack_harness.dart';
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
          theme: AppTheme.clean(brightness: Brightness.dark),
          home: Scaffold(
            body: Consumer<CharacterStore>(
              builder: (_, current, __) =>
                  BackpackHarness(character: current.activeCharacter!),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('contenido del inventario', () {
    testWidgets('muestra armas, objetos y bolsa', (tester) async {
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

      // Con ×1 la cantidad no se pinta en la fila: solo lo inusual.
      expect(find.text('×1'), findsNothing);

      // Bolsa (subpestaña Dinero) con los tres stacks y la equivalencia.
      await tester.tap(find.text('Dinero'));
      await tester.pumpAndSettle();
      expect(find.text('Bolsa'), findsOneWidget);
      expect(find.text('Oro'), findsOneWidget);
      expect(find.text('10 po'), findsOneWidget);
      expect(find.text('Plata'), findsOneWidget);
      expect(find.text('5 pp'), findsOneWidget);
      expect(find.text('Cobre'), findsOneWidget);
      expect(find.text('2 pc'), findsOneWidget);
      expect(find.text('Equivale a 10.52 po'), findsOneWidget);

      // Los compañeros viven en Personaje (ver hud_companions_test.dart).
      expect(find.text('Compañeros'), findsNothing);
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

      expect(find.text('×5'), findsNothing);
      await tester.tap(find.text('Espada Larga'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar arma'), findsOneWidget);
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
      await tester.tap(find.text('Dinero'));
      await tester.pumpAndSettle();
      expect(find.text('Equivale a 0 po'), findsOneWidget);
    });
  });

  group('ajustes de mesa', () {
    testWidgets('las copias de un arma suben y bajan', (tester) async {
      final store = await bootWith(
        buildCharacter(id: 'char_qty', name: 'Rook'),
      );
      await pumpInventory(tester, store);

      // El ajuste vive en la hoja de detalle que se abre al tocar la fila.
      await tester.tap(find.text('Espada Larga'));
      await tester.pumpAndSettle();
      expect(find.text('×1'), findsOneWidget); // solo el stepper

      await tester.tap(find.byTooltip('Sumar una copia de Espada Larga'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.inventory.weapons.single.quantity, 2);
      expect(find.text('×2'), findsNWidgets(2)); // hoja y fila

      await tester.tap(find.byTooltip('Restar una copia de Espada Larga'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.inventory.weapons.single.quantity, 1);
      expect(find.text('×1'), findsOneWidget);
    });

    testWidgets('las unidades de un objeto mundano se ajustan', (tester) async {
      final store = await bootWith(
        buildCharacter(id: 'char_item', name: 'Rook'),
      );
      await pumpInventory(tester, store);

      await tester.tap(find.text('Cuerda'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sumar una unidad de Cuerda'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.inventory.mundaneItems.single.quantity, 2);
      expect(find.text('×2'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Restar una unidad de Cuerda'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.inventory.mundaneItems.single.quantity, 1);
    });
  });
}
