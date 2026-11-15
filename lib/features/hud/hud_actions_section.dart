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
import '../../core/theme/tactical_theme_tokens.dart';
import '../../core/theme/telemetry.dart';

class HudActionsSection extends StatefulWidget {
  const HudActionsSection({super.key, required this.character, this.random});

  final CharacterModel character;

  /// Inyectable para tests determinísticos. En la app queda null y la
  /// hoja usa Random().
  final Random? random;

  @override
  State<HudActionsSection> createState() => _HudActionsSectionState();
}

/// Filtro rápido de la sección: qué familias de acciones se muestran.
enum _ActionFilter { all, weapons, abilities, spells }

class _HudActionsSectionState extends State<HudActionsSection> {
  _ActionFilter _filter = _ActionFilter.all;

  CharacterModel get character => widget.character;
  Random? get random => widget.random;

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

    final showWeapons =
        _filter == _ActionFilter.all || _filter == _ActionFilter.weapons;
    final showTraits =
        _filter == _ActionFilter.all || _filter == _ActionFilter.abilities;
    final showSpells =
        _filter == _ActionFilter.all || _filter == _ActionFilter.spells;

    // Conteos para las etiquetas del filtro: lo que cada chip muestra.
    final spellCount = abilities.all.where((a) => a.isSpell).length;
    final traitCount = abilities.all.where((a) => a.isTrait).length;
    final visibleCount =
        (showWeapons ? weapons.length : 0) +
        (showSpells ? spellCount - _passiveSpells(abilities) : 0) +
        (showTraits ? traitCount : 0);

    return Column(
      children: [
        _ActionFilterBar(
          selected: _filter,
          counts: {
            _ActionFilter.all: weapons.length + abilities.all.length,
            _ActionFilter.weapons: weapons.length,
            _ActionFilter.abilities: traitCount,
            _ActionFilter.spells: spellCount,
          },
          onSelected: (value) => setState(() => _filter = value),
        ),
        if (visibleCount == 0)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: HudEmptyHint('No hay nada que mostrar con este filtro.'),
          ),
        if (weapons.isNotEmpty && showWeapons)
          HudSectionCard(
            icon: Icons.gavel_rounded,
            title: 'Armas',
            tone: context.tactical.weapon,
            child: Column(
              children: [
                for (final action in [
                  for (final weapon in weapons) _weaponAction(weapon, store),
                ])
                  _ActionTile(
                    action: action,
                    tone: context.tactical.weapon,
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
            showSpells: showSpells,
            showTraits: showTraits,
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
            showSpells: showSpells,
            showTraits: showTraits,
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
            showSpells: showSpells,
            showTraits: showTraits,
          ),
        if (abilities.passive.isNotEmpty && showTraits)
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

  /// Conjuros que viven en "passive" (no se muestran como acciones).
  int _passiveSpells(AbilitiesByAction abilities) =>
      abilities.passive.where((a) => a.isSpell).length;

  Widget _abilityCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Ability> abilities,
    required StatsBlock stats,
    required int proficiency,
    required int? saveDc,
    required CharacterStore store,
    required bool showSpells,
    required bool showTraits,
  }) {
    // El filtro rápido decide qué familias entran; una tarjeta sin nada
    // que mostrar desaparece entera.
    final cantrips = showSpells
        ? abilities.where((a) => a.isCantrip).toList()
        : <Ability>[];
    final leveledSpells = showSpells
        ? abilities.where((a) => a.isLeveledSpell).toList()
        : <Ability>[];
    final traits = showTraits
        ? abilities.where((a) => a.isTrait).toList()
        : <Ability>[];
    if (cantrips.isEmpty && leveledSpells.isEmpty && traits.isEmpty) {
      return const SizedBox.shrink();
    }
    final spellLevels = leveledSpells.map((a) => a.baseLevel).toSet().toList()
      ..sort();

    final showHeaders = cantrips.isNotEmpty || spellLevels.isNotEmpty;

    Widget buildTile(Ability ability) {
      final action = _abilityAction(
        ability,
        stats: stats,
        proficiency: proficiency,
        saveDc: saveDc,
        store: store,
      );
      return _ActionTile(
        action: action,
        tone: ability.isTrait
            ? context.tactical.ability
            : context.tactical.spell,
        ability: ability,
        onTap: () => _open(context, action),
      );
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
                tone: context.tactical.spell,
              ),
            for (final ability in cantrips) buildTile(ability),
          ],
          for (final lvl in spellLevels) ...[
            _SubCategoryHeader(
              icon: Icons.auto_awesome_rounded,
              title: 'Conjuros de Nivel $lvl',
              count: leveledSpells.where((a) => a.baseLevel == lvl).length,
              tone: context.tactical.spell,
            ),
            for (final ability in leveledSpells.where(
              (a) => a.baseLevel == lvl,
            ))
              buildTile(ability),
          ],
          if (traits.isNotEmpty)
            // El grupo de habilidades activas va en su propio panel
            // tintado: es lo que más se consulta junto a los recursos.
            Container(
              margin: EdgeInsets.only(top: showHeaders ? AppSpacing.md : 0),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                0,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              decoration: ShapeDecoration(
                color: context.tactical.ability.withValues(alpha: 0.07),
                shape: context.tactical.insetBorder(
                  context.tactical.ability.withValues(alpha: 0.38),
                ),
              ),
              // Material propio: las filas pintan su tinta acá y no quedan
              // tapadas por el fondo tintado del panel.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SubCategoryHeader(
                      icon: Icons.flash_on_rounded,
                      title: 'Habilidades',
                      count: traits.length,
                      tone: context.tactical.ability,
                    ),
                    for (final ability in traits) buildTile(ability),
                  ],
                ),
              ),
            ),
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
  const _ActionTile({
    required this.action,
    required this.onTap,
    required this.tone,
    this.ability,
  });

  final RollAction action;
  final VoidCallback onTap;

  /// La habilidad o conjuro de origen (null en armas): de acá salen la
  /// insignia de origen, la de concentración y la lectura de reglas.
  final Ability? ability;

  /// Color de rol: arma, conjuro o habilidad activa.
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = _subtitle();
    final noCharges =
        (action.hasCharges && action.charges!.current <= 0) ||
        (action.usesResource && action.resourceCurrent < action.resourceCost);
    final color = noCharges ? scheme.outline : tone;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      leading: AnimatedContainer(
        duration: AppDurations.normal,
        width: 38,
        height: 38,
        decoration: ShapeDecoration(
          color: color.withValues(alpha: noCharges ? 0.08 : 0.15),
          shape: context.tactical.insetBorder(
            color.withValues(alpha: noCharges ? 0.30 : 0.50),
          ),
        ),
        child: Icon(action.icon, size: 18, color: color),
      ),
      title: Text(
        action.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: noCharges ? scheme.outline : null,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)
                .tabular,
          ),
          if (ability != null) _badgeRow(context, ability!),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action.usesResource) ...[
            _ResourceBadge(
              name: action.resourceName!,
              current: action.resourceCurrent,
              max: action.resourceMax,
              tone: tone,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (action.hasCharges) ...[
            _ChargeBadge(
              current: action.charges!.current,
              max: action.charges!.max,
              tone: tone,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Icon(Icons.casino_rounded, size: 20, color: color),
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
  const _ChargeBadge({
    required this.current,
    required this.max,
    required this.tone,
  });

  final int current;
  final int max;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depleted = current <= 0;
    final color = depleted ? context.tactical.damage : tone;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$current/$max',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700)
              .tabular,
        ),
        const SizedBox(height: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 64),
          child: ResourcePips(current: current, max: max, color: tone, size: 7),
        ),
      ],
    );
  }
}

