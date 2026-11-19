// Pestaña Ficha: lo que define al personaje, cada cosa en su pantalla.

import 'package:flutter/material.dart';

import '../../../core/theme/tactical_theme_tokens.dart';
import '../../../core/dnd_rules.dart';
import '../../../core/ui/app_icons.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/ui/clean_kit.dart';
import '../../../domain/models/character.dart';
import '../hud_pages.dart';
import '../hud_sheet_tab.dart';

class SheetTab extends StatelessWidget {
  const SheetTab({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final icons = AppIcons.of(context);
    final info = character.basicInfo;
    final mod = character.stats.modFor('dex');
    final stats = character.stats;
    final scores = {
      'str': stats.str,
      'dex': stats.dex,
      'con': stats.con,
      'int': stats.intelligence,
      'wis': stats.wis,
      'cha': stats.cha,
    };
    return CleanList(
      children: [
        _IdentityCard(character: character),
        _AttributesHeader(
          onTap: () => pushCharacterPage(
            context,
            title: 'Atributos',
            builder: (context, c) => [
              Text(
                'Defensa ${c.basicInfo.ac} · Iniciativa '
                '${mod >= 0 ? '+$mod' : '$mod'} · Te mueves '
                '${c.basicInfo.speed} ft por turno',
              ),
              const SizedBox(height: 12),
              HudAttributesSection(stats: c.stats),
            ],
          ),
        ),
        StatGrid(
          key: const ValueKey('attributes-grid'),
          tiles: [
            for (final e in kStatLabels.entries)
              StatTile(
                value: scores[e.key]!.modFormatted,
                label: e.value,
                sub: '${scores[e.key]!.value}',
                tone: Theme.of(context).colorScheme.primary,
                help:
                    'Puntuación ${scores[e.key]!.value}; '
                    'el número grande es lo que sumas a las tiradas.',
              ),
          ],
        ),
        NavTilePair(
          tiles: [
            NavTileCard(
              key: const ValueKey('nav-skills'),
              icon: icons.ability,
              iconColor: context.tactical.ability,
              title: 'Habilidades',
              subtitle: _topSkills(character),
              onTap: () => pushCharacterPage(
                context,
                title: 'Habilidades',
                builder: (context, c) => [HudSkillsSection(skills: c.skills)],
              ),
            ),
            NavTileCard(
              key: const ValueKey('nav-story'),
              icon: Icons.menu_book_rounded,
              iconColor: context.tactical.coinGold,
              title: 'Historia',
              subtitle: info.race.trim().isEmpty
                  ? 'Trasfondo y personalidad'
                  : '${info.race.trim()} · trasfondo y personalidad',
              onTap: () => pushCharacterPage(
                context,
                title: 'Historia',
                builder: (context, c) => [
                  HudLoreSection(character: c),
                  HudCodexSection(character: c),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Las tres habilidades con más bonus, para el resumen de la tarjeta.
String _topSkills(CharacterModel c) {
  if (c.skills.isEmpty) return 'Sin habilidades en la ficha';
  final sorted = [...c.skills]
    ..sort((a, b) => b.modifier.compareTo(a.modifier));
  return sorted
      .take(3)
      .map((s) => '${s.name} ${s.modifier >= 0 ? '+' : ''}${s.modifier}')
      .join(', ');
}

/// Quién es el personaje: raza, clase y nivel, antes de los números.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = character.basicInfo;
    final parts = [
      if (info.race.trim().isNotEmpty) info.race.trim(),
      if (info.characterClass.trim().isNotEmpty) info.characterClass.trim(),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: CleanCard(
        key: const ValueKey('identity-card'),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (parts.isNotEmpty)
                    Text(
                      parts.join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text('NIV ${info.level}', style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

/// Título de la rejilla de atributos; toca para ver el detalle.
class _AttributesHeader extends StatelessWidget {
  const _AttributesHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: const ValueKey('nav-attributes'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text('Atributos', style: theme.textTheme.titleSmall),
            ),
            Text(
              'Ver detalle',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
