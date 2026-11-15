// Tablero de combate (Etapa 5).
//
// La hoja viva del personaje activo, ordenada por urgencia en mesa:
// vida → economía de turno → condiciones → recursos → ranuras →
// descansos. Cada tarjeta llama a los métodos del store sin validar
// antes (el store se autoprotege) y se re-renderiza sola porque el
// shell del HUD escucha el ChangeNotifier.
//
// Las acciones con dados (armas y habilidades) viven en
// hud_actions_section.dart; acá se ocupa el estado y las tiradas de
// descanso.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dnd_rules.dart';
import '../../domain/models/character.dart';
import '../../state/character_store.dart';
import 'hud_actions_section.dart';
import 'hud_dialogs.dart';
import 'hud_widgets.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/tactical_theme_tokens.dart';
import '../../core/theme/telemetry.dart';

class HudCombatTab extends StatelessWidget {
  const HudCombatTab({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        _HealthSection(character: character),
        _TurnSection(character: character),
        HudActionsSection(character: character),
        _ConditionsSection(character: character),
        if (character.resources.isNotEmpty)
          _ResourcesSection(character: character),
        if (character.spellSlots.slots.isNotEmpty)
          _SlotsSection(character: character),
        _RestsSection(character: character),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Vida + números defensivos.
// ---------------------------------------------------------------------

class _HealthSection extends StatelessWidget {
  const _HealthSection({required this.character});

  final CharacterModel character;

  Future<void> _adjust(BuildContext context, {required bool damage}) async {
    final store = context.read<CharacterStore>();
    final messenger = ScaffoldMessenger.of(context);
    final info = character.basicInfo;

    final amount = await showAmountDialog(
      context,
      title: damage ? 'Aplicar daño' : 'Aplicar curación',
      label: damage ? 'Cantidad de daño' : 'Cantidad de curación',
      confirmLabel: damage ? 'Aplicar daño' : 'Curar',
      description: 'PG actuales: ${info.currentHp} / ${info.hpMax}',
    );
    if (amount == null) return;

    if (damage) {
      store.applyDamage(amount);
      messenger.showSnackBar(
        SnackBar(content: Text('Recibiste $amount de daño.')),
      );
    } else {
      store.applyHealing(amount);
      messenger.showSnackBar(
        SnackBar(content: Text('Recuperaste $amount PG.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tactical = context.tactical;
    final info = character.basicInfo;
    final ratio = info.hpMax <= 0
        ? 0.0
        : (info.currentHp / info.hpMax).clamp(0.0, 1.0);
    final critical = info.currentHp <= 0 || ratio <= 0.25;
    final hpColor = critical ? tactical.damage : tactical.heal;
    final initiative = character.stats.modFor('dex');
    final saveDc = info.spellSaveDc;

    return HudSectionCard(
      icon: Icons.favorite_rounded,
      title: 'Vida',
      tone: hpColor,
      trailing: _HealthBadge(currentHp: info.currentHp, hpMax: info.hpMax),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedSwitcher(
                          duration: AppDurations.fast,
                          child: Text(
                            '${info.currentHp}',
                            key: ValueKey(info.currentHp),
                            style: theme.textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  color: critical ? tactical.damage : null,
                                )
                                .tabular,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 4,
                            left: AppSpacing.xs,
                          ),
                          child: Text(
                            '/ ${info.hpMax} PG',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: scheme.onSurfaceVariant)
                                .tabular,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    VitalBar(value: ratio, color: hpColor, height: 14),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              ArmorShield(value: '${info.ac}'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tactical.damage,
                    side: BorderSide(
                      color: tactical.damage.withValues(alpha: 0.6),
                    ),
                  ),
                  onPressed: () => _adjust(context, damage: true),
                  icon: const Icon(Icons.remove_rounded),
                  label: const Text('Daño'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: tactical.heal,
                    foregroundColor: scheme.surface,
                  ),
                  onPressed: () => _adjust(context, damage: false),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Curación'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: HudStatTile(
                  icon: Icons.flash_on_rounded,
                  label: 'Iniciativa',
                  value: initiative >= 0 ? '+$initiative' : '$initiative',
                  richValue: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HudStatTile(
                  icon: Icons.directions_walk_rounded,
                  label: 'Velocidad',
                  value: '${info.speed} ft',
                ),
              ),
              if (saveDc != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: HudStatTile(
                    icon: Icons.auto_awesome_rounded,
                    label: 'CD conjuros',
                    value: '$saveDc',
                    tone: tactical.spell,
                    richValue: true,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HudStatTile(
                  icon: Icons.casino_rounded,
                  label: 'Dados de golpe',
                  value:
                      '${info.hitDiceCurrent}/${info.hitDiceMax} '
                      'd${info.hitDieSides}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de estado de vida: Ileso / Herido / Malherido / Inconsciente.
/// Es solo información: el número y la barra ya cuentan la historia.
class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.currentHp, required this.hpMax});

  final int currentHp;
  final int hpMax;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tactical = context.tactical;
    final (label, tone) = switch (currentHp) {
      <= 0 => ('Inconsciente', tactical.damage),
      _ when currentHp >= hpMax => ('Ileso', tactical.heal),
      _ when currentHp * 2 >= hpMax => ('Herido', theme.colorScheme.primary),
      _ => ('Malherido', tactical.damage),
    };

    return AnimatedSwitcher(
      duration: AppDurations.normal,
      child: TonePill(key: ValueKey(label), label: label, tone: tone),
    );
  }
}

// ---------------------------------------------------------------------
// Economía de turno.
// ---------------------------------------------------------------------

class _TurnSection extends StatelessWidget {
  const _TurnSection({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.read<CharacterStore>();
    final status = character.turnStatus;
    final speed = character.basicInfo.speed;
    final movementRatio = speed <= 0
        ? 0.0
        : (status.movementRemaining / speed).clamp(0.0, 1.0);

    return HudSectionCard(
      icon: Icons.hourglass_bottom_rounded,
      title: 'Turno',
      trailing: TextButton.icon(
        onPressed: store.resetTurn,
        icon: const Icon(Icons.replay_rounded, size: 18),
        label: const Text('Terminar turno'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TurnChip(
                icon: Icons.bolt_rounded,
                label: 'Acción',
                used: status.actionUsed,
                onToggle: () => store.toggleAction('action'),
              ),
              _TurnChip(
                icon: Icons.fast_forward_rounded,
                label: 'Adicional',
                used: status.bonusActionUsed,
                onToggle: () => store.toggleAction('bonus'),
              ),
              _TurnChip(
                icon: Icons.reply_rounded,
                label: 'Reacción',
                used: status.reactionUsed,
                onToggle: () => store.toggleAction('reaction'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Icon(
                Icons.directions_walk_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Movimiento'),
                        const Spacer(),
                        Text(
                          '${status.movementRemaining} / $speed ft',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)
                              .tabular,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    VitalBar(
                      value: movementRatio,
                      color: theme.colorScheme.primary,
                      height: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              TacticalStepper(
                decrementTooltip: 'Restar 5 ft de movimiento',
                incrementTooltip: 'Sumar 5 ft de movimiento',
                onDecrement: status.movementRemaining <= 0
                    ? null
                    : () => store.setMovementRemaining(
                        status.movementRemaining - 5,
                      ),
                onIncrement: status.movementRemaining >= speed
                    ? null
                    : () => store.setMovementRemaining(
                        status.movementRemaining + 5,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip de recurso de acción. `used` significa "ya lo gastaste este
/// turno": se pinta con el color de alerta y tilde, y tocarlo lo libera.
class _TurnChip extends StatelessWidget {
  const _TurnChip({
    required this.icon,
    required this.label,
    required this.used,
    required this.onToggle,
  });

  final IconData icon;
  final String label;
  final bool used;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Disponible = encendida con el acento; gastada = apagada y tachada.
    final foreground = used ? scheme.outline : scheme.onSurface;

    return FilterChip(
      avatar: Icon(
        icon,
        size: 18,
        color: used ? scheme.outline : scheme.primary,
      ),
      label: Text(label),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: foreground,
        fontWeight: used ? FontWeight.w500 : FontWeight.w700,
        decoration: used ? TextDecoration.lineThrough : null,
        decorationColor: foreground,
      ),
      selected: used,
      onSelected: (_) => onToggle(),
      backgroundColor: scheme.primary.withValues(alpha: 0.16),
      selectedColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      side: BorderSide(
        color: used ? scheme.outline : scheme.primary.withValues(alpha: 0.75),
        width: used ? 1 : 1.4,
      ),
      checkmarkColor: scheme.outline,
      showCheckmark: true,
    );
  }
}

// ---------------------------------------------------------------------
// Condiciones.
// ---------------------------------------------------------------------

class _ConditionsSection extends StatelessWidget {
  const _ConditionsSection({required this.character});

  final CharacterModel character;

  Future<void> _add(BuildContext context) async {
    final store = context.read<CharacterStore>();
    final name = await showConditionPicker(
      context,
      activeConditions: character.activeConditions,
    );
    if (name == null) return;
    // El picker ya excluye las activas, pero entre abrir y confirmar el
    // estado pudo cambiar: se agrega solo si sigue sin estar.
    if (!character.activeConditions.contains(name)) {
      store.toggleCondition(name);
    }
  }

  Future<void> _showDetail(BuildContext context, String name) async {
    final store = context.read<CharacterStore>();
    final detail = DndRules.conditions[name];

    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: Text(
          detail?.description ??
              'Condición personalizada: no está en el catálogo, así que '
                  'no aporta descripción ni desventaja automática.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cerrar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (remove == true) store.toggleCondition(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = character.activeConditions;
    final hasDisadvantage = active.any(
      (name) => DndRules.conditions[name]?.causesDisadvantage ?? false,
    );

    return HudSectionCard(
      icon: Icons.healing_rounded,
      title: 'Condiciones',
      trailing: TextButton.icon(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Agregar'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (active.isEmpty)
            const HudEmptyHint('Sin condiciones activas.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final name in active)
                  InputChip(
                    avatar: Icon(
                      Icons.coronavirus_outlined,
                      size: 16,
                      color: context.tactical.damage,
                    ),
                    side: BorderSide(
                      color: context.tactical.damage.withValues(alpha: 0.55),
                    ),
                    backgroundColor: context.tactical.damage.withValues(
                      alpha: 0.12,
                    ),
                    label: Text(name),
                    onPressed: () => _showDetail(context, name),
                    onDeleted: () =>
                        context.read<CharacterStore>().toggleCondition(name),
                    deleteButtonTooltipMessage: 'Quitar $name',
                  ),
              ],
            ),
          if (hasDisadvantage) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: context.tactical.damage,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Desventaja en tiradas de ataque y pruebas de '
                    'característica.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.tactical.damage,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Recursos genéricos.
// ---------------------------------------------------------------------

class _ResourcesSection extends StatelessWidget {
  const _ResourcesSection({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.read<CharacterStore>();

    final tone = context.tactical.ability;

    return HudSectionCard(
      icon: Icons.toll_rounded,
      title: 'Recursos',
      tone: tone,
      trailing: IconButton(
        tooltip: 'Recargar recursos',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: store.restoreAllResources,
      ),
      child: Column(
        children: [
          for (final resource in character.resources)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${resource.current} de ${resource.max} usos',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                              .tabular,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ResourcePips(
                          current: resource.current,
                          max: resource.max,
                          color: tone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TacticalStepper(
                    tone: tone,
                    decrementTooltip: 'Gastar un punto de ${resource.name}',
                    incrementTooltip: 'Recuperar un punto de ${resource.name}',
                    onDecrement: resource.current <= 0
                        ? null
                        : () => store.decrementResource(resource.name),
                    onIncrement: resource.current >= resource.max
                        ? null
                        : () => store.incrementResource(resource.name),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Ranuras de conjuro.
// ---------------------------------------------------------------------

class _SlotsSection extends StatelessWidget {
  const _SlotsSection({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.read<CharacterStore>();
    final slots = [...character.spellSlots.slots]
      ..sort((a, b) => a.level.compareTo(b.level));

    final tone = context.tactical.spell;

    return HudSectionCard(
      icon: Icons.layers_rounded,
      title: 'Ranuras de conjuro',
      tone: tone,
      trailing: IconButton(
        tooltip: 'Recargar ranuras',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: store.restoreAllSpellSlots,
      ),
      child: Column(
        children: [
          for (final slot in slots)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(width: 64, child: Text('Nivel ${slot.level}')),
                  Expanded(
                    child: ResourcePips(
                      current: slot.current,
                      max: slot.max,
                      color: tone,
                      size: 11,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: Text(
                      '${slot.current}/${slot.max}',
                      key: ValueKey(
                        '${slot.level}:${slot.current}/${slot.max}',
                      ),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)
                          .tabular,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TacticalStepper(
                    tone: tone,
                    decrementTooltip: 'Gastar ranura de nivel ${slot.level}',
                    incrementTooltip: 'Recuperar ranura de nivel ${slot.level}',
                    onDecrement: slot.current <= 0
                        ? null
                        : () => store.consumeSpellSlot(slot.level),
                    onIncrement: slot.current >= slot.max
                        ? null
                        : () => store.restoreSpellSlot(slot.level),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Descansos.
// ---------------------------------------------------------------------

class _RestsSection extends StatelessWidget {
  const _RestsSection({required this.character});

  final CharacterModel character;

  Future<void> _shortRest(BuildContext context) async {
    final store = context.read<CharacterStore>();
    final messenger = ScaffoldMessenger.of(context);
    final info = character.basicInfo;

    if (info.hitDiceCurrent <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No te quedan dados de golpe. Tomate un descanso '
            'largo.',
          ),
        ),
      );
      return;
    }

    final count = await showAmountDialog(
      context,
      title: 'Descanso corto',
      label: 'Dados de golpe a gastar',
      confirmLabel: 'Descansar',
      description:
          'Tenés ${info.hitDiceCurrent} dados '
          'd${info.hitDieSides} disponibles. Cada uno cura '
          '1d${info.hitDieSides} + mod. de Constitución (mínimo 1).',
      initialAmount: 1,
      maxAmount: info.hitDiceCurrent,
    );
    if (count == null) return;

    final healed = store.spendHitDice(count);
    store.shortRest();
    messenger.showSnackBar(SnackBar(content: Text('Recuperaste $healed PG.')));
  }

  Future<void> _longRest(BuildContext context) async {
    final store = context.read<CharacterStore>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showLongRestDialog(context);
    if (!confirmed) return;

    store.longRest();
    messenger.showSnackBar(
      const SnackBar(content: Text('Descanso largo completado.')),
    );
  }

  Future<void> _customRest(BuildContext context) async {
    final store = context.read<CharacterStore>();
    final messenger = ScaffoldMessenger.of(context);

    final choice = await showCustomRestDialog(context);
    if (choice == null) return;

    store.customRest(
      healMax: choice.healMax,
      restoreSpells: choice.restoreSpells,
      restoreCharges: choice.restoreCharges,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Descanso personalizado aplicado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = character.basicInfo;

    return HudSectionCard(
      icon: Icons.night_shelter_rounded,
      title: 'Descansos',
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.hotel_rounded),
            title: const Text('Descanso corto'),
            subtitle: Text(
              info.hitDiceCurrent > 0
                  ? 'Gastá dados de golpe '
                        '(${info.hitDiceCurrent}/${info.hitDiceMax})'
                  : 'Sin dados de golpe disponibles',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: info.hitDiceCurrent > 0 ? () => _shortRest(context) : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bedtime_rounded),
            title: const Text('Descanso largo'),
            subtitle: const Text(
              'Vida, ranuras, cargas y mitad de los dados de golpe',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _longRest(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Descanso personalizado'),
            subtitle: const Text('Elegí qué recuperar'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _customRest(context),
          ),
        ],
      ),
    );
  }
}
