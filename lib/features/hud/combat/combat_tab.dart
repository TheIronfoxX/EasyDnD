// Pestaña Combate: lo que se usa cada turno.
//
// Arriba, los recursos (ranuras y puntos con usos) que se gastan tocando
// los puntos. Debajo, tarjetas que abren su propia pantalla: Conjuros,
// Ataques y habilidades, Estados y Compañeros. La vida no está aquí
// (vive en la píldora de la barra superior) salvo a 0 PG, cuando manda.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/tactical_theme_tokens.dart';
import '../../../core/ui/app_icons.dart';
import '../../../core/ui/clean_kit.dart';
import '../../../domain/models/character.dart';
import '../../../state/character_store.dart';
import '../hud_companions.dart';
import '../hud_pages.dart';
import '../hud_resources.dart';
import '../hud_status_tab.dart';
import 'powers.dart';

class CombatTab extends StatelessWidget {
  const CombatTab({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final icons = AppIcons.of(context);
    final tactical = context.tactical;
    final spells = powerEntries(character, spells: true);
    final others = powerEntries(character, spells: false);
    final conditions = character.activeConditions;
    final companions = character.companions;
    final down = character.basicInfo.currentHp <= 0;

    return CleanList(
      children: [
        if (down) _DownCard(character: character),
        if (character.spellSlots.slots.isNotEmpty ||
            character.resources.isNotEmpty)
          _ResourcesCard(character: character),
        if (spells.isNotEmpty)
          NavRowCard(
            key: const ValueKey('nav-spells'),
            icon: icons.spell,
            iconColor: tactical.spell,
            title: 'Conjuros',
            subtitle: '${spells.length} · por Daño, Defensa, Apoyo y Utilidad',
            onTap: () => pushCharacterPage(
              context,
              title: 'Conjuros',
              builder: (context, c) => [
                if (c.basicInfo.spellSaveDc != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Para resistir tus conjuros, los enemigos necesitan '
                      'sacar ${c.basicInfo.spellSaveDc} o más (tu CD).',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ...groupedPowerList(context, c, powerEntries(c, spells: true)),
              ],
            ),
          ),
        NavRowCard(
          key: const ValueKey('nav-attacks'),
          icon: icons.weapon,
          iconColor: tactical.weapon,
          title: 'Ataques y habilidades',
          subtitle: others.isEmpty
              ? 'Nada todavía'
              : '${others.length} · armas, rasgos y lo que siempre tienes',
          onTap: () => pushCharacterPage(
            context,
            title: 'Ataques y habilidades',
            builder: (context, c) {
              final entries = powerEntries(c, spells: false);
              if (entries.isEmpty) {
                return const [
                  Text('Esta ficha todavía no tiene armas ni habilidades.'),
                ];
              }
              return groupedPowerList(
                context,
                c,
                entries,
                passivesFolded: true,
              );
            },
          ),
        ),
        NavRowCard(
          key: const ValueKey('nav-conditions'),
          icon: Icons.healing_rounded,
          iconColor: conditions.isEmpty ? null : tactical.damage,
          title: 'Estados',
          subtitle: conditions.isEmpty
              ? 'Ninguno: estás bien'
              : conditions.join(', '),
          onTap: () => pushCharacterPage(
            context,
            title: 'Estados',
            builder: (context, c) => [HudConditionsSection(character: c)],
          ),
        ),
        if (companions.isNotEmpty)
          NavRowCard(
            key: const ValueKey('nav-companions'),
            icon: icons.companion,
            title: 'Compañeros',
            subtitle: companions.map((c) => c.name).join(', '),
            onTap: () => pushCharacterPage(
              context,
              title: 'Compañeros',
              builder: (context, c) => [HudCompanionsSection(character: c)],
            ),
          ),
      ],
    );
  }
}

/// Con 0 PG la vida sí manda: aviso rojo con las salvaciones de muerte.
class _DownCard extends StatelessWidget {
  const _DownCard({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final damage = context.tactical.damage;
    return CleanCard(
      key: const ValueKey('down-card'),
      color: Color.alphaBlend(
        damage.withValues(alpha: 0.12),
        Theme.of(context).colorScheme.surface,
      ),
      child: HudDeathSaves(info: character.basicInfo),
    );
  }
}

/// Ranuras y recursos con usos, gastables tocando los puntos.
class _ResourcesCard extends StatelessWidget {
  const _ResourcesCard({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.read<CharacterStore>();
    final tactical = context.tactical;
    final slots = [...character.spellSlots.slots]
      ..sort((a, b) => a.level.compareTo(b.level));

    Widget row(String label, Widget pips) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(child: pips),
        ],
      ),
    );

    return CleanCard(
      key: const ValueKey('resources-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tus recursos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('refill-resources'),
                onPressed: () {
                  store.restoreAllSpellSlots();
                  store.restoreAllResources();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Recargar'),
              ),
            ],
          ),
          Text(
            'Toca un punto para gastarlo; uno vacío para recuperarlo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final slot in slots)
            row(
              'Ranuras nv ${slot.level}',
              TapPips(
                current: slot.current,
                max: slot.max,
                tone: tactical.spell,
                spendTooltip: 'Gastar ranura de nivel ${slot.level}',
                recoverTooltip: 'Recuperar ranura de nivel ${slot.level}',
                onSpend: () => store.consumeSpellSlot(slot.level),
                onRecover: () => store.restoreSpellSlot(slot.level),
              ),
            ),
          for (final r in character.resources)
            row(
              r.name,
              TapPips(
                current: r.current,
                max: r.max,
                tone: tactical.ability,
                spendTooltip: 'Gastar un punto de ${r.name}',
                recoverTooltip: 'Recuperar un punto de ${r.name}',
                onSpend: () => store.decrementResource(r.name),
                onRecover: () => store.incrementResource(r.name),
              ),
            ),
        ],
      ),
    );
  }
}
