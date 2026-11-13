// Pestaña Ficha (Etapa 5d): la hoja del personaje de SOLO LECTURA.
//
// Cuatro bloques, en el orden en que se consultan en mesa:
//   atributos → competencias → historia y personalidad → códice.
//
// La edición vive en CharacterEditorScreen. Acá no hay campos ni
// botones que muten nada: el jugador lee, el editor escribe. Eso permite
// que esta pestaña sea un widget puro (sin store) y que el shell la
// reconstruya con la ficha activa cuando cambie de personaje.

import 'package:flutter/material.dart';

import '../../core/dnd_rules.dart';
import '../../domain/models/character.dart';
import '../../domain/models/stats.dart';
import 'hud_widgets.dart';
import '../../core/theme/design_tokens.dart';

class HudSheetTab extends StatelessWidget {
  const HudSheetTab({super.key, required this.character});

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
        _AttributesSection(stats: character.stats),
        _SkillsSection(skills: character.skills),
        _LoreSection(lore: character.loreInfo),
        _CodexSection(character: character),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Atributos: valor y modificador de las seis características.
// ---------------------------------------------------------------------

class _AttributesSection extends StatelessWidget {
  const _AttributesSection({required this.stats});

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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score.value}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  score.modFormatted,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Competencias: modificador final ya calculado por la ficha.
// ---------------------------------------------------------------------

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({required this.skills});

  final List<Skill> skills;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HudSectionCard(
      icon: Icons.military_tech_rounded,
      title: 'Competencias',
      child: skills.isEmpty
          ? const HudEmptyHint('La ficha no trae competencias.')
          : Column(
              children: [
                for (final skill in skills)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      foregroundColor: theme.colorScheme.onSecondaryContainer,
                      child: Text(
                        skill.relatedStat.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      skill.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_skillSubtitle(skill)),
                    trailing: Text(
                      skill.modifierFormatted,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  /// "Sabiduría" cuando el atributo es conocido; si una ficha vieja
  /// trae una clave rara, se muestra cruda en vez de romper.
  static String _skillSubtitle(Skill skill) {
    final label = kStatLabels[skill.relatedStat];
    if (label != null) return label;
    return skill.relatedStat.isEmpty ? 'Sin atributo' : skill.relatedStat;
  }
}

// ---------------------------------------------------------------------
// Historia y personalidad (cinco campos narrativos).
// ---------------------------------------------------------------------

class _LoreSection extends StatelessWidget {
  const _LoreSection({required this.lore});

  final LoreInfo lore;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('Trasfondo', lore.backstory),
      ('Rasgos de personalidad', lore.personalityTraits),
      ('Ideales', lore.ideals),
      ('Vínculos', lore.bonds),
      ('Defectos', lore.flaws),
    ].where((entry) => entry.$2.trim().isNotEmpty).toList();

    return HudSectionCard(
      icon: Icons.auto_stories_rounded,
      title: 'Historia y personalidad',
      child: entries.isEmpty
          ? const HudEmptyHint('La ficha no trae historia ni personalidad.')
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

// ---------------------------------------------------------------------
// Códice: notas de IA, tácticas del jugador y diario de aventura.
// ---------------------------------------------------------------------

class _CodexSection extends StatelessWidget {
  const _CodexSection({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('Notas de la IA', character.aiTips),
      ('Tácticas del jugador', character.userTactics),
      ('Diario de aventura', character.adventureNotes),
    ].where((entry) => entry.$2.trim().isNotEmpty).toList();

    return HudSectionCard(
      icon: Icons.menu_book_rounded,
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
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(text.trim(), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
