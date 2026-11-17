// Saneado de JSON pegado desde una IA.
//
// ChatGPT/Claude casi nunca devuelven JSON "puro": suele venir envuelto
// en un bloque de código Markdown (```json ... ```) y/o con texto de
// cortesía antes o después ("¡Aquí tienes tu personaje!", "Espero que
// lo disfrutes"...). jsonDecode() no tolera nada de eso y revienta con
// un FormatException genérico — este helper se queda solo con el objeto
// JSON real antes de intentar decodificarlo, para que el "texto extra"
// deje de ser un problema para el jugador.

/// Devuelve el substring que contiene (con suerte) el objeto JSON real.
/// Pasos:
///  1. Quita vallas de código Markdown si las hay (```json ... ```).
///  2. Se queda con lo que hay entre la primera '{' y la última '}',
///     por si aún queda texto de cortesía alrededor.
String sanitizeJsonText(String raw) {
  var text = raw.trim();

  final fenceMatch = RegExp(
    r'```(?:json)?\s*([\s\S]*?)\s*```',
    caseSensitive: false,
  ).firstMatch(text);
  if (fenceMatch != null) {
    text = fenceMatch.group(1)!.trim();
  }

  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end != -1 && end > start) {
    text = text.substring(start, end + 1);
  }

  return text;
}

// ---------------------------------------------------------------------
// NORMALIZACIÓN TOLERANTE
// ---------------------------------------------------------------------
//
// Las IA se equivocan de formas previsibles: números entre comillas
// ("44"), `null` donde va un array, secciones de notas omitidas. En vez de
// rechazar la ficha por eso, esta pasada previa a la validación corrige lo
// inequívoco y deja intacto todo lo demás: un texto no numérico en un
// campo numérico NO se toca (el validador lo reporta como siempre), y no
// se inventan campos críticos (nombre, PG, atributos...) para que los
// avisos de "falta X" sigan siendo honestos.

/// Convierte [v] a entero si es inequívoco: un número entero o con
/// decimales .0, o un String numérico ("44", " +3 ", "18.0"). Cualquier
/// otra cosa se devuelve tal cual.
Object? _tolerantNum(Object? v) {
  if (v is int) return v;
  if (v is double) return v == v.roundToDouble() ? v.toInt() : v;
  if (v is String) {
    final t = v.trim();
    final asInt = int.tryParse(t.startsWith('+') ? t.substring(1) : t);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(t);
    if (asDouble != null && asDouble == asDouble.roundToDouble()) {
      return asDouble.toInt();
    }
  }
  return v;
}

/// Aplica [_tolerantNum] a las claves [keys] de [map] que existan.
void _numKeys(Object? map, Iterable<String> keys) {
  if (map is! Map) return;
  for (final k in keys) {
    if (map.containsKey(k)) map[k] = _tolerantNum(map[k]);
  }
}

/// Copia profunda de un árbol JSON (Maps con claves String y Lists).
Object? _deepCopy(Object? v) {
  if (v is Map) {
    return v.map((k, value) => MapEntry(k.toString(), _deepCopy(value)));
  }
  if (v is List) return v.map(_deepCopy).toList();
  return v;
}

/// `null` -> `[]` para la clave [key] de [map] (solo si está presente y
/// es null; una clave ausente no se toca).
void _nullToList(Object? map, String key) {
  if (map is Map && map.containsKey(key) && map[key] == null) {
    map[key] = <dynamic>[];
  }
}

