import 'dart:convert';
import 'package:flutter/services.dart';

import '../domain/models/srd_equipment.dart';
import '../domain/models/srd_spell.dart' show normalizeSpellName;

export '../domain/models/srd_equipment.dart';

/// Repositorio de armas y armaduras del catálogo local offline.
abstract final class EquipmentCatalog {
  static List<SrdWeapon>? _weapons;
  static List<SrdArmor>? _armors;

  static Future<List<SrdWeapon>> loadWeapons([AssetBundle? bundle]) async {
    await _ensureLoaded(bundle);
    return _weapons!;
  }

  static Future<List<SrdArmor>> loadArmors([AssetBundle? bundle]) async {
    await _ensureLoaded(bundle);
    return _armors!;
  }

  static Future<void> _ensureLoaded(AssetBundle? bundle) async {
    if (_weapons != null && _armors != null) return;
    try {
      final jsonStr = await (bundle ?? rootBundle).loadString(
        'assets/srd/equipment_5e.json',
      );
      final parsed = parse(jsonStr);
      _weapons = parsed.$1;
      _armors = parsed.$2;
    } catch (_) {
      _weapons = const [];
      _armors = const [];
    }
  }

  /// Construye el catálogo desde un String JSON (útil para tests).
  static (List<SrdWeapon>, List<SrdArmor>) parse(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return (
      ((map['weapons'] as List<dynamic>?) ?? const [])
          .map((e) => SrdWeapon.fromJson(e as Map<String, dynamic>))
          .toList(),
      ((map['armors'] as List<dynamic>?) ?? const [])
          .map((e) => SrdArmor.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Filtra armas por texto, categoría, tipo de alcance y/o propiedad.
  static List<SrdWeapon> searchWeapons(
    List<SrdWeapon> all, {
    String query = '',
    String? category,
    String? rangeType,
    String? property,
  }) {
    final q = normalizeSpellName(query);
    return all.where((w) {
      if (category != null && w.category != category) return false;
      if (rangeType != null && w.rangeType != rangeType) return false;
      if (property != null && !w.hasProperty(property)) return false;
      return q.isEmpty || normalizeSpellName(w.name).contains(q);
    }).toList();
  }

  /// Filtra armaduras por texto y/o categoría.
  static List<SrdArmor> searchArmors(
    List<SrdArmor> all, {
    String query = '',
    String? category,
  }) {
    final q = normalizeSpellName(query);
    return all.where((a) {
      if (category != null && a.category != category) return false;
      return q.isEmpty || normalizeSpellName(a.name).contains(q);
    }).toList();
  }

  static SrdWeapon? weaponByIdOrName(List<SrdWeapon> all, String key) {
    final k = normalizeSpellName(key);
    for (final w in all) {
      if (normalizeSpellName(w.id) == k || normalizeSpellName(w.name) == k) {
        return w;
      }
    }
    return null;
  }

  static SrdArmor? armorByIdOrName(List<SrdArmor> all, String key) {
    final k = normalizeSpellName(key);
    for (final a in all) {
      if (normalizeSpellName(a.id) == k || normalizeSpellName(a.name) == k) {
        return a;
      }
    }
    return null;
  }

  /// Limpia la caché (útil para tests).
  static void clearCache() {
    _weapons = null;
    _armors = null;
  }
}
