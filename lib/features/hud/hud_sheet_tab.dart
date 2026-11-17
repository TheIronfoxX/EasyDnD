// Pestaña Personaje: la hoja del personaje, partida en subpestañas
// (Atributos · Habilidades · Recursos · Compañeros · Trasfondo) para
// que nunca haya más de un tema en pantalla.
//
// La edición vive en CharacterEditorScreen. Atributos, habilidades y
// trasfondo son de solo lectura; recursos y compañeros sí se gastan en
// mesa y llaman al store.

import 'package:flutter/material.dart';
import '../../core/ui/app_icons.dart';
import 'package:provider/provider.dart';

import '../../core/dnd_rules.dart';
import '../../domain/models/character.dart';
import '../../domain/models/stats.dart';
import '../../state/character_store.dart';
import 'hud_widgets.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/tactical_theme_tokens.dart';
import '../../core/theme/telemetry.dart';

// ---------------------------------------------------------------------
// Atributos: valor y modificador de las seis características.
// ---------------------------------------------------------------------

class HudAttributesSection extends StatelessWidget {
  const HudAttributesSection({super.key, required this.stats});

  final StatsBlock stats;

  @override
  Widget build(BuildContext context) {
    final scores = <String, AbilityScore>{
      'str': stats.str,
      'dex': stats.dex,
      'con': stats.con,
      'int': stats.intelligence,
      'wis': stats.wis,
      'cha': stats.cha,
    };

    return HudSectionCard(
      icon: Icons.insights_rounded,
      title: 'Atributos',
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Dos columnas: con tres, "Constitución" no entra en un
          // teléfono angosto.
          final width = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in kStatLabels.entries)
                SizedBox(
                  width: width,
                  child: _ScoreTile(
                    label: entry.value,
                    score: scores[entry.key]!,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.label, required this.score});

  final String label;
  final AbilityScore score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.40),
        shape: context.tactical.insetBorder(
          context.tactical.metalBorder.withValues(alpha: 0.75),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${score.value}',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800, height: 1.1)
                      .tabular,
                ),
              ],
            ),
          ),
          // El modificador es lo que se suma a la tirada: va destacado.
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              shape: context.tactical.insetBorder(
                scheme.primary.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              score.modFormatted,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)
                  .tabular,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Competencias: cuadrícula de 2 columnas con indicador, atributo y modificador.
// ---------------------------------------------------------------------

class HudSkillsSection extends StatelessWidget {
  const HudSkillsSection({super.key, required this.skills});

  final List<Skill> skills;

  @override
  Widget build(BuildContext context) {
    return HudSectionCard(
      icon: AppIcons.of(context).classFeature,
      title: 'Competencias',
      child: skills.isEmpty
          ? const HudEmptyHint('La ficha no trae competencias.')
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 340;
                final width = isWide
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final skill in skills)
                      SizedBox(
                        width: width,
                        child: _SkillTile(skill: skill),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statLabel =
        kStatLabels[skill.relatedStat] ??
        (skill.relatedStat.isEmpty ? '—' : skill.relatedStat);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 8,
      ),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        shape: context.tactical.insetBorder(
          scheme.outline.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  skill.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  statLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(
                context.tactical.shapes.pillRadius,
              ),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
            ),
            child: Text(
              skill.modifierFormatted,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Historia y personalidad (cinco campos narrativos + foto del personaje).
// ---------------------------------------------------------------------

class HudLoreSection extends StatelessWidget {
  const HudLoreSection({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final lore = character.loreInfo;
    final entries = <(String, String)>[
      ('Trasfondo', lore.backstory),
      ('Rasgos de personalidad', lore.personalityTraits),
      ('Ideales', lore.ideals),
      ('Vínculos', lore.bonds),
      ('Defectos', lore.flaws),
    ].where((entry) => entry.$2.trim().isNotEmpty).toList();

    final portraitPath = character.loreAvatarPath ?? character.avatarPath;

    return HudSectionCard(
      icon: AppIcons.of(context).spellbook,
      title: 'Historia y personalidad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CharacterAvatar(
                    size: 96,
                    avatarPath: portraitPath,
                    name: character.basicInfo.name,
                    onTap: () {
                      final store = context.read<CharacterStore?>();
                      if (store == null) return;
                      AvatarPickerHelper.showAvatarOptions(
                        context,
                        currentPath:
                            character.loreAvatarPath ?? character.avatarPath,
                        onSelected: store.setLoreAvatarPath,
                      );
                    },
                  ),
                  IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (entries.isEmpty)
            const HudEmptyHint('La ficha no trae historia ni personalidad.')
          else
            for (final entry in entries)
              _ReadOnlyField(label: entry.$1, text: entry.$2),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Códice: notas de IA, tácticas del jugador y diario de aventura.
// ---------------------------------------------------------------------

class HudCodexSection extends StatelessWidget {
  const HudCodexSection({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('Notas de la IA', character.aiTips),
      ('Tácticas del jugador', character.userTactics),
      ('Diario de aventura', character.adventureNotes),
    ].where((entry) => entry.$2.trim().isNotEmpty).toList();

    return HudSectionCard(
      icon: AppIcons.of(context).notes,
      title: 'Códice',
      child: entries.isEmpty
          ? const HudEmptyHint('Sin notas en el códice todavía.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in entries)
                  _ReadOnlyField(label: entry.$1, text: entry.$2),
              ],
            ),
    );
  }
}

/// Bloque de texto de solo lectura con su etiqueta en mayúsculas. Se usa
/// para lore y códice; no tiene campo de edición a propósito.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(text.trim(), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