/// Corrige torpezas típicas de la IA en el JSON de una ficha, ANTES de
/// validarla. No muta [json]: devuelve una copia normalizada.
///
/// - Strings numéricos -> enteros en PG, CA, velocidad, nivel, CD,
///   atributos, ranuras, bonos de arma, cantidades, recursos, monedas...
/// - `null` -> `[]` en los campos que son arrays (armas, categorías de
///   habilidades, recursos, inventario, condiciones...).
/// - Valores por defecto seguros para secciones no críticas que falten
///   (notas, monedas, lore, recursos).
Map<String, dynamic> normalizeCharacterJson(Map<String, dynamic> json) {
  final out = _deepCopy(json) as Map<String, dynamic>;

  // ---- basic_info
  _numKeys(out['basic_info'], const [
    'hp_max',
    'hp_current',
    'ac',
    'speed',
    'level',
    'spell_save_dc',
    'spell_attack_bonus',
    'hit_die_sides',
    'hit_dice_max',
    'hit_dice_current',
  ]);

  // ---- stats (atributos)
  final stats = out['stats'];
  if (stats is Map) {
    for (final stat in stats.values) {
      _numKeys(stat, const ['value', 'mod']);
    }
  }

  // ---- arrays de primer nivel: null -> []
  for (final key in const [
    'resources',
    'spell_slots',
    'skills',
    'active_conditions',
    'conditions',
    'companions',
  ]) {
    _nullToList(out, key);
  }

  _listOfMaps(
    out['spell_slots'],
    (s) => _numKeys(s, const ['level', 'max', 'current']),
  );
  _listOfMaps(out['resources'], (r) => _numKeys(r, const ['current', 'max']));
  _listOfMaps(out['skills'], (s) => _numKeys(s, const ['modifier']));

  // ---- inventory: null -> {} y sus listas null -> []
  if (out.containsKey('inventory') && out['inventory'] == null) {
    out['inventory'] = <String, dynamic>{
      'weapons': <dynamic>[],
      'mundane_items': <dynamic>[],
    };
  }
  final inventory = out['inventory'];
  if (inventory is Map) {
    _nullToList(inventory, 'weapons');
    _nullToList(inventory, 'mundane_items');
    _listOfMaps(inventory['weapons'], (w) {
      _numKeys(w, const ['attack_bonus']);
      _nullToList(w, 'conditional_damage');
      _nullToList(w, 'properties');
      if (w is Map) _numKeys(w['magic_charges'], const ['max', 'current']);
    });
    _listOfMaps(
      inventory['mundane_items'],
      (i) => _numKeys(i, const ['quantity']),
    );
  }

  // ---- abilities_by_action: null -> {} y cada categoría null -> []
  if (out.containsKey('abilities_by_action') &&
      out['abilities_by_action'] == null) {
    out['abilities_by_action'] = <String, dynamic>{};
  }
  final abilities = out['abilities_by_action'];
  if (abilities is Map) {
    for (final bucket in const [
      'action',
      'bonus_action',
      'reaction',
      'passive',
    ]) {
      if (!abilities.containsKey(bucket) || abilities[bucket] == null) {
        // Una categoría ausente dentro de un objeto que sí existe es
        // inequívocamente "vacía".
        abilities[bucket] = <dynamic>[];
      }
      _listOfMaps(abilities[bucket], (a) {
        _numKeys(a, const ['base_level']);
        if (a is Map) _numKeys(a['magic_charges'], const ['max', 'current']);
      });
    }
  }

  // ---- purse
  if (out['purse'] is Map) {
    _numKeys(out['purse'], const ['gold', 'silver', 'copper']);
  }

  // ---- defaults seguros para secciones no críticas ausentes o null
  for (final key in const ['ai_tips', 'user_tactics', 'adventure_notes']) {
    if (out[key] == null) out[key] = '';
  }
  if (out['purse'] == null) {
    out['purse'] = {'gold': 0, 'silver': 0, 'copper': 0};
  }
  if (out['lore_info'] == null) {
    out['lore_info'] = {
      'backstory': '',
      'personality_traits': '',
      'ideals': '',
      'bonds': '',
      'flaws': '',
    };
  }
  if (!out.containsKey('resources')) out['resources'] = <dynamic>[];

  return out;
}

void _listOfMaps(Object? list, void Function(Object? item) visit) {
  if (list is! List) return;
  for (final item in list) {
    visit(item);
  }
}
