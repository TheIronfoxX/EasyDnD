// Taller de calibración de fichas: el editor manual en 4 pestañas
// (Núcleo, Arsenal, Grimorio y Mochila).
//
// Flujo: se edita sobre una COPIA de la ficha (o una ficha en blanco
// para el alta manual) y el roster no se toca hasta "Guardar". Ahí se
// valida con el MISMO CharacterValidator que la importación con IA y
// recién entonces se commitea — por índice si la ficha ya existía
// (replaceCharacter, sin duplicar) o como alta si no.
//
// Las pestañas mutan el borrador EN EL LUGAR: no hay "guardar" por
// pestaña, hay UN commit al final. Salir con
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
import '../../core/theme/app_fonts.dart';
import 'editor_tab_arsenal.dart';
import 'editor_tab_core.dart';
import 'editor_tab_grimorio.dart';
import 'editor_tab_mochila.dart';
import '../../core/theme/design_tokens.dart';

class CharacterEditorScreen extends StatefulWidget {
  const CharacterEditorScreen({super.key, this.character});

  /// La ficha a editar. Null = alta manual desde cero.
  final CharacterModel? character;

  @override
  State<CharacterEditorScreen> createState() => _CharacterEditorScreenState();
}

class _CharacterEditorScreenState extends State<CharacterEditorScreen> {
  late final CharacterModel _draft;
  late final String _originalJson;

  /// True después de un guardado exitoso: el PopScope deja pasar el
  /// pop sin pedir confirmación de descarte.
  bool _saved = false;

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

  /// Las pestañas avisan cuando algo cambió para refrescar el shell.
  void _onDraftChanged() {
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
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
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
                    title: Text(
                      warning.field,
                      style: const TextStyle(
                        fontFamily: AppFonts.jetBrainsMono,
                      ),
                    ),
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
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              isNew
                  ? 'Nueva ficha'
                  : 'Editar a ${widget.character!.basicInfo.name}',
            ),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Núcleo'),
                Tab(text: 'Arsenal'),
                Tab(text: 'Grimorio'),
                Tab(text: 'Mochila'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _KeepAlive(
                child: EditorTabCore(draft: _draft, onChanged: _onDraftChanged),
              ),
              _KeepAlive(
                child: EditorTabArsenal(
                  draft: _draft,
                  onChanged: _onDraftChanged,
                ),
              ),
              _KeepAlive(
                child: EditorTabGrimorio(
                  draft: _draft,
                  onChanged: _onDraftChanged,
                ),
              ),
              _KeepAlive(
                child: EditorTabMochila(
                  draft: _draft,
                  onChanged: _onDraftChanged,
                ),
              ),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.colorScheme.outline)),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
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
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mantiene vivo el estado de una pestaña al cambiar de una a otra: así
/// no se pierde el scroll ni lo tipeado en campos con estado propio.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
