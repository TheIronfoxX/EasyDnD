// Pestaña Estado del HUD (rework de interfaz).
//
// Solo lo que se mira en cada turno: vida, defensa, economía de turno y
// condiciones. Las acciones, los conjuros, los recursos y los descansos
// viven en sus propias pestañas (o en el menú ⋮) para que esta pantalla
// respire. Cada tarjeta llama a los métodos del store sin validar antes
// (el store se autoprotege) y se re-renderiza sola porque el shell del
// HUD escucha el ChangeNotifier.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dnd_rules.dart';
import '../../core/ui/pip_shape.dart';
import '../../domain/models/character.dart';
import '../../state/character_store.dart';
import 'hud_dialogs.dart';
import 'hud_widgets.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/tactical_theme_tokens.dart';
import '../../core/theme/telemetry.dart';

// ---------------------------------------------------------------------
// Vida + números defensivos.
// ---------------------------------------------------------------------

class HudHealthSection extends StatelessWidget {
  const HudHealthSection({super.key, required this.character});

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

  Future<void> _setTempHp(BuildContext context) async {
    final store = context.read<CharacterStore>();
    final info = character.basicInfo;
    final amount = await showAmountDialog(
      context,
      title: 'PG temporales',
      label: 'PG temporales',
      confirmLabel: 'Fijar',
      description:
          'No se acumulan: se conserva el mayor valor. '
          'Actuales: ${info.tempHp}',
      initialAmount: info.tempHp > 0 ? info.tempHp : 1,
    );
    if (amount == null) return;
    store.setTempHp(amount);
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

    return HudSectionCard(
      icon: Icons.favorite_rounded,
      title: 'Vida',
      tone: hpColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        AnimatedSwitcher(
                          duration: AppDurations.fast,
                          child: Text(
                            '${info.currentHp}',
                            key: ValueKey(info.currentHp),
                            style: theme.textTheme.displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  color: critical ? tactical.damage : null,
                                )
                                .tabular,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            'de ${info.hpMax}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: scheme.onSurfaceVariant)
                                .tabular,
                          ),
                        ),
                      ],
                    ),
                    if (info.tempHp > 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      TonePill(
                        key: const ValueKey('temp-hp-pill'),
                        label: '+${info.tempHp} de escudo',
                        tone: tactical.spell,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              ArmorShield(value: '${info.ac}', label: 'Defensa'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          VitalBar(value: ratio, color: hpColor, height: 16),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
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
                    minimumSize: const Size.fromHeight(48),
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('temp-hp-button'),
              onPressed: () => _setTempHp(context),
              icon: const Icon(Icons.shield_moon_rounded, size: 18),
              label: const Text('Vida temporal'),
            ),
          ),
          if (info.currentHp <= 0) ...[
            const SizedBox(height: AppSpacing.lg),
            HudDeathSaves(info: info),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Iniciativa ${initiative >= 0 ? '+$initiative' : '$initiative'}'
            '  ·  Te mueves ${info.speed} ft por turno',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Salvaciones de muerte: 3 pips de éxito y 3 de fallo. Solo se muestra
/// con 0 PG. Los pips toman forma/colores de los tokens tácticos.
class HudDeathSaves extends StatelessWidget {
  const HudDeathSaves({super.key, required this.info});

  final BasicInfo info;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    final tactical = context.tactical;
    final theme = Theme.of(context);

    Widget row({
      required String label,
      required int count,
      required Color color,
      required bool success,
    }) {
      return Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: PipGlyph(
                shape: tactical.pipShape,
                filled: i < count,
                color: color,
                size: 16,
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: success ? 'Añadir éxito' : 'Añadir fallo',
            key: ValueKey(success ? 'death-success' : 'death-failure'),
            onPressed: () => store.addDeathSave(success: success),
            icon: Icon(
              success ? Icons.check_rounded : Icons.close_rounded,
              color: color,
            ),
          ),
        ],
      );
    }

    // Explicación en una frase: a 0 PG el novato no sabe qué toca hacer.
    final String headline;
    if (info.deathSaveFailures >= 3) {
      headline = 'Muerto. Tu personaje no ha superado las salvaciones.';
    } else if (info.deathSaveSuccesses >= 3) {
      headline = 'Estable: ya no tiras más, pero sigues a 0 PG.';
    } else {
      headline =
          'Inconsciente. En tu turno tira un d20: '
          '10 o más es un éxito, menos es un fallo.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          headline,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        row(
          label: 'Éxitos',
          count: info.deathSaveSuccesses,
          color: tactical.heal,
          success: true,
        ),
        row(
          label: 'Fallos',
          count: info.deathSaveFailures,
          color: tactical.damage,
          success: false,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('death-reset'),
            onPressed: store.resetDeathSaves,
            child: const Text('Reiniciar salvaciones'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Condiciones.
// ---------------------------------------------------------------------

class HudConditionsSection extends StatelessWidget {
  const HudConditionsSection({super.key, required this.character});

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
