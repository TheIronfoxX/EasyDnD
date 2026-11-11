// El editor manual de fichas por secciones (Etapa 4).
//
// Flujo: se edita sobre una COPIA de la ficha (o una ficha en blanco
// para el alta manual) y el roster no se toca hasta "Guardar". Ahí se
// valida con el MISMO CharacterValidator que la importación con IA y
// recién entonces se commitea — por índice si la ficha ya existía
// (replaceCharacter, sin duplicar) o como alta si no.
//
// Las secciones (datos, atributos, habilidades, inventario...) son
// páginas que el shell apila y que mutan el borrador EN EL LUGAR: no
// hay "guardar" por sección, hay UN commit al final. Salir con
// cambios sin guardar pide confirmación comparando el JSON del
// borrador contra el original — barato y sin flag "dirty" que
// mantener a mano.
//
// El estado de combate (PG actuales, recursos gastados, turno)
// sobrevive a la edición porque viaja serializado en la ficha: la
// copia lo conserva tal cual y los cambios que lo afectan lo
// mantienen coherente (ver setHpMax/setLevel/setSpeed del modelo).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/character_validator.dart';
import '../../domain/models/character.dart';
import '../../state/character_store.dart';
import 'editor_section_basic_info.dart';
import 'editor_section_skills.dart';
import 'editor_section_slots.dart';
import 'editor_section_stats.dart';

class CharacterEditorScreen extends StatefulWidget {
  const CharacterEditorScreen({super.key, this.character});

  /// La ficha a editar. Null = alta manual desde cero.
  final CharacterModel? character;

  @override
  State<CharacterEditorScreen> createState() => _CharacterEditorScreenState();
}

/// Una sección del editor: tile del menú + página que recibe el
/// borrador. Las secciones de las etapas 4b-4d se agregan a
/// [_sections] sin tocar nada más del shell.
class _SectionSpec {
  const _SectionSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String Function(CharacterModel draft) subtitle;
  final Widget Function(CharacterModel draft) page;
}

class _CharacterEditorScreenState extends State<CharacterEditorScreen> {
  late final CharacterModel _draft;
  late final String _originalJson;

  /// True después de un guardado exitoso: el PopScope deja pasar el
  /// pop sin pedir confirmación de descarte.
  bool _saved = false;

  static final List<_SectionSpec> _sections = [
    _SectionSpec(
      icon: Icons.badge_outlined,
      title: 'Datos básicos',
      subtitle: _basicInfoSubtitle,
      page: (draft) => EditorSectionBasicInfo(draft: draft),
    ),
    _SectionSpec(
      icon: Icons.fitness_center_rounded,
      title: 'Atributos',
      subtitle: _statsSubtitle,
      page: (draft) => EditorSectionStats(draft: draft),
    ),
    _SectionSpec(
      icon: Icons.workspace_premium_rounded,
      title: 'Competencias',
      subtitle: _skillsSubtitle,
      page: (draft) => EditorSectionSkills(draft: draft),
    ),
    _SectionSpec(
      icon: Icons.layers_rounded,
      title: 'Ranuras de conjuro',
      subtitle: _slotsSubtitle,
      page: (draft) => EditorSectionSlots(draft: draft),
    ),
    // 4c: habilidades por economía de acciones.
    // 4d: recursos, inventario, lore y compañeros.
  ];

  static String _basicInfoSubtitle(CharacterModel draft) {
    final basic = draft.basicInfo;
    final clase =
        basic.characterClass.isEmpty ? 'sin clase' : basic.characterClass;
    return 'Nivel ${basic.level} · ${basic.hpMax} PG · CA ${basic.ac} · $clase';
  }

  /// "STR 16 · DEX 12 · ..." — las siglas del shape tal cual las lee
  /// la gente de D&D; los valores sin mods para que quepa en un tile.
  static String _statsSubtitle(CharacterModel draft) {
    const keys = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];
    final scores = draft.stats.asList;
    return [
      for (var i = 0; i < keys.length; i++) '${keys[i]} ${scores[i].value}',
    ].join(' · ');
  }

  static String _skillsSubtitle(CharacterModel draft) {
    final count = draft.skills.length;
    if (count == 0) return 'sin competencias';
    return count == 1 ? '1 competencia' : '$count competencias';
  }

  static String _slotsSubtitle(CharacterModel draft) {
    final slots = draft.spellSlots.slots;
    if (slots.isEmpty) return 'no lanza conjuros';
    return [
      for (final slot in slots) '${slot.max} de nivel ${slot.level}',
    ].join(' · ');
  }

  @override
  void initState() {
    super.initState();
    _draft = widget.character?.copy() ?? CharacterModel.blank();
    _originalJson = jsonEncode(_draft.toJson());
  }

  bool get _hasChanges => jsonEncode(_draft.toJson()) != _originalJson;

  // -------------------------------------------------------------------
  // ACCIONES
  // -------------------------------------------------------------------

  Future<void> _openSection(_SectionSpec section) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => section.page(_draft)),
    );
    // Al volver: los contadores de los tiles pueden haber cambiado.
    if (mounted) setState(() {});
  }

  Future<void> _confirmDiscardAndPop() async {
    if (!_hasChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Descartar los cambios?'),
        content: const Text(
          'Esta ficha tiene cambios sin guardar. Si salís ahora, se pierden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir editando'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _save() async {
    // Se captura antes de los awaits: después de los diálogos el
    // contexto podría ya no estar montado.
    final store = context.read<CharacterStore>();

    final result = CharacterValidator.validateMap(_draft.toJson());

    // Errores bloqueantes (en la práctica: nombre vacío): no entra nada.
    if (!result.isOk) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('La ficha no se puede guardar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final error in result.errors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${error.field} — ${error.message}'),
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Corregir'),
            ),
          ],
        ),
      );
      return;
    }

    // Avisos: no bloquean (mismo criterio permisivo que el wizard de
    // importación), pero se listan antes de dejarlos pasar.
    final warnings = result.warnings;
    if (warnings.isNotEmpty) {
      final goOn = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Hay ${warnings.length} avisos'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final warning in warnings)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(warning.field,
                        style: const TextStyle(fontFamily: 'monospace')),
                    subtitle: Text(warning.message),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Seguir editando'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Guardar igual'),
            ),
          ],
        ),
      );
      if (goOn != true) return;
    }

    final character = result.character!;
    final index = store.roster.indexWhere((c) => c.id == character.id);
    if (index >= 0) {
      store.replaceCharacter(index, character);
    } else {
      // Alta manual — o la ficha se borró del roster mientras el
      // editor estaba abierto: entra como nueva en vez de perderla.
      store.addCharacter(character);
    }

    if (mounted) {
      setState(() => _saved = true);
      Navigator.of(context).pop(true);
    }
  }

  // -------------------------------------------------------------------
  // LAYOUT
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.character == null;

    return PopScope(
      // Mientras no se guardó, todo pop (botón atrás, gesto, cierre)
      // pasa por la confirmación de descarte.
      canPop: _saved,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return; // ya salió: save o sin cambios.
        _confirmDiscardAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isNew
              ? 'Nueva ficha'
              : 'Editar a ${widget.character!.basicInfo.name}'),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final section in _sections)
              ListTile(
                leading: Icon(section.icon),
                title: Text(section.title),
                subtitle: Text(section.subtitle(_draft)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openSection(section),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(isNew ? 'Crear ficha' : 'Guardar cambios'),
              ),
              const SizedBox(height: 6),
              Text(
                'Los cambios viven en el borrador hasta que guardes.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
