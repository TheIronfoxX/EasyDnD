// Lista sencilla de poderes (conjuros, armas y habilidades) agrupada por
// categoría —Daño, Defensa, Apoyo, Utilidad— y su pantalla de detalle.
//
// Cada fila: nombre, nivel o tiempo, UNA frase en llano y UNA línea de
// datos clave. Al tocarla se abre el detalle completo con el botón Usar,
// que lanza la hoja de tirada de siempre.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/tactical_theme_tokens.dart';
import '../../../core/ui/clean_kit.dart';
import '../../../data/spell_catalog.dart';
import '../../../domain/models/ability.dart';
import '../../../domain/models/character.dart';
import '../../../domain/models/weapon.dart';
import '../../../domain/power_category.dart';
import '../../../state/character_store.dart';
import '../hud_pages.dart';
import '../hud_resolution_sheet.dart';
import '../hud_roll_actions.dart';

/// Color de cada categoría, sacado de los colores de rol del tema.
Color categoryColor(BuildContext context, PowerCategory category) {
  final t = context.tactical;
  return switch (category) {
    PowerCategory.damage => t.damage,
    PowerCategory.defense => t.spell,
    PowerCategory.support => t.heal,
    PowerCategory.utility => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

/// Un poder listo para pintar: viene de una habilidad/conjuro o de un arma.
class PowerEntry {
  PowerEntry.ability(this.ability, {required this.castLabel})
    : weapon = null,
      category = categoryOf(ability!),
      name = ability.name,
      summary = plainSummaryOf(ability);

  PowerEntry.weapon(this.weapon)
    : ability = null,
      castLabel = 'Acción',
      category = PowerCategory.damage,
      name = weapon!.name,
      summary = _weaponSummary(weapon);

  final Ability? ability;
  final Weapon? weapon;
  final String name;
  final PowerCategory category;
  final String summary;

  /// "Acción", "Adicional", "Reacción" o "Siempre activo".
  final String castLabel;

  bool get isPassive => castLabel == 'Siempre activo';

  /// Id estable del poder (de la habilidad o del arma).
  String get powerId => ability?.id ?? weapon!.id;

  /// Orden dentro de su categoría: trucos y armas primero, luego por nivel.
  int get sortLevel => ability?.baseLevel ?? 0;

  static String _weaponSummary(Weapon w) {
    final plain = w.tacticalSummary?.trim() ?? '';
    if (plain.isNotEmpty) return plain.split(RegExp(r'(?<=[.!?])\s')).first;
    return 'Golpeas con tu arma.';
  }

  /// "truco", "nv 3", "arma" o el tiempo de lanzamiento de un rasgo.
  String get tag {
    if (weapon != null) return 'arma';
    final a = ability!;
    if (a.isCantrip) return 'truco';
    if (a.isLeveledSpell) return 'nv ${a.baseLevel}';
    return castLabel.toLowerCase();
  }

  /// Una línea con lo esencial: cómo se tira y cuánto hace.
  String dataLine(CharacterModel character) {
    final w = weapon;
    if (w != null) {
      return 'Ataque ${_signed(w.attackBonus)} · Daño ${w.damage.baseDice}'
          '${w.damage.baseType.trim().isEmpty ? '' : ' ${w.damage.baseType}'}';
    }
    final a = ability!;
    final parts = <String>[];
    if (a.attackType == 'attack' && !isPassive) {
      final mod =
          character.stats.modFor(a.relatedStat) +
          character.basicInfo.proficiencyBonus;
      parts.add('Ataque ${_signed(mod)}');
    } else if (a.isSavingThrowType) {
      final dc = character.basicInfo.spellSaveDc;
      parts.add(dc == null ? 'Salvación' : 'Salvación CD $dc');
    }
    final dmg = a.damageDice?.trim() ?? '';
    if (dmg.isNotEmpty) parts.add('Daño $dmg');
    final heal = a.healDice?.trim() ?? '';
    if (heal.isNotEmpty) parts.add('Cura $heal');
    if (a.concentration) parts.add('Concentración');
    return parts.join(' · ');
  }
}

/// Todas las entradas de una ficha. [spells] true = solo conjuros;
/// false = armas y habilidades que no son conjuros.
List<PowerEntry> powerEntries(CharacterModel c, {required bool spells}) {
  final abilities = c.abilitiesByAction;
  bool keep(Ability a) => spells ? a.isSpell : !a.isSpell;
  return [
    if (!spells)
      for (final w in c.inventory.weapons) PowerEntry.weapon(w),
    for (final a in abilities.action.where(keep))
      PowerEntry.ability(a, castLabel: 'Acción'),
    for (final a in abilities.bonusAction.where(keep))
      PowerEntry.ability(a, castLabel: 'Adicional'),
    for (final a in abilities.reaction.where(keep))
      PowerEntry.ability(a, castLabel: 'Reacción'),
    for (final a in abilities.passive.where(keep))
      PowerEntry.ability(a, castLabel: 'Siempre activo'),
  ];
}

/// Bloques por categoría. Las pasivas que no son conjuros van aparte,
/// plegadas al final ([passivesFolded]).
List<Widget> groupedPowerList(
  BuildContext context,
  CharacterModel character,
  List<PowerEntry> entries, {
  bool passivesFolded = false,
}) {
  final active = passivesFolded
      ? entries.where((e) => !e.isPassive).toList()
      : entries;
  final passives = passivesFolded
      ? entries.where((e) => e.isPassive).toList()
      : <PowerEntry>[];

  return [
    for (final category in PowerCategory.values)
      ..._categoryBlock(
        context,
        character,
        category,
        active.where((e) => e.category == category).toList()
          ..sort((a, b) => a.sortLevel.compareTo(b.sortLevel)),
      ),
    if (passives.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: CleanCard(
          padding: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const PageStorageKey('always-active'),
              title: Text('Siempre activos (${passives.length})'),
              subtitle: const Text('Funcionan solos: no tienes que usarlos'),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              children: [
                for (final e in passives)
                  PowerRow(entry: e, character: character, flat: true),
              ],
            ),
          ),
        ),
      ),
  ];
}

