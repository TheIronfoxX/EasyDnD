// Parche de enriquecimiento con IA para fichas de Nivel20.
//
// La ficha base la construye Nivel20Mapper de forma determinista
// (atributos, PG, CA, velocidad, ranuras, armas y conjuros del SRD). La
// IA ya NO recibe ni devuelve esa ficha: solo clasifica rasgos, extrae
// recursos, desglosa el equipo y redacta textos, y responde con un JSON
// "parche" de claves opcionales. Este archivo decodifica ese
// parche y lo fusiona sobre el CharacterModel base SIN tocar nada más.
//
// Forma del parche (todas las claves opcionales):
// {
//   "classified_features": [
//     { "name", "category": "action|bonus_action|reaction|passive",
//       "tactical_role" (solo passive), "attack_type" (solo activas),
//       "tactical_summary", "lore_description" }
//   ],
//   "resources": [ { "name", "current", "max" } ],
//   "inventory": { "mundane_items": [ { "name", "description", "quantity" } ] },
//   "lore_info": { "tactical_summary", "lore_description" },
//   "purse": { "gold", "silver", "copper" }   // monedas ADICIONALES: se suman
//   "companions": [ { "name", "type", "has_hp", "current_hp", "max_hp", "ac" } ]
// }
//
// Puro Dart, sin Flutter.

import 'dart:convert';

import '../core/json_sanitizer.dart';
import 'models/ability.dart';
import 'models/character.dart';
import 'models/srd_spell.dart' show normalizeSpellName;

class Nivel20Patch {
  Nivel20Patch._();

  /// Las únicas claves que la IA puede devolver.
  static const patchKeys = [
    'classified_features',
    'resources',
    'inventory',
    'lore_info',
    'purse',
    'companions',
  ];

  static const _categories = ['action', 'bonus_action', 'reaction', 'passive'];
  static const _roles = ['Ofensivo', 'Defensivo', 'Utilidad'];
  static const _attackTypes = ['save', 'attack', 'none'];

  /// ¿Es [json] un parche (alguna clave de parche y NO una ficha completa)?
  static bool looksLikePatch(Map<String, dynamic> json) =>
      !json.containsKey('basic_info') && patchKeys.any(json.containsKey);

  /// Decodifica el texto pegado (con vallas de código y cortesía incluidas)
  /// como parche. Null si no es JSON, no es un objeto o es una ficha
  /// completa (modo clásico).
  static Map<String, dynamic>? tryDecode(String text) {
    try {
      final decoded = jsonDecode(sanitizeJsonText(text));
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      return looksLikePatch(map) ? map : null;
    } on FormatException {
      return null;
    }
  }

  /// Fusiona [patch] sobre una COPIA de [base] y la devuelve. [base] no se
  /// modifica. Garantía: atributos, habilidades (skills), PG, CA, velocidad,
  /// ranuras, armas y conjuros quedan intactos; cualquier valor del
  /// parche fuera de rango o mal formado se ignora en silencio.
  static CharacterModel apply(CharacterModel base, Map<String, dynamic> patch) {
    final c = CharacterModel.fromJson(
      mergePurseAndCompanions(
        jsonDecode(jsonEncode(base.toJson())) as Map<String, dynamic>,
        patch,
      ),
    );
    _features(c, patch['classified_features']);
    _resources(c, patch['resources']);
    _inventory(c, patch['inventory']);
    _lore(c, patch['lore_info']);
    return c;
  }

