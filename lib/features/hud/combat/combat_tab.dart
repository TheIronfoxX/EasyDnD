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
import '../../../core/theme/telemetry.dart';
import '../../../core/ui/app_icons.dart';
import '../../../core/ui/clean_kit.dart';
import '../../../domain/models/character.dart';
import '../../../state/character_store.dart';
import '../hud_companions.dart';
import '../hud_pages.dart';
import '../hud_resources.dart';
import '../hud_status_tab.dart';
import 'hero_header.dart';
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
    final allPowers = [...spells, ...others];
    final favorites = [
      for (final id in character.favoritePowers)
        ...allPowers.where((e) => e.powerId == id),
    ];

    return CleanList(
      children: [
        if (down) _DownCard(character: character),
        HeroHeader(character: character),
        _HealthCard(character: character),
        _VitalsStrip(character: character),
        if (character.spellSlots.slots.isNotEmpty)
          _SlotsSchema(character: character, onTap: () => _openSpells(context)),
        NavTilePair(
          tiles: [
            if (spells.isNotEmpty || character.spellSlots.slots.isNotEmpty)
              NavTileCard(
                key: const ValueKey('nav-spells'),
                icon: icons.spell,
                iconColor: tactical.spell,
                title: 'Conjuros',
                subtitle: spells.isEmpty
                    ? 'Tus ranuras'
                    : '${spells.length} · por Daño, Defensa, Apoyo y Utilidad',
                onTap: () => _openSpells(context),
              ),
            NavTileCard(
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
          ],
        ),
        if (allPowers.isNotEmpty)
          _FavoritesSection(favorites: favorites, character: character),
        if (character.resources.isNotEmpty)
          _ResourcesCard(character: character),
        NavTilePair(
          tiles: [
            NavTileCard(
              key: const ValueKey('nav-conditions'),
              icon: Icons.healing_rounded,
              iconColor: conditions.isEmpty ? null : tactical.damage,
              title: 'Estados',
              subtitle: conditions.isEmpty
                  ? 'Ninguno: estás bien'
                  : conditions.join(', '),
              trailing: conditions.isEmpty
                  ? null
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
            if (companions.isNotEmpty)
              NavTileCard(
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
        ),
      ],
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

/// Los números que más se preguntan en mesa, grandes y de un vistazo.
/// Cada uno lleva debajo una pista de una línea, en llano.
class _VitalsStrip extends StatelessWidget {
  const _VitalsStrip({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final tactical = context.tactical;
    final info = character.basicInfo;
    final init = character.stats.modFor('dex');
    final dc = info.spellSaveDc;
    final tiles = [
      _Vital(
        key: const ValueKey('vital-ac'),
        tone: Theme.of(context).colorScheme.primary,
        value: '${info.ac}',
        label: 'Armadura',
        help: 'te golpean con ${info.ac}+',
      ),
      _Vital(
        key: const ValueKey('vital-init'),
        tone: tactical.coinGold,
        value: init >= 0 ? '+$init' : '$init',
        label: 'Iniciativa',
        help: 'quién actúa antes',
      ),
      _Vital(
        key: const ValueKey('vital-speed'),
        tone: tactical.ability,
        value: '${info.speed}',
        unit: 'pies',
        label: 'Velocidad',
        help: '${(info.speed / 5).floor()} casillas',
      ),
      if (dc != null)
        _Vital(
          key: const ValueKey('vital-dc'),
          tone: tactical.spell,
          value: '$dc',
          label: 'CD conjuros',
          help: 'resisten con $dc+',
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

class _Vital extends StatelessWidget {
  const _Vital({
    super.key,
    required this.tone,
    required this.value,
    required this.label,
    required this.help,
    this.unit,
  });

  final Color tone;
  final String value;
  final String? unit;
  final String label;
  final String help;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DotRing(
                    color: scheme.onSurface.withValues(alpha: 0.25),
                    dots: 24,
                    dotRadius: 1.3,
                  ),
                ),
                Positioned(
                  top: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: tone,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: theme.textTheme.headlineMedium?.tabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            unit == null
                ? label.toUpperCase()
                : '${label.toUpperCase()} · $unit',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontSize: 10,
            ),
          ),
          Text(
            help,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
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

/// La vida, única y a la vista: lectura `actual/máx`, barra con degradado
/// y botones directos −1 / +1. Tocar la barra abre la hoja de Vida (daño,
/// curación, PG temporales).
class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.character});

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
    return CleanCard(
      key: const ValueKey('health-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('hp-pill'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => showLifeSheet(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Icon(Icons.favorite_rounded, size: 18, color: color),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${info.currentHp}/${info.hpMax}',
                      style: theme.textTheme.headlineMedium?.tabular,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      info.tempHp > 0
                          ? 'PG · +${info.tempHp} temporales'
                          : 'PG',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: ratio),
                  duration: AppDurations.normal,
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 12,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color: scheme.onSurface.withValues(alpha: 0.12),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: v,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color.withValues(alpha: 0.65),
                                    color,
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
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Toca la barra para quitar o curar varios PG',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('hp-minus'),
                  onPressed: info.currentHp > 0
                      ? () => store.applyDamage(1)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                  label: const Text('-1'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('hp-plus'),
                  onPressed: info.currentHp < info.hpMax
                      ? () => store.applyHealing(1)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('+1'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Poderes marcados con la estrella: lo que más se usa, a un toque.
class _FavoritesSection extends StatelessWidget {
  const _FavoritesSection({required this.favorites, required this.character});

  final List<PowerEntry> favorites;
  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('favorites-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CleanSectionTitle(
          'Favoritas',
          trailing: favorites.isEmpty
              ? null
              : Text('${favorites.length}', style: theme.textTheme.labelLarge),
        ),
        if (favorites.isEmpty)
          CleanCard(
            key: const ValueKey('favorites-empty'),
            child: Row(
              children: [
                Icon(
                  Icons.star_outline_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Toca la estrella de un conjuro, arma o habilidad para '
                    'tenerlo aquí, a mano.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final e in favorites) PowerRow(entry: e, character: character),
      ],
    );
  }
}

/// Fila de puntos de una tarjeta de recursos.
Widget _pipRow(BuildContext context, String label, Widget pips) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(child: pips),
      ],
    ),
  );
}

/// Cabecera común: medallón, título y botón de recargar.
Widget _resourceHeader(
  BuildContext context, {
  required IconData icon,
  required Color tone,
  required String title,
  required String hint,
  required Key refillKey,
  required VoidCallback onRefill,
}) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          IconMedallion(icon: icon, tone: tone, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            key: refillKey,
            onPressed: onRefill,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Recargar'),
          ),
        ],
      ),
      Text(
        hint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
    ],
  );
}

/// Pantalla de Conjuros: ranuras con detalle (gastables) y la lista por rol.
void _openSpells(BuildContext context) {
  pushCharacterPage(
    context,
    title: 'Conjuros',
    builder: (context, c) => [
      if (c.spellSlots.slots.isNotEmpty) _SlotsCard(character: c),
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
  );
}

/// Tira de ranuras: un grupo de puntitos por nivel. Tocar un nivel gasta
/// una ranura; si ya no quedan, recupera una. La flecha abre la pantalla
/// de Conjuros con el detalle.
class _SlotsSchema extends StatelessWidget {
  const _SlotsSchema({required this.character, required this.onTap});

  final CharacterModel character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = context.tactical.spell;
    final store = context.read<CharacterStore>();
    final slots = [...character.spellSlots.slots]
      ..sort((a, b) => a.level.compareTo(b.level));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        key: const ValueKey('slots-schema'),
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: tone),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 2,
                  children: [
                    for (final s in slots)
                      InkWell(
                        key: ValueKey('slot-level-${s.level}'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => s.current > 0
                            ? store.consumeSpellSlot(s.level)
                            : store.restoreSpellSlot(s.level),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${s.level}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              for (var i = 0; i < s.max; i++)
                                AnimatedContainer(
                                  duration: AppDurations.fast,
                                  width: 9,
                                  height: 9,
                                  margin: const EdgeInsets.only(right: 3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i < s.current ? tone : null,
                                    border: Border.all(
                                      color: i < s.current
                                          ? tone
                                          : scheme.onSurface.withValues(
                                              alpha: 0.3,
                                            ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('slots-open'),
                tooltip: 'Ver conjuros y ranuras con detalle',
                visualDensity: VisualDensity.compact,
                onPressed: onTap,
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ranuras de conjuro por nivel, gastables tocando los puntos.
class _SlotsCard extends StatelessWidget {
  const _SlotsCard({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    final tone = context.tactical.spell;
    final slots = [...character.spellSlots.slots]
      ..sort((a, b) => a.level.compareTo(b.level));
    return CleanCard(
      key: const ValueKey('slots-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _resourceHeader(
            context,
            icon: Icons.auto_awesome_rounded,
            tone: tone,
            title: 'Ranuras de conjuro',
            hint:
                'Cada conjuro de nivel gasta una. Toca un punto para '
                'gastarlo; uno vacío para recuperarlo.',
            refillKey: const ValueKey('refill-slots'),
            onRefill: store.restoreAllSpellSlots,
          ),
          for (final slot in slots)
            _pipRow(
              context,
              'Nivel ${slot.level}',
              TapPips(
                current: slot.current,
                max: slot.max,
                tone: tone,
                spendTooltip: 'Gastar ranura de nivel ${slot.level}',
                recoverTooltip: 'Recuperar ranura de nivel ${slot.level}',
                onSpend: () => store.consumeSpellSlot(slot.level),
                onRecover: () => store.restoreSpellSlot(slot.level),
              ),
            ),
        ],
      ),
    );
  }
}

/// Recursos con usos (Furia, Ki, Hechicería…): una línea cada uno, con
/// − y + para gastar o recuperar.
class _ResourcesCard extends StatelessWidget {
  const _ResourcesCard({required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    final theme = Theme.of(context);
    final tone = context.tactical.ability;
    return CleanCard(
      key: const ValueKey('resources-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in character.resources)
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Gastar un punto de ${r.name}',
                  visualDensity: VisualDensity.compact,
                  onPressed: r.current > 0
                      ? () => store.decrementResource(r.name)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${r.current}/${r.max}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.tabular.copyWith(
                      color: r.current == 0
                          ? theme.colorScheme.onSurfaceVariant
                          : tone,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Recuperar un punto de ${r.name}',
                  visualDensity: VisualDensity.compact,
                  onPressed: r.current < r.max
                      ? () => store.incrementResource(r.name)
                      : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
