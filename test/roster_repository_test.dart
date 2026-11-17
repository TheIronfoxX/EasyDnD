import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/data/roster_repository.dart';

import 'fakes/test_fichas.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('instalación nueva', () {
    test('roster vacío, índice 0, sin migración', () async {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = await RosterRepository(prefs).load();

      expect(snapshot.roster, isEmpty);
      expect(snapshot.activeIndex, 0);
      expect(snapshot.migratedFromLegacy, isFalse);
    });
  });

  group('migración legacy (app vieja)', () {
    test('migra el roster e inyecta las cantidades por arma', () async {
      final fichaA = buildFichaJson(id: 'char_a', name: 'A', weaponId: 'w1');
      final fichaB = buildFichaJson(
        id: 'char_b',
        name: 'B',
        weaponId: 'w2',
        weaponQuantity: 2,
      );
      SharedPreferences.setMockInitialValues({
        'character_roster_v2': [jsonEncode(fichaA), jsonEncode(fichaB)],
        'active_character_index': 1,
        'weapon_quantity_w1': 4, // cantidad guardada por la app vieja
      });

      final prefs = await SharedPreferences.getInstance();
      final snapshot = await RosterRepository(prefs).load();

      expect(snapshot.migratedFromLegacy, isTrue);
      expect(snapshot.roster, hasLength(2));
      expect(snapshot.activeIndex, 1);
      // w1 tenía 4 en las claves legacy → migradas adentro de la ficha.
      expect(snapshot.roster[0].inventory.weapons.single.quantity, 4);
      // w2 no tenía clave legacy → mantiene la del JSON.
      expect(snapshot.roster[1].inventory.weapons.single.quantity, 2);
    });

    test('idempotente: la segunda carga entra por la clave nueva', () async {
      SharedPreferences.setMockInitialValues({
        'character_roster_v2': [jsonEncode(buildFichaJson(id: 'char_a'))],
        'weapon_quantity_w1': 4,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = RosterRepository(prefs);

      final first = await repo.load();
      final second = await repo.load();

      expect(first.migratedFromLegacy, isTrue);
      expect(second.migratedFromLegacy, isFalse); // ya migrado
      expect(second.roster.length, first.roster.length);
      expect(
        second.roster.map((c) => c.id).toList(),
        first.roster.map((c) => c.id).toList(),
      );
    });

    test('no destructiva: las claves legacy se conservan', () async {
      SharedPreferences.setMockInitialValues({
        'character_roster_v2': [jsonEncode(buildFichaJson(id: 'char_a'))],
        'active_character_index': 0,
        'weapon_quantity_w1': 4,
      });
      final prefs = await SharedPreferences.getInstance();
      await RosterRepository(prefs).load();

      expect(prefs.getStringList('character_roster_v2'), isNotNull);
      expect(prefs.getInt('active_character_index'), 0);
      expect(prefs.getInt('weapon_quantity_w1'), 4);
      // ... y la clave nueva quedó escrita.
      expect(prefs.getStringList(RosterRepository.rosterKey), isNotNull);
      expect(prefs.getInt(RosterRepository.activeIndexKey), 0);
    });

    test(
      'fichas legacy sin id obtienen uno estable desde la migración',
      () async {
        final ficha = buildFichaJson()..remove('id');
        SharedPreferences.setMockInitialValues({
          'character_roster_v2': [jsonEncode(ficha)],
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = RosterRepository(prefs);

        final first = await repo.load();
        expect(first.roster.single.id, isNotEmpty);

        // El id se fijó al persistir tras la migración: no cambia en el
        // próximo arranque (la clave nueva ya lo trae).
        final second = await repo.load();
        expect(second.roster.single.id, first.roster.single.id);
      },
    );

    test('tolera entradas corruptas sin tirar el resto', () async {
      SharedPreferences.setMockInitialValues({
        'character_roster_v2': [
          '{esto no es json',
          jsonEncode(buildFichaJson(id: 'char_ok')),
          '42',
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final snapshot = await RosterRepository(prefs).load();

      expect(snapshot.roster, hasLength(1));
      expect(snapshot.roster.single.id, 'char_ok');
    });

    test('índice activo legacy fuera de rango se clampa', () async {
      SharedPreferences.setMockInitialValues({
        'character_roster_v2': [jsonEncode(buildFichaJson(id: 'a'))],
        'active_character_index': 7,
      });
      final prefs = await SharedPreferences.getInstance();
      final snapshot = await RosterRepository(prefs).load();
      expect(snapshot.activeIndex, 0);
    });
  });

  group('save/load', () {
    test('roundtrip preserva cargas, cantidades e índice', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = RosterRepository(prefs);

      final model = buildCharacter(
        weaponQuantity: 7,
        abilityChargesCurrent: 1,
        slotCurrent: 2,
      );
      await repo.save([model]);
      await repo.saveActiveIndex(0);

      final snapshot = await repo.load();
      expect(snapshot.roster.single.inventory.weapons.single.quantity, 7);
      expect(
        snapshot
            .roster
            .single
            .abilitiesByAction
            .action
            .single
            .magicCharges
            .current,
        1,
      );
      expect(snapshot.roster.single.spellSlots.slots.single.current, 2);
      expect(snapshot.activeIndex, 0);
    });
  });
}
