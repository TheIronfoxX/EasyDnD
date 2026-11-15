// Acciones del turno (Etapa 5c): armas, acción, acción adicional,
// reacción y pasivas de la ficha activa.
//
// Cada lista es una tarjeta con sus entradas. Tocar una acción tirable
// abre la hoja de resolución (hud_resolution_sheet.dart) con los valores
// YA resueltos: modificador (mod. de característica + competencia), CD de
// salvación de la ficha, ranuras disponibles y cargas restantes. La hoja
// avisa por callback cuándo gastar una ranura o una carga; esta sección
// traduce esos avisos a los métodos del store.
//
// Lo que se muestra es la semántica heredada de la app vieja:
// - Arma: +attackBonus al ataque y damage.baseDice tal cual (ya trae sus
//   bonificadores embebidos, ej. "1d8+3").
// - Conjuro/rasgo de ataque: mod. de relatedStat + competencia.
// - Conjuro de salvación: la CD es basicInfo.spellSaveDc ya resuelta, no
//   se recalcula por habilidad.
// - Truco (baseLevel 0): nunca gasta ranura.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/ability.dart';
import '../../domain/models/character.dart';
import '../../domain/models/stats.dart';
import '../../domain/models/weapon.dart';
import '../../state/character_store.dart';
import 'hud_resolution_sheet.dart';
import 'hud_widgets.dart';
import '../../core/theme/design_tokens.dart';

class HudActionsSection extends StatelessWidget {
  const HudActionsSection({super.key, required this.character, this.random});

  final CharacterModel character;

  /// Inyectable para tests determinísticos. En la app queda null y la
  /// hoja usa Random().
  final Random? random;

  void _open(BuildContext context, RollAction action) {
    showResolutionSheet(context, action, random: random);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    final stats = character.stats;
    final proficiency = character.basicInfo.proficiencyBonus;
    final saveDc = character.basicInfo.spellSaveDc;
    final abilities = character.abilitiesByAction;
    final weapons = character.inventory.weapons;

    return Column(
      children: [
        if (weapons.isNotEmpty)
          HudSectionCard(
            icon: Icons.gavel_rounded,
            title: 'Armas',
            child: Column(
              children: [
                for (final action in [
                  for (final weapon in weapons) _weaponAction(weapon, store),
                ])
                  _ActionTile(
                    action: action,
                    onTap: () => _open(context, action),
                  ),
              ],
            ),
          ),
        if (abilities.action.isNotEmpty)
          _abilityCard(
            context,
            title: 'Acción',
            icon: Icons.bolt_rounded,
            abilities: abilities.action,
            stats: stats,
            proficiency: proficiency,
            saveDc: saveDc,
            store: store,
          ),
        if (abilities.bonusAction.isNotEmpty)
          _abilityCard(
            context,
            title: 'Acción adicional',
            icon: Icons.fast_forward_rounded,
            abilities: abilities.bonusAction,
            stats: stats,
            proficiency: proficiency,
            saveDc: saveDc,
            store: store,
          ),
        if (abilities.reaction.isNotEmpty)
          _abilityCard(
            context,
            title: 'Reacción',
            icon: Icons.reply_rounded,
            abilities: abilities.reaction,
            stats: stats,
            proficiency: proficiency,
            saveDc: saveDc,
            store: store,
          ),
        if (abilities.passive.isNotEmpty)
          HudSectionCard(
            icon: Icons.auto_stories_rounded,
            title: 'Pasivas',
            child: Column(
              children: [
                for (final ability in abilities.passive)
                  _PassiveTile(ability: ability),
              ],
            ),
          ),
      ],
    );
  }

  Widget _abilityCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Ability> abilities,
    required StatsBlock stats,
    required int proficiency,
    required int? saveDc,
    required CharacterStore store,
  }) {
    final cantrips = abilities.where((a) => a.isCantrip).toList();
    final leveledSpells = abilities.where((a) => a.isLeveledSpell).toList();
    final traits = abilities.where((a) => a.isTrait).toList();
    final spellLevels = leveledSpells.map((a) => a.baseLevel).toSet().toList()..sort();

    final showHeaders = cantrips.isNotEmpty || spellLevels.isNotEmpty;

    Widget buildTile(Ability ability) {
      final action = _abilityAction(
        ability,
        stats: stats,
        proficiency: proficiency,
        saveDc: saveDc,
        store: store,
      );
      return _ActionTile(action: action, onTap: () => _open(context, action));
    }

    return HudSectionCard(
      icon: icon,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cantrips.isNotEmpty) ...[
            if (showHeaders)
              _SubCategoryHeader(
                icon: Icons.auto_awesome_outlined,
                title: 'Trucos',
                count: cantrips.length,
              ),
            for (final ability in cantrips) buildTile(ability),
          ],
          for (final lvl in spellLevels) ...[
            _SubCategoryHeader(
              icon: Icons.auto_awesome_rounded,
              title: 'Conjuros de Nivel $lvl',
              count: leveledSpells.where((a) => a.baseLevel == lvl).length,
            ),
            for (final ability in leveledSpells.where((a) => a.baseLevel == lvl))
              buildTile(ability),
          ],
          if (traits.isNotEmpty) ...[
            _SubCategoryHeader(
              icon: Icons.flash_on_rounded,
              title: 'Habilidades',
              count: traits.length,
            ),
            for (final ability in traits) buildTile(ability),
          ],
        ],
      ),
    );
  }

  RollAction _weaponAction(Weapon weapon, CharacterStore store) {
    return RollAction(
      name: weapon.name,
      kindLabel: 'Arma',
      icon: Icons.gavel_rounded,
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
    );
  }

  /// Recurso de la ficha al que apunta una habilidad. Si el nombre ya
  /// no existe (se borró el recurso) la habilidad se comporta como si no
  /// lo gastara.
  ResourcePoint? _findResource(String? name) {
    if (name == null) return null;
    for (final r in character.resources) {
      if (r.name == name) return r;
    }
    return null;
  }

  RollAction _abilityAction(
    Ability ability, {
    required StatsBlock stats,
    required int proficiency,
    required int? saveDc,
    required CharacterStore store,
  }) {
    final isSpell = ability.type == 'spell';
    final usesSpellSlot = ability.baseLevel >= 1;
    final resource = _findResource(ability.resourceName);

    return RollAction(
      name: ability.name,
      kindLabel: isSpell ? 'Conjuro' : 'Habilidad',
      icon: isSpell ? Icons.auto_awesome_rounded : Icons.flash_on_rounded,
      modifier: stats.modFor(ability.relatedStat) + proficiency,
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
      saveDc: ability.isSavingThrowType ? saveDc : null,
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
    );
  }
}

