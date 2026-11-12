// Sección "Historia y personalidad" del editor: los cinco campos
// narrativos clásicos de ficha (trasfondo, rasgos, ideales, vínculos y
// defectos). Son texto libre y de sola lectura en el HUD: acá se
// completan o se corrigen a mano.
//
// No se tocan las notas de IA (ai_tips) ni el códice del jugador
// (user_tactics / adventure_notes): son contenido del HUD/diario, no
// identidad de la ficha.

import 'package:flutter/material.dart';

import '../../domain/models/character.dart';
import 'editor_fields.dart';

class EditorSectionLore extends StatelessWidget {
  const EditorSectionLore({super.key, required this.draft});

  final CharacterModel draft;

  @override
  Widget build(BuildContext context) {
    final lore = draft.loreInfo;

    return EditorSectionScaffold(
      title: 'Historia y personalidad',
      help:
          'Los cinco campos narrativos de la ficha. El HUD los muestra '
          'de sola lectura; completalos con tus palabras.',
      children: [
        EditorTextField(
          label: 'Trasfondo',
          initialValue: lore.backstory,
          hint: 'De dónde viene y qué lo trajo hasta acá',
          maxLines: 4,
          minLines: 3,
          onChanged: (value) => lore.backstory = value,
        ),
        EditorTextField(
          label: 'Rasgos de personalidad',
          initialValue: lore.personalityTraits,
          hint: 'Cómo se comporta, qué gestos o frases lo delatan',
          maxLines: 4,
          minLines: 3,
          onChanged: (value) => lore.personalityTraits = value,
        ),
        EditorTextField(
          label: 'Ideales',
          initialValue: lore.ideals,
          hint: 'Lo que defiende incluso cuando le cuesta',
          maxLines: 4,
          minLines: 3,
          onChanged: (value) => lore.ideals = value,
        ),
        EditorTextField(
          label: 'Vínculos',
          initialValue: lore.bonds,
          hint: 'Personas, lugares o promesas que lo atan al mundo',
          maxLines: 4,
          minLines: 3,
          onChanged: (value) => lore.bonds = value,
        ),
        EditorTextField(
          label: 'Defectos',
          initialValue: lore.flaws,
          hint: 'La grieta que lo mete en problemas',
          maxLines: 4,
          minLines: 3,
          onChanged: (value) => lore.flaws = value,
        ),
      ],
    );
  }
}
