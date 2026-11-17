import 'dart:convert';
import 'package:flutter/services.dart';

import '../domain/models/srd_class.dart';
import '../domain/models/srd_spell.dart' show normalizeSpellName;

export '../domain/models/srd_class.dart';

/// Repositorio de clases del catálogo local offline.
abstract final class ClassCatalog {
  static List<SrdClass>? _cached;

  /// Carga el catálogo JSON de assets (o usa la lista en caché si ya se cargó).
  static Future<List<SrdClass>> load([AssetBundle? bundle]) async {
    if (_cached != null) return _cached!;
    try {
      final jsonStr = await (bundle ?? rootBundle).loadString(
        'assets/srd/classes_5e.json',
      );
      _cached = parse(jsonStr);
    } catch (_) {
      _cached = const [];
    }
    return _cached!;
  }

  /// Construye el catálogo desde un String JSON (útil para tests).
  static List<SrdClass> parse(String jsonStr) =>
      (jsonDecode(jsonStr) as List<dynamic>)
          .map((e) => SrdClass.fromJson(e as Map<String, dynamic>))
          .toList();

  /// Busca por id o nombre (sin tildes ni mayúsculas). Null si no existe.
  static SrdClass? byIdOrName(List<SrdClass> all, String key) {
    final k = normalizeSpellName(key);
    for (final c in all) {
      if (normalizeSpellName(c.id) == k || normalizeSpellName(c.name) == k) {
        return c;
      }
    }
    return null;
  }

  /// Filtra por texto y/o tipo de lanzamiento ('full', 'half', 'third', 'pact', 'none').
  static List<SrdClass> search(
    List<SrdClass> all, {
    String query = '',
    String? spellcastingType,
  }) {
    final q = normalizeSpellName(query);
    return all.where((c) {
      if (spellcastingType != null && c.spellcastingType != spellcastingType) {
        return false;
      }
      return q.isEmpty || normalizeSpellName(c.name).contains(q);
    }).toList();
  }

  /// Limpia la caché (útil para tests).
  static void clearCache() => _cached = null;
}
