// Compañeros en el HUD: tarjeta en Combate y hoja propia por compañero
// (PG, economía de turno, condiciones y acciones).
//
// Todo se direcciona por id (Companion.id), no por posición, así que
// reordenar o borrar no apunta al compañero equivocado. Los colores
// salen del tema.

import 'package:flutter/material.dart';
import '../../core/ui/app_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/theme/tactical_theme_tokens.dart';
import '../../domain/models/character.dart';
import '../../state/character_store.dart';
import 'hud_dialogs.dart';
import 'hud_widgets.dart';

/// Tarjeta con todos los compañeros de la ficha. Tocar una fila abre su
/// hoja de combate. Si la ficha no tiene compañeros no ocupa lugar.
class HudCompanionsSection extends StatelessWidget {
  const HudCompanionsSection({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final companions = character.companions;
    if (companions.isEmpty) return const SizedBox.shrink();

    return HudSectionCard(
      icon: AppIcons.of(context).companion,
      title: 'Compañeros',
      child: Column(
        children: [for (final c in companions) _CompanionRow(companion: c)],
      ),
    );
  }
}

class _CompanionRow extends StatelessWidget {
  const _CompanionRow({required this.companion});

  final Companion companion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.read<CharacterStore>();
    final type = companion.type.trim();
    final subtitle = [
      if (type.isNotEmpty) type,
      if (!companion.hasHp) 'Apoyo invulnerable',
      'CA ${companion.ac}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('companion-${companion.id}'),
            onTap: () => showCompanionSheet(context, companion.id),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  foregroundColor: theme.colorScheme.onTertiaryContainer,
                  child: Icon(AppIcons.of(context).companion, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companion.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (companion.hasHp)
                  Text(
                    '${companion.currentHp}/${companion.maxHp} PG',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (companion.hasHp) ...[
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: companion.maxHp <= 0
                  ? 0
                  : (companion.currentHp / companion.maxHp).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Quitar 1 PG a ${companion.name}',
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: companion.currentHp <= 0
                      ? null
                      : () => store.applyCompanionHp(companion.id, -1),
                ),
                IconButton(
                  tooltip: 'Curar 1 PG a ${companion.name}',
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: companion.currentHp >= companion.maxHp
                      ? null
                      : () => store.applyCompanionHp(companion.id, 1),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Abre la hoja de combate del compañero [id].
Future<void> showCompanionSheet(BuildContext context, String id) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider<CharacterStore>.value(
      value: context.read<CharacterStore>(),
      child: _CompanionSheet(id: id),
    ),
  );
}

class _CompanionSheet extends StatelessWidget {
  const _CompanionSheet({required this.id});

  final String id;

  Future<void> _adjust(
    BuildContext context,
    Companion pet, {
    required bool damage,
  }) async {
    final store = context.read<CharacterStore>();
    final amount = await showAmountDialog(
      context,
      title: damage ? 'Daño a ${pet.name}' : 'Curar a ${pet.name}',
      label: damage ? 'Cantidad de daño' : 'Cantidad de curación',
      confirmLabel: damage ? 'Aplicar daño' : 'Curar',
      description: 'PG: ${pet.currentHp} / ${pet.maxHp}',
    );
    if (amount == null) return;
    store.applyCompanionHp(id, damage ? -amount : amount);
  }

  Future<void> _addCondition(BuildContext context, Companion pet) async {
    final store = context.read<CharacterStore>();
    final name = await showConditionPicker(
      context,
      activeConditions: pet.conditions,
    );
    if (name == null) return;
    if (!pet.conditions.contains(name)) {
      store.toggleCompanionCondition(id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CharacterStore>();
    final pet = store.companionById(id);
    final theme = Theme.of(context);
    final tactical = context.tactical;

    if (pet == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: HudEmptyHint('Este compañero ya no existe.'),
      );
    }

    final type = pet.type.trim();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pet.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              [
                if (type.isNotEmpty) type,
                'CA ${pet.ac}',
                '${pet.speed} ft',
              ].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (pet.hasHp) ...[
              Text(
                '${pet.currentHp} / ${pet.maxHp} PG',
                key: const ValueKey('companion-sheet-hp'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: pet.currentHp <= 0 ? tactical.damage : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('companion-damage'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tactical.damage,
                      ),
                      onPressed: () => _adjust(context, pet, damage: true),
                      icon: const Icon(Icons.remove_rounded),
                      label: const Text('Daño'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('companion-heal'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tactical.heal,
                        foregroundColor: theme.colorScheme.surface,
                      ),
                      onPressed: () => _adjust(context, pet, damage: false),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Curación'),
                    ),
                  ),
                ],
              ),
            ] else
              const HudEmptyHint('Apoyo invulnerable: no gestiona PG.'),
            const SizedBox(height: AppSpacing.lg),
            Text('Condiciones', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final c in pet.conditions)
                  InputChip(
                    label: Text(c),
                    onDeleted: () => store.toggleCompanionCondition(id, c),
                  ),
                ActionChip(
                  key: const ValueKey('companion-add-condition'),
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Condición'),
                  onPressed: () => _addCondition(context, pet),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Acciones', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            if (pet.actions.isEmpty)
              const HudEmptyHint(
                'Sin acciones. Se añaden al editar la ficha (Mochila).',
              )
            else
              for (final a in pet.actions)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.name),
                  subtitle: a.damage.isEmpty ? null : Text(a.damage),
                  trailing: a.attackBonus == null
                      ? null
                      : Text(
                          a.attackBonus! >= 0
                              ? '+${a.attackBonus}'
                              : '${a.attackBonus}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
          ],
        ),
      ),
    );
  }
}
