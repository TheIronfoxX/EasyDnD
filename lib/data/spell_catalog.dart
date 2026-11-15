import 'dart:convert';
import 'package:flutter/services.dart';

import '../domain/models/srd_spell.dart';

export '../domain/models/srd_spell.dart';

/// Repositorio de conjuros del catálogo local offline.
abstract final class SpellCatalog {
  static List<SrdSpell>? _cached;

  /// Carga el catálogo JSON de assets (o usa la lista en caché si ya se cargó).
  static Future<List<SrdSpell>> load([AssetBundle? bundle]) async {
    if (_cached != null) return _cached!;

    final actualBundle = bundle ?? rootBundle;
    try {
      final jsonStr = await actualBundle.loadString(
        'assets/srd/spells_5e.json',
      );
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _cached = list
          .map((e) => SrdSpell.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _cached = const [];
    }
    return _cached!;
  }

  /// Filtra los conjuros cargados por texto y/o nivel.
  static List<SrdSpell> search(
    List<SrdSpell> all, {
    String query = '',
    int? level,
  }) {
    final cleanQuery = _normalize(query);
    return all.where((spell) {
      if (level != null && spell.level != level) return false;
      if (cleanQuery.isEmpty) return true;

      final nameMatch = _normalize(spell.name).contains(cleanQuery);
      final englishMatch = _normalize(spell.englishName).contains(cleanQuery);
      final schoolMatch = _normalize(spell.school).contains(cleanQuery);
      return nameMatch || englishMatch || schoolMatch;
    }).toList();
  }

  /// Conjuros de la lista de una clase (por id, ej. `mago`). Usa [all] o,
  /// si falta, el catálogo ya cargado en caché.
  static List<SrdSpell> forClass(String classId, [List<SrdSpell>? all]) {
    final id = _normalize(classId);
    return (all ?? _cached ?? const <SrdSpell>[])
        .where((s) => s.classes.any((c) => _normalize(c) == id))
        .toList();
  }

  static String _normalize(String input) => normalizeSpellName(input);

  /// Limpia la caché (útil para tests).
  static void clearCache() {
    _cached = null;
  }
}
