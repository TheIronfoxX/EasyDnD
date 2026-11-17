// Reglas puras de resolución de tiradas (Etapa 5c).
//
// El HUD necesita calcular el daño de un arma/conjuro —incluido el
// escalado por nivel de ranura— sin montar un widget. En la app vieja
// esta cuenta vivía dentro del State del modal, así que comprobarla
// exigía abrir un diálogo completo. Acá es una función sin Flutter,
// testeable sola, y el modal se limita a mostrarla.
//
// No duplica el parser: toda la notación ("2d6+3", "1d8", "+2") la
// resuelve DiceFormula de core/dice.dart.

import 'dart:math';

import 'dice.dart';

/// Resultado de una tirada de daño, con el desglose listo para pintar.
class DamageRoll {
  final int total;

  /// Fórmula usada, ej. "8d6" o "8d6 + 2 × 1d6". Informativo.
  final String breakdown;

  /// Desglose por grupo de dados ("2d8 [5, 3] = 8", "4d6 [...] = 14",
  /// "Bono +3"). Vacío si la fórmula es un plano puro.
  final List<DamageGroupBreakdown> groups;

  const DamageRoll({
    required this.total,
    required this.breakdown,
    this.groups = const [],
  });
}

/// Una línea del desglose de una [DamageRoll].
class DamageGroupBreakdown {
  /// "2d8", "4d6", "2 × 1d8 (escalado)" o "Bono".
  final String label;
  final List<int> dice;
  final int subtotal;

  const DamageGroupBreakdown(this.label, this.dice, this.subtotal);

  @override
  String toString() => dice.isEmpty
      ? '$label = $subtotal'
      : '$label [${dice.join(', ')}] = $subtotal';
}

/// Resuelve el daño base más el escalado por nivel de lanzamiento.
///
/// Devuelve null si [baseDice] es null o no parsea: la acción no inflige
/// daño resoluble y la UI simplemente no muestra la fase de daño.
///
/// [selectedLevel] solo suma niveles POR ENCIMA de [baseLevel]; si es
/// igual o menor (un truco, o una habilidad no escalable) se tira solo
/// el dado base. [maxExtraLevels] es un tope defensivo contra fichas
/// corruptas: nunca se disparan miles de dados por un número absurdo.
DamageRoll? resolveDamageRoll({
  required String? baseDice,
  required bool isScalable,
  required int baseLevel,
  required String? scalingFormula,
  required int selectedLevel,
  Random? random,
  int maxExtraLevels = 20,
}) {
  if (baseDice == null) return null;
  final base = DiceExpression.tryParse(baseDice);
  if (base == null) return null;

  final rng = random ?? Random();
  final baseRoll = base.rollDetailed(random: rng);
  var total = baseRoll.total;
  final groups = <DamageGroupBreakdown>[
    for (final g in baseRoll.groups)
      DamageGroupBreakdown(
        '${g.group.negative ? '-' : ''}${g.group.notation}',
        g.dice,
        g.subtotal,
      ),
    if (baseRoll.bonus != 0 || baseRoll.groups.isEmpty)
      DamageGroupBreakdown('Bono', const [], baseRoll.bonus),
  ];
  var extraLevels = 0;

  if (isScalable && scalingFormula != null) {
    extraLevels = (selectedLevel - baseLevel).clamp(0, maxExtraLevels);
    if (extraLevels > 0) {
      final scale = DiceExpression.tryParse(scalingFormula);
      if (scale != null) {
        // Una tirada de escalado por nivel extra: sirve igual para dados
        // ("1d6" por nivel), compuestos ("1d8+1d6") o planos ("+2").
        final perGroup = List.generate(scale.groups.length, (_) => <int>[]);
        var flat = 0;
        for (var i = 0; i < extraLevels; i++) {
          final r = scale.rollDetailed(random: rng);
          for (var k = 0; k < r.groups.length; k++) {
            perGroup[k].addAll(r.groups[k].dice);
          }
          flat += r.bonus;
        }
        for (var k = 0; k < scale.groups.length; k++) {
          final g = scale.groups[k];
          final sum = perGroup[k].fold<int>(0, (a, b) => a + b);
          groups.add(
            DamageGroupBreakdown(
              '$extraLevels × ${g.negative ? '-' : ''}${g.notation} (escalado)',
              perGroup[k],
              g.negative ? -sum : sum,
            ),
          );
        }
        if (flat != 0) {
          groups.add(DamageGroupBreakdown('Escalado plano', const [], flat));
        }
        total += groups
            .skip(groups.length - scale.groups.length - (flat != 0 ? 1 : 0))
            .fold<int>(0, (a, g) => a + g.subtotal);
      }
    }
  }

  return DamageRoll(
    total: total,
    breakdown: extraLevels > 0
        ? '$baseDice + $extraLevels × $scalingFormula'
        : baseDice,
    groups: groups,
  );
}