  /// Fusiona sobre el JSON de la ficha base las claves "purse" y
  /// "companions" del [patch], sin pisar lo que el mapeador ya detectó:
  /// - "purse": monedas ADICIONALES, se suman (nunca restan ni reemplazan).
  /// - "companions": se añaden los que no estén ya (por nombre).
  /// Devuelve una copia; [baseJson] no se modifica.
  static Map<String, dynamic> mergePurseAndCompanions(
    Map<String, dynamic> baseJson,
    Map<String, dynamic> patch,
  ) {
    final merged = Map<String, dynamic>.from(baseJson);

    final patchPurse = patch['purse'];
    if (patchPurse is Map) {
      final purse = Map<String, dynamic>.from(
        (merged['purse'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      for (final key in ['gold', 'silver', 'copper']) {
        final extra = _i(patchPurse[key]) ?? 0;
        purse[key] = ((purse[key] as num?)?.toInt() ?? 0) + (extra > 0 ? extra : 0);
      }
      merged['purse'] = purse;
    }

    final patchCompanions = patch['companions'];
    if (patchCompanions is List) {
      final companions = List<dynamic>.from(
        (merged['companions'] as List?) ?? const [],
      );
      final names = companions
          .map((c) => _key(_s((c as Map)['name'])))
          .toSet();
      for (final c in _maps(patchCompanions)) {
        final name = _s(c['name']);
        if (name.isEmpty || !names.add(_key(name))) continue;
        companions.add(c);
      }
      merged['companions'] = companions;
    }

    return merged;
  }

  // ---------------------------------------------------------------------

  static List<Map<String, dynamic>> _maps(Object? v) => v is List
      ? [
          for (final e in v)
            if (e is Map) e.cast<String, dynamic>(),
        ]
      : const [];

  static String _s(Object? v) => v is String ? v.trim() : '';

  static int? _i(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static String _key(String name) => normalizeSpellName(name);

  static void _features(CharacterModel c, Object? raw) {
    final abilities = c.abilitiesByAction;
    final lists = {
      'action': abilities.action,
      'bonus_action': abilities.bonusAction,
      'reaction': abilities.reaction,
      'passive': abilities.passive,
    };
    final usedIds = abilities.all.map((a) => a.id).toSet();

    for (final f in _maps(raw)) {
      final name = _s(f['name']);
      final category = _s(f['category']);
      if (name.isEmpty || !_categories.contains(category)) continue;

      final key = _key(name);
      // Los conjuros (SRD o no) no se tocan nunca: solo rasgos y acciones.
      if (abilities.all.any((a) => a.isSpell && _key(a.name) == key)) continue;

      Ability? existing;
      String? from;
      for (final e in lists.entries) {
        for (final a in e.value) {
          if (!a.isSpell && _key(a.name) == key) {
            existing = a;
            from = e.key;
          }
        }
      }

      final role = _roles.contains(_s(f['tactical_role']))
          ? _s(f['tactical_role'])
          : null;
      final attack =
          _attackTypes.contains(_s(f['attack_type'])) ? _s(f['attack_type']) : null;
      final summary = _s(f['tactical_summary']);
      final lore = _s(f['lore_description']);

      final ability = existing ??
          Ability(
            id: _uniqueId('patch-${key.replaceAll(' ', '-')}', usedIds),
            name: name,
            type: 'trait',
            relatedStat: '',
            successDescription: '',
            failureDescription: '',
            attackType: 'none',
          );

      if (category == 'passive') {
        ability.tacticalRole = role ?? ability.tacticalRole ?? 'Utilidad';
      } else {
        ability.attackType = attack ?? (existing == null ? 'none' : ability.attackType);
        ability.tacticalRole = null;
      }
      if (summary.isNotEmpty) ability.tacticalSummary = summary;
      if (lore.isNotEmpty) ability.loreDescription = lore;

      if (from != null && from != category) lists[from]!.remove(ability);
      if (from != category) lists[category]!.add(ability);
    }
  }

  static String _uniqueId(String base, Set<String> used) {
    var id = base;
    var n = 2;
    while (!used.add(id)) {
      id = '$base-$n';
      n++;
    }
    return id;
  }

  static void _resources(CharacterModel c, Object? raw) {
    final known = c.resources.map((r) => _key(r.name)).toSet();
    for (final r in _maps(raw)) {
      final name = _s(r['name']);
      final max = _i(r['max']);
      if (name.isEmpty || max == null || max <= 0) continue;
      if (!known.add(_key(name))) continue;
      final current = (_i(r['current']) ?? max).clamp(0, max);
      c.resources.add(ResourcePoint(name: name, current: current, max: max));
    }
  }

  static void _inventory(CharacterModel c, Object? raw) {
    if (raw is! Map) return;
    final items = <MundaneItem>[];
    for (final i in _maps(raw['mundane_items'])) {
      final name = _s(i['name']);
      if (name.isEmpty) continue;
      final qty = _i(i['quantity']);
      items.add(MundaneItem(
        name: name,
        description: _s(i['description']),
        quantity: qty != null && qty > 0 ? qty : 1,
      ));
    }
    if (items.isEmpty) return;

    // El desglose reemplaza al objeto genérico "Equipo" del mapeador.
    c.inventory.mundaneItems.removeWhere((m) => _key(m.name) == 'equipo');
    final known = c.inventory.mundaneItems.map((m) => _key(m.name)).toSet();
    for (final item in items) {
      if (known.add(_key(item.name))) c.inventory.mundaneItems.add(item);
    }
  }

  /// "tactical_summary" -> notas de la IA (ai_tips); "lore_description" ->
  /// trasfondo, solo si Nivel20 no trajo ya uno (el texto del jugador manda).
  static void _lore(CharacterModel c, Object? raw) {
    if (raw is! Map) return;
    final summary = _s(raw['tactical_summary']);
    final lore = _s(raw['lore_description']);
    if (summary.isNotEmpty) c.aiTips = summary;
    if (lore.isNotEmpty && c.loreInfo.backstory.trim().isEmpty) {
      c.loreInfo.backstory = lore;
    }
  }
}
