// Buscador de reglas: estados (condiciones), conjuros del reglamento
// (SRD empaquetado) y los poderes de la ficha activa, explicados en
// llano. Todo offline.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dnd_rules.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/ui/clean_kit.dart';
import '../../data/spell_catalog.dart';
import '../../domain/power_category.dart';
import '../../state/character_store.dart';
import 'combat/powers.dart';

class RulesSearchScreen extends StatefulWidget {
  const RulesSearchScreen({super.key});

  @override
  State<RulesSearchScreen> createState() => _RulesSearchScreenState();
}

class _RulesSearchScreenState extends State<RulesSearchScreen> {
  final _controller = TextEditingController();
  List<SrdSpell> _spells = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    SpellCatalog.load().then((all) {
      if (mounted) setState(() => _spells = all);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = normalizeSpellName(_query);
    final character = context.watch<CharacterStore>().activeCharacter;

    final conditions = DndRules.conditions.entries
        .where((e) => q.isEmpty || normalizeSpellName(e.key).contains(q))
        .toList();
    final own = character == null || q.isEmpty
        ? <PowerEntry>[]
        : [
            ...powerEntries(character, spells: true),
            ...powerEntries(character, spells: false),
          ].where((e) => normalizeSpellName(e.name).contains(q)).toList();
    final spells = q.length < 2
        ? <SrdSpell>[]
        : SpellCatalog.search(_spells, query: _query).take(30).toList();

    Widget result(String title, String body, {VoidCallback? onTap}) =>
        CleanCard(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );

    void showFull(String title, String body) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text(body, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('rules-search-field'),
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Busca un estado, conjuro o regla',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: CleanList(
        children: [
          if (own.isNotEmpty) ...[
            const CleanSectionTitle('Tus poderes'),
            for (final e in own) PowerRow(entry: e, character: character!),
          ],
          if (conditions.isNotEmpty) ...[
            const CleanSectionTitle('Estados'),
            for (final e in conditions)
              result(
                e.key,
                e.value.description,
                onTap: () => showFull(e.key, e.value.description),
              ),
          ],
          if (spells.isNotEmpty) ...[
            const CleanSectionTitle('Conjuros del reglamento'),
            for (final s in spells)
              result(
                s.name,
                '${s.level == 0 ? 'Truco' : 'Nivel ${s.level}'} · '
                '${s.castingTime} · ${s.range}\n${s.description}',
                onTap: () => showFull(
                  s.name,
                  '${s.level == 0 ? 'Truco' : 'Nivel ${s.level}'} · '
                  '${s.school}\nLanzamiento: ${s.castingTime}\n'
                  'Alcance: ${s.range}\n\n${s.description}',
                ),
              ),
          ],
          if (q.isNotEmpty &&
              own.isEmpty &&
              conditions.isEmpty &&
              spells.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Nada con "$_query".',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          if (q.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Escribe para buscar también entre tus poderes y los '
                'conjuros del reglamento. Categorías: '
                '${PowerCategory.values.map((c) => c.label).join(', ')}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
