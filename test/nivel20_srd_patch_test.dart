import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/core/dice.dart';
import 'package:easydnd/core/resolution.dart';
import 'package:easydnd/domain/character_validator.dart';
import 'package:easydnd/domain/models/ability.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/domain/models/srd_spell.dart';
import 'package:easydnd/domain/models/weapon.dart';
import 'package:easydnd/domain/nivel20_mapper.dart';
import 'package:easydnd/domain/nivel20_patch.dart';
import 'package:easydnd/features/import/nivel20_import.dart';

import 'fakes/fake_random.dart';

void main() {
  late Map<String, dynamic> raw;
  late List<SrdSpell> srd;

  setUpAll(() {
    raw = jsonDecode(File('test/fixtures/nivel20/kael_nar_ardinys.trimmed.json')
        .readAsStringSync()) as Map<String, dynamic>;
    srd = (jsonDecode(File('assets/srd/spells_5e.json').readAsStringSync())
            as List)
        .map((e) => SrdSpell.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  Map<String, dynamic> find(Map<String, dynamic> json, String name) =>
      (json['abilities_by_action'] as Map)
          .values
          .expand((l) => l as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((a) => a['name'] == name);

  group('conditional_damage', () {
    test('el Bastón versátil sobrevive al roundtrip del modelo', () {
      final c = Nivel20Mapper.map(raw);
      final staff = c.inventory.weapons.single;
      expect(staff.conditionalDamage.single.trigger, 'Ataque a dos manos');
      expect(staff.conditionalDamage.single.dice, '1d8-1');
      expect(staff.conditionalDamage.single.type, 'contundente');

      final back = Weapon.fromJson(
        jsonDecode(jsonEncode(staff.toJson())) as Map<String, dynamic>,
      );
      expect(back.conditionalDamage.single.toJson(), {
        'trigger': 'Ataque a dos manos',
        'dice': '1d8-1',
        'type': 'contundente',
      });
    });

    test('lee también el shape antiguo (condition/damage_dice/damage_type)', () {
      final c = ConditionalDamage.fromJson({
        'condition': 'A dos manos',
        'damage_dice': '1d10+4',
        'damage_type': 'cortante',
      });
      expect(c.toJson(), {'trigger': 'A dos manos', 'dice': '1d10+4', 'type': 'cortante'});
    });
  });

  group('Ability.toJson — esquema estricto', () {
    final ability = Ability.fromJson({
      'id': 'x',
      'name': 'X',
      'attack_type': 'save',
      'damage_dice': '2d6',
      'tactical_role': 'Ofensivo',
    });

    test('pasivas: sin attack_type ni damage_dice, con tactical_role', () {
      final j = ability.toJson(category: 'passive');
      expect(j.containsKey('attack_type'), isFalse);
      expect(j.containsKey('damage_dice'), isFalse);
      expect(j['tactical_role'], 'Ofensivo');
    });

    test('activas: sin tactical_role, con attack_type y damage_dice', () {
      for (final cat in ['action', 'bonus_action', 'reaction']) {
        final j = ability.toJson(category: cat);
        expect(j.containsKey('tactical_role'), isFalse, reason: cat);
        expect(j['attack_type'], 'save');
        expect(j['damage_dice'], '2d6');
      }
    });

    test('AbilitiesByAction.toJson aplica la limpieza por categoría', () {
      final group = AbilitiesByAction(
        action: [ability],
        bonusAction: [],
        reaction: [],
        passive: [ability],
      ).toJson();
      expect((group['action'] as List).single.containsKey('tactical_role'), isFalse);
      expect((group['passive'] as List).single.containsKey('attack_type'), isFalse);
    });
  });

  group('dados compuestos', () {
    test('parsea 2d8+4d6, 1d8+1d6+3 y planos; rechaza basura', () {
      final a = DiceExpression.tryParse('2d8+4d6')!;
      expect(a.groups.map((g) => g.notation), ['2d8', '4d6']);
      expect(a.bonus, 0);
      expect(a.notation, '2d8+4d6');
      expect(a.isCompound, isTrue);

      final b = DiceExpression.tryParse('1d8 + 1d6 + 3')!;
      expect(b.groups.length, 2);
      expect(b.bonus, 3);
      expect(b.notation, '1d8+1d6+3');

      expect(DiceExpression.tryParse('2d6-1')!.bonus, -1);
      expect(DiceExpression.tryParse('+3')!.isFlat, isTrue);
      for (final bad in ['', '2d8+', '2d8 4d6', '2d8++4d6', 'hola', '2d8+4d']) {
        expect(DiceExpression.tryParse(bad), isNull, reason: bad);
      }
      expect(a.average, closeTo(2 * 4.5 + 4 * 3.5, 1e-9));
    });

    test('rollDetailed tira todos los grupos y desglosa', () {
      // nextInt % max: con [0] todos los dados valen 1.
      final r = DiceExpression.tryParse('2d8+4d6+3')!.rollDetailed(random: FakeRandom([0]));
      expect(r.groups[0].dice, [1, 1]);
      expect(r.groups[1].dice, [1, 1, 1, 1]);
      expect(r.total, 2 + 4 + 3);
    });

    test('resolveDamageRoll devuelve el desglose por grupo', () {
      final r = resolveDamageRoll(
        baseDice: '2d8+4d6',
        isScalable: true,
        baseLevel: 4,
        scalingFormula: '1d8',
        selectedLevel: 5,
        random: FakeRandom([0]),
      )!;
      expect(r.total, 2 + 4 + 1);
      expect(r.groups.map((g) => g.label), ['2d8', '4d6', '1 × 1d8 (escalado)']);
      expect(r.groups.map((g) => g.subtotal), [2, 4, 1]);
    });

    test('el validador acepta dados compuestos y avisa de los rotos', () {
      final json = Nivel20Mapper.toJson(raw, srd: srd);
      expect(
        CharacterValidator.validateMap(json).issues.where((i) => i.field.contains('damage_dice')),
        isEmpty,
      );
      find(json, 'Tormenta de hielo')['damage_dice'] = '2d8 4d6';
      expect(
        CharacterValidator.validateMap(json).issues.any((i) => i.field.contains('damage_dice')),
        isTrue,
      );
    });
  });

  group('cruce de conjuros con el SRD', () {
    test('Tormenta de hielo hereda dado compuesto, escalado y descripción', () {
      final ice = find(Nivel20Mapper.toJson(raw, srd: srd), 'Tormenta de hielo');
      expect(ice['damage_dice'], '2d8+4d6');
      expect(ice['scaling_formula'], '1d8');
      expect(ice['is_scalable'], isTrue);
      expect(ice['attack_type'], 'save');
      expect(ice['base_level'], 4);
      expect(ice['lore_description'], contains('granizo'));
    });

    test('sin catálogo cae al texto crudo de Nivel20 (fallback)', () {
      final ice = find(Nivel20Mapper.toJson(raw), 'Tormenta de hielo');
      expect(ice['damage_dice'], '2d8+4');
    });

    test('el cruce ignora mayúsculas y tildes', () {
      expect(normalizeSpellName('  TORMENTA  de Hielo '), 'tormenta de hielo');
      expect(normalizeSpellName('Palabra de Curación'), 'palabra de curacion');
      final mutated = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      final text = jsonEncode(mutated).replaceAll('Manos ardientes', 'MANOS ÁRDIENTES');
      final json = Nivel20Mapper.toJson(jsonDecode(text) as Map<String, dynamic>, srd: srd);
      final manos = find(json, 'MANOS ÁRDIENTES');
      expect(manos['lore_description'], srd.firstWhere((s) => s.name == 'Manos ardientes').description);
    });

    test('homebrew fuera del SRD conserva los datos de Nivel20', () {
      final json = Nivel20Mapper.toJson(raw, srd: srd);
      final retirada = find(json, 'Retirada expeditiva');
      final sin = find(Nivel20Mapper.toJson(raw), 'Retirada expeditiva');
      expect(retirada['lore_description'], sin['lore_description']);
      expect(retirada['tactical_summary'], sin['tactical_summary']);
    });

    test('los trucos conservan el dado ya escalado al nivel del personaje', () {
      final rayo = find(Nivel20Mapper.toJson(raw, srd: srd), 'Rayo de fuego');
      expect(rayo['damage_dice'], '2d10');
      expect(rayo['is_scalable'], isFalse);
    });
  });

  group('parche de IA', () {
    const patchText = '''
Aquí tienes:
```json
{
  "classified_features": [
    {"name": "Forma cambiante", "category": "action", "attack_type": "none",
     "tactical_summary": "Te conviertes en zorro | Gasta: acción",
     "lore_description": "Tu cuerpo se pliega."},
    {"name": "Supernova", "category": "passive", "tactical_role": "Ofensivo",
     "attack_type": "save"},
    {"name": "Tormenta de hielo", "category": "bonus_action", "attack_type": "attack"},
    {"name": "Truco nuevo", "category": "reaction", "attack_type": "none"}
  ],
  "resources": [
    {"name": "Forma cambiante", "current": 2, "max": 2},
    {"name": "Basura", "current": 1, "max": 0}
  ],
  "inventory": {"mundane_items": [
    {"name": "Aguja infalible", "description": "Nunca se dobla", "quantity": 1},
    {"name": "Cuerda", "quantity": 2}
  ]},
  "lore_info": {"tactical_summary": "Mago de evocación.", "lore_description": "Sabor."},
  "stats": {"str": {"value": 30}}, "spell_slots": []
}
```''';

    late CharacterModel base;
    late CharacterModel merged;

    setUpAll(() {
      base = Nivel20Mapper.map(raw, srd: srd);
      merged = Nivel20Patch.apply(base, Nivel20Patch.tryDecode(patchText)!);
    });

    test('tryDecode distingue parche de ficha completa y de basura', () {
      expect(Nivel20Patch.tryDecode(patchText), isNotNull);
      expect(Nivel20Patch.tryDecode(jsonEncode(base.toJson())), isNull);
      expect(Nivel20Patch.tryDecode('hola'), isNull);
      expect(Nivel20Patch.tryDecode('{"foo": 1}'), isNull);
    });

    test('atributos, PG, CA, velocidad, ranuras, armas y conjuros quedan intactos', () {
      final a = base.toJson();
      final b = merged.toJson();
      for (final k in ['basic_info', 'stats', 'skills', 'spell_slots', 'purse']) {
        expect(b[k], a[k], reason: k);
      }
      expect(b['inventory']['weapons'], a['inventory']['weapons']);

      List<dynamic> spells(Map<String, dynamic> j) => (j['abilities_by_action'] as Map)
          .values
          .expand((l) => l as List)
          .where((x) => x['type'] == 'spell')
          .toList();
      expect(spells(b), spells(a)); // incluso Tormenta de hielo (el parche la intentó mover)
      expect(merged.basicInfo.hpMax, base.basicInfo.hpMax);
      expect(base.toJson()['abilities_by_action'], isNotNull); // base no se muta
    });

    test('clasifica rasgos: mueve de categoría y respeta el esquema', () {
      final forma = merged.abilitiesByAction.action.firstWhere((a) => a.name == 'Forma cambiante');
      expect(forma.attackType, 'none');
      expect(forma.tacticalSummary, contains('zorro'));
      expect(base.abilitiesByAction.passive.any((a) => a.name == 'Forma cambiante'), isTrue);
      expect(merged.abilitiesByAction.passive.any((a) => a.name == 'Forma cambiante'), isFalse);

      final nova = merged.abilitiesByAction.passive.firstWhere((a) => a.name == 'Supernova');
      expect(nova.tacticalRole, 'Ofensivo');

      final nuevo = merged.abilitiesByAction.reaction.single;
      expect(nuevo.name, 'Truco nuevo');
      final ids = merged.abilitiesByAction.all.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('resources: añade válidos y descarta los inválidos', () {
      expect(merged.resources.map((r) => r.name), ['Forma cambiante']);
      expect(merged.resources.single.max, 2);
      expect(merged.resources.single.current, 2);
    });

    test('inventario: desglosa y reemplaza el objeto genérico "Equipo"', () {
      final names = merged.inventory.mundaneItems.map((m) => m.name).toList();
      expect(names, containsAll(['Aguja infalible', 'Cuerda']));
      expect(names, isNot(contains('Equipo')));
      expect(merged.inventory.mundaneItems.firstWhere((m) => m.name == 'Cuerda').quantity, 2);
    });

    test('lore_info: resumen táctico a las notas de la IA', () {
      expect(merged.aiTips, 'Mago de evocación.');
    });

    test('Nivel20Import.applyPatch devuelve una ficha válida', () {
      final r = Nivel20Import.applyPatch(raw, patchText, srd: srd);
      expect(r.isOk, isTrue);
      expect(r.character!.resources.single.name, 'Forma cambiante');
      expect(Nivel20Import.applyPatch(raw, 'no es json', srd: srd).isOk, isFalse);
    });
  });
}
