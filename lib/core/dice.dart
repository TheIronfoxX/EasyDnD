// Parser y tirador de dados — LA única implementación de notación de
// dados de toda la app.
//
// En el código viejo esta lógica estaba triplicada y divergente: el
// regex de `_parseDice` en resolution_modal.dart, el casi-igual
// `_looksLikeValidDiceOrFlat` en ability_model.dart y el dado suelto
// dentro de spendHitDice en character_provider.dart. Acá vive una sola
// vez, se testea una sola vez, y todo el resto (modal de tiradas,
// escalado de conjuros, dados de golpe) la consume desde acá.

import 'dart:math';

/// Modo de una tirada de d20.
enum AdvantageMode { normal, advantage, disadvantage }

/// Una fórmula de dados ya parseada: "2d6+3", "1d8", "8d6-2", o un
/// plano puro ("+3", "-1", "4") para habilidades que escalan con un
/// número fijo por nivel en vez de tirar dados extra.
class DiceFormula {
  final int count; // cantidad de dados (0 si es plano)
  final int sides; // caras del dado (0 si es plano)
  final int bonus; // bonificador plano, puede ser negativo

  const DiceFormula(this.count, this.sides, this.bonus);

  /// Un "dado" que no tira nada: siempre vale [bonus].
  bool get isFlat => count == 0 && sides == 0;

  /// Notación canónica reconstruida: "2d6+3", "1d8", "+3", "-1".
  String get notation {
    if (isFlat) {
      return bonus >= 0 ? '+$bonus' : '$bonus';
    }
    final base = '${count}d$sides';
    if (bonus == 0) return base;
    return '$base${bonus > 0 ? '+' : ''}$bonus';
  }

  /// Valor esperado (media). Útil para que la UI muestre "~21 de daño
  /// promedio" sin recalcular nada a mano.
  double get average {
    if (isFlat) return bonus.toDouble();
    return count * (sides + 1) / 2 + bonus;
  }

  /// Parsea una fórmula. Tolera espacios alrededor del signo
  /// ("2d6 + 3"). Null si el string no es ni notación de dado ni un
  /// plano válido — es el reemplazo directo del viejo
  /// `_looksLikeValidDiceOrFlat` y del `_parseDice` del modal.
  static DiceFormula? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final diceMatch =
        RegExp(r'^(\d+)d(\d+)\s*([+-]\s*\d+)?$').firstMatch(trimmed);
    if (diceMatch != null) {
      final bonusRaw = diceMatch.group(3)?.replaceAll(' ', '') ?? '0';
      return DiceFormula(
        int.parse(diceMatch.group(1)!),
        int.parse(diceMatch.group(2)!),
        int.parse(bonusRaw),
      );
    }

    final flatMatch = RegExp(r'^([+-]?\s*\d+)$').firstMatch(trimmed);
    if (flatMatch != null) {
      return DiceFormula(
        0,
        0,
        int.parse(flatMatch.group(1)!.replaceAll(' ', '')),
      );
    }

    return null;
  }

  /// Tira la fórmula y devuelve el total. [random] es inyectable para
  /// que los tests sean determinísticos.
  int roll({Random? random}) {
    final rng = random ?? Random();
    if (isFlat) return bonus;
    var total = bonus;
    for (var i = 0; i < count; i++) {
      total += rng.nextInt(sides) + 1;
    }
    return total;
  }
}

/// Resultado de una tirada de d20. Guarda TODOS los dados tirados para
/// que la UI pueda mostrar el detalle ("tiraste 14 y 7 — con ventaja
/// cuenta el 14") sin repetir la lógica de selección.
class D20RollResult {
  final List<int> dice;
  final AdvantageMode mode;

  const D20RollResult(this.dice, this.mode);

  /// El valor que cuenta según el modo.
  int get kept {
    if (dice.isEmpty) return 0;
    switch (mode) {
      case AdvantageMode.advantage:
        return dice.reduce((a, b) => a > b ? a : b);
      case AdvantageMode.disadvantage:
        return dice.reduce((a, b) => a < b ? a : b);
      case AdvantageMode.normal:
        return dice.first;
    }
  }
}

/// Tira el d20 de siempre: uno normal, o dos quedándose con el más
/// alto (ventaja) o el más bajo (desventaja).
D20RollResult rollD20({
  AdvantageMode mode = AdvantageMode.normal,
  Random? random,
}) {
  final rng = random ?? Random();
  switch (mode) {
    case AdvantageMode.normal:
      return D20RollResult([rng.nextInt(20) + 1], mode);
    case AdvantageMode.advantage:
    case AdvantageMode.disadvantage:
      return D20RollResult(
        [rng.nextInt(20) + 1, rng.nextInt(20) + 1],
        mode,
      );
  }
}
