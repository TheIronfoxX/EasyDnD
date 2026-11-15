// Pestaña "Núcleo" del taller: identidad, vitales de combate, atributos
// y competencias. Todo muta el borrador en el lugar (el commit es el
// "Guardar" del shell).

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/theme/tactical_palette.dart';
import '../../core/theme/telemetry.dart';
import '../../core/ui/tactical_card.dart';
import '../../core/ui/character_avatar.dart';
import '../../domain/models/character.dart';
import '../../domain/models/stats.dart';
import 'editor_dialog_skill.dart';
import 'editor_fields.dart';

class EditorTabCore extends StatefulWidget {
  const EditorTabCore({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final CharacterModel draft;

  /// Avisa al shell para refrescar lo que dependa del borrador.
  final VoidCallback onChanged;

  @override
  State<EditorTabCore> createState() => _EditorTabCoreState();
}

class _EditorTabCoreState extends State<EditorTabCore> {
  /// Un controller por modificador: "usar estándar" tiene que poder
  /// sobreescribir el texto del campo.
  late final List<TextEditingController> _modControllers = [
    for (final score in widget.draft.stats.asList)
      TextEditingController(text: score.mod.toString()),
  ];

  @override
  void dispose() {
    for (final c in _modControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch() {
    setState(() {});
    widget.onChanged();
  }

  /// Percepción pasiva = 10 + bono de Percepción (o el mod. de Sabiduría
  /// si la ficha no trae esa competencia).
  int get _passivePerception {
    final skills = widget.draft.skills.where(
      (s) => s.name.toLowerCase().startsWith('percep'),
    );
    final bonus = skills.isEmpty
        ? widget.draft.stats.wis.mod
        : skills.first.modifier;
    return 10 + bonus;
  }

  static String _signed(int n) => n >= 0 ? '+$n' : '$n';

  Future<void> _editSkill({int? index}) async {
    final skills = widget.draft.skills;
    final result = await showDialog<Skill>(
      context: context,
      builder: (_) =>
          SkillDialog(initial: index == null ? null : skills[index]),
    );
    if (result == null) return;
    if (index == null) {
      skills.add(result);
    } else {
      skills[index] = result;
    }
    _touch();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final basic = draft.basicInfo;
    final theme = Theme.of(context);
    final scores = draft.stats.asList;
    final statKeys = kStatLabels.keys.toList(growable: false);

    return ListView(
      key: const Key('list-core'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ----------------------------- identidad -----------------------------
        TacticalCard(
          tone: theme.colorScheme.primary,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CharacterAvatar(
                    avatarPath: draft.avatarPath,
                    name: basic.name,
                    size: 72,
                    onTap: () => AvatarPickerHelper.showAvatarOptions(
                      context,
                      currentPath: draft.avatarPath,
                      onSelected: (newPath) {
                        setState(() => draft.avatarPath = newPath);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      children: [
                        EditorTextField(
                          label: 'Nombre',
                          initialValue: basic.name,
                          onChanged: (v) {
                            basic.name = v;
                            widget.onChanged();
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        EditorTextField(
                          label: 'Clase',
                          initialValue: basic.characterClass,
                          hint: 'Ej: Artillero 6',
                          onChanged: (v) => basic.characterClass = v,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: EditorTextField(
                      label: 'Raza',
                      initialValue: basic.race,
                      onChanged: (v) => basic.race = v,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: EditorTextField(
                      label: 'Alineamiento',
                      initialValue: basic.alignment,
                      onChanged: (v) => basic.alignment = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              EditorStepperField(
                id: 'level',
                label: 'Nivel',
                value: basic.level,
                min: 1,
                onChanged: (v) {
                  if (v != null) {
                    basic.setLevel(v);
                    _touch();
                  }
                },
              ),
            ],
          ),
        ),

        // ------------------------------ vitales ------------------------------
        const EditorBlockTitle('Vitales de combate'),
        // Cuadrícula de instrumentos: dos columnas cuando hay ancho, una
        // fila por vital (con su icono) en teléfonos angostos.
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 480;
            final cell = twoColumns
                ? (constraints.maxWidth - AppSpacing.sm) / 2
                : constraints.maxWidth;
            final tactical = context.tactical;

            Widget vital(IconData icon, Color tone, Widget field) => SizedBox(
              width: cell,
              child: TacticalCard(
                tone: tone,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    EditorIconPlate(icon: icon, tone: tone, size: 36),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: field),
                  ],
                ),
              ),
            );

            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                vital(
                  Icons.favorite_rounded,
                  tactical.heal,
                  EditorStepperField(
                    id: 'hp',
                    label: 'PG máximos',
                    value: basic.hpMax,
                    min: 1,
                    onChanged: (v) {
                      if (v != null) {
                        basic.setHpMax(v);
                        _touch();
                      }
                    },
                  ),
                ),
                vital(
                  Icons.shield_rounded,
                  theme.colorScheme.primary,
                  EditorStepperField(
                    id: 'ac',
                    label: 'CA',
                    value: basic.ac,
                    onChanged: (v) {
                      if (v != null) {
                        basic.ac = v;
                        _touch();
                      }
                    },
                  ),
                ),
                vital(
                  Icons.directions_walk_rounded,
                  tactical.ability,
                  EditorStepperField(
                    id: 'speed',
                    label: 'Velocidad (pies por turno)',
                    value: basic.speed,
                    min: 5,
                    onChanged: (v) {
                      if (v != null) {
                        draft.setSpeed(v);
                        _touch();
                      }
                    },
                  ),
                ),
                vital(
                  Icons.auto_awesome_rounded,
                  tactical.spell,
                  EditorStepperField(
                    id: 'dc',
                    label: 'CD de salvación',
                    value: basic.spellSaveDc,
                    allowEmpty: true,
                    nullStart: 10,
                    onChanged: (v) {
                      basic.spellSaveDc = v;
                      _touch();
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        TacticalCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: EditorReadout(
                  id: 'initiative',
                  label: 'Iniciativa',
                  value: _signed(draft.stats.dex.mod),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: context.tactical.metalBorder.withValues(alpha: 0.7),
              ),
              Expanded(
                child: EditorReadout(
                  id: 'passive-perception',
                  label: 'Percepción pasiva',
                  value: '$_passivePerception',
                ),
              ),
            ],
          ),
        ),

        // ----------------------------- atributos -----------------------------
        const EditorBlockTitle('Atributos y salvaciones'),
        for (var i = 0; i < scores.length; i++)
          _ScoreCard(
            key: ValueKey('score-${statKeys[i]}'),
            label: kStatLabels[statKeys[i]]!,
            statKey: statKeys[i],
            score: scores[i],
            modController: _modControllers[i],
            onChanged: _touch,
            onApplyStandard: () {
              final standard = (scores[i].value - 10) ~/ 2;
              scores[i].mod = standard;
              _modControllers[i].text = standard.toString();
              _touch();
            },
          ),

        // ---------------------------- competencias ---------------------------
        const SizedBox(height: AppSpacing.sm),
        TacticalCard(
          padding: EdgeInsets.zero,
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('skills-expansion'),
              title: const Text('Competencias'),
              subtitle: Text(
                draft.skills.isEmpty
                    ? 'sin competencias'
                    : (draft.skills.length == 1
                          ? '1 competencia'
                          : '${draft.skills.length} competencias'),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              children: [
                Text(
                  'El modificador final de cada competencia, tal como lo usa el '
                  'HUD. No se recalcula solo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (draft.skills.isEmpty)
                  const EditorEmptyHint(
                    'Todavía no hay competencias en la ficha.',
                  ),
                for (var i = 0; i < draft.skills.length; i++)
                  ListTile(
                    dense: true,
                    leading: StatBadge(skill: draft.skills[i]),
                    title: Text(draft.skills[i].name),
                    subtitle: Text(_skillSubtitle(draft.skills[i])),
                    trailing: IconButton(
                      tooltip: 'Borrar competencia',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () {
                        draft.skills.removeAt(i);
                        _touch();
                      },
                    ),
                    onTap: () => _editSkill(index: i),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('add-skill'),
                    onPressed: () => _editSkill(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar competencia'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        EditorTextField(
          label: 'Enlace de Nivel20',
          initialValue: basic.nivel20Link ?? '',
          hint: 'https://nivel20.com/games/.../characters/...',
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: (v) => basic.nivel20Link = v.trim().isEmpty ? null : v,
        ),
      ],
    );
  }

  static String _skillSubtitle(Skill skill) {
    final label = kStatLabels[skill.relatedStat];
    return label == null
        ? skill.modifierFormatted
        : '$label · ${skill.modifierFormatted}';
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    super.key,
    required this.label,
    required this.statKey,
    required this.score,
    required this.modController,
    required this.onChanged,
    required this.onApplyStandard,
  });

  final String label;
  final String statKey;
  final AbilityScore score;
  final TextEditingController modController;
  final VoidCallback onChanged;
  final VoidCallback onApplyStandard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final standard = (score.value - 10) ~/ 2;

    return TacticalCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // El modificador vivo, como placa: es lo que se suma a
              // las tiradas.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  score.modFormatted,
                  key: Key('mod-live-$statKey'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      )
                      .tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: EditorStepperField(
                  key: ValueKey('value-$statKey'),
                  id: 'value-$statKey',
                  label: 'Valor',
                  value: score.value,
                  onChanged: (v) {
                    if (v != null) {
                      // El mod NO se recalcula solo (puede ser homebrew):
                      // "Usar estándar" lo alinea con el valor nuevo.
                      score.value = v;
                      onChanged();
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: ValueKey('mod-$statKey'),
                  controller: modController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Modificador',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) {
                    final parsed = int.tryParse(text);
                    if (parsed != null) {
                      score.mod = parsed;
                      onChanged();
                    }
                  },
                ),
              ),
            ],
          ),
          if (score.mod != standard)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: ValueKey('standard-$statKey'),
                onPressed: onApplyStandard,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                label: Text(
                  'Usar estándar (${standard >= 0 ? '+' : ''}$standard)',
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          EditorTextField(
            key: ValueKey('note-$statKey'),
            label: 'Nota / salvación',
            initialValue: score.description,
            hint: 'Ej: Salvación +5 (competente)',
            onChanged: (v) => score.description = v,
          ),
        ],
      ),
    );
  }
}
