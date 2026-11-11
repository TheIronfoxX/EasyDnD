import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/core/dice.dart';
import 'package:easydnd/core/dnd_rules.dart';

import 'fakes/fake_random.dart';

void main() {
  group('DiceFormula.tryParse', () {
    test('parsea dados con bono', () {
      final f = DiceFormula.tryParse('2d6+3')!;
      expect(f.count, 2);
      expect(f.sides, 6);
      expect(f.bonus, 3);
      expect(f.isFlat, isFalse);
    });

    test('parsea dados solos y con bono negativo', () {
      expect(DiceFormula.tryParse('1d8')!.bonus, 0);
      final f = DiceFormula.tryParse('8d6-2')!;
      expect(f.count, 8);
      expect(f.bonus, -2);
    });

    test('tolera espacios alrededor del signo', () {
      final f = DiceFormula.tryParse('2d6 + 3')!;
      expect(f.bonus, 3);
    });

    test('parsea planos puros (+3, -1, 4)', () {
      expect(DiceFormula.tryParse('+3')!.isFlat, isTrue);
      expect(DiceFormula.tryParse('+3')!.bonus, 3);
      expect(DiceFormula.tryParse('-1')!.bonus, -1);
      expect(DiceFormula.tryParse('4')!.bonus, 4);
    });

    test('rechaza todo lo demás', () {
      for (final bad in ['', '  ', 'hola', '1d', 'd6', '1d6+', '2d6 extra', '1d6 2d4', '2d6++3']) {
        expect(DiceFormula.tryParse(bad), isNull, reason: '"$bad" debería ser inválido');
      }
    });
  });

  group('DiceFormula', () {
    test('notation reconstruye la fórmula canónica', () {
      expect(const DiceFormula(2, 6, 3).notation, '2d6+3');
      expect(const DiceFormula(1, 8, 0).notation, '1d8');
      expect(const DiceFormula(2, 6, -2).notation, '2d6-2');
      expect(const DiceFormula(0, 0, 3).notation, '+3');
      expect(const DiceFormula(0, 0, -1).notation, '-1');
    });

    test('average calcula la media', () {
      expect(const DiceFormula(2, 6, 3).average, 10.0); // 2*3.5 + 3
      expect(const DiceFormula(0, 0, 5).average, 5.0);
    });

    test('roll tira los dados que dice (Random inyectable)', () {
      // 2d6+1 con resultados de nextInt 2 y 5 → (3 + 6) + 1 = 10.
      final f = DiceFormula.tryParse('2d6+1')!;
      expect(f.roll(random: FakeRandom([2, 5])), 10);
    });

    test('roll plano devuelve siempre el bono', () {
      final f = DiceFormula.tryParse('+7')!;
      expect(f.roll(random: FakeRandom([1, 2, 3])), 7);
    });
  });

  group('rollD20', () {
    test('normal tira un solo dado', () {
      final result = rollD20(random: FakeRandom([14]));
      expect(result.dice, hasLength(1));
      expect(result.kept, 15); // nextInt(20)=14 → dado 15
    });

    test('ventaja se queda con el más alto', () {
      final result = rollD20(mode: AdvantageMode.advantage, random: FakeRandom([14, 7]));
      expect(result.dice, [15, 8]);
      expect(result.kept, 15);
    });

    test('desventaja se queda con el más bajo', () {
      final result =
          rollD20(mode: AdvantageMode.disadvantage, random: FakeRandom([14, 7]));
      expect(result.kept, 8);
    });
  });

  group('DndRules', () {
    test('bonificador de competencia por nivel', () {
      expect(DndRules.proficiencyBonusFor(1), 2);
      expect(DndRules.proficiencyBonusFor(4), 2);
      expect(DndRules.proficiencyBonusFor(5), 3);
      expect(DndRules.proficiencyBonusFor(8), 3);
      expect(DndRules.proficiencyBonusFor(9), 4);
      expect(DndRules.proficiencyBonusFor(12), 4);
      expect(DndRules.proficiencyBonusFor(13), 5);
      expect(DndRules.proficiencyBonusFor(16), 5);
      expect(DndRules.proficiencyBonusFor(17), 6);
      expect(DndRules.proficiencyBonusFor(20), 6);
    });

    test('nivel extraído del texto de clase', () {
      expect(DndRules.levelFromCharacterClass('Artillero 6'), 6);
      expect(DndRules.levelFromCharacterClass('Mago 12'), 12);
      expect(DndRules.levelFromCharacterClass('Bárbaro'), 1);
      expect(DndRules.levelFromCharacterClass(''), 1);
    });

    test('dado de golpe inferido de la clase', () {
      expect(DndRules.hitDieSidesFromClass('Bárbaro 6'), 12);
      expect(DndRules.hitDieSidesFromClass('Paladín 3'), 10);
      expect(DndRules.hitDieSidesFromClass('Explorador 1'), 10);
      expect(DndRules.hitDieSidesFromClass('Artillero 6'), 8);
      expect(DndRules.hitDieSidesFromClass('Clérigo 2'), 8);
      expect(DndRules.hitDieSidesFromClass('Mago 5'), 6);
      expect(DndRules.hitDieSidesFromClass('Hechicero 8'), 6);
      // Clase desconocida → d8 (el más común).
      expect(DndRules.hitDieSidesFromClass('Alquimista Loco 7'), 8);
    });

    test('catálogo de condiciones completo y consistente', () {
      expect(DndRules.conditions, hasLength(12));
      expect(DndRules.conditions['Envenenado']!.causesDisadvantage, isTrue);
      expect(DndRules.conditions['Derribado']!.causesDisadvantage, isTrue);
      expect(DndRules.conditions['Cegado']!.causesDisadvantage, isTrue);
      expect(DndRules.conditions['Apresado']!.causesDisadvantage, isFalse);
      expect(DndRules.conditions['Invisible']!.causesDisadvantage, isFalse);
      for (final detail in DndRules.conditions.values) {
        expect(detail.description, isNotEmpty);
      }
    });
  });
}
