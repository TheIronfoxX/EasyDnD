// Pantallas de Conjuros y de Ataques y habilidades.
//
// Mismo lenguaje que Combate: un filtro por uso arriba (Daño, Defensa,
// Apoyo, Utilidad) y una tarjeta por grupo con filas planas, cada una con
// ▶ para lanzar directo y la estrella de favorita.
//
// - Conjuros: agrupados por lo que hacen (Ataque, Curación, Estados,
//   Utilidad; ver [spellEffectOf]), cada fila con su nivel. Arriba, la CD
//   y los espacios en mosaicos ([SpellSlotsGrid]). Sin filtro: los grupos
//   ya son la clasificación.
// - Ataques y habilidades: agrupados por lo que gastan del turno (Armas,
//   Acción, Adicional, Reacción) y los "Siempre activos" plegados al final.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/tactical_theme_tokens.dart';
import '../../../core/theme/telemetry.dart';
import '../../../core/ui/clean_kit.dart';
import '../../../domain/models/character.dart';
import '../../../domain/power_category.dart';
import '../../../domain/spell_effect.dart';
import '../../../state/character_store.dart';
import '../../../state/skin_controller.dart';
import '../hud_pages.dart';
import 'powers.dart';
import 'spell_slots_grid.dart';

/// Abre la pantalla de Conjuros.
void openSpellsPage(BuildContext context) => pushCharacterPage(
  context,
  title: 'Conjuros',
  builder: (context, c) => [_PowerBrowser(character: c, spells: true)],
);

/// Abre la pantalla de Ataques y habilidades.
void openAbilitiesPage(BuildContext context) => pushCharacterPage(
  context,
  title: 'Ataques y habilidades',
  builder: (context, c) => [_PowerBrowser(character: c, spells: false)],
);

/// Un grupo de la lista: título, cabecera derecha opcional y sus filas.
class _Group {
  const _Group(this.title, this.entries, {this.key, this.hint, this.color});

  final String title;
  final List<PowerEntry> entries;
  final Key? key;

  /// Una línea en llano bajo el título.
  final String? hint;

  /// Color del grupo (título y puntitos); null = el de cada categoría.
  final Color? color;
}

class _PowerBrowser extends StatefulWidget {
  const _PowerBrowser({required this.character, required this.spells});

  final CharacterModel character;
  final bool spells;

  @override
  State<_PowerBrowser> createState() => _PowerBrowserState();
}

