// Sección "Datos básicos" del editor: identidad y números defensivos
// de la ficha (nombre, raza, clase, nivel, PG máx, CA, velocidad, CD
// de salvación y el enlace de Nivel20).
//
// Lo que NO se edita acá a propósito:
// - PG actuales / dados de golpe gastados / movimiento del turno:
//   estado de COMBATE que administra el HUD (Etapa 5). Igual los
//   cambios acá los mantienen coherentes (ver setHpMax/setLevel/
//   setSpeed del modelo).
// - hit_die_sides: se infiere de la clase (DndRules), tocarlo a mano
//   sería invitar a errores; si la clase es homebrew rara, el valor
//   correcto llega igual desde la importación con IA.
//
// Cada cambio se aplica al borrador al toque (no hay botón "listo"
// por sección: el commit a la ficha real es el "Guardar" del editor).

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/ui/character_avatar.dart';
import '../../domain/models/character.dart';
import 'editor_fields.dart';

class EditorSectionBasicInfo extends StatefulWidget {
  const EditorSectionBasicInfo({super.key, required this.draft});

  /// El borrador compartido del editor: se muta en el lugar.
  final CharacterModel draft;

  @override
  State<EditorSectionBasicInfo> createState() => _EditorSectionBasicInfoState();
}

class _EditorSectionBasicInfoState extends State<EditorSectionBasicInfo> {
  @override
  Widget build(BuildContext context) {
    final basic = widget.draft.basicInfo;

    return EditorSectionScaffold(
      title: 'Datos básicos',
      help: 'Identidad y números defensivos. Si bajás el tope de PG o '
          'la velocidad, el estado de combate actual se recorta para '
          'quedar coherente (nunca al revés).',
      children: [
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CharacterAvatar(
                avatarPath: widget.draft.avatarPath,
                name: basic.name,
                size: 84,
                onTap: () => AvatarPickerHelper.showAvatarOptions(
                  context,
                  currentPath: widget.draft.avatarPath,
                  onSelected: (newPath) {
                    setState(() => widget.draft.avatarPath = newPath);
                  },
                ),
              ),
              IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        EditorTextField(
          label: 'Nombre',
          initialValue: basic.name,
          onChanged: (value) => basic.name = value,
        ),
        EditorTextField(
          label: 'Raza',
          initialValue: basic.race,
          onChanged: (value) => basic.race = value,
        ),
        EditorTextField(
          label: 'Clase',
          initialValue: basic.characterClass,
          hint: 'Ej: Artillero 6 (con el nivel pegado también vale)',
          onChanged: (value) => basic.characterClass = value,
        ),
        EditorIntField(
          label: 'Nivel',
          value: basic.level,
          onChanged: (value) {
            if (value != null) basic.setLevel(value);
          },
        ),
        EditorIntField(
          label: 'PG máximos',
          value: basic.hpMax,
          onChanged: (value) {
            if (value != null) basic.setHpMax(value);
          },
        ),
        EditorIntField(
          label: 'CA',
          value: basic.ac,
          onChanged: (value) => basic.ac = value ?? basic.ac,
        ),
        EditorIntField(
          label: 'Velocidad (pies por turno)',
          value: basic.speed,
          onChanged: (value) {
            if (value != null) widget.draft.setSpeed(value);
          },
        ),
        EditorIntField(
          label: 'CD de salvación',
          value: basic.spellSaveDc,
          allowEmpty: true,
          hint: 'Dejalo vacío si no lanza conjuros',
          onChanged: (value) => basic.spellSaveDc = value,
        ),
        EditorTextField(
          label: 'Enlace de Nivel20',
          initialValue: basic.nivel20Link ?? '',
          hint: 'https://nivel20.com/games/.../characters/...',
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: (value) =>
              basic.nivel20Link = value.trim().isEmpty ? null : value,
        ),
      ],
    );
  }
}
