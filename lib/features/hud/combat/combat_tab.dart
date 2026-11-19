// Pestaña Combate: lo que se usa cada turno, en dos bloques.
//
// 1. Panel de estado (una sola superficie): quién eres (emblema y lema),
//    la vida con −1/+1, los números de mesa (CA, iniciativa, velocidad,
//    CD), las ranuras y los recursos con usos.
// 2. Acciones: favoritas arriba y el resto filtrable, en una sola lista
//    de filas planas con lanzamiento directo. Los accesos a Conjuros y
//    Ataques viven en la cabecera de la lista.
// Al final, Estados y Compañeros como filas de una misma tarjeta.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/clean_shape.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/tactical_theme_tokens.dart';
import '../../../core/theme/telemetry.dart';
import '../../../core/ui/app_icons.dart';
import '../../../core/ui/clean_kit.dart';
import '../../../domain/models/character.dart';
import '../../../state/character_store.dart';
import '../../../state/skin_controller.dart';
import '../hud_companions.dart';
import '../hud_pages.dart';
import '../hud_status_tab.dart';
import 'hero_header.dart';
import 'power_pages.dart';
import 'spell_slots_grid.dart';
import 'powers.dart';

class CombatTab extends StatelessWidget {
  const CombatTab({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final spells = powerEntries(character, spells: true);
    final others = powerEntries(character, spells: false);
    final down = character.basicInfo.currentHp <= 0;
    final allPowers = [...spells, ...others];
    final favorites = [
      for (final id in character.favoritePowers)
        ...allPowers.where((e) => e.powerId == id),
    ];

    return CleanList(
      children: [
        if (down) _DownCard(character: character),
        _StatusPanel(character: character),
        if (character.spellSlots.slots.isNotEmpty)
          _SpellSlotsCard(character: character),
        if (character.resources.isNotEmpty)
          _ResourcesCard(character: character),
        _ActionsDeck(
          entries: [...others, ...spells],
          favorites: favorites,
          character: character,
          hasSpells: spells.isNotEmpty || character.spellSlots.slots.isNotEmpty,
        ),
        _MoreCard(character: character),
      ],
    );
  }
}

/// Línea fina que separa las partes de una misma superficie.
class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: AppSpacing.lg,
    thickness: 1,
    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
  );
}

