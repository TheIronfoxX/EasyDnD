// Tests de las reglas puras de resolución (Etapa 5c).
//
// resolveDamageRoll() es la cuenta que el HUD usa para tirar daño sin
// montar un widget: dado base + escalado por nivel de lanzamiento. Acá
// se fija el contrato (daño, tope de niveles, fórmulas rotas) para que
// el modal de la hoja se limite a mostrar el resultado.

import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/core/resolution.dart';

import 'fakes/fake_random.dart';

void main() {
  group('resolveDamageRoll — daño base', () {
    test('tira solo el dado base cuando la acción no escala', () {
      final result = resolveDamageRoll(
        baseDice: '2d6',
        isScalable: false,
        baseLevel: 0,
        scalingFormula: null,
        selectedLevel: 0,
        // FakeRandom devuelve el valor módulo las caras: 1 → 2, 2 → 3.
        random: FakeRandom([1, 2]),
      );

      expect(result, isNotNull);
      expect(result!.total, 5);
      expect(result.breakdown, '2d6');
    });

    test('respeta el bonificador plano embebido en la fórmula', () {
      final result = resolveDamageRoll(
        baseDice: '1d8+3',
        isScalable: false,
        baseLevel: 0,
        scalingFormula: null,
        selectedLevel: 0,
        random: FakeRandom([4]), // 4 + 1 + 3
      );

      expect(result!.total, 8);
      expect(result.breakdown, '1d8+3');
    });
  });

  group('resolveDamageRoll — escalado por nivel', () {
    test('suma un dado extra por cada nivel por encima del base', () {
      final result = resolveDamageRoll(
        baseDice: '1d8',
        isScalable: true,
        baseLevel: 3,
        scalingFormula: '1d6',
        selectedLevel: 5, // 2 niveles extra
        random: FakeRandom([0, 0, 0]), // 1 + 1 + 1
      );

      expect(result!.total, 3);
      expect(result.breakdown, '1d8 + 2 × 1d6');
    });

    test('el escalado plano suma el bonificador por nivel extra', () {
      final result = resolveDamageRoll(
        baseDice: '1d8',
        isScalable: true,
        baseLevel: 1,
        scalingFormula: '+2',
        selectedLevel: 3, // 2 niveles extra
        random: FakeRandom([0]), // 1 + 2 + 2
      );

      expect(result!.total, 5);
      expect(result.breakdown, contains('2 ×'));
    });

    test('no escala si el nivel elegido no supera el base', () {
      final result = resolveDamageRoll(
        baseDice: '1d8',
        isScalable: true,
        baseLevel: 3,
        scalingFormula: '1d6',
        selectedLevel: 2,
        random: FakeRandom([4]), // 5, sin dados extra
      );

      expect(result!.total, 5);
      expect(result.breakdown, '1d8');
    });

    test('no escala si isScalable es false aunque haya fórmula', () {
      final result = resolveDamageRoll(
        baseDice: '1d8',
        isScalable: false,
        baseLevel: 1,
        scalingFormula: '1d6',
        selectedLevel: 9,
        random: FakeRandom([0]),
      );

      expect(result!.total, 1);
      expect(result.breakdown, '1d8');
    });

    test('clampea los niveles extra a maxExtraLevels', () {
      final result = resolveDamageRoll(
        baseDice: '1d4',
        isScalable: true,
        baseLevel: 1,
        scalingFormula: '1d6',
        selectedLevel: 100,
        maxExtraLevels: 3,
        random: FakeRandom([0]), // FakeRandom cicla: cada dado vale 1
      );

      expect(result!.total, 4); // 1 base + 3 extras
      expect(result.breakdown, '1d4 + 3 × 1d6');
    });
  });

  group('resolveDamageRoll — fórmulas inválidas', () {
    test('devuelve null sin dado base', () {
      expect(
        resolveDamageRoll(
          baseDice: null,
          isScalable: true,
          baseLevel: 1,
          scalingFormula: '1d6',
          selectedLevel: 3,
        ),
        isNull,
      );
    });

    test('devuelve null si el dado base no parsea', () {
      for (final invalid in ['', '   ', 'mucho daño', '2d', 'd6']) {
        expect(
          resolveDamageRoll(
            baseDice: invalid,
            isScalable: false,
            baseLevel: 0,
            scalingFormula: null,
            selectedLevel: 0,
          ),
          isNull,
          reason: 'Debería rechazar "$invalid"',
        );
      }
    });

    test('una fórmula de escalado rota no suma nada (y no revienta)', () {
      final result = resolveDamageRoll(
        baseDice: '1d8',
        isScalable: true,
        baseLevel: 1,
        scalingFormula: 'no-es-un-dado',
        selectedLevel: 5,
        random: FakeRandom([0]),
      );

      expect(result!.total, 1);
    });

    test('sin fórmula de escalado tira solo el dado base', () {
      final result = resolveDamageRoll(
        baseDice: '1d10',
        isScalable: true,
        baseLevel: 1,
        scalingFormula: null,
        selectedLevel: 4,
        random: FakeRandom([0]),
      );

      expect(result!.total, 1);
      expect(result.breakdown, '1d10');
    });
  });
}
