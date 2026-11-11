import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/state/character_store.dart';

import 'fakes/fake_random.dart';
import 'fakes/test_fichas.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Levanta un store sobre los prefs mockeados del test. Llamar de
  /// nuevo simula "reiniciar la app": mismo almacenamiento, estado
  /// fresco.
  Future<CharacterStore> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    return store;
  }

  /// Deja correr el event loop para que las persistencias
  /// fire-and-forget del store (_notifyAndPersist) terminen de
  /// escribir antes de reconstruir el store.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('arranque', () {
    test('instalación nueva: ready, sin personaje activo, sin migración', () async {
      final store = await boot();
      expect(store.isReady, isTrue);
      expect(store.activeCharacter, isNull);
      expect(store.migratedFromLegacy, isFalse);
    });

    test('arranca migrando el roster de la app vieja', () async {
      SharedPreferences.setMockInitialValues({
        'character_roster_v2': [jsonEncode(buildFichaJson(id: 'char_a', name: 'A'))],
        'active_character_index': 0,
        'weapon_quantity_w1': 4,
      });
      final store = await boot();
      expect(store.migratedFromLegacy, isTrue);
      expect(store.roster, hasLength(1));
      expect(store.activeCharacter!.inventory.weapons.single.quantity, 4);
    });
  });

  group('roster', () {
    test('addCharacter añade y selecciona', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(name: 'A'));
      expect(store.roster, hasLength(1));
      expect(store.activeCharacter!.basicInfo.name, 'A');

      store.addCharacter(buildCharacter(id: 'b', name: 'B'));
      expect(store.activeCharacter!.basicInfo.name, 'B');
    });

    test('switchCharacter fuera de rango no hace nada', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(name: 'A'));
      store.switchCharacter(5);
      store.switchCharacter(-1);
      expect(store.activeIndex, 0);
    });

    test('deleteCharacter reajusta el índice para no apuntar al vacío', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'a', name: 'A'));
      store.addCharacter(buildCharacter(id: 'b', name: 'B'));
      store.addCharacter(buildCharacter(id: 'c', name: 'C'));
      store.switchCharacter(2); // activo: C

      store.deleteCharacter(0); // borro A → C corre a índice 1
      expect(store.activeCharacter!.basicInfo.name, 'C');

      store.deleteCharacter(store.activeIndex); // borro el activo (C)
      expect(store.activeCharacter!.basicInfo.name, 'B'); // cae al anterior

      store.deleteCharacter(0);
      store.deleteCharacter(0);
      expect(store.roster, isEmpty);
      expect(store.activeCharacter, isNull);
    });

    test('importCharacterFromText válido añade y selecciona', () async {
      final store = await boot();
      final result =
          store.importCharacterFromText(jsonEncode(buildFichaJson(name: 'Importado')));
      expect(result.isOk, isTrue);
      expect(store.roster, hasLength(1));
      expect(store.activeCharacter!.basicInfo.name, 'Importado');
    });

    test('importCharacterFromText inválido no toca el roster', () async {
      final store = await boot();
      final result = store.importCharacterFromText('la IA se fue de tema');
      expect(result.isOk, isFalse);
      expect(result.character, isNull);
      expect(store.roster, isEmpty);
    });

    test('replaceCharacterFromText sustituye sin duplicar', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'a', name: 'Original'));
      final result = store.replaceCharacterFromText(
        0,
        jsonEncode(buildFichaJson(id: 'a', name: 'Corregido')),
      );
      expect(result.isOk, isTrue);
      expect(store.roster, hasLength(1));
      expect(store.activeCharacter!.basicInfo.name, 'Corregido');
    });
  });

  group('vida y dados de golpe', () {
    test('applyDamage/applyHealing clampean entre 0 y hpMax', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(hpMax: 20, hpCurrent: 20));

      store.applyDamage(25);
      expect(store.activeCharacter!.basicInfo.currentHp, 0);

      store.applyHealing(999);
      expect(store.activeCharacter!.basicInfo.currentHp, 20);

      store.applyDamage(5);
      store.applyHealing(3);
      expect(store.activeCharacter!.basicInfo.currentHp, 18);
    });

    test('sin personaje activo, las mutaciones son no-op', () async {
      final store = await boot();
      store.applyDamage(10);
      store.applyHealing(10);
      store.longRest();
      expect(store.spendHitDice(2), 0);
      store.consumeSpellSlot(1);
      store.toggleCondition('Envenenado');
      expect(store.hasDisadvantage, isFalse);
      expect(store.activeCharacter, isNull); // y no reventó
    });

    test('spendHitDice es determinístico con Random inyectable', () async {
      final store = await boot();
      // Con mod +2 y dado d10: nextInt=3 → dado 4 → 4+2 = 6 de curación.
      store.addCharacter(buildCharacter(hpMax: 20, hpCurrent: 20, conMod: 2, hitDieSides: 10));
      store.applyDamage(10); // hp 10

      final healed = store.spendHitDice(1, random: FakeRandom([3]));
      expect(healed, 6);
      expect(store.activeCharacter!.basicInfo.currentHp, 16);
      expect(store.activeCharacter!.basicInfo.hitDiceCurrent, 4);
    });

    test('spendHitDice nunca cura menos de 1 por dado', () async {
      final store = await boot();
      // Con mod -5: dado 4 + (-5) = -1 → mínimo 1.
      store.addCharacter(buildCharacter(hpMax: 20, hpCurrent: 20, conMod: -5, hitDieSides: 10));
      store.applyDamage(10);

      final healed = store.spendHitDice(1, random: FakeRandom([3]));
      expect(healed, 1);
    });

    test('spendHitDice clama los dados a los disponibles', () async {
      final store = await boot();
      store.addCharacter(
        buildCharacter(hpMax: 20, hpCurrent: 20, conMod: 2, hitDieSides: 10, hitDiceMax: 5, hitDiceCurrent: 5),
      );
      store.applyDamage(20); // hp 0

      // Pide 10, tiene 5. Cada dado: nextInt(10)=0 → 1 + 2 = 3.
      final healed = store.spendHitDice(10, random: FakeRandom([0, 0, 0, 0, 0]));
      expect(healed, 15);
      expect(store.activeCharacter!.basicInfo.hitDiceCurrent, 0);
      expect(store.activeCharacter!.basicInfo.currentHp, 15);

      // Sin dados: devuelve 0 y no hace nada.
      expect(store.spendHitDice(3), 0);
    });

    test('longRest restaura vida, ranuras, cargas y mitad de los dados de golpe', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(
        hpMax: 20,
        hpCurrent: 20,
        hitDiceMax: 5,
        hitDiceCurrent: 5,
      ));

      // Llevarlo a un estado gastado de todo.
      store.applyDamage(20); // hp 0
      store.spendHitDice(4, random: FakeRandom([0, 0, 0, 0])); // dados 1, hp 12
      store.applyDamage(7); // hp 5
      store.consumeSpellSlot(1);
      store.consumeSpellSlot(1);
      store.consumeSpellSlot(1); // ranura 1/4
      store.consumeWeaponCharge('w1');
      store.consumeWeaponCharge('w1');
      store.consumeWeaponCharge('w1'); // cargas arma 0/3
      store.consumeAbilityCharge('a1'); // cargas habilidad 0/3

      store.longRest();

      final character = store.activeCharacter!;
      expect(character.basicInfo.currentHp, 20);
      expect(character.spellSlots.slots.single.current, 4);
      expect(character.inventory.weapons.single.magicCharges.current, 3);
      expect(character.abilitiesByAction.action.single.magicCharges.current, 3);
      // 1 dado + ceil(5/2)=3 recuperados, clampeado a 5.
      expect(character.basicInfo.hitDiceCurrent, 4);
    });

    test('customRest ejecuta solo lo marcado', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(hpCurrent: 5, weaponChargesCurrent: 0, slotCurrent: 1));

      store.customRest(healMax: true);
      final character = store.activeCharacter!;
      expect(character.basicInfo.currentHp, 20);
      expect(character.spellSlots.slots.single.current, 1); // sin tocar
      expect(character.inventory.weapons.single.magicCharges.current, 0); // sin tocar

      store.customRest(restoreSpells: true, restoreCharges: true);
      expect(character.spellSlots.slots.single.current, 4);
      expect(character.inventory.weapons.single.magicCharges.current, 3);
    });
  });

  group('ranuras y cargas', () {
    test('consumeSpellSlot gasta y se protege', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(slotCurrent: 4));

      store.consumeSpellSlot(1);
      store.consumeSpellSlot(1);
      expect(store.activeCharacter!.spellSlots.slots.single.current, 2);

      store.consumeSpellSlot(9); // nivel inexistente: no-op
      store.spendSpellSlot(1); // alias público
      store.consumeSpellSlot(1);
      store.consumeSpellSlot(1); // ya en 0: no baja más
      expect(store.activeCharacter!.spellSlots.slots.single.current, 0);
    });

    test('restoreAllSpellSlots recarga todo', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(slotCurrent: 0));
      store.restoreAllSpellSlots();
      expect(store.activeCharacter!.spellSlots.slots.single.current, 4);
    });

    test('cargas de armas por id, con guards', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(weaponChargesCurrent: 3));

      store.consumeWeaponCharge('w1');
      expect(store.activeCharacter!.inventory.weapons.single.magicCharges.current, 2);

      store.consumeWeaponCharge('arma-inexistente'); // no-op
      store.restoreWeaponCharges('w1');
      expect(store.activeCharacter!.inventory.weapons.single.magicCharges.current, 3);
    });

    test('cargas de habilidades por id, con guards', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(abilityChargesCurrent: 2));

      store.consumeAbilityCharge('a1');
      expect(store.activeCharacter!.abilitiesByAction.action.single.magicCharges.current, 1);

      store.consumeAbilityCharge('habilidad-inexistente'); // no-op
      store.restoreAbilityCharges('a1');
      expect(store.activeCharacter!.abilitiesByAction.action.single.magicCharges.current, 3);
    });
  });

  group('condiciones y turno', () {
    test('toggleCondition activa y desactiva; hasDisadvantage resuelve', () async {
      final store = await boot();
      store.addCharacter(buildCharacter());

      store.toggleCondition('Envenenado');
      expect(store.activeCharacter!.activeConditions, ['Envenenado']);
      expect(store.hasDisadvantage, isTrue);

      store.toggleCondition('Apresado'); // no impone desventaja
      expect(store.hasDisadvantage, isTrue);

      store.toggleCondition('Envenenado'); // off
      expect(store.hasDisadvantage, isFalse);

      store.toggleCondition('Condición Casera'); // fuera del catálogo
      expect(store.hasDisadvantage, isFalse); // se ignora, no rompe
    });

    test('economía de acción del turno', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(speed: 9));

      store.toggleAction('action');
      expect(store.activeCharacter!.turnStatus.actionUsed, isTrue);
      store.toggleAction('action');
      expect(store.activeCharacter!.turnStatus.actionUsed, isFalse);
      store.toggleAction('reaccion'); // tipo desconocido: no-op
      expect(store.activeCharacter!.turnStatus.actionUsed, isFalse);

      store.setMovementRemaining(99);
      expect(store.activeCharacter!.turnStatus.movementRemaining, 9);
      store.setMovementRemaining(-4);
      expect(store.activeCharacter!.turnStatus.movementRemaining, 0);

      store.toggleAction('bonus');
      store.setMovementRemaining(3);
      store.resetTurn();
      final status = store.activeCharacter!.turnStatus;
      expect(status.actionUsed, isFalse);
      expect(status.bonusActionUsed, isFalse);
      expect(status.movementRemaining, 9);
    });
  });

  group('recursos y compañeros', () {
    test('recursos clampean entre 0 y max', () async {
      final store = await boot();
      store.addCharacter(buildCharacter()); // Furia 2/3

      store.decrementResource('Furia');
      expect(store.activeCharacter!.resources.single.current, 1);
      store.decrementResource('Furia');
      store.decrementResource('Furia');
      store.decrementResource('Furia'); // ya en 0
      expect(store.activeCharacter!.resources.single.current, 0);

      store.incrementResource('Furia');
      store.incrementResource('Furia');
      store.incrementResource('Furia');
      store.incrementResource('Furia'); // ya en 3
      expect(store.activeCharacter!.resources.single.current, 3);

      store.decrementResource('Recurso Inexistente'); // no-op
    });

    test('restoreAllResources recarga todo', () async {
      final store = await boot();
      store.addCharacter(buildCharacter());
      store.decrementResource('Furia');
      store.decrementResource('Furia');
      store.restoreAllResources();
      expect(store.activeCharacter!.resources.single.current, 3);
    });

    test('compañeros clampean y se protegen', () async {
      final store = await boot();
      store.addCharacter(buildCharacter()); // Lobo 5/10

      store.updateCompanionHp(0, 3);
      expect(store.activeCharacter!.companions.single.currentHp, 8);
      store.updateCompanionHp(0, -100);
      expect(store.activeCharacter!.companions.single.currentHp, 0);

      store.updateCompanionHp(7, 5); // índice inválido: no-op
      store.removeCompanion(7); // índice inválido: no-op
      expect(store.activeCharacter!.companions, hasLength(1));

      store.removeCompanion(0);
      expect(store.activeCharacter!.companions, isEmpty);
    });
  });

  group('inventario', () {
    test('bolsa: añadir, gastar y fijar clampean a 0', () async {
      final store = await boot();
      store.addCharacter(buildCharacter()); // 10 oro, 5 plata, 2 cobre

      store.addCurrency(CurrencyType.gold, 5);
      expect(store.activeCharacter!.purse.gold, 15);

      store.spendCurrency(CurrencyType.gold, 999);
      expect(store.activeCharacter!.purse.gold, 0);

      store.setCurrency(CurrencyType.silver, -7);
      expect(store.activeCharacter!.purse.silver, 0);

      store.addCurrency(CurrencyType.copper, -5); // negativo: no-op
      expect(store.activeCharacter!.purse.copper, 2);
    });

    test('códice: los tres campos de texto', () async {
      final store = await boot();
      store.addCharacter(buildCharacter());

      store.updateUserTactics('táctica');
      store.updateAdventureNotes('diario');
      store.setAiTips('consejos');
      final character = store.activeCharacter!;
      expect(character.userTactics, 'táctica');
      expect(character.adventureNotes, 'diario');
      expect(character.aiTips, 'consejos');
    });

    test('avatares y enlace Nivel20', () async {
      final store = await boot();
      store.addCharacter(buildCharacter());

      store.setAvatarPath('/photos/perfil.jpg');
      store.setLoreAvatarPath('/photos/lore.jpg');
      store.updateNivel20Link('https://nivel20.com/x');
      final character = store.activeCharacter!;
      expect(character.avatarPath, '/photos/perfil.jpg');
      expect(character.loreAvatarPath, '/photos/lore.jpg');
      expect(character.basicInfo.nivel20Link, 'https://nivel20.com/x');
    });

    test('cantidad de armas: steppers con floor y armas únicas congeladas', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(weaponQuantity: 2));

      store.incrementQuantity('w1');
      expect(store.activeCharacter!.inventory.weapons.single.quantity, 3);
      store.decrementQuantity('w1');
      store.decrementQuantity('w1');
      store.decrementQuantity('w1'); // floor en 0
      expect(store.activeCharacter!.inventory.weapons.single.quantity, 0);

      store.incrementQuantity('arma-inexistente'); // no-op

      store.switchCharacter(0);
      store.addCharacter(buildCharacter(
        id: 'unique-char',
        name: 'Unic',
        weaponIsUnique: true,
        weaponQuantity: 1,
      ));
      store.incrementQuantity('w1'); // única: siempre 1
      expect(store.activeCharacter!.inventory.weapons.single.quantity, 1);
    });

    test('REGRESIÓN: cantidades independientes por personaje', () async {
      final store = await boot();
      // Dos fichas con el MISMO id de arma ('w1'): el mapa global de
      // la app vieja las pisaba entre sí.
      store.addCharacter(buildCharacter(id: 'char_a', name: 'A', weaponQuantity: 1));
      store.addCharacter(buildCharacter(id: 'char_b', name: 'B', weaponQuantity: 1));

      // B está activa (la última añadida): subo su cantidad.
      store.incrementQuantity('w1');
      store.incrementQuantity('w1');
      expect(store.activeCharacter!.inventory.weapons.single.quantity, 3);

      // A no se enteró de nada.
      store.switchCharacter(0);
      expect(store.activeCharacter!.inventory.weapons.single.quantity, 1);

      // Y tras reiniciar la app, cada uno conserva la suya.
      await flush();
      final reloaded = await boot();
      expect(reloaded.roster[0].inventory.weapons.single.quantity, 1);
      expect(reloaded.roster[1].inventory.weapons.single.quantity, 3);
    });

    test('removeWeapon saca el arma del personaje activo', () async {
      final store = await boot();
      store.addCharacter(buildCharacter());
      store.removeWeapon('w1');
      expect(store.activeCharacter!.inventory.weapons, isEmpty);
      store.removeWeapon('w1'); // idem dos veces: no-op
    });

    test('objetos mundanos: alta, edición y baja', () async {
      final store = await boot();
      store.addCharacter(buildCharacter()); // trae "Cuerda" x1

      store.addEmptyMundaneItem();
      expect(store.activeCharacter!.inventory.mundaneItems, hasLength(2));
      expect(store.activeCharacter!.inventory.mundaneItems.last.name, 'Nuevo Objeto');

      store.updateMundaneItemQuantity(0, -5); // clamp a 0
      expect(store.activeCharacter!.inventory.mundaneItems[0].quantity, 0);
      store.updateMundaneItemQuantity(0, 7);
      expect(store.activeCharacter!.inventory.mundaneItems[0].quantity, 7);

      store.removeMundaneItem(9); // índice inválido: no-op
      store.removeMundaneItem(1);
      expect(store.activeCharacter!.inventory.mundaneItems, hasLength(1));
    });

    test('habilidades: alta, edición con mudanza de categoría y baja', () async {
      final store = await boot();
      store.addCharacter(buildCharacter());

      store.addAbility(
        actionType: 'passive',
        name: 'Visión en la Oscuridad',
        description: 'Ve en penumbra',
        tacticalRole: 'Ofensivo',
      );
      final passives = store.activeCharacter!.abilitiesByAction.passive;
      expect(passives, hasLength(1));
      expect(passives.single.name, 'Visión en la Oscuridad');
      expect(passives.single.tacticalRole, 'Ofensivo');
      expect(passives.single.type, 'passive'); // forzado en pasivas

      // Mudar la pasiva a "action" conserva el id.
      final abilityId = passives.single.id;
      store.updateAbility(abilityId: abilityId, actionType: 'action', name: 'Renombrada');
      expect(store.activeCharacter!.abilitiesByAction.passive, isEmpty);
      expect(
        store.activeCharacter!.abilitiesByAction.action.any((a) => a.id == abilityId),
        isTrue,
      );
      // El resto de habilidades sigue intacto.
      expect(store.activeCharacter!.abilitiesByAction.action, hasLength(2));

      store.removeAbility(abilityId);
      store.removeAbility(abilityId); // doble tap: no-op la segunda
      expect(store.activeCharacter!.abilitiesByAction.action, hasLength(1));
    });
  });

  group('persistencia (las dos regresiones de la app vieja)', () {
    test('REGRESIÓN: las cargas de habilidades sobreviven un reinicio', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(abilityChargesCurrent: 2));

      store.consumeAbilityCharge('a1');
      store.consumeAbilityCharge('a1'); // 0/3
      expect(store.activeCharacter!.abilitiesByAction.action.single.magicCharges.current, 0);

      await flush();
      final reloaded = await boot();
      // En la app vieja esto volvía a 3: el toJson de Ability perdía
      // magic_charges y el arranque las recargaba al máximo.
      expect(
        reloaded.activeCharacter!.abilitiesByAction.action.single.magicCharges.current,
        0,
      );
      expect(
        reloaded.activeCharacter!.abilitiesByAction.action.single.magicCharges.max,
        3,
      );
    });

    test('las cargas de armas sobreviven un reinicio', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(weaponChargesCurrent: 2));
      store.consumeWeaponCharge('w1'); // 1/3

      await flush();
      final reloaded = await boot();
      expect(
        reloaded.activeCharacter!.inventory.weapons.single.magicCharges.current,
        1,
      );
    });

    test('el índice activo sobrevive un reinicio', () async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_a', name: 'A'));
      store.addCharacter(buildCharacter(id: 'char_b', name: 'B'));
      store.switchCharacter(0);

      await flush();
      final reloaded = await boot();
      expect(reloaded.activeCharacter!.basicInfo.name, 'A');
    });
  });
}
