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

  const DamageRoll({required this.total, required this.breakdown});
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
  final base = DiceFormula.tryParse(baseDice);
  if (base == null) return null;

  final rng = random ?? Random();
  var total = base.roll(random: rng);
  var extraLevels = 0;

  if (isScalable && scalingFormula != null) {
    extraLevels = (selectedLevel - baseLevel).clamp(0, maxExtraLevels);
    if (extraLevels > 0) {
      final scale = DiceFormula.tryParse(scalingFormula);
      if (scale != null) {
        // Una tirada de escalado por nivel extra: sirve igual para dados
        // ("1d6" por nivel) que para planos ("+2" por nivel).
        for (var i = 0; i < extraLevels; i++) {
          total += scale.roll(random: rng);
        }
      }
    }
  }

  return DamageRoll(
    total: total,
    breakdown: extraLevels > 0
        ? '$baseDice + $extraLevels × $scalingFormula'
        : baseDice,
  );
}