class _PowerBrowserState extends State<_PowerBrowser> {
  /// null = Todo.
  PowerCategory? _category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.character;
    final all = powerEntries(c, spells: widget.spells);
    final present = {for (final e in all) e.category};
    final category = present.contains(_category) ? _category : null;
    final shown = [
      for (final e in all)
        if (category == null || e.category == category) e,
    ];
    final groups = widget.spells ? _spellGroups(shown) : _abilityGroups(shown);
    final passives = widget.spells
        ? const <PowerEntry>[]
        : shown.where((e) => e.isPassive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Intro(character: c, spells: widget.spells),
        if (!widget.spells && all.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                _chip(null, 'Todo', all.length, category),
                for (final cat in PowerCategory.values)
                  if (present.contains(cat))
                    _chip(
                      cat,
                      cat.label,
                      all.where((e) => e.category == cat).length,
                      category,
                    ),
              ],
            ),
          ),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              widget.spells
                  ? 'Esta ficha todavía no tiene conjuros.'
                  : 'Esta ficha todavía no tiene armas ni habilidades.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final g in groups) ...[
          CleanSectionTitle(
            g.title,
            key: g.key,
            color: g.color,
            trailing: Text(
              '${g.entries.length}',
              style: theme.textTheme.labelLarge,
            ),
          ),
          if (g.hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                g.hint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (g.entries.isNotEmpty)
            _GroupCard(entries: g.entries, character: c, dotColor: g.color),
        ],
        if (passives.isNotEmpty) _PassivesCard(entries: passives, character: c),
      ],
    );
  }

  Widget _chip(
    PowerCategory? cat,
    String label,
    int count,
    PowerCategory? sel,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        key: ValueKey('power-filter-${cat?.name ?? 'all'}'),
        label: Text('$label · $count'),
        selected: sel == cat,
        onSelected: (_) => setState(() => _category = cat),
      ),
    );
  }

  /// Un grupo por efecto, en orden fijo; dentro, de truco a nivel alto y
  /// por nombre. Los grupos vacíos no salen.
  Color _effectColor(SpellEffect effect) {
    final t = context.tactical;
    return switch (effect) {
      SpellEffect.attack => t.damage,
      SpellEffect.healing => t.heal,
      SpellEffect.condition => t.spell,
      SpellEffect.utility => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  List<_Group> _spellGroups(List<PowerEntry> shown) {
    int level(PowerEntry e) => e.ability?.baseLevel ?? 0;
    return [
      for (final effect in SpellEffect.values)
        if (shown.any((e) => spellEffectOf(e.ability!) == effect))
          _Group(
            effect.label,
            [
              for (final e in shown)
                if (spellEffectOf(e.ability!) == effect) e,
            ]..sort((a, b) {
              final byLevel = level(a).compareTo(level(b));
              return byLevel != 0 ? byLevel : a.name.compareTo(b.name);
            }),
            key: ValueKey('spell-effect-${effect.name}'),
            hint: effect.hint,
            color: _effectColor(effect),
          ),
    ];
  }

  List<_Group> _abilityGroups(List<PowerEntry> shown) {
    final active = shown.where((e) => !e.isPassive).toList();
    List<PowerEntry> where(bool Function(PowerEntry) test) =>
        active.where(test).toList();
    return [
      for (final g in [
        _Group('Armas', where((e) => e.weapon != null)),
        _Group(
          'Acción',
          where((e) => e.weapon == null && e.castLabel == 'Acción'),
        ),
        _Group('Acción adicional', where((e) => e.castLabel == 'Adicional')),
        _Group('Reacción', where((e) => e.castLabel == 'Reacción')),
      ])
        if (g.entries.isNotEmpty) g,
    ];
  }
}

/// Cabecera de la pantalla. En Conjuros: la CD en grande con su
/// explicación y, debajo, los espacios ([SpellSlotsGrid]) con ↻. En
/// Ataques y habilidades: una línea de cómo se usa.
class _Intro extends StatelessWidget {
  const _Intro({required this.character, required this.spells});

  final CharacterModel character;
  final bool spells;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    if (!spells) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(
          'Toca ▶ para atacar o usar una habilidad; el nombre abre el detalle.',
          style: muted,
        ),
      );
    }
    final dc = character.basicInfo.spellSaveDc;
    final store = context.read<CharacterStore>();
    final tone = context.tactical.spell;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dc != null)
          CleanCard(
            key: const ValueKey('spell-dc'),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      '$dc',
                      style: theme.textTheme.headlineMedium?.tabular.copyWith(
                        color: tone,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'CD',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    'Para resistir tus conjuros, los enemigos necesitan sacar '
                    '$dc o más en su salvación.',
                    style: muted,
                  ),
                ),
              ],
            ),
          ),
        if (character.spellSlots.slots.isNotEmpty) ...[
          CleanSectionTitle(
            'Espacios de conjuro',
            trailing: IconButton(
              key: const ValueKey('refill-slots'),
              tooltip: 'Recuperar todos los espacios',
              visualDensity: VisualDensity.compact,
              onPressed: store.restoreAllSpellSlots,
              icon: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              'Cada conjuro de nivel gasta un espacio de ese nivel o mayor.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            key: const ValueKey('slots-strip'),
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
            child: SpellSlotsGrid(character: character),
          ),
        ],
      ],
    );
  }
}

/// Las filas de un grupo en una sola tarjeta, separadas por una línea.
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.entries,
    required this.character,
    this.dotColor,
  });

  final List<PowerEntry> entries;
  final CharacterModel character;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final compact = context.watch<SkinController>().compactHud;
    final line = Theme.of(context).colorScheme.outline.withValues(alpha: 0.6);
    return CleanCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
                color: line,
              ),
            PowerRow(
              key: ValueKey('power-${entries[i].powerId}'),
              entry: entries[i],
              character: character,
              flat: true,
              quickCast: true,
              compact: compact,
              dotColor: dotColor,
            ),
          ],
        ],
      ),
    );
  }
}

/// Rasgos que funcionan solos, plegados para no estorbar.
class _PassivesCard extends StatelessWidget {
  const _PassivesCard({required this.entries, required this.character});

  final List<PowerEntry> entries;
  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outline.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: CleanCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const PageStorageKey('always-active'),
            title: Text('Siempre activos (${entries.length})'),
            subtitle: const Text('Funcionan solos: no tienes que usarlos'),
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                    color: line,
                  ),
                PowerRow(entry: entries[i], character: character, flat: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
