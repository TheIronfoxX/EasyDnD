// Tablero de combate (Etapa 5b).
//
// La hoja viva del personaje activo, ordenada por urgencia en mesa:
// vida → economía de turno → condiciones → recursos → ranuras →
// descansos. Cada tarjeta llama a los métodos del store sin validar
// antes (el store se autoprotege) y se re-renderiza sola porque el
// shell del HUD escucha el ChangeNotifier.
//
// Las acciones con dados (armas y habilidades) llegan en 5c; esta
// pantalla se ocupa del estado y de las tiradas de descanso.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dnd_rules.dart';
import '../../domain/models/character.dart';
import '../../state/character_store.dart';
import 'hud_actions_section.dart';
import 'hud_dialogs.dart';
import 'hud_widgets.dart';

class HudCombatTab extends StatelessWidget {
  const HudCombatTab({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
    final info = character.basicInfo;
    final ratio = info.hpMax <= 0
        ? 0.0
        : (info.currentHp / info.hpMax).clamp(0.0, 1.0);
    final critical = info.currentHp <= 0 || ratio <= 0.25;

    return HudSectionCard(
      icon: Icons.favorite_rounded,
      title: 'Vida',
      trailing: _HealthBadge(currentHp: info.currentHp, hpMax: info.hpMax),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${info.currentHp}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: critical ? theme.colorScheme.error : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '/ ${info.hpMax} PG',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
            color: critical
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _adjust(context, damage: true),
                  icon: const Icon(Icons.remove_rounded),
                  label: const Text('Daño'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _adjust(context, damage: false),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Curación'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HudStatTile(
                  icon: Icons.shield_rounded,
                  label: 'CA',
                  value: '${info.ac}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HudStatTile(
                  icon: Icons.directions_walk_rounded,
                  label: 'Velocidad',
                  value: '${info.speed} m',
                ),
              ),
              const SizedBox(width: 8),
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

    final (label, background, foreground) = switch (currentHp) {
      <= 0 => (
        'Inconsciente',
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      _ when currentHp >= hpMax => (
        'Ileso',
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      ),
      _ when currentHp * 2 >= hpMax => (
        'Herido',
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
      _ => (
        'Malherido',
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.directions_walk_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Movimiento'),
                        const Spacer(),
                        Text(
                          '${status.movementRemaining} / $speed m',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: movementRatio,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Restar 1 m de movimiento',
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: status.movementRemaining <= 0
                    ? null
                    : () => store.setMovementRemaining(
                        status.movementRemaining - 1,
                      ),
              ),
              IconButton(
                tooltip: 'Sumar 1 m de movimiento',
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: status.movementRemaining >= speed
                    ? null
                    : () => store.setMovementRemaining(
                        status.movementRemaining + 1,
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
    final foreground = used
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurface;

    return FilterChip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(label),
      labelStyle: theme.textTheme.labelLarge?.copyWith(color: foreground),
      selected: used,
      onSelected: (_) => onToggle(),
      selectedColor: theme.colorScheme.errorContainer,
      checkmarkColor: theme.colorScheme.onErrorContainer,
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
                    label: Text(name),
                    onPressed: () => _showDetail(context, name),
                    onDeleted: () =>
                        context.read<CharacterStore>().toggleCondition(name),
                    deleteButtonTooltipMessage: 'Quitar $name',
                  ),
              ],
            ),
          if (hasDisadvantage) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Desventaja en tiradas de ataque y pruebas de '
                    'característica.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
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

    return HudSectionCard(
      icon: Icons.toll_rounded,
      title: 'Recursos',
      trailing: IconButton(
        tooltip: 'Recargar recursos',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: store.restoreAllResources,
      ),
      child: Column(
        children: [
          for (final resource in character.resources)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resource.name),
                        Text(
                          '${resource.current} de ${resource.max} usos',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gastar un punto de ${resource.name}',
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    onPressed: resource.current <= 0
                        ? null
                        : () => store.decrementResource(resource.name),
                  ),
                  IconButton(
                    tooltip: 'Recuperar un punto de ${resource.name}',
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: resource.current >= resource.max
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

    return HudSectionCard(
      icon: Icons.layers_rounded,
      title: 'Ranuras de conjuro',
      trailing: IconButton(
        tooltip: 'Recargar ranuras',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: store.restoreAllSpellSlots,
      ),
      child: Column(
        children: [
          for (final slot in slots)
            Row(
              children: [
                Expanded(child: Text('Nivel ${slot.level}')),
                Text(
                  '${slot.current}/${slot.max}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  tooltip: 'Gastar ranura de nivel ${slot.level}',
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: slot.current <= 0
                      ? null
                      : () => store.consumeSpellSlot(slot.level),
                ),
                IconButton(
                  tooltip: 'Recuperar ranura de nivel ${slot.level}',
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: slot.current >= slot.max
                      ? null
                      : () => store.restoreSpellSlot(slot.level),
                ),
              ],
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
