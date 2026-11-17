// Respaldo y exportación de fichas (Dart puro, sin Flutter).
//
// Formatos:
// - Ficha suelta: el JSON de CharacterModel tal cual (lo que ya entiende
//   CharacterValidator), solo que sin rutas de avatar.
// - Respaldo del roster: { "easydnd_backup": 1, "characters": [ ... ] }.
//
// Las rutas de avatar (`avatar_path`, `lore_avatar_path`) son locales al
// dispositivo: en otro teléfono apuntarían a la nada, así que se vacían
// al exportar.

import 'dart:convert';

import '../core/json_sanitizer.dart';
import 'character_validator.dart';
import 'models/character.dart';

/// Versión del formato de respaldo. Sube solo ante cambios incompatibles.
const int kBackupFormatVersion = 1;

/// Resultado de leer un respaldo: las fichas válidas más un informe por
/// cada ficha rechazada o con avisos, para mostrar al jugador.
class BackupParseResult {
  final List<CharacterModel> characters;

  /// Mensajes legibles ("Ficha 2: ...") de errores y avisos.
  final List<String> messages;

  /// Cantidad de entradas del respaldo que no se pudieron leer.
  final int skipped;

  /// Error global (JSON roto, no es un respaldo). Con esto no hay fichas.
  final String? fatalError;

  const BackupParseResult({
    required this.characters,
    required this.messages,
    required this.skipped,
    this.fatalError,
  });

  bool get isOk => fatalError == null && characters.isNotEmpty;
}

class RosterBackup {
  RosterBackup._();

  /// JSON de una ficha lista para compartir (sin avatares locales).
  static Map<String, dynamic> characterToExportMap(CharacterModel c) {
    final map = Map<String, dynamic>.from(c.toJson());
    map['avatar_path'] = null;
    map['lore_avatar_path'] = null;
    return map;
  }

  static String encodeCharacter(CharacterModel c) =>
      const JsonEncoder.withIndent('  ').convert(characterToExportMap(c));

  static String encodeBackup(List<CharacterModel> characters) {
    return const JsonEncoder.withIndent('  ').convert({
      'easydnd_backup': kBackupFormatVersion,
      'characters': characters.map(characterToExportMap).toList(),
    });
  }

  /// ¿El texto parece un respaldo (y no una ficha suelta)? Barato: sirve
  /// para decidir qué flujo de importación usar.
  static bool looksLikeBackup(String rawText) {
    final decoded = _decode(rawText);
    return decoded is Map && decoded.containsKey('easydnd_backup');
  }

  /// Lee un respaldo. Cada ficha pasa por el validador normal, así que
  /// una entrada corrupta se salta sin tirar abajo al resto.
  static BackupParseResult parseBackup(String rawText) {
    final decoded = _decode(rawText);
    if (decoded == null) {
      return const BackupParseResult(
        characters: [],
        messages: [],
        skipped: 0,
        fatalError: 'El texto no contiene un JSON válido.',
      );
    }
    if (decoded is! Map || decoded['easydnd_backup'] is! num) {
      return const BackupParseResult(
        characters: [],
        messages: [],
        skipped: 0,
        fatalError: 'El archivo no es un respaldo de EasyDnD.',
      );
    }
    final list = decoded['characters'];
    if (list is! List) {
      return const BackupParseResult(
        characters: [],
        messages: [],
        skipped: 0,
        fatalError: 'El respaldo no trae la lista "characters".',
      );
    }

    final characters = <CharacterModel>[];
    final messages = <String>[];
    var skipped = 0;
    for (var i = 0; i < list.length; i++) {
      final entry = list[i];
      if (entry is! Map) {
        skipped++;
        messages.add('Ficha ${i + 1}: entrada no válida, omitida.');
        continue;
      }
      final result = CharacterValidator.validateMap(
        normalizeCharacterJson(entry.cast<String, dynamic>()),
      );
      if (!result.isOk) {
        skipped++;
        final reason = result.errors.isEmpty
            ? 'ficha inválida'
            : result.errors.first.message;
        messages.add('Ficha ${i + 1}: omitida ($reason)');
        continue;
      }
      characters.add(result.character!);
      for (final w in result.warnings) {
        messages.add(
          'Ficha ${i + 1} (${result.character!.basicInfo.name}): '
          '${w.message}',
        );
      }
    }
    return BackupParseResult(
      characters: characters,
      messages: messages,
      skipped: skipped,
    );
  }

  static dynamic _decode(String rawText) {
    try {
      return jsonDecode(sanitizeJsonText(rawText));
    } on FormatException {
      return null;
    }
  }
}
