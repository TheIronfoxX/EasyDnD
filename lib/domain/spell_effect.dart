// Qué hace un conjuro, para agrupar la pantalla de Conjuros en lenguaje de
// mesa: Ataque, Curación, Estados (mejorar a un aliado o entorpecer a un
// enemigo) y Utilidad (todo lo demás).
//
// Orden de prioridad:
//   1. dados de curación → Curación;
//   2. dados de daño o tirada de ataque → Ataque;
//   3. la categoría de siempre ([categoryOf]): Daño → Ataque; Defensa →
//      Estados; Apoyo → Curación si el texto habla de curar, si no Estados;
//   4. palabras de condición en el texto o salvación sin daño → Estados;
//   5. si no, Utilidad.
//
// Sin Flutter: es dominio puro y se prueba sin widgets.

import 'models/ability.dart';
import 'power_category.dart';

enum SpellEffect {
  attack('Ataque', 'Hacen daño'),
  healing('Curación', 'Te devuelven vida a ti o a un aliado'),
  condition('Estados', 'Mejoran a un aliado o entorpecen a un enemigo'),
  utility('Utilidad', 'Todo lo demás: luz, sentidos, movimiento…');

  const SpellEffect(this.label, this.hint);

  final String label;

  /// Una línea en llano bajo el título del grupo.
  final String hint;
}

const _healWords = [
  'curas',
  'cura ',
  'curar',
  'recupera puntos de golpe',
  'recuperas puntos de golpe',
  'recupera vida',
  'puntos de golpe temporales',
];

const _conditionWords = [
  'condición',
  'asustad',
  'hechizad',
  'paralizad',
  'derribad',
  'cegad',
  'ensordecid',
  'aturdid',
  'apresad',
  'envenenad',
  'restringid',
  'incapacitad',
  'invisible',
  'ventaja',
  'desventaja',
  'bonificador',
  'velocidad se reduce',
];

SpellEffect spellEffectOf(Ability ability) {
  if (ability.healDice?.trim().isNotEmpty ?? false) return SpellEffect.healing;
  if ((ability.damageDice?.trim().isNotEmpty ?? false) ||
      ability.attackType == 'attack') {
    return SpellEffect.attack;
  }

  final text =
      ' ${[ability.name, ability.plainSummary, ability.tacticalSummary, ability.successDescription, ability.failureDescription].whereType<String>().join(' ').toLowerCase()} ';
  bool has(List<String> words) => words.any(text.contains);

  switch (categoryOf(ability)) {
    case PowerCategory.damage:
      return SpellEffect.attack;
    case PowerCategory.defense:
      return SpellEffect.condition;
    case PowerCategory.support:
      return has(_healWords) ? SpellEffect.healing : SpellEffect.condition;
    case PowerCategory.utility:
      break;
  }
  if (has(_conditionWords) || ability.isSavingThrowType) {
    return SpellEffect.condition;
  }
  return SpellEffect.utility;
}