/// Chip con los puntos que quedan del recurso vinculado ("Ki 3/4").
class _ResourceBadge extends StatelessWidget {
  const _ResourceBadge({
    required this.name,
    required this.current,
    required this.max,
    required this.tone,
  });

  final String name;
  final int current;
  final int max;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depleted = current <= 0;
    final color = depleted ? context.tactical.damage : tone;

    return AnimatedContainer(
      duration: AppDurations.normal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.14),
        shape: context.tactical.buttonBorder(
          color.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.toll_rounded, size: 12, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$name $current/$max',
                key: const ValueKey('resource_badge'),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700)
                    .tabular,
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Los pips con la forma de la skin: se ve cuánto queda sin leer.
          ResourcePips(current: current, max: max, color: tone, size: 6),
        ],
      ),
    );
  }
}

/// Insignias de una habilidad o conjuro bajo su resumen: origen (Clase,
/// Racial, Dote, Objeto), concentración y el botón de lectura de reglas.
Widget _badgeRow(BuildContext context, Ability ability) {
  final tactical = context.tactical;
  final origin = abilityOriginLabel(ability);
  final badges = <Widget>[
    if (origin != null)
      TonePill(
        key: ValueKey('origin_badge_${ability.id}'),
        label: origin.$1,
        icon: origin.$2,
        tone: tactical.ability,
      ),
    if (ability.concentration)
      TonePill(
        key: ValueKey('concentration_badge_${ability.id}'),
        label: 'Concentración',
        icon: Icons.filter_tilt_shift_rounded,
        tone: tactical.spell,
      ),
  ];

  return Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: badges,
          ),
        ),
        IconButton(
          key: ValueKey('info_${ability.id}'),
          tooltip: 'Leer reglas de ${ability.name}',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          iconSize: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: () => showAbilityInfoSheet(context, ability),
        ),
      ],
    ),
  );
}

