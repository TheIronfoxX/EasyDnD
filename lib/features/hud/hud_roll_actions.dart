// Construcción de las [RollAction] que abre la hoja de tirada, a partir
// de un arma o de una habilidad/conjuro de la ficha activa.
//
// Vive aparte de las listas para que cualquier pantalla (lista de
// conjuros, de ataques, detalle de un poder) lance la misma tirada con
// los mismos callbacks al store.

import 'package:flutter/material.dart';

import '../../core/ui/app_icons.dart';
import '../../domain/models/ability.dart';
import '../../domain/models/character.dart';
import '../../domain/models/weapon.dart';
import '../../state/character_store.dart';
import 'hud_resolution_sheet.dart';

RollAction weaponRollAction(
  BuildContext context,
  Weapon weapon,
  CharacterStore store,
) {
  return RollAction(
    name: weapon.name,
    kindLabel: 'Arma',
    icon: AppIcons.of(context).weapon,
    modifier: weapon.attackBonus,
    damageDice: weapon.damage.baseDice,
    damageType: weapon.damage.baseType,
    successDescription: weapon.successDescription,
    failureDescription: weapon.failureDescription,
    loreDescription: weapon.loreDescription,
    tacticalSummary: weapon.tacticalSummary,
    charges: weapon.magicCharges.hasCharges
        ? RollCharges(
            current: weapon.magicCharges.current,
            max: weapon.magicCharges.max,
          )
        : null,
    onConsumeCharge: () => store.consumeWeaponCharge(weapon.id),
    startWithDisadvantage: store.hasDisadvantage,
  );
}

ResourcePoint? findResource(CharacterModel character, String? name) {
  if (name == null) return null;
  for (final r in character.resources) {
    if (r.name == name) return r;
  }
  return null;
}

RollAction abilityRollAction(
  BuildContext context,
  CharacterModel character,
  Ability ability,
  CharacterStore store,
) {
  final isSpell = ability.type == 'spell';
  final usesSpellSlot = ability.baseLevel >= 1;
  final resource = findResource(character, ability.resourceName);
  final icons = AppIcons.of(context);

  return RollAction(
    name: ability.name,
    kindLabel: isSpell ? 'Conjuro' : 'Habilidad',
    icon: isSpell ? icons.spell : icons.ability,
    modifier:
        character.stats.modFor(ability.relatedStat) +
        character.basicInfo.proficiencyBonus,
    attackType: ability.attackType,
    damageDice: ability.damageDice,
    healDice: ability.healDice,
    resourceName: resource?.name,
    resourceCurrent: resource?.current ?? 0,
    resourceMax: resource?.max ?? 0,
    resourceCost: ability.resourceCost,
    onConsumeResource: resource == null
        ? null
        : () => store.spendResource(resource.name, ability.resourceCost),
    successDescription: ability.successDescription,
    failureDescription: ability.failureDescription,
    loreDescription: ability.loreDescription,
    tacticalSummary: ability.tacticalSummary,
    isScalable: ability.isScalable,
    baseLevel: ability.baseLevel,
    scalingFormula: ability.scalingFormula,
    saveDc: ability.isSavingThrowType ? character.basicInfo.spellSaveDc : null,
    charges: ability.magicCharges.hasCharges
        ? RollCharges(
            current: ability.magicCharges.current,
            max: ability.magicCharges.max,
          )
        : null,
    slotOptions: usesSpellSlot
        ? [
            for (final slot in character.spellSlots.slots)
              RollSlotOption(
                level: slot.level,
                current: slot.current,
                max: slot.max,
              ),
          ]
        : const [],
    onConsumeCharge: ability.magicCharges.hasCharges
        ? () => store.consumeAbilityCharge(ability.id)
        : null,
    onConsumeSlot: usesSpellSlot
        ? (level) => store.consumeSpellSlot(level)
        : null,
    startWithDisadvantage: store.hasDisadvantage,
    onApplyHeal: store.applyHealing,
  );
}