List<Widget> _categoryBlock(
  BuildContext context,
  CharacterModel character,
  PowerCategory category,
  List<PowerEntry> entries,
) {
  if (entries.isEmpty) return const [];
  final color = categoryColor(context, category);
  return [
    CleanSectionTitle(
      category.label,
      color: color,
      trailing: Text(
        '${entries.length}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    ),
    for (final e in entries) PowerRow(entry: e, character: character),
  ];
}

/// Fila de la lista: nombre + etiqueta, frase en llano y datos clave.
class PowerRow extends StatelessWidget {
  const PowerRow({
    super.key,
    required this.entry,
    required this.character,
    this.flat = false,
    this.quickCast = false,
    this.compact = false,
    this.dotColor,
  });

  /// Color del puntito de la fila; por defecto, el de su categoría.
  final Color? dotColor;

  final PowerEntry entry;
  final CharacterModel character;

  /// Botón de lanzamiento directo (abre la hoja de tirada sin pasar por
  /// el detalle). Solo en listas de uso: favoritas y acciones de Combate.
  final bool quickCast;

  /// Vista Compacta: una línea densa en vez de la tarjeta explicada.
  final bool compact;

  /// Sin tarjeta propia (dentro de un grupo plegable).
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = dotColor ?? categoryColor(context, entry.category);
    final data = entry.dataLine(character);
    final castButton = quickCast && !entry.isPassive
        ? IconButton.filledTonal(
            key: ValueKey('use-${entry.powerId}'),
            tooltip: 'Usar ${entry.name}',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              final store = context.read<CharacterStore>();
              final w = entry.weapon;
              showResolutionSheet(
                context,
                w != null
                    ? weaponRollAction(context, w, store)
                    : abilityRollAction(
                        context,
                        character,
                        entry.ability!,
                        store,
                      ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
          )
        : null;
    final content = compact
        ? Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: entry.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      if (data.isNotEmpty)
                        TextSpan(
                          text: '  $data',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FavoriteStar(entry: entry, character: character),
              ?castButton,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6, right: AppSpacing.md),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          entry.tag,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        FavoriteStar(entry: entry, character: character),
                        ?castButton,
                      ],
                    ),
                    if (entry.summary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(entry.summary, style: theme.textTheme.bodyMedium),
                    ],
                    if (data.isNotEmpty || quickCast) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (data.isNotEmpty) data,
                          // Vista Guiada: qué gasta del turno.
                          if (quickCast && !entry.isPassive) entry.castLabel,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

    void open() => pushPage<void>(
      context,
      PowerDetailPage(
        abilityId: entry.ability?.id,
        weaponId: entry.weapon?.id,
        castLabel: entry.castLabel,
      ),
    );

    if (flat) {
      return InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: content,
        ),
      );
    }
    return CleanCard(
      onTap: open,
      padding: compact
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            )
          : const EdgeInsets.all(AppSpacing.lg),
      margin: EdgeInsets.only(bottom: compact ? AppSpacing.xs : AppSpacing.md),
      child: content,
    );
  }
}

/// Estrella para marcar un poder como favorito. Lee el estado de la ficha
/// que recibe: las pantallas que la pintan ya escuchan al store.
class FavoriteStar extends StatelessWidget {
  const FavoriteStar({super.key, required this.entry, required this.character});

  final PowerEntry entry;
  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final on = character.favoritePowers.contains(entry.powerId);
    return IconButton(
      key: ValueKey('fav-${entry.powerId}'),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      tooltip: on ? 'Quitar de favoritas' : 'Marcar como favorita',
      icon: Icon(
        on ? Icons.star_rounded : Icons.star_outline_rounded,
        color: on
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () =>
          context.read<CharacterStore>().toggleFavoritePower(entry.powerId),
    );
  }
}