/// Etiqueta e icono de origen de una habilidad según su `type`. Los
/// conjuros no llevan insignia de origen (ya van agrupados por nivel).
/// `trait` (y cualquier tipo desconocido) cae a "Habilidad"; el
/// `class_feature` de fichas hechas con el prompt anterior cuenta como
/// Clase.
(String, IconData)? abilityOriginLabel(Ability ability) {
  return switch (ability.type) {
    'spell' => null,
    'class' || 'class_feature' => ('Clase', Icons.military_tech_rounded),
    'racial' => ('Racial', Icons.diversity_3_rounded),
    'feat' => ('Dote', Icons.workspace_premium_rounded),
    'item' => ('Objeto', Icons.auto_fix_high_rounded),
    _ => ('Habilidad', Icons.flash_on_rounded),
  };
}

/// Hoja de lectura rápida: descripción, éxito y fallo de una habilidad o
/// conjuro sin entrar al editor ni tirar dados.
Future<void> showAbilityInfoSheet(BuildContext context, Ability ability) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _AbilityInfoSheet(ability: ability),
  );
}

class _AbilityInfoSheet extends StatelessWidget {
  const _AbilityInfoSheet({required this.ability});

  final Ability ability;

  static bool _has(String? text) => text != null && text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tactical = context.tactical;
    final tone = ability.isSpell ? tactical.spell : tactical.ability;
    final origin = abilityOriginLabel(ability);

    Widget block(
      String label,
      String text,
      Color color, {
      bool italic = false,
    }) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: italic ? FontStyle.italic : null,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    final hasAnything =
        _has(ability.loreDescription) ||
        _has(ability.successDescription) ||
        _has(ability.failureDescription) ||
        _has(ability.tacticalSummary);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ability.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              TonePill(
                label: ability.isCantrip
                    ? 'Truco'
                    : ability.isLeveledSpell
                    ? 'Conjuro de nivel ${ability.baseLevel}'
                    : 'Habilidad',
                tone: tone,
              ),
              if (origin != null)
                TonePill(label: origin.$1, icon: origin.$2, tone: tone),
              if (ability.concentration)
                TonePill(
                  label: 'Concentración',
                  icon: Icons.filter_tilt_shift_rounded,
                  tone: tactical.spell,
                ),
            ],
          ),
          if (!hasAnything)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg),
              child: HudEmptyHint(
                'Sin descripción todavía. Podés agregarla desde Editar ficha.',
              ),
            ),
          if (_has(ability.loreDescription))
            block('Descripción', ability.loreDescription!, tone, italic: true),
          if (_has(ability.tacticalSummary))
            block('En mesa', ability.tacticalSummary!, tone),
          if (_has(ability.successDescription))
            block('Si tiene éxito', ability.successDescription, tactical.heal),
          if (_has(ability.failureDescription))
            block('Si falla', ability.failureDescription, tactical.damage),
        ],
      ),
    );
  }
}

/// Barra de filtro rápido: Todo | Armas | Habilidades | Conjuros. Cada
/// chip lleva el conteo; así "Armas · 1" no se confunde con el título de
/// la tarjeta de armas.
class _ActionFilterBar extends StatelessWidget {
  const _ActionFilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final _ActionFilter selected;
  final Map<_ActionFilter, int> counts;
  final ValueChanged<_ActionFilter> onSelected;

  static const _labels = {
    _ActionFilter.all: 'Todo',
    _ActionFilter.weapons: 'Armas',
    _ActionFilter.abilities: 'Habilidades',
    _ActionFilter.spells: 'Conjuros',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final entry in _labels.entries)
              ChoiceChip(
                key: Key('actions-filter-${entry.key.name}'),
                label: Text('${entry.value} · ${counts[entry.key] ?? 0}'),
                selected: selected == entry.key,
                showCheckmark: false,
                selectedColor: primary.withValues(alpha: 0.22),
                side: BorderSide(
                  color: selected == entry.key
                      ? primary
                      : theme.colorScheme.outline,
                ),
                labelStyle: theme.textTheme.labelMedium
                    ?.copyWith(
                      color: selected == entry.key
                          ? primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: selected == entry.key
                          ? FontWeight.w800
                          : FontWeight.w500,
                    )
                    .tabular,
                onSelected: (_) => onSelected(entry.key),
              ),
          ],
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
    required this.tone,
  });

  final IconData icon;
  final String title;
  final int count;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 12, AppSpacing.xs, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: tone,
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
