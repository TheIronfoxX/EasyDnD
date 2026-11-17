// Compañeros como combatientes: tarjeta en Personaje → Compañeros y hoja propia.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/state/character_store.dart';
import 'package:easydnd/state/skin_controller.dart';

import 'fakes/test_fichas.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<CharacterStore> bootWith(CharacterModel c) async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    store.addCharacter(c);
    return store;
  }

  Future<void> pumpApp(WidgetTester tester, CharacterStore store) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    final skin = SkinController(prefs);
    await skin.init();
    await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
    await tester.pumpAndSettle();
  }

  /// Los compañeros viven en Personaje → Compañeros.
  /// Compañeros es una tarjeta de Combate que abre su propia pantalla.
  Future<void> openCompanions(WidgetTester tester) async {
    final card = find.byKey(const ValueKey('nav-companions'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  group('modelo', () {
    test('compañero antiguo (sin id/turno) carga con fallbacks', () {
      final c = Companion.fromJson({'name': 'Lobo', 'max_hp': 10});
      expect(c.id, startsWith('comp_'));
      expect(c.speed, 30);
      expect(c.turn.movementRemaining, 30);
      expect(c.conditions, isEmpty);
      expect(c.actions, isEmpty);
    });

    test('ida y vuelta conserva id, turno, condiciones y acciones', () {
      final c = Companion(
        name: 'Lobo',
        type: 'bestia',
        maxHp: 10,
        currentHp: 4,
        conditions: ['Envenenado'],
        actions: [
          CompanionAction(name: 'Mordisco', attackBonus: 4, damage: '2d4+2'),
        ],
      )..turn.reactionUsed = true;
      final back = Companion.fromJson(
        jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>,
      );
      expect(back.id, c.id);
      expect(back.turn.reactionUsed, isTrue);
      expect(back.conditions, ['Envenenado']);
      expect(back.actions.single.attackBonus, 4);
    });
  });

  group('store por id', () {
    test('HP, acciones, condiciones y reinicio de turno', () async {
      final store = await bootWith(buildCharacter()); // Lobo 5/10
      final pet = store.activeCharacter!.companions.single;

      store.applyCompanionHp(pet.id, 3);
      expect(pet.currentHp, 8);
      store.applyCompanionHp(pet.id, -100);
      expect(pet.currentHp, 0);
      store.applyCompanionHp('nope', 5); // no-op

      store.toggleCompanionAction(pet.id, 'action');
      store.toggleCompanionAction(pet.id, 'bogus'); // no-op
      expect(pet.turn.actionUsed, isTrue);

      store.toggleCompanionCondition(pet.id, 'Aturdido');
      expect(pet.conditions, ['Aturdido']);
      store.toggleCompanionCondition(pet.id, 'Aturdido');
      expect(pet.conditions, isEmpty);

      store.resetCompanionTurn(pet.id);
      expect(pet.turn.actionUsed, isFalse);
    });

    test('resetTurn del personaje también reinicia a los compañeros', () async {
      final store = await bootWith(buildCharacter());
      final pet = store.activeCharacter!.companions.single;
      store.toggleCompanionAction(pet.id, 'bonus');
      store.resetTurn();
      expect(pet.turn.bonusActionUsed, isFalse);
    });

    test('un compañero sin PG ignora el daño', () async {
      final c = buildCharacter();
      c.companions.add(
        Companion(name: 'Cuervo', type: 'familiar', hasHp: false),
      );
      final store = await bootWith(c);
      final cuervo = store.activeCharacter!.companions.last;
      store.applyCompanionHp(cuervo.id, -5);
      expect(cuervo.currentHp, 0);
    });
  });

  group('UI', () {
    testWidgets('la tarjeta vive en Combate y cura/descuenta 1 PG', (
      tester,
    ) async {
      final store = await bootWith(buildCharacter(name: 'Rook'));
      await pumpApp(tester, store);
      await openCompanions(tester);

      final heal = find.byTooltip('Curar 1 PG a Lobo');
      await tester.tap(heal);
      await tester.pumpAndSettle();
      expect(find.text('6/10 PG'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar 1 PG a Lobo'));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.companions.single.currentHp, 5);
    });

    testWidgets('sin compañeros no aparece la tarjeta', (tester) async {
      final c = buildCharacter(name: 'Rook')..companions.clear();
      final store = await bootWith(c);
      await pumpApp(tester, store);
      expect(find.byKey(const ValueKey('nav-companions')), findsNothing);
    });

    testWidgets('la hoja aplica daño y añade condición', (tester) async {
      final store = await bootWith(buildCharacter(name: 'Rook'));
      await pumpApp(tester, store);
      final pet = store.activeCharacter!.companions.single;
      await openCompanions(tester);

      final row = find.byKey(ValueKey('companion-${pet.id}'));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('companion-sheet-hp')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('companion-damage')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.tap(find.widgetWithText(FilledButton, 'Aplicar daño'));
      await tester.pumpAndSettle();
      expect(pet.currentHp, 3);

      // Sin control de turno: la hoja no lo muestra.
      expect(find.text('Reiniciar turno'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('companion-add-condition')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
    });
  });
}
