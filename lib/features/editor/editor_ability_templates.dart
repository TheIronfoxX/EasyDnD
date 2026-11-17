// Plantillas de habilidades activas no-conjuro para el "+ Habilidad" del
// Arsenal: los rasgos activos de `core_features` del catálogo de clases
// (Furia, Tomar aliento, Inspiración bárdica, Imposición de manos, Ki,
// Recuperación arcana...) más unos pocos poderes raciales/dotes habituales
// que el catálogo de clases no puede traer (Aliento de dragón).

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/class_catalog.dart';
import '../../domain/character_builder_engine.dart';
import '../../domain/models/ability.dart';
import '../../domain/models/character.dart';
import '../../domain/models/srd_spell.dart' show normalizeSpellName;

/// Una plantilla lista para volverse [Ability] (y, si trae [resource],
/// un [ResourcePoint] vinculado).
class AbilityTemplate {
  final String id;
  final String name;

  /// Clave de AbilitiesByAction.listFor: 'action' | 'bonusAction' | 'reaction'.
  final String category;
  final String description;
  final String source;
  final String attackType;
  final String relatedStat;
  final String? damageDice;

  /// Puede referirse al nivel: "1d10+level".
  final String? healDice;
  final SrdClassResource? resource;

  const AbilityTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.source,
    this.attackType = 'none',
    this.relatedStat = '',
    this.damageDice,
    this.healDice,
    this.resource,
  });

  /// Construye la habilidad. Si la plantilla trae recurso y la ficha no
  /// lo tiene, lo agrega a [resources]; en cualquier caso la vincula.
  Ability build({
    required int level,
    required Map<String, int> mods,
    required int proficiency,
    required List<ResourcePoint> resources,
  }) {
    final ability = Ability(
      id: 'ability_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      type: 'trait',
      relatedStat: relatedStat,
      successDescription: description,
      failureDescription: '',
      attackType: attackType,
      damageDice: damageDice,
      healDice: healDice?.replaceAll('level', '$level'),
      loreDescription: description,
      tacticalSummary: source,
    );

    final r = resource;
    if (r != null) {
      final key = normalizeSpellName(r.name);
      final exists = resources.any((x) => normalizeSpellName(x.name) == key);
      if (!exists) {
        var uses = 1;
        try {
          uses = CharacterBuilderEngine.resolveFormula(
            r.maxFormula.replaceAll('proficiency', '$proficiency'),
            level: level,
            mods: mods,
          );
        } on FormatException {
          // Fórmula que el motor no entiende: un uso, editable en el Grimorio.
        }
        resources.add(
          ResourcePoint(
            name: r.name,
            current: uses,
            max: uses,
            recovery: r.recovery,
          ),
        );
      }
      ability.resourceName = resources
          .firstWhere((x) => normalizeSpellName(x.name) == key)
          .name;
    }
    return ability;
  }
}

/// Poderes raciales / dotes habituales que no viven en el catálogo de clases.
const List<AbilityTemplate> kExtraAbilityTemplates = [
  AbilityTemplate(
    id: 'extra_aliento_de_dragon',
    name: 'Aliento de dragón',
    category: 'action',
    description:
        'Exhalas energía destructiva en un cono o línea. Los afectados '
        'tiran salvación de Destreza; la superan para recibir la mitad.',
    source: 'Poder racial (Dracónido)',
    attackType: 'save',
    relatedStat: 'con',
    damageDice: '2d6',
    resource: SrdClassResource(
      name: 'Aliento de dragón',
      maxFormula: 'proficiency',
      recovery: 'long_rest',
    ),
  ),
];

/// Overrides de datos mecánicos que el catálogo de clases no trae.
const Map<String, String> _kHealByName = {'tomar aliento': '1d10+level'};

Future<List<AbilityTemplate>> loadAbilityTemplates() async {
  final classes = await ClassCatalog.load();
  final fromCatalog = <AbilityTemplate>[];
  for (final cls in classes) {
    for (final f in cls.coreFeatures) {
      if (f.actionType == 'passive') continue;
      fromCatalog.add(
        AbilityTemplate(
          id: 'srd_${cls.id}_${normalizeSpellName(f.name).replaceAll(' ', '_')}',
          name: f.name,
          category: f.actionType == 'bonus_action'
              ? 'bonusAction'
              : f.actionType,
          description: f.description,
          source: '${cls.name} nivel ${f.level}',
          healDice: _kHealByName[normalizeSpellName(f.name)],
          resource: f.resource,
        ),
      );
    }
  }
  return [...fromCatalog, ...kExtraAbilityTemplates];
}

/// Resultado del selector: una plantilla, o null = habilidad casera.
class AbilityPick {
  final AbilityTemplate? template;
  const AbilityPick(this.template);
}

Future<AbilityPick?> showAbilityTemplatePicker(BuildContext context) {
  return showModalBottomSheet<AbilityPick>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _AbilityTemplatePicker(),
  );
}

class _AbilityTemplatePicker extends StatefulWidget {
  const _AbilityTemplatePicker();

  @override
  State<_AbilityTemplatePicker> createState() => _AbilityTemplatePickerState();
}

class _AbilityTemplatePickerState extends State<_AbilityTemplatePicker> {
  List<AbilityTemplate> _all = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    loadAbilityTemplates().then((items) {
      if (mounted) {
        setState(() {
          _all = items;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = normalizeSpellName(_query);
    final shown = _all
        .where((t) => q.isEmpty || normalizeSpellName(t.name).contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          ListTile(
            key: const Key('ability-homebrew'),
            leading: const Icon(Icons.edit_note_rounded),
            title: const Text('Habilidad casera'),
            subtitle: const Text('Formulario en blanco'),
            onTap: () => Navigator.of(context).pop(const AbilityPick(null)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar plantilla SRD',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      for (final t in shown)
                        ListTile(
                          key: Key('ability-template-${t.id}'),
                          title: Text(t.name),
                          subtitle: Text(
                            [
                              t.source,
                              if (t.resource != null)
                                'Recurso: ${t.resource!.name}',
                            ].join(' · '),
                          ),
                          onTap: () =>
                              Navigator.of(context).pop(AbilityPick(t)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