/// Todo el estado del personaje en una superficie, con un leve velo del
/// color principal arriba.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = context.cleanShape;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        key: const ValueKey('health-card'),
        shape: shape.surface(24),
        clipBehavior: Clip.antiAlias,
        color: scheme.surface,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.10),
                  scheme.surface,
                ),
                scheme.surface,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeroHeader(character: character),
                const SizedBox(height: AppSpacing.md),
                _HealthRow(character: character),
                const _PanelDivider(),
                _VitalsRow(character: character),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La vida: −1 a la izquierda, lectura y barra en el centro (tocarla abre
/// la hoja de Vida para daño, curación y temporales) y +1 a la derecha.
class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tactical = context.tactical;
    final store = context.read<CharacterStore>();
    final info = character.basicInfo;
    final ratio = info.hpMax <= 0
        ? 0.0
        : (info.currentHp / info.hpMax).clamp(0.0, 1.0);
    final color = ratio <= 0.25 ? tactical.damage : tactical.heal;
    return Row(
      children: [
        IconButton.outlined(
          key: const ValueKey('hp-minus'),
          tooltip: 'Quitar 1 PG',
          onPressed: info.currentHp > 0 ? () => store.applyDamage(1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Tooltip(
            message: 'Quitar o curar varios PG',
            child: InkWell(
              key: const ValueKey('hp-pill'),
              borderRadius: context.cleanShape.radius(12),
              onTap: () => showLifeSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Icon(Icons.favorite_rounded, size: 16, color: color),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${info.currentHp}/${info.hpMax}',
                          style: theme.textTheme.headlineSmall?.tabular,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          info.tempHp > 0 ? 'PG +${info.tempHp}' : 'PG',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: ratio),
                      duration: AppDurations.normal,
                      builder: (context, v, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 8,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ColoredBox(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.10,
                                  ),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: v,
                                heightFactor: 1,
                                child: ColoredBox(color: color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.outlined(
          key: const ValueKey('hp-plus'),
          tooltip: 'Curar 1 PG',
          onPressed: info.currentHp < info.hpMax
              ? () => store.applyHealing(1)
              : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

/// Los números que más se preguntan en mesa, en columnas planas
/// separadas por una línea fina. Cada uno con su pista en llano.
class _VitalsRow extends StatelessWidget {
  const _VitalsRow({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final info = character.basicInfo;
    final init = character.stats.modFor('dex');
    final tiles = [
      _Vital(
        key: const ValueKey('vital-ac'),
        value: '${info.ac}',
        label: 'Armadura',
        help:
            'Clase de Armadura: para golpearte, el enemigo necesita sacar '
            '${info.ac} o más.',
      ),
      _Vital(
        key: const ValueKey('vital-init'),
        value: init >= 0 ? '+$init' : '$init',
        label: 'Iniciativa',
        help:
            'Se suma a tu d20 al empezar el combate: quien saca más, '
            'actúa antes.',
      ),
      _Vital(
        key: const ValueKey('vital-speed'),
        value: '${info.speed}',
        unit: 'pies',
        label: 'Velocidad',
        help:
            'Lo que te mueves en tu turno: ${info.speed} pies son '
            '${(info.speed / 5).floor()} casillas.',
      ),
    ];
    final line = Theme.of(context).colorScheme.outline.withValues(alpha: 0.6);
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) VerticalDivider(width: 1, thickness: 1, color: line),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

/// Un número de mesa: valor grande y su nombre debajo. La explicación en
/// llano sale al tocarlo, no ocupa sitio.
class _Vital extends StatelessWidget {
  const _Vital({
    super.key,
    required this.value,
    required this.label,
    required this.help,
    this.unit,
  });

  final String value;
  final String? unit;
  final String label;
  final String help;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: help,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 2,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: theme.textTheme.titleLarge?.tabular,
                    ),
                    if (unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: muted,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título de sección de contadores: el título de siempre con ↻ (y otras
/// acciones) a la derecha.
Widget _meterTitle(
  BuildContext context, {
  required String title,
  required Key refillKey,
  required String refillTooltip,
  required VoidCallback onRefill,
  List<Widget> extra = const [],
}) {
  final muted = Theme.of(context).colorScheme.onSurfaceVariant;
  return CleanSectionTitle(
    title,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: refillKey,
          tooltip: refillTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onRefill,
          icon: Icon(Icons.refresh_rounded, size: 20, color: muted),
        ),
        ...extra,
      ],
    ),
  );
}

/// Espacios de conjuro: título con ↻ y › y la cuadrícula de mosaicos
/// ([SpellSlotsGrid]).
class _SpellSlotsCard extends StatelessWidget {
  const _SpellSlotsCard({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    return Column(
      key: const ValueKey('slots-schema'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _meterTitle(
          context,
          title: 'Espacios de conjuro',
          refillKey: const ValueKey('refill-slots-inline'),
          refillTooltip: 'Recuperar todos los espacios',
          onRefill: store.restoreAllSpellSlots,
          extra: [
            IconButton(
              key: const ValueKey('slots-open'),
              tooltip: 'Ver conjuros',
              visualDensity: VisualDensity.compact,
              onPressed: () => openSpellsPage(context),
              icon: Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: SpellSlotsGrid(character: character),
        ),
      ],
    );
  }
}

/// Recursos con usos (Furia, Ki, Hechicería…): una tarjeta por recurso
/// con nombre, `actual/máx`, barra fina y − / +.
class _ResourcesCard extends StatelessWidget {
  const _ResourcesCard({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final tone = context.tactical.ability;
    final store = context.read<CharacterStore>();
    return Column(
      key: const ValueKey('resources-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _meterTitle(
          context,
          title: 'Recursos',
          refillKey: const ValueKey('refill-resources-inline'),
          refillTooltip: 'Recargar todos los recursos',
          onRefill: store.restoreAllResources,
        ),
        for (final r in character.resources)
          _ResourceTile(
            name: r.name,
            current: r.current,
            max: r.max,
            tone: tone,
            onSpend: () => store.decrementResource(r.name),
            onRecover: () => store.incrementResource(r.name),
          ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.name,
    required this.current,
    required this.max,
    required this.tone,
    required this.onSpend,
    required this.onRecover,
  });

  final String name;
  final int current;
  final int max;
  final Color tone;
  final VoidCallback onSpend;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    return CleanCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$current/$max',
                      style: theme.textTheme.titleSmall?.tabular.copyWith(
                        color: current > 0 ? tone : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: ratio),
                    duration: AppDurations.normal,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 4,
                      color: tone,
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Gastar uno de $name',
            visualDensity: VisualDensity.compact,
            onPressed: current > 0 ? onSpend : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          IconButton(
            tooltip: 'Recuperar uno de $name',
            visualDensity: VisualDensity.compact,
            onPressed: current < max ? onRecover : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

enum _ActionFilter { all, weapons, abilities, spells }

/// Acciones de combate en una sola lista: favoritas arriba y el resto
/// filtrable debajo, filas planas con lanzamiento directo. La cabecera
/// lleva los accesos a las pantallas completas de Conjuros y Ataques.
class _ActionsDeck extends StatefulWidget {
  const _ActionsDeck({
    required this.entries,
    required this.favorites,
    required this.character,
    required this.hasSpells,
  });

  final List<PowerEntry> entries;
  final List<PowerEntry> favorites;
  final CharacterModel character;
  final bool hasSpells;

  @override
  State<_ActionsDeck> createState() => _ActionsDeckState();
}

class _ActionsDeckState extends State<_ActionsDeck> {
  _ActionFilter _filter = _ActionFilter.all;

  static const _labels = {
    _ActionFilter.all: 'Todo',
    _ActionFilter.weapons: 'Armas',
    _ActionFilter.abilities: 'Habilidades',
    _ActionFilter.spells: 'Conjuros',
  };

  bool _keep(PowerEntry e) => switch (_filter) {
    _ActionFilter.all => true,
    _ActionFilter.weapons => e.weapon != null,
    _ActionFilter.abilities =>
      e.weapon == null && !(e.ability?.isSpell ?? false),
    _ActionFilter.spells => e.ability?.isSpell ?? false,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact = context.watch<SkinController>().compactHud;
    final favs = widget.character.favoritePowers;
    final shown = widget.entries
        .where((e) => !e.isPassive && !favs.contains(e.powerId) && _keep(e))
        .toList();
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    Widget row(PowerEntry e, {Key? key}) => PowerRow(
      key: key,
      entry: e,
      character: widget.character,
      quickCast: true,
      compact: compact,
      flat: true,
    );

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );

    final divider = Divider(
      height: 1,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
      color: scheme.outline.withValues(alpha: 0.6),
    );

    return Column(
      key: const ValueKey('actions-deck'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CleanSectionTitle(
          'Acciones',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.hasSpells)
                TextButton(
                  key: const ValueKey('nav-spells'),
                  onPressed: () => openSpellsPage(context),
                  child: const Text('Conjuros'),
                ),
              TextButton(
                key: const ValueKey('nav-attacks'),
                onPressed: () => openAbilitiesPage(context),
                child: const Text('Ataques'),
              ),
            ],
          ),
        ),
        if (widget.entries.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                for (final f in _ActionFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      key: ValueKey('filter-${f.name}'),
                      label: Text(_labels[f]!),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
        CleanCard(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Column(
            key: const ValueKey('favorites-section'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label('Favoritas'),
              if (widget.favorites.isEmpty)
                Padding(
                  key: const ValueKey('favorites-empty'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Text(
                    'Toca la estrella de un conjuro, arma o habilidad para '
                    'tenerlo aquí.',
                    style: muted,
                  ),
                )
              else
                for (var i = 0; i < widget.favorites.length; i++) ...[
                  if (i > 0) divider,
                  row(widget.favorites[i]),
                ],
              if (widget.entries.isNotEmpty) ...[
                label(widget.favorites.isEmpty ? 'Todas' : 'El resto'),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Text('Nada de esto en tu ficha.', style: muted),
                  )
                else
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) divider,
                    row(shown[i], key: ValueKey('deck-${shown[i].powerId}')),
                  ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Estados y Compañeros: filas de una misma tarjeta al final.
class _MoreCard extends StatelessWidget {
  const _MoreCard({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final icons = AppIcons.of(context);
    final tactical = context.tactical;
    final scheme = Theme.of(context).colorScheme;
    final conditions = character.activeConditions;
    final companions = character.companions;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: CleanCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              key: const ValueKey('nav-conditions'),
              leading: Icon(
                Icons.healing_rounded,
                color: conditions.isEmpty
                    ? scheme.onSurfaceVariant
                    : tactical.damage,
              ),
              title: const Text('Estados'),
              subtitle: Text(
                conditions.isEmpty
                    ? 'Ninguno: estás bien'
                    : conditions.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: conditions.isEmpty
                  ? const Icon(Icons.chevron_right_rounded)
                  : _CountBadge(
                      count: conditions.length,
                      tone: tactical.damage,
                    ),
              onTap: () => pushCharacterPage(
                context,
                title: 'Estados',
                builder: (context, c) => [HudConditionsSection(character: c)],
              ),
            ),
            if (companions.isNotEmpty) ...[
              Divider(
                height: 1,
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
                color: scheme.outline.withValues(alpha: 0.6),
              ),
              ListTile(
                key: const ValueKey('nav-companions'),
                leading: Icon(icons.companion, color: scheme.onSurfaceVariant),
                title: const Text('Compañeros'),
                subtitle: Text(
                  companions.map((c) => c.name).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => pushCharacterPage(
                  context,
                  title: 'Compañeros',
                  builder: (context, c) => [HudCompanionsSection(character: c)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Globito con un número (p. ej. cuántos estados tienes encima).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.tone});

  final int count;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.surface,
          fontWeight: FontWeight.w800,
        ),
      ),
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
