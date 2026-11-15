import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/spell_catalog.dart';
import '../../domain/models/ability.dart';

/// Abre la hoja de búsqueda y selección de conjuros del catálogo SRD 5e.
///
/// Devuelve la [Ability] elegida junto con la categoría de economía de
/// acciones resuelta ('action'/'bonusAction'/'reaction'), o null al
/// cancelar — ver [SrdSpell.toAbility].
Future<(Ability, String)?> showSpellPickerSheet(
  BuildContext context, {
  String defaultStat = 'int',
  String? preferredActionCategory,
}) async {
  return showModalBottomSheet<(Ability, String)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SpellPickerSheet(
      defaultStat: defaultStat,
      preferredActionCategory: preferredActionCategory,
    ),
  );
}

class SpellPickerSheet extends StatefulWidget {
  const SpellPickerSheet({
    super.key,
    this.defaultStat = 'int',
    this.preferredActionCategory,
  });

  final String defaultStat;
  final String? preferredActionCategory;

  @override
  State<SpellPickerSheet> createState() => _SpellPickerSheetState();
}

class _SpellPickerSheetState extends State<SpellPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<SrdSpell> _allSpells = const [];
  bool _loading = true;
  int? _selectedLevel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final spells = await SpellCatalog.load();
    if (mounted) {
      setState(() {
        _allSpells = spells;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final results = SpellCatalog.search(
      _allSpells,
      query: _searchController.text,
      level: _selectedLevel,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Catálogo de Conjuros'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar conjuro (ej. Bola de fuego, Curar...)',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _selectedLevel == null,
                  onSelected: (_) => setState(() => _selectedLevel = null),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilterChip(
                  label: const Text('Trucos'),
                  selected: _selectedLevel == 0,
                  onSelected: (_) => setState(() => _selectedLevel = 0),
                ),
                for (var lvl = 1; lvl <= 9; lvl++) ...[
                  const SizedBox(width: AppSpacing.xs),
                  FilterChip(
                    label: Text('Nivel $lvl'),
                    selected: _selectedLevel == lvl,
                    onSelected: (_) => setState(() => _selectedLevel = lvl),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty
                    ? Center(
                        child: Text(
                          'No se encontraron conjuros para "${_searchController.text}"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final spell = results[index];
                          return ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.primary.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: scheme.primary.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                spell.level == 0 ? 'T' : '${spell.level}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              spell.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${spell.level == 0 ? "Truco" : "Nivel ${spell.level}"} · ${spell.school} · ${spell.castingTime}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: spell.damageDice != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest,
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.pill),
                                      border: Border.all(color: scheme.outline),
                                    ),
                                    child: Text(
                                      spell.damageDice!,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () {
                              final result = spell.toAbility(
                                relatedStat: widget.defaultStat,
                                preferredActionCategory:
                                    widget.preferredActionCategory,
                              );
                              Navigator.of(context).pop(result);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
