// Exportar / copiar / importar fichas y respaldo del roster (Ajustes).
//
// La pantalla resuelve los plugins (file_picker, portapapeles) y le pasa
// al store valores ya resueltos: el store nunca toca plugins.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/character.dart';
import '../../domain/roster_backup.dart';
import '../../state/character_store.dart';
import 'file_save_stub.dart' if (dart.library.js_interop) 'file_save_web.dart';

/// Nombre de archivo seguro a partir del nombre del personaje.
String backupFileName(String base) {
  final clean = base
      .trim()
      .replaceAll(RegExp(r'[^\wáéíóúüñÁÉÍÓÚÜÑ-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return clean.isEmpty ? 'ficha' : clean;
}

Future<void> exportCharacterFile(
  BuildContext context,
  CharacterModel character,
) {
  return _saveText(
    context,
    text: RosterBackup.encodeCharacter(character),
    fileName: '${backupFileName(character.basicInfo.name)}.json',
    done: 'Ficha de ${character.basicInfo.name} exportada.',
  );
}

Future<void> exportRosterBackup(
  BuildContext context,
  List<CharacterModel> roster,
) {
  return _saveText(
    context,
    text: RosterBackup.encodeBackup(roster),
    fileName: 'easydnd_respaldo.json',
    done: 'Respaldo de ${roster.length} fichas exportado.',
  );
}

/// Copia la ficha al portapapeles: alternativa sin archivos.
Future<void> copyCharacterToClipboard(
  BuildContext context,
  CharacterModel character,
) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(
    ClipboardData(text: RosterBackup.encodeCharacter(character)),
  );
  messenger.showSnackBar(
    const SnackBar(content: Text('Ficha copiada al portapapeles.')),
  );
}

Future<void> _saveText(
  BuildContext context, {
  required String text,
  required String fileName,
  required String done,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (kIsWeb) {
      // Chrome: descarga directa (ver file_save_web.dart).
      await saveTextFile(text, fileName);
      messenger.showSnackBar(SnackBar(content: Text(done)));
      return;
    }
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Guardar',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
    // null = el jugador cerró el selector: sin aviso.
    if (saved == null) return;
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } catch (e) {
    // El JSON no se pierde: queda en el portapapeles, y el error real se
    // muestra para poder saber por qué falló el archivo.
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          'No se pudo guardar el archivo ($e). El JSON quedó copiado al '
          'portapapeles.',
        ),
      ),
    );
  }
}

/// Elige un .json y lo importa: respaldo (varias fichas) o ficha suelta.
Future<void> importFromFile(BuildContext context, CharacterStore store) async {
  final messenger = ScaffoldMessenger.of(context);
  String text;
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    text = utf8.decode(bytes);
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo leer el archivo elegido.')),
    );
    return;
  }
  if (!context.mounted) return;

  if (RosterBackup.looksLikeBackup(text)) {
    final parsed = RosterBackup.parseBackup(text);
    if (!parsed.isOk) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(parsed.fatalError ?? 'El respaldo no trae fichas.'),
        ),
      );
      return;
    }
    final choice = await _askBackupMode(context, parsed);
    if (choice == null) return;
    final n = store.importBackup(parsed.characters, replace: choice);
    messenger.showSnackBar(SnackBar(content: Text('$n fichas importadas.')));
    return;
  }

  final result = store.importCharacterFromText(text);
  if (result.isOk) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Ficha de ${result.character!.basicInfo.name} importada.',
        ),
      ),
    );
  } else {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.errors.isEmpty
              ? 'No se pudo importar la ficha.'
              : result.errors.first.message,
        ),
      ),
    );
  }
}

/// true = reemplazar todo, false = añadir, null = cancelar.
Future<bool?> _askBackupMode(BuildContext context, BackupParseResult parsed) {
  final theme = Theme.of(context);
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Importar respaldo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${parsed.characters.length} fichas listas'
              '${parsed.skipped > 0 ? ' (${parsed.skipped} omitidas)' : ''}.',
            ),
            for (final m in parsed.messages.take(8))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(m, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const ValueKey('backup-replace'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Reemplazar todo'),
        ),
        FilledButton(
          key: const ValueKey('backup-add'),
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Añadir'),
        ),
      ],
    ),
  );
}
