import 'package:easydnd/domain/models/ability.dart';
import 'package:easydnd/domain/spell_effect.dart';
import 'package:flutter_test/flutter_test.dart';

Ability _a(Map<String, dynamic> extra) => Ability.fromJson({
  'id': 'a',
  'name': 'Conjuro',
  'type': 'spell',
  'attack_type': 'none',
  ...extra,
});

void main() {
  group('spellEffectOf', () {
    test('dados de curación → Curación, aunque también dañe', () {
      expect(
        spellEffectOf(_a({'heal_dice': '1d8', 'damage_dice': '2d6'})),
        SpellEffect.healing,
      );
    });

    test('dados de daño o tirada de ataque → Ataque', () {
      expect(spellEffectOf(_a({'damage_dice': '8d6'})), SpellEffect.attack);
      expect(spellEffectOf(_a({'attack_type': 'attack'})), SpellEffect.attack);
    });

    test('Defensa → Estados; Apoyo sin curar → Estados', () {
      expect(
        spellEffectOf(_a({'power_role': 'Defensa'})),
        SpellEffect.condition,
      );
      expect(
        spellEffectOf(
          _a({
            'power_role': 'Apoyo',
            'plain_summary': 'Tus aliados suman 1d4 a sus tiradas.',
          }),
        ),
        SpellEffect.condition,
      );
    });

    test('Apoyo que habla de curar → Curación', () {
      expect(
        spellEffectOf(
          _a({'power_role': 'Apoyo', 'plain_summary': 'Curas a un aliado.'}),
        ),
        SpellEffect.healing,
      );
    });

    test('salvación sin daño o palabras de condición → Estados', () {
      expect(spellEffectOf(_a({'attack_type': 'save'})), SpellEffect.condition);
      expect(
        spellEffectOf(_a({'plain_summary': 'El objetivo queda paralizado.'})),
        SpellEffect.condition,
      );
    });

    test('lo demás → Utilidad', () {
      expect(
        spellEffectOf(
          _a({'name': 'Luz', 'plain_summary': 'Haces que un objeto brille.'}),
        ),
        SpellEffect.utility,
      );
    });
  });
}
