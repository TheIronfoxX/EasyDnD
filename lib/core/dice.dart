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

    final diceMatch = RegExp(
      r'^(\d+)d(\d+)\s*([+-]\s*\d+)?$',
    ).firstMatch(trimmed);
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

/// Un grupo de dados dentro de una [DiceExpression]: "4d6", o "-1d4"
/// si [negative] (resta el subtotal).
class DiceGroup {
  final int count;
  final int sides;
  final bool negative;

  const DiceGroup(this.count, this.sides, {this.negative = false});

  /// "4d6" (sin signo; el signo lo pone la expresión).
  String get notation => '${count}d$sides';

  double get average => (negative ? -1 : 1) * count * (sides + 1) / 2;
}

/// Resultado de tirar un [DiceGroup]: los dados sueltos y su subtotal
/// (ya con signo), para mostrar el desglose por grupo.
class DiceGroupRoll {
  final DiceGroup group;
  final List<int> dice;

  const DiceGroupRoll(this.group, this.dice);

  int get subtotal {
    final sum = dice.fold<int>(0, (a, b) => a + b);
    return group.negative ? -sum : sum;
  }
}

/// Resultado completo de tirar una [DiceExpression].
class DiceExpressionRoll {
  final List<DiceGroupRoll> groups;
  final int bonus;

  const DiceExpressionRoll(this.groups, this.bonus);

  int get total => groups.fold<int>(bonus, (a, g) => a + g.subtotal);
}

/// Expresión con VARIOS grupos de dados y un bonificador plano opcional:
/// "2d8+4d6" (Tormenta de hielo), "1d8+1d6+3", "2d6-1", "+3".
/// Generaliza a [DiceFormula] (que sigue existiendo para el caso de un
/// único grupo); las tiradas consumen el [Random] en orden de grupos, así
/// que una expresión de un solo grupo tira exactamente igual que antes.
class DiceExpression {
  final List<DiceGroup> groups;
  final int bonus;

  const DiceExpression(this.groups, this.bonus);

  /// Sin dados: siempre vale [bonus].
  bool get isFlat => groups.isEmpty;

  /// true si hay más de un grupo de dados.
  bool get isCompound => groups.length > 1;

  static final RegExp _term = RegExp(r'([+-])?\s*(\d+)(?:d(\d+))?');

  /// Null si no es una expresión válida. Tolera espacios.
  static DiceExpression? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (!RegExp(
      r'^[+-]?\s*\d+(?:d\d+)?(?:\s*[+-]\s*\d+(?:d\d+)?)*$',
    ).hasMatch(text)) {
      return null;
    }
    final groups = <DiceGroup>[];
    var bonus = 0;
    for (final m in _term.allMatches(text)) {
      final negative = m.group(1) == '-';
      final n = int.parse(m.group(2)!);
      final sidesRaw = m.group(3);
      if (sidesRaw == null) {
        bonus += negative ? -n : n;
      } else {
        final sides = int.parse(sidesRaw);
        // "0d0" es válido (valor por defecto del modelo) pero no tira nada.
        if (n > 0 && sides > 0) {
          groups.add(DiceGroup(n, sides, negative: negative));
        }
      }
    }
    return DiceExpression(groups, bonus);
  }

  /// Notación canónica: "2d8+4d6", "1d8+1d6+3", "2d6-1", "+3".
  String get notation {
    if (isFlat) return bonus >= 0 ? '+$bonus' : '$bonus';
    final b = StringBuffer();
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      if (g.negative) {
        b.write('-');
      } else if (i > 0) {
        b.write('+');
      }
      b.write(g.notation);
    }
    if (bonus != 0) b.write(bonus > 0 ? '+$bonus' : '$bonus');
    return b.toString();
  }

  double get average =>
      groups.fold<double>(bonus.toDouble(), (a, g) => a + g.average);

  /// Tira todos los grupos a la vez y conserva el desglose por grupo.
  DiceExpressionRoll rollDetailed({Random? random}) {
    final rng = random ?? Random();
    return DiceExpressionRoll([
      for (final g in groups)
        DiceGroupRoll(g, [
          for (var i = 0; i < g.count; i++) rng.nextInt(g.sides) + 1,
        ]),
    ], bonus);
  }

  int roll({Random? random}) => rollDetailed(random: random).total;
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
      return D20RollResult([rng.nextInt(20) + 1, rng.nextInt(20) + 1], mode);
  }
}
