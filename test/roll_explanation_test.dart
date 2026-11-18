// La hoja de tirada explica en español llano qué se tira y contra qué.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/features/hud/hud_resolution_sheet.dart';

RollAction _action({
  int modifier = 7,
  String attackType = 'attack',
  String? damageDice,
  String? damageType,
  int? saveDc,
  String? healDice,
}) => RollAction(
  name: 'Prueba',
  kindLabel: 'Arma',
  icon: Icons.casino_rounded,
  modifier: modifier,
  attackType: attackType,
  damageDice: damageDice,
  damageType: damageType,
  saveDc: saveDc,
  healDice: healDice,
);

void main() {
  test('ataque: d20 + bono contra la Armadura y luego el daño', () {
    expect(
      explainRoll(_action(damageDice: '2d6+4')),
      'Tiras 1d20 +7 para golpear; si igualas o superas la Armadura del '
      'objetivo, tiras 2d6+4 de daño.',
    );
  });

  test('ataque con bono negativo y tipo de daño', () {
    final text = explainRoll(
      _action(modifier: -1, damageDice: '1d8', damageType: 'cortante'),
    );
    expect(text, contains('1d20 -1'));
    expect(text, contains('1d8 de cortante'));
  });

  test('salvación: el objetivo tira contra tu CD', () {
    expect(
      explainRoll(_action(attackType: 'save', saveDc: 15, damageDice: '8d6')),
      'El objetivo tira una salvación contra tu CD (15); si la falla, '
      'tiras 8d6 de daño.',
    );
  });

  test('sin tirada: curación, daño directo o solo efecto', () {
    expect(
      explainRoll(_action(attackType: 'none', healDice: '1d8+3')),
      contains('1d8+3 para curar'),
    );
    expect(
      explainRoll(_action(attackType: 'none', damageDice: '3d4')),
      contains('3d4 de daño'),
    );
    expect(
      explainRoll(_action(attackType: 'none')),
      'Sin tirada: se aplica el efecto directamente.',
    );
  });

  testWidgets('la hoja muestra la frase antes de tirar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showResolutionSheet(context, _action(damageDice: '2d6+4')),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('roll-explanation')), findsOneWidget);
    expect(find.textContaining('Tiras 1d20 +7 para golpear'), findsOneWidget);
  });
}
