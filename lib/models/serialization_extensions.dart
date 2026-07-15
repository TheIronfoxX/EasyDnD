// ---------------------------------------------------------------------------
// Fase 12 — Serialización de apoyo.
//
// toJson() para todo lo que necesita CharacterModel.toJson() y que vive en
// weapon_model.dart, ability_model.dart y stats_model.dart (ninguno de esos
// archivos traía toJson() propio). Importa este archivo desde cualquier
// sitio donde llames a .toJson() sobre Weapon, Ability, AbilitiesByAction,
// StatsBlock, AbilityScore o Skill — los métodos de extension solo están
// en scope donde se importan.
// ---------------------------------------------------------------------------

import 'weapon_model.dart';
import 'ability_model.dart';
import 'stats_model.dart';

extension MagicChargesJson on MagicCharges {
  Map<String, dynamic> toJson() => {
        'has_charges': hasCharges,
        'max': max,
        'current': current,
      };
}

extension AbilityJson on Ability {
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'related_stat': relatedStat,
        'success_description': successDescription,
        'failure_description': failureDescription,
        'attack_type': attackType,
        'is_scalable': isScalable,
        'base_level': baseLevel,
        'scaling_formula': scalingFormula,
        'damage_dice': damageDice,
        'lore_description': loreDescription,
        'tactical_summary': tacticalSummary,
        'magic_charges': magicCharges.toJson(),
      };
}

extension WeaponJson on Weapon {
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'attack_bonus': attackBonus,
        'damage': {
          'base_dice': damage.baseDice,
          'base_type': damage.baseType,
        },
        'conditional_damage': conditionalDamage
            .map((c) => {
                  'trigger': c.trigger,
                  'dice': c.dice,
                  'type': c.type,
                })
            .toList(),
        'properties': properties,
        'homebrew_effect': homebrewEffect,
        // MagicCharges.toJson() ya existe en tu proyecto (weapon_model.dart
        // u otro archivo) — se reutiliza tal cual.
        'magic_charges': magicCharges.toJson(),
        'success_description': successDescription,
        'failure_description': failureDescription,
      };
}

extension AbilitiesByActionJson on AbilitiesByAction {
  Map<String, dynamic> toJson() => {
        // Ability.toJson() ya existe en tu proyecto — se reutiliza tal cual.
        'action': action.map((a) => a.toJson()).toList(),
        'bonus_action': bonusAction.map((a) => a.toJson()).toList(),
        'reaction': reaction.map((a) => a.toJson()).toList(),
        'passive': passive.map((a) => a.toJson()).toList(),
      };
}

extension AbilityScoreJson on AbilityScore {
  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'mod': mod,
        'description': description,
      };
}

extension StatsBlockJson on StatsBlock {
  Map<String, dynamic> toJson() => {
        'str': str.toJson(),
        'dex': dex.toJson(),
        'con': con.toJson(),
        'int': intelligence.toJson(),
        'wis': wis.toJson(),
        'cha': cha.toJson(),
      };
}

extension SkillJson on Skill {
  Map<String, dynamic> toJson() => {
        'name': name,
        'related_stat': relatedStat,
        'modifier': modifier,
      };
}