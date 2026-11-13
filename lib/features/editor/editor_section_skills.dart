// Sección "Competencias" del editor: las skills con su modificador
// FINAL (Atletismo +5, Arcanos +7...).
//
// El modificador no se recalcula desde relatedStat + bono de
// competencia: la ficha es la fuente de verdad (mismo criterio que la
// app vieja — no trae la tabla de competencias de cada clase).
// relatedStat solo agrupa visualmente; si sube un atributo, el
// modificador se actualiza a mano.
//
// Patrón de la lista: tap en el ítem abre el diálogo de edición, la
// basura borra directo SIN confirmar (el borrador del editor cubre el
// arrepentimiento: descartás y volvés al original) y el FAB agrega.

import 'package:flutter/material.dart';

import '../../domain/models/character.dart';
import '../../domain/models/stats.dart';
import 'editor_fields.dart';
import '../../core/theme/design_tokens.dart';

class EditorSectionSkills extends StatefulWidget {
  const EditorSectionSkills({super.key, required this.draft});

  final CharacterModel draft;

  @override
  State<EditorSectionSkills> createState() => _EditorSectionSkillsState();
}

class _EditorSectionSkillsState extends State<EditorSectionSkills> {
  /// Abre el diálogo de alta/edición. Cancelar no toca el borrador:
  /// el diálogo arma una Skill nueva y recién al confirmar la página
  /// la inserta o reemplaza.
  Future<void> _edit({int? index}) async {
    final skills = widget.draft.skills;
    final result = await showDialog<Skill>(
      context: context,
      builder: (_) =>
          _SkillDialog(initial: index == null ? null : skills[index]),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        skills.add(result);
      } else {
        skills[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final skills = widget.draft.skills;

    return EditorSectionScaffold(
      title: 'Competencias',
      help:
          'El modificador final de cada competencia, tal como lo usa '
          'el HUD. No se recalcula solo: si cambia un atributo o el '
          'bono de competencia, actualizalo a mano.',
      onAdd: () => _edit(),
      addLabel: 'Agregar competencia',
      children: [
        if (skills.isEmpty)
          const EditorEmptyHint('Todavía no hay competencias en la ficha.'),
        for (var i = 0; i < skills.length; i++)
          ListTile(
            leading: _StatBadge(skill: skills[i]),
            title: Text(skills[i].name),
            subtitle: Text(_subtitleFor(skills[i])),
            trailing: IconButton(
              tooltip: 'Borrar competencia',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => setState(() => widget.draft.skills.removeAt(i)),
            ),
            onTap: () => _edit(index: i),
          ),
      ],
    );
  }

  /// "Sabiduría · +7" cuando el stat es conocido (el shape permite
  /// relatedStat raro en fichas viejas: mejor mostrarlo crudo).
  static String _subtitleFor(Skill skill) {
    final label = kStatLabels[skill.relatedStat];
    if (label == null) return skill.modifierFormatted;
    return '$label · ${skill.modifierFormatted}';
  }
}

/// Chip con la sigla del atributo relacionado (STR, DEX...). Es la
/// clave del shape en mayúsculas, así que una ficha vieja con un stat
/// raro muestra lo que trajo sin romperse.
class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      maxRadius: 16,
      backgroundColor: theme.colorScheme.secondaryContainer,
      foregroundColor: theme.colorScheme.onSecondaryContainer,
      child: Text(
        skill.relatedStat.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Diálogo de alta/edición de una competencia. Retorna la Skill lista
/// para insertar, o null si se canceló — nunca muta el borrador, así
/// cancelar no deja items fantasma a mitad de carga.
class _SkillDialog extends StatefulWidget {
  const _SkillDialog({this.initial});

  /// Null = alta nueva.
  final Skill? initial;

  @override
  State<_SkillDialog> createState() => _SkillDialogState();
}

class _SkillDialogState extends State<_SkillDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name = widget.initial?.name ?? '';
  late String _relatedStat = widget.initial?.relatedStat ?? '';
  late int _modifier = widget.initial?.modifier ?? 0;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Skill(name: _name.trim(), relatedStat: _relatedStat, modifier: _modifier),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Nueva competencia' : 'Editar competencia',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _name = value,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Poné un nombre.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              // Valor inicial vacío (ficha vieja sin related_stat):
              // arranca sin selección y el validator exige elegir.
              initialValue: kStatLabels.containsKey(_relatedStat)
                  ? _relatedStat
                  : null,
              items: [
                for (final entry in kStatLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              decoration: const InputDecoration(
                labelText: 'Atributo',
                hintText: 'Elegí un atributo',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null ? 'Elegí a qué atributo se agarra.' : null,
              onChanged: (value) => setState(() => _relatedStat = value ?? ''),
            ),
            const SizedBox(height: AppSpacing.md),
            EditorIntField(
              label: 'Modificador',
              value: _modifier,
              allowNegative: true,
              onChanged: (value) {
                if (value != null) _modifier = value;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
