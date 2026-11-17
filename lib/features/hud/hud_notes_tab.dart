// Pestaña Notas: diario por sesiones de la ficha activa.
//
// Lista de entradas fechadas (la más reciente primero). Crear, editar y
// borrar pasan por el store; ningún color propio, todo del tema.

import 'package:flutter/material.dart';
import '../../core/ui/app_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/models/character.dart';
import '../../domain/models/session_note.dart';
import '../../state/character_store.dart';
import 'hud_widgets.dart';

class HudNotesTab extends StatelessWidget {
  const HudNotesTab({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CharacterStore>();
    final notes = [...character.sessionNotes]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            96, // deja sitio al botón flotante
          ),
          children: [
            HudSectionCard(
              icon: AppIcons.of(context).notes,
              title: 'Diario de sesiones',
              child: notes.isEmpty
                  ? const HudEmptyHint(
                      'Todavía no hay notas. Toca "Nueva nota" para anotar '
                      'lo que pasó en la sesión.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final note in notes)
                          _NoteTile(
                            note: note,
                            onEdit: () => _edit(context, store, note),
                            onDelete: () => _delete(context, store, note),
                          ),
                      ],
                    ),
            ),
          ],
        ),
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: FloatingActionButton.extended(
            key: const ValueKey('add-note'),
            heroTag: null,
            onPressed: () => _edit(context, store, null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva nota'),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    CharacterStore store,
    SessionNote? note,
  ) async {
    final result = await showDialog<({String title, String body})>(
      context: context,
      builder: (_) => _NoteDialog(note: note),
    );
    if (result == null) return;
    if (note == null) {
      store.addSessionNote(title: result.title, body: result.body);
    } else {
      store.updateSessionNote(note.id, title: result.title, body: result.body);
    }
  }

  Future<void> _delete(
    BuildContext context,
    CharacterStore store,
    SessionNote note,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar nota'),
        content: Text(
          '¿Eliminar "${note.title.isEmpty ? 'Sin título' : note.title}"? '
          'No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-note'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) store.deleteSessionNote(note.id);
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final SessionNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('note-${note.id}'),
      contentPadding: EdgeInsets.zero,
      onTap: onEdit,
      title: Text(
        note.title.isEmpty ? 'Sin título' : note.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _date(note.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (note.body.isNotEmpty)
            Text(note.body, maxLines: 4, overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: IconButton(
        tooltip: 'Eliminar nota',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: onDelete,
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({this.note});

  final SessionNote? note;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = TextEditingController(text: widget.note?.body ?? '');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? 'Nueva nota' : 'Editar nota'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('note-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('note-body'),
              controller: _body,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('save-note'),
          onPressed: () =>
              Navigator.pop(context, (title: _title.text, body: _body.text)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