/// Detalle completo de un poder, con el botón Usar. Busca el poder por id
/// en la ficha activa para reflejar cargas/ranuras al momento.
class PowerDetailPage extends StatelessWidget {
  const PowerDetailPage({
    super.key,
    this.abilityId,
    this.weaponId,
    required this.castLabel,
  });

  final String? abilityId;
  final String? weaponId;
  final String castLabel;

  @override
  Widget build(BuildContext context) {
    return ActiveCharacterPage(
      title: 'Detalle',
      builder: (context, character) {
        final weapon = weaponId == null
            ? null
            : character.inventory.weapons
                  .where((w) => w.id == weaponId)
                  .firstOrNull;
        final ability = abilityId == null
            ? null
            : character.abilitiesByAction.all
                  .where((a) => a.id == abilityId)
                  .firstOrNull;
        if (weapon == null && ability == null) {
          return const [Text('Este poder ya no está en la ficha.')];
        }
        final entry = weapon != null
            ? PowerEntry.weapon(weapon)
            : PowerEntry.ability(ability!, castLabel: castLabel);
        return _detail(context, character, entry);
      },
    );
  }

  List<Widget> _detail(
    BuildContext context,
    CharacterModel character,
    PowerEntry entry,
  ) {
    final theme = Theme.of(context);
    final color = categoryColor(context, entry.category);
    final store = context.read<CharacterStore>();
    final a = entry.ability;
    final w = entry.weapon;

    final facts = <(String, String)>[
      if (a != null && a.isCantrip)
        ('Tipo', 'Truco: gratis, siempre que quieras'),
      if (a != null && a.isLeveledSpell)
        ('Tipo', 'Conjuro de nivel ${a.baseLevel}: gasta una ranura'),
      (
        'Cuándo',
        switch (entry.castLabel) {
          'Acción' => 'Usa tu acción del turno',
          'Adicional' => 'Usa tu acción adicional',
          'Reacción' => 'Fuera de tu turno, como reacción',
          _ => 'Siempre activo',
        },
      ),
      if (entry.dataLine(character).isNotEmpty)
        ('Tirada', entry.dataLine(character)),
      if (a != null && a.isScalable && (a.scalingFormula?.isNotEmpty ?? false))
        ('A más nivel', 'Suma ${a.scalingFormula} por cada nivel extra'),
      if (a?.resourceName != null)
        ('Gasta', '${a!.resourceCost} de ${a.resourceName}'),
      if (a != null && a.magicCharges.hasCharges)
        ('Usos', '${a.magicCharges.current} de ${a.magicCharges.max}'),
      if (w != null && w.magicCharges.hasCharges)
        ('Cargas', '${w.magicCharges.current} de ${w.magicCharges.max}'),
      if (a != null && a.concentration)
        ('Concentración', 'Dura mientras no pierdas la concentración'),
    ];

    Widget block(String label, String? text) {
      if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
      return CleanCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(text.trim(), style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return [
      Row(
        children: [
          Expanded(
            child: Text(
              entry.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FavoriteStar(entry: entry, character: character),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              entry.category.label,
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
      if (entry.summary.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        Text(entry.summary, style: theme.textTheme.titleMedium),
      ],
      if (a?.whenToUse?.trim().isNotEmpty ?? false) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Cuándo usarlo: ${a!.whenToUse!.trim()}',
          key: const ValueKey('power-when'),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      if (!entry.isPassive)
        FilledButton.icon(
          key: const ValueKey('power-use'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => showResolutionSheet(
            context,
            w != null
                ? weaponRollAction(context, w, store)
                : abilityRollAction(context, character, a!, store),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Usar'),
        ),
      const SizedBox(height: AppSpacing.lg),
      CleanCard(
        child: Column(
          children: [
            for (final (label, value) in facts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 116,
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(value, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      if (a != null && a.isSpell) _SrdFacts(name: a.name),
      block('Cómo se usa en la mesa', a?.tacticalSummary ?? w?.tacticalSummary),
      block('Si sale bien', a?.successDescription ?? w?.successDescription),
      block('Si sale mal', a?.failureDescription ?? w?.failureDescription),
      block('Descripción', a?.loreDescription ?? w?.loreDescription),
    ];
  }
}

/// Alcance, tiempo de lanzamiento y texto del reglamento (SRD) de un
/// conjuro, si está en el catálogo empaquetado.
class _SrdFacts extends StatelessWidget {
  const _SrdFacts({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SrdSpell>>(
      future: SpellCatalog.load(),
      builder: (context, snapshot) {
        final key = normalizeSpellName(name);
        final spell = snapshot.data
            ?.where((s) => normalizeSpellName(s.name) == key)
            .firstOrNull;
        if (spell == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return CleanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reglamento',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Alcance: ${spell.range}'),
              Text('Lanzamiento: ${spell.castingTime}'),
              const SizedBox(height: AppSpacing.sm),
              Text(spell.description, style: theme.textTheme.bodyMedium),
            ],
          ),
        );
      },
    );
  }
}