/// Fila de una acción tirable: nombre, resumen mecánico, cargas restantes
/// e ícono de dados. Es tappable en toda la fila.
class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.onTap});

  final RollAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = _subtitle();
    final noCharges = (action.hasCharges && action.charges!.current <= 0) ||
        (action.usesResource && action.resourceCurrent < action.resourceCost);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.6,
        ),
        foregroundColor: noCharges
            ? theme.colorScheme.outline
            : theme.colorScheme.primary,
        child: Icon(action.icon, size: 18),
      ),
      title: Text(
        action.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: noCharges ? theme.colorScheme.outline : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action.usesResource) ...[
            _ResourceBadge(
              name: action.resourceName!,
              current: action.resourceCurrent,
              max: action.resourceMax,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (action.hasCharges) ...[
            _ChargeBadge(
              current: action.charges!.current,
              max: action.charges!.max,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Icon(
            Icons.casino_rounded,
            size: 20,
            color: noCharges
                ? theme.colorScheme.outline
                : theme.colorScheme.primary,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _subtitle() {
    final dice = action.damageDice?.trim();
    final hasDice = dice != null && dice.isNotEmpty;
    final type = action.damageType?.trim();
    final typeSuffix = (type != null && type.isNotEmpty) ? ' $type' : '';

    if (action.isSavingThrow) {
      final dc = action.saveDc != null ? 'CD ${action.saveDc}' : 'CD —';
      return [
        action.kindLabel,
        dc,
        if (hasDice) '$dice$typeSuffix',
      ].join(' · ');
    }
    if (action.isPlainUse) {
      final heal = action.healDice?.trim();
      return [
        action.kindLabel,
        'Efecto',
        if (hasDice) dice,
        if (heal != null && heal.isNotEmpty) 'Cura $heal',
      ].join(' · ');
    }

    final mod = action.modifier >= 0
        ? '+${action.modifier}'
        : '${action.modifier}';
    return [
      action.kindLabel,
      'Ataque $mod',
      if (hasDice) '$dice$typeSuffix',
    ].join(' · ');
  }
}

/// Pasiva: no se tira. Si trae lore o resumen táctico se despliega al
/// tocar; si no, es una fila informativa y nada más.
class _PassiveTile extends StatelessWidget {
  const _PassiveTile({required this.ability});

  final Ability ability;

  bool get _hasInfo =>
      (ability.loreDescription?.trim().isNotEmpty ?? false) ||
      (ability.tacticalSummary?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = ability.tacticalRole?.trim();

    if (!_hasInfo) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.6,
          ),
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          child: const Icon(Icons.auto_stories_rounded, size: 18),
        ),
        title: Text(ability.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null || subtitle.isEmpty
            ? const Text('Rasgo pasivo')
            : Text(subtitle),
      );
    }

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          0,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.6,
          ),
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          child: const Icon(Icons.auto_stories_rounded, size: 18),
        ),
        title: Text(ability.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          subtitle == null || subtitle.isEmpty ? 'Rasgo pasivo' : subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          if (ability.loreDescription?.trim().isNotEmpty ?? false)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                ability.loreDescription!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (ability.tacticalSummary?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                ability.tacticalSummary!,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChargeBadge extends StatelessWidget {
  const _ChargeBadge({required this.current, required this.max});

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depleted = current <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: depleted
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$current/$max',
        style: theme.textTheme.labelSmall?.copyWith(
          color: depleted
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Chip con los puntos que quedan del recurso vinculado ("Ki 3/4").
class _ResourceBadge extends StatelessWidget {
  const _ResourceBadge({
    required this.name,
    required this.current,
    required this.max,
  });

  final String name;
  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depleted = current <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: depleted
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$name $current/$max',
        key: const ValueKey('resource_badge'),
        style: theme.textTheme.labelSmall?.copyWith(
          color: depleted
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SubCategoryHeader extends StatelessWidget {
  const _SubCategoryHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 12, AppSpacing.xs, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Divider(
              color: scheme.outline.withValues(alpha: 0.4),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
