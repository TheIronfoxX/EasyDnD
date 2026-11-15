import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/domain/models/ability.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/domain/models/weapon.dart';

import 'fakes/test_fichas.dart';

/// Serializa y relee una ficha — exactamente el camino que hacía la
/// app vieja al persistir en SharedPreferences y recargar al
/// reiniciar. Todos los tests de regresión de la Etapa 2 pasan por acá.
Map<String, dynamic> roundtrip(CharacterModel model) =>
    jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;

void main() {
  group('Ability — regresión del bug de la app vieja', () {
    test('roundtrip directo conserva magic_charges', () {
      final original = Ability.fromJson({
        'id': 'a1',
        'name': 'Test',
        'magic_charges': {'has_charges': true, 'max': 3, 'current': 1},
      });
      final revived = Ability.fromJson(original.toJson());

      expect(revived.magicCharges.hasCharges, isTrue);
      expect(revived.magicCharges.max, 3);
      expect(revived.magicCharges.current, 1); // no vuelve a 3 (el bug)
    });

    test('roundtrip de la ficha completa conserva las cargas', () {
      final model = buildCharacter(abilityChargesCurrent: 1);
      final revived = CharacterModel.fromJson(roundtrip(model));

      expect(revived.abilitiesByAction.action.single.magicCharges.current, 1);
    });

    test('sin magic_charges en el JSON queda hasCharges = false', () {
      final ability = Ability.fromJson({'id': 'a1', 'name': 'Test'});
      expect(ability.magicCharges.hasCharges, isFalse);
    });
  });

  group('Weapon.quantity — regresión del mapa global', () {
    test('roundtrip conserva la cantidad', () {
      final model = buildCharacter(weaponQuantity: 5);
      final revived = CharacterModel.fromJson(roundtrip(model));
      expect(revived.inventory.weapons.single.quantity, 5);
    });

    test('dos personajes con el MISMO id de arma no comparten cantidad', () {
      // El caso exacto que rompía la app vieja: weapon_quantity_<id>
      // era una clave global y las fichas se pisaban entre sí.
      final a = buildCharacter(id: 'char_a', name: 'A', weaponQuantity: 2);
      final b = buildCharacter(id: 'char_b', name: 'B', weaponQuantity: 7);

      final revivedA = CharacterModel.fromJson(roundtrip(a));
      final revivedB = CharacterModel.fromJson(roundtrip(b));

      expect(revivedA.inventory.weapons.single.quantity, 2);
      expect(revivedB.inventory.weapons.single.quantity, 7);
      expect(
        revivedA.inventory.weapons.single.id,
        revivedB.inventory.weapons.single.id,
      ); // mismo arma, distinta cantidad
    });

    test('is_unique fuerza quantity 1 al leer y al escribir', () {
      final model = buildCharacter(weaponIsUnique: true, weaponQuantity: 7);
      expect(model.inventory.weapons.single.quantity, 1); // al leer
      expect(
        model.toJson()['inventory']['weapons'][0]['quantity'],
        1,
      ); // al escribir
    });

    test('arma sin id genera uno a partir del nombre', () {
      final json = buildFichaJson();
      ((json['inventory'] as Map)['weapons'] as List).single.remove('id');
      final weapon = Weapon.fromJson(json['inventory']['weapons'][0]);
      expect(weapon.id, isNotEmpty);
    });
  });

  group('CharacterModel', () {
    test('toJson marca schema_version 2', () {
      final model = buildCharacter();
      expect(model.toJson()['schema_version'], 2);
      expect(CharacterModel.schemaVersion, 2);
    });

    test('roundtrip conserva id y todo el estado de combate', () {
      final model = buildCharacter(hpCurrent: 10, slotCurrent: 2);
      model.turnStatus.actionUsed = true;
      model.turnStatus.reactionUsed = true;
      model.turnStatus.movementRemaining = 4;
      model.activeConditions.add('Envenenado');

      final revived = CharacterModel.fromJson(roundtrip(model));

      expect(revived.id, 'char_test');
      expect(revived.basicInfo.currentHp, 10);
      expect(revived.spellSlots.slots.single.current, 2);
      expect(revived.spellSlots.maxLevel, 1);
      expect(revived.turnStatus.actionUsed, isTrue);
      expect(revived.turnStatus.reactionUsed, isTrue);
      expect(revived.turnStatus.movementRemaining, 4);
      expect(revived.activeConditions, ['Envenenado']);
      expect(revived.purse.gold, 10);
      expect(revived.resources.single.current, 2);
      expect(revived.companions.single.currentHp, 5);
      expect(revived.inventory.mundaneItems.single.quantity, 1);
      expect(revived.basicInfo.proficiencyBonus, 3); // nivel 5
    });

    test('sin id genera uno no vacío que persiste', () {
      final json = buildFichaJson()..remove('id');
      final model = CharacterModel.fromJson(json);
      expect(model.id, isNotEmpty);
      expect(model.id, isNot('char_test'));
      expect(model.toJson()['id'], model.id);
    });

    test('fallbacks de BasicInfo', () {
      final json = buildFichaJson(characterClass: 'Artillero 6');
      final basic = json['basic_info'] as Map;
      basic.remove('level');
      basic.remove('hp_current');
      basic.remove('hit_die_sides');
      basic.remove('hit_dice_max');
      basic.remove('hit_dice_current');
      basic.remove('speed');

      final model = CharacterModel.fromJson(json);

      expect(model.basicInfo.level, 6); // desde "Artillero 6"
      expect(model.basicInfo.currentHp, model.basicInfo.hpMax); // arranca full
      expect(model.basicInfo.hitDieSides, 8); // Artillero → d8
      expect(model.basicInfo.hitDiceMax, 6); // uno por nivel
      expect(model.basicInfo.hitDiceCurrent, 6);
      expect(model.basicInfo.speed, 30); // default humano
    });

    test('sin turn_status el movimiento arranca a tope según speed', () {
      final json = buildFichaJson(speed: 12)..remove('turn_status');
      final model = CharacterModel.fromJson(json);
      expect(model.turnStatus.movementRemaining, 12);
    });

    test(
      'turn_status viejo sin reactionUsed arranca con la reacción libre',
      () {
        final json = buildFichaJson();
        (json['turn_status'] as Map<String, dynamic>).remove('reactionUsed');
        final model = CharacterModel.fromJson(json);
        expect(model.turnStatus.reactionUsed, isFalse);
      },
    );

    test('SpellSlot sin current arranca lleno', () {
      final slot = SpellSlot.fromJson({'level': 1, 'max': 4});
      expect(slot.current, 4);
    });
  });

  group('AbilitiesByAction', () {
    test('all aplanal las cuatro categorías', () {
      final model = buildCharacter();
      model.abilitiesByAction.bonusAction.add(
        Ability.fromJson({'id': 'a2', 'name': 'B'}),
      );
      model.abilitiesByAction.passive.add(
        Ability.fromJson({'id': 'a3', 'name': 'P'}),
      );
      expect(model.abilitiesByAction.all.map((a) => a.id), ['a1', 'a2', 'a3']);
    });

    test('listFor resuelve cada categoría y cae en action', () {
      final abilities = buildCharacter().abilitiesByAction;
      expect(abilities.listFor('action'), same(abilities.action));
      expect(abilities.listFor('bonusAction'), same(abilities.bonusAction));
      expect(abilities.listFor('reaction'), same(abilities.reaction));
      expect(abilities.listFor('passive'), same(abilities.passive));
      expect(abilities.listFor('cualquier cosa'), same(abilities.action));
    });
  });

  group('MagicCharges', () {
    test('consume no baja de 0 y restoreAll recarga', () {
      final charges = Weapon.fromJson(
        buildFichaJson()['inventory']['weapons'][0],
      ).magicCharges;
      charges.current = 1;
      charges.consumeCharge();
      charges.consumeCharge(); // ya en 0, no baja más
      expect(charges.current, 0);
      charges.restoreAll();
      expect(charges.current, 3);
    });
  });

  group('StatsBlock.modFor', () {
    test('resuelve las seis claves de característica', () {
      final stats = buildCharacter(conMod: 2).stats;

      expect(stats.modFor('str'), 3);
      expect(stats.modFor('dex'), 1);
      expect(stats.modFor('con'), 2);
      expect(stats.modFor('int'), 0);
      expect(stats.modFor('wis'), 0);
      expect(stats.modFor('cha'), 0);
    });

    test('una clave vacía o desconocida vale 0 en vez de reventar', () {
      final stats = buildCharacter().stats;

      expect(stats.modFor(''), 0);
      expect(stats.modFor('luck'), 0);
      expect(stats.modFor('intelligence'), 0); // el JSON usa 'int'
    });
  });

  group('Purse', () {
    test('totalInGold convierte sin colapsar los stacks', () {
      final purse = buildCharacter().purse;
      expect(purse.totalInGold, closeTo(10.52, 0.0001)); // 10 + 0.5 + 0.02
      expect(purse.gold, 10);
      expect(purse.silver, 5);
      expect(purse.copper, 2);
    });
  });
}
