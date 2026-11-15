// Agregar objetos y dinero desde la pestaña Inventario del HUD.

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

  Future<CharacterStore> boot(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    store.addCharacter(buildCharacter(id: 'char_inv', name: 'Rook'));

    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider<CharacterStore>.value(
        value: store,
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
    return store;
  }

  Purse purseOf(CharacterStore store) => store.activeCharacter!.purse;

  group('dinero', () {
    testWidgets('agregar oro suma al stack y avisa', (tester) async {
      final store = await boot(tester);
      final before = purseOf(store).gold;

      await tester.tap(find.byKey(const Key('hud-add-money')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('currency-amount')), '25');
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      expect(purseOf(store).gold, before + 25);
      expect(find.textContaining('Agregaste 25 po'), findsOneWidget);
    });

    testWidgets('platino y electro se agregan y aparecen en la bolsa', (
      tester,
    ) async {
      final store = await boot(tester);
      expect(find.text('Platino'), findsNothing);

      await tester.tap(find.byKey(const Key('hud-add-money')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('currency-platinum')));
      await tester.enterText(find.byKey(const Key('currency-amount')), '3');
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      expect(purseOf(store).platinum, 3);
      expect(find.text('Platino'), findsOneWidget);
      expect(find.text('3 pp'), findsOneWidget);
    });

    testWidgets('gastar descuenta y no deja gastar de más', (tester) async {
      final store = await boot(tester);
      final gold = purseOf(store).gold;

      await tester.tap(find.byKey(const Key('hud-spend-money')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('currency-amount')),
        '${gold + 1}',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Gastar'));
      await tester.pumpAndSettle();
      // El diálogo sigue abierto con el error y nada se descontó.
      expect(find.textContaining('No te alcanza'), findsOneWidget);
      expect(purseOf(store).gold, gold);

      await tester.enterText(find.byKey(const Key('currency-amount')), '2');
      await tester.tap(find.widgetWithText(FilledButton, 'Gastar'));
      await tester.pumpAndSettle();
      expect(purseOf(store).gold, gold - 2);
      expect(find.textContaining('Gastaste 2 po'), findsOneWidget);
    });

    testWidgets('cancelar no toca la bolsa', (tester) async {
      final store = await boot(tester);
      final before = purseOf(store).toJson();

      await tester.tap(find.byKey(const Key('hud-add-money')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(purseOf(store).toJson(), before);
    });

    test('el store maneja platino y electro sin pasar a negativo', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = CharacterStore(RosterRepository(prefs));
      await store.init();
      store.addCharacter(buildCharacter(id: 'c', name: 'Rook'));

      store.addCurrency(CurrencyType.electrum, 4);
      store.spendCurrency(CurrencyType.electrum, 99);
      store.addCurrency(CurrencyType.platinum, 2);
      store.setCurrency(CurrencyType.platinum, -5);

      expect(store.activeCharacter!.purse.electrum, 0);
      expect(store.activeCharacter!.purse.platinum, 0);
    });
  });

  group('objetos', () {
    testWidgets('agregar un objeto lo suma a la lista con su cantidad', (
      tester,
    ) async {
      final store = await boot(tester);
      final before = store.activeCharacter!.inventory.mundaneItems.length;

      await tester.tap(find.byKey(const Key('hud-add-item')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Antorcha');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      final items = store.activeCharacter!.inventory.mundaneItems;
      expect(items.length, before + 1);
      expect(items.last.name, 'Antorcha');
      expect(find.text('Antorcha'), findsOneWidget);
    });

    testWidgets('cancelar el diálogo no agrega nada', (tester) async {
      final store = await boot(tester);
      final before = store.activeCharacter!.inventory.mundaneItems.length;

      await tester.tap(find.byKey(const Key('hud-add-item')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.inventory.mundaneItems.length, before);
    });
  });
}
