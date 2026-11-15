// Asistente guiado de creación de personajes en 5 pasos:
//
//   1. Identidad   — nombre, nivel, clase, raza, velocidad, trasfondo.
//   2. Atributos   — método, bonos raciales, totales.
//   3. Competencias — habilidades, PG, resumen vital.
//   4. Equipo      — armas, armaduras y conjuros del SRD.
//   5. Revisión    — vista previa (compartida con la importación) y alta.
//
// Todo el estado vive en CreationDraftController, que sobrevive a los
// cambios de paso: "Atrás" y "Adelante" no pierden ninguna selección.
// El roster solo se muta al confirmar el último paso.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/class_catalog.dart';
import '../../data/equipment_catalog.dart';
import '../../data/spell_catalog.dart';
import '../../state/character_store.dart';
import '../import/import_wizard_screen.dart' show WizardStepIndicator;
import '../import/wizard_step_preview.dart';
import 'creation_draft_controller.dart';
import 'creation_step_abilities.dart';
import 'creation_step_equipment.dart';
import 'creation_step_identity.dart';
import 'creation_step_proficiencies.dart';

class CharacterCreationWizardScreen extends StatefulWidget {
  const CharacterCreationWizardScreen({super.key});

  @override
  State<CharacterCreationWizardScreen> createState() => _CharacterCreationWizardScreenState();
}

class _CharacterCreationWizardScreenState extends State<CharacterCreationWizardScreen> {
  static const _labels = ['Identidad', 'Atributos', 'Competencias', 'Equipo', 'Revisión'];

  final CreationDraftController _draft = CreationDraftController();
  int _step = 0;

  List<SrdClass>? _classes;
  List<SrdWeapon> _weapons = const [];
  List<SrdArmor> _armors = const [];
  List<SrdSpell> _spells = const [];

  CharacterPreview? _preview;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    final classes = await ClassCatalog.load();
    final weapons = await EquipmentCatalog.loadWeapons();
    final armors = await EquipmentCatalog.loadArmors();
    final spells = await SpellCatalog.load();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _weapons = weapons;
      _armors = armors;
      _spells = spells;
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  /// Qué falta para salir del paso actual (null = se puede continuar).
  String? _blocker() {
    switch (_step) {
      case 0:
        if (_draft.name.trim().isEmpty) return 'Escribe el nombre del personaje.';
        if (_draft.srdClass == null) return 'Elige una clase.';
      case 2:
        final left = _draft.skillChoicesLeft;
        if (left > 0) return 'Elige $left habilidad${left == 1 ? '' : 'es'} más.';
    }
    return null;
  }

  void _next() {
    if (_blocker() != null) return;
    if (_step == 3) {
      try {
        _preview = _draft.buildPreview();
        _previewError = null;
      } on CharacterCreationException catch (e) {
        _preview = null;
        _previewError = e.problems.join('\n');
      }
    }
    setState(() => _step++);
  }

  void _confirm() {
    final preview = _preview;
    if (preview == null) return;
    context.read<CharacterStore>().addCharacter(preview.character);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final classes = _classes;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear personaje')),
      body: classes == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: _draft,
              builder: (context, _) => Column(
                children: [
                  WizardStepIndicator(current: _step, labels: _labels),
                  const Divider(height: 1),
                  Expanded(child: _buildStep(classes)),
                  const Divider(height: 1),
                  _bottomBar(context),
                ],
              ),
            ),
    );
  }

  Widget _buildStep(List<SrdClass> classes) {
    switch (_step) {
      case 0:
        return CreationStepIdentity(draft: _draft, classes: classes);
      case 1:
        return CreationStepAbilities(draft: _draft);
      case 2:
        return CreationStepProficiencies(draft: _draft);
      case 3:
        return CreationStepEquipment(
          draft: _draft,
          weapons: _weapons,
          armors: _armors,
          spells: _spells,
        );
      default:
        final preview = _preview;
        if (preview == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                _previewError ?? 'No se pudo generar la ficha.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
        return WizardStepPreview(
          key: const ValueKey('creation-step-preview'),
          result: preview.validationResult,
          isReplace: false,
          onConfirm: _confirm,
        );
    }
  }

  Widget _bottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final blocker = _blocker();
    final isLast = _step == _labels.length - 1;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (blocker != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                blocker,
                key: const Key('creation-blocker'),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          Row(
            children: [
              if (_step > 0)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: OutlinedButton(
                    key: const Key('creation-back'),
                    onPressed: () => setState(() => _step--),
                    child: const Text('Atrás'),
                  ),
                ),
              Expanded(
                child: isLast
                    ? FilledButton.icon(
                        key: const Key('creation-confirm'),
                        onPressed: _preview == null ? null : _confirm,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Crear personaje'),
                      )
                    : FilledButton(
                        key: const Key('creation-next'),
                        onPressed: blocker == null ? _next : null,
                        child: const Text('Continuar'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
