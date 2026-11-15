// Mapeador determinista Nivel20 -> CharacterModel.
//
// Alternativa sin IA al flujo del prompt: toma el JSON de una ficha de
// Nivel20 (ya limpio de HTML por Nivel20Extractor; con o sin el
// envoltorio "printable_hash") y construye la ficha en el formato JSON de
// EasyDnD. Pura de Dart, sin Flutter, para testearla sin widget tree.
//
// Límites conocidos (Nivel20 no da el dato o no es fiable), documentados
// aquí para no sorprender a nadie:
// - Sin PG actuales: hp_current = hp_max al importar.
// - Sin recursos gastables: resources vacío.
// - Monedas: Nivel20 no trae un bloque de monedas estructurado, así que
//   se detectan por regex en el texto libre de equipo y notas (ver
//   _purse/_extractCurrency). Solo se reconocen oro/plata/cobre (po/pp/pc
//   y sus formas largas) porque el modelo Purse no tiene campos para
//   electro ni platino; lo que la regex no detecte lo puede completar el
//   parche de IA (AiPrompt.forNivel20Enrichment).
// - Sin clasificación de rasgos: todo rasgo va a "passive" con rol
//   "Utilidad" (el jugador lo ajusta en el editor).
// - Las tiradas de salvación y el bonificador de competencia no tienen
//   campo en el modelo (se derivan del nivel), así que no se importan.
// - El texto "attack" de los conjuros de Nivel20 a veces trae dados
//   erróneos. Por eso cada conjuro se cruza por nombre normalizado con el
//   catálogo SRD local (parámetro `srd`): si coincide, hereda sus datos
//   limpios (dado, escalado, tipo de ataque, descripción). Solo los
//   conjuros que no están en el SRD (homebrew) usan el texto de Nivel20,
//   como mejor esfuerzo. Excepción: en los trucos el dado se queda con el
//   ya escalado al nivel del personaje que da Nivel20 (el catálogo guarda
//   el dado base de nivel 1).

import 'models/character.dart';
import 'models/srd_spell.dart';

class Nivel20Mapper {
  Nivel20Mapper._(); // clase estática: no se instancia.

  /// Construye el [CharacterModel]. Lanza [FormatException] si el JSON no
  /// parece una ficha de Nivel20 (sin "info" ni nombre).
  static CharacterModel map(Map<String, dynamic> raw,
          {List<SrdSpell> srd = const []}) =>
      CharacterModel.fromJson(toJson(raw, srd: srd));

  /// Igual que [map] pero devuelve el JSON en formato EasyDnD, útil para
  /// pasarlo por CharacterValidator.validateMap o para inspeccionarlo.
  static Map<String, dynamic> toJson(Map<String, dynamic> raw,
      {List<SrdSpell> srd = const []}) {
    final root = _unwrap(raw);
    final info = _map(root['info']);
    final name = info['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException(
          'El JSON no parece una ficha de Nivel20 (falta "info.name").');
    }

    final professions = _list(root['professions']).map(_map).toList();
    final spellBook = _list(root['spell_books']).map(_map).firstOrNull ?? {};
    final level = _level(info, professions);
    final actionDice = _actionDice(root);
    final spellDc = _int(spellBook['spell_save_dc']);
    final spellAtk = _int(spellBook['spell_attack_bonus']);
    final castStat = _statKey(spellBook['spell_ability_slug']);
    final srdIndex = <String, SrdSpell>{
      for (final sp in srd) normalizeSpellName(sp.englishName): sp,
      for (final sp in srd) normalizeSpellName(sp.name): sp,
    }..remove('');

    return {
      'schema_version': 2,
      'basic_info': {
        'name': name.trim(),
        'race': info['race'] ?? info['race_name'] ?? '',
        'characterClass': _classText(info, professions),
        'level': level,
        'hp_max': _int(info['hit_points']) ?? 1,
        'hp_current': _int(info['hit_points']) ?? 1,
        'ac': _ac(root),
        'speed': _int(_map(root['speed'])['total']) ?? _int(info['speed']) ?? 30,
        'spell_save_dc': spellDc,
        if (professions.isNotEmpty &&
            _int(professions.first['hit_points_dice']) != null)
          'hit_die_sides': _int(professions.first['hit_points_dice']),
      },
      'purse': _purse(root),
      'ai_tips': '',
      'user_tactics': '',
      'adventure_notes': '',
      'resources': <dynamic>[],
      'inventory': {
        'weapons': _weapons(root),
        'mundane_items': _mundaneItems(root),
      },
      'stats': _stats(root),
      'spell_slots': _spellSlots(root, spellBook),
      'skills': _skills(root),
      'abilities_by_action': _abilities(
        root,
        professions,
        level: level,
        spellBook: spellBook,
        spellDc: spellDc,
        spellAtk: spellAtk,
        castStat: castStat,
        actionDice: actionDice,
        srdIndex: srdIndex,
      ),
      'lore_info': _lore(root),
    };
  }

  /// ¿Parece el JSON de una ficha de Nivel20 (con o sin "printable_hash")?
  /// Sirve para decidir si ofrecer la importación directa.
  static bool looksLikeNivel20(Map<String, dynamic> raw) {
    final root = _unwrap(raw);
    return _map(root['info']).containsKey('name') &&
        root['ability'] is Map;
  }

  /// Textos crudos que el mapeador NO puede clasificar solo (rasgos,
  /// acciones caseras, equipo), para el prompt de enriquecimiento con IA.
  static Nivel20Sources enrichmentSources(Map<String, dynamic> raw) {
    final root = _unwrap(raw);
    final info = _map(root['info']);
    final professions = _list(root['professions']).map(_map).toList();
    final level = _level(info, professions);

    final feats = StringBuffer();
    void addFeat(Map<String, dynamic> f, String origin) {
      final name = _str(f['name']);
      if (name.isEmpty || f['visible'] == false) return;
      final req = _int(f['required_level']);
      if (req != null && req > level) return;
      final text = _str(f['description']).isNotEmpty
          ? _str(f['description'])
          : _str(f['summary']);
      feats.writeln('- [$origin] $name: $text');
    }

    for (final p in professions) {
      for (final f in _list(p['feats']).map(_map)) {
        addFeat(f, _str(p['name']));
      }
    }
    for (final f in _list(root['race_feats']).map(_map)) {
      addFeat(f, 'Raza');
    }
    for (final f in _list(root['other_feats']).map(_map)) {
      addFeat(f, 'Otro');
    }
    for (final f in _list(root['custom_feats']).map(_map)) {
      addFeat(f, 'Personalizado');
    }

    final custom = StringBuffer();
    for (final a in _list(root['actions']).map(_map)) {
      final id = _str(a['id']);
      if (id == 'skill-checks' || id == 'saving-throws') continue;
      if (_str(a['action_type']) != 'folder') continue;
      if (_str(a['source_name']) == 'Equipo') continue;
      for (final e in _list(a['elements']).map(_map)) {
        final name = _str(e['name']);
        if (name.isEmpty) continue;
        custom.writeln('- [${_str(a['name'])}] $name: ${_str(e['description'])}');
      }
    }

    final equipment = StringBuffer();
    final free = _str(root['equipment']);
    if (free.isNotEmpty) equipment.writeln(free);
    final items = _map(root['items']);
    for (final key in ['armaduras', 'equipo_de_aventuras', 'monturas_y_vehiculos']) {
      for (final i in _list(items[key]).map(_map)) {
        final name = _str(i['name']);
        if (name.isNotEmpty) {
          equipment.writeln('- $name: ${_str(i['description'])}');
        }
      }
    }

    return Nivel20Sources(
      name: _str(info['name']),
      characterClass: _classText(info, professions),
      level: level,
      feats: feats.toString().trim(),
      customActions: custom.toString().trim(),
      equipment: equipment.toString().trim(),
    );
  }

  // ---------------------------------------------------------------------
  // BASIC INFO
  // ---------------------------------------------------------------------

  static String _classText(
      Map<String, dynamic> info, List<Map<String, dynamic>> professions) {
    final named = professions.where((p) => _str(p['name']).isNotEmpty);
    if (named.isEmpty) return _str(info['level_desc']);
    return named.map((p) {
      final arch = _str(p['archetype_name']);
      final lvl = _int(p['level']);
      return '${_str(p['name'])}${lvl != null ? ' $lvl' : ''}'
          '${arch.isNotEmpty ? ' ($arch)' : ''}';
    }).join(' / ');
  }

  static int _level(
      Map<String, dynamic> info, List<Map<String, dynamic>> professions) {
    final direct = _int(info['level']);
    if (direct != null && direct > 0) return direct;
    final sum = professions.fold<int>(0, (a, p) => a + (_int(p['level']) ?? 0));
    if (sum > 0) return sum;
    final m = RegExp(r'(\d+)').firstMatch(_str(info['level_desc']));
    return int.tryParse(m?.group(1) ?? '') ?? 1;
  }

  static int _ac(Map<String, dynamic> root) {
    final normal = _int(_map(root['armor'])['normal']);
    if (normal != null) return normal;
    final fallback = _int(_map(_map(_map(root['originals'])['static'])
        ['armor_normal'])['total']);
    return fallback ?? 10;
  }

  // ---------------------------------------------------------------------
  // STATS / SKILLS
  // ---------------------------------------------------------------------

  /// Abreviatura de Nivel20 -> clave del modelo EasyDnD.
  static const _statKeys = {
    'fue': 'str',
    'des': 'dex',
    'con': 'con',
    'int': 'int',
    'sab': 'wis',
    'car': 'cha',
  };

  static String _statKey(Object? slug) => _statKeys[_str(slug)] ?? '';

  static const _statDescriptions = {
    'str': 'Mide la fuerza física y la capacidad atlética.',
    'dex': 'Mide la agilidad, los reflejos y la coordinación.',
    'con': 'Mide la resistencia física y la salud.',
    'int': 'Mide el conocimiento y la lógica.',
    'wis': 'Mide la intuición y la percepción.',
    'cha': 'Mide la fuerza de personalidad.',
  };

  static Map<String, dynamic> _stats(Map<String, dynamic> root) {
    final abilities = _map(root['ability']);
    final out = <String, dynamic>{};
    _statKeys.forEach((n20, key) {
      final a = _map(abilities[n20]);
      out[key] = {
        'name': _str(a['name']).isEmpty ? n20 : a['name'],
        'value': _int(a['total']) ?? 10,
        'mod': _int(a['mod']) ?? 0,
        'description': _statDescriptions[key],
      };
    });
    return out;
  }

  static List<Map<String, dynamic>> _skills(Map<String, dynamic> root) {
    final skills = _map(root['skill']);
    return skills.values.map(_map).where((s) => s.isNotEmpty).map((s) {
      return {
        'name': _str(s['name']),
        'related_stat': _statKey(s['ability']),
        'modifier': _int(s['total']) ?? 0,
      };
    }).toList();
  }

  // ---------------------------------------------------------------------
  // CONJUROS Y RANURAS
  // ---------------------------------------------------------------------

  static List<Map<String, dynamic>> _spellSlots(
      Map<String, dynamic> root, Map<String, dynamic> spellBook) {
    var source = _map(spellBook['current_level_slots']);
    if (source.isEmpty) source = _map(_map(root['resources'])['spell_slots']);
    final out = <Map<String, dynamic>>[];
    source.forEach((key, value) {
      final level = int.tryParse(key); // "cantrips"/"cantrip" -> null
      final max = _int(value);
      if (level == null || level < 1 || max == null || max <= 0) return;
      out.add({'level': level, 'max': max, 'current': max});
    });
    out.sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));
    return out;
  }

  /// Dado de los trucos ya escalado al nivel del personaje, tal como lo
  /// guarda Nivel20 en las acciones personalizadas (Rayo de Fuego: 2d10).
  /// Clave: nombre normalizado.
  static Map<String, String> _actionDice(Map<String, dynamic> root) {
    final out = <String, String>{};
    for (final a in _list(root['actions']).map(_map)) {
      final id = _str(a['id']);
      if (id == 'skill-checks' || id == 'saving-throws') continue;
      if (_str(a['action_type']) != 'dice_roll') continue;
      final dice = _diceIn(_str(a['dice_roll']));
      if (dice != null) out[_slug(_str(a['name']))] = dice;
    }
    return out;
  }

  static final RegExp _diceRegex = RegExp(r'\d+d\d+(?:\s*[+-]\s*\d+)?');

  /// Primer dado con bono opcional en [text], sin espacios ("1d6 -1" ->
  /// "1d6-1"), o null si no hay.
  static String? _diceIn(String text) {
    final m = _diceRegex.firstMatch(text);
    return m?.group(0)!.replaceAll(RegExp(r'\s+'), '');
  }

  static final RegExp _scalingRegex = RegExp(
    r'aument\w*\s+en\s+(\d+d\d+(?:\s*[+-]\s*\d+)?)[^.\n]*?por cada nivel',
    caseSensitive: false,
  );

  static Map<String, List<Map<String, dynamic>>> _emptyBuckets() => {
        'action': [],
        'bonus_action': [],
        'reaction': [],
        'passive': [],
      };

  static Map<String, dynamic> _abilities(
    Map<String, dynamic> root,
    List<Map<String, dynamic>> professions, {
    required int level,
    required Map<String, dynamic> spellBook,
    required int? spellDc,
    required int? spellAtk,
    required String castStat,
    required Map<String, String> actionDice,
    required Map<String, SrdSpell> srdIndex,
  }) {
    final buckets = _emptyBuckets();
    final usedIds = <String>{};

    String uniqueId(String base) {
      var id = base;
      var n = 2;
      while (!usedIds.add(id)) {
        id = '$base-$n';
        n++;
      }
      return id;
    }

    // ---- Conjuros (spell_books[].spells = [[nivel, [conjuro...]], ...])
    for (final book in _list(root['spell_books']).map(_map)) {
      for (final group in _list(book['spells'])) {
        if (group is! List || group.length < 2) continue;
        for (final spell in _list(group[1]).map(_map)) {
          if (spell.isEmpty || spell['included'] == false) continue;
          final bucket = switch (_str(spell['casting_time_unit'])) {
            'bonus_action' => 'bonus_action',
            'reaction' => 'reaction',
            _ => 'action',
          };
          buckets[bucket]!.add(_spell(
            spell,
            id: uniqueId('spell-${_slug(_str(spell['name']))}'),
            spellDc: spellDc,
            spellAtk: spellAtk,
            castStat: castStat,
            actionDice: actionDice,
            srd: srdIndex[normalizeSpellName(_str(spell['name']))],
          ));
        }
      }
    }

    // ---- Rasgos de clase/subclase y de raza -> pasivas
    void addFeat(Map<String, dynamic> f, String type) {
      final fname = _str(f['name']);
      if (fname.isEmpty || f['visible'] == false) return;
      final req = _int(f['required_level']);
      if (req != null && req > level) return;
      final desc = _str(f['description']);
      final summary = _str(f['summary']);
      // Economía activa EXPLÍCITA (casting_time_unit / action_type): el
      // rasgo es un poder táctico y va a su categoría, no a pasivas.
      // Sin ese dato se sigue asumiendo pasivo (no se adivina por texto).
      final active = _activeCategory(f);
      if (active != null) {
        buckets[active]!.add(_activeFeat(
          id: uniqueId('feat-${_slug(fname)}'),
          name: fname,
          type: type,
          description: desc.isNotEmpty ? desc : summary,
          summary: summary,
        ));
        return;
      }
      buckets['passive']!.add(_passive(
        id: uniqueId('feat-${_slug(fname)}'),
        name: fname,
        type: type,
        description: desc.isNotEmpty ? desc : summary,
        summary: summary,
      ));
    }

    for (final p in professions) {
      for (final f in _list(p['feats']).map(_map)) {
        addFeat(f, 'class_feature');
      }
    }
    for (final f in _list(root['race_feats']).map(_map)) {
      addFeat(f, 'trait');
    }
    // Dotes: mismo tratamiento que los rasgos de raza.
    for (final key in const ['other_feats', 'custom_feats']) {
      for (final f in _list(root[key]).map(_map)) {
        addFeat(f, 'trait');
      }
    }

    // ---- Carpetas personalizadas de actions[] (homebrew del jugador).
    // Se ignoran las carpetas de pruebas/salvaciones y las de equipo.
    for (final a in _list(root['actions']).map(_map)) {
      final id = _str(a['id']);
      if (id == 'skill-checks' || id == 'saving-throws') continue;
      if (_str(a['action_type']) != 'folder') continue;
      if (_str(a['source_name']) == 'Equipo') continue;
      for (final e in _list(a['elements']).map(_map)) {
        final ename = _str(e['name']);
        final desc = _str(e['description']);
        if (ename.isEmpty || desc.isEmpty) continue;
        if (_str(e['action_type']) != 'none') continue;
        buckets['passive']!.add(_passive(
          id: uniqueId('custom-${_slug(ename)}'),
          name: ename,
          type: 'trait',
          description: desc,
          summary: '',
        ));
      }
    }

    return buckets;
  }

  static const _activeCategories = {'action', 'bonus_action', 'reaction'};

  /// 'action' | 'bonus_action' | 'reaction' si el rasgo declara su
  /// economía activa explícitamente; null si no (queda pasivo).
  static String? _activeCategory(Map<String, dynamic> feat) {
    for (final key in const ['casting_time_unit', 'action_type']) {
      final v = _str(feat[key]);
      if (_activeCategories.contains(v)) return v;
    }
    return null;
  }

  static Map<String, dynamic> _activeFeat({
    required String id,
    required String name,
    required String type,
    required String description,
    required String summary,
  }) =>
      {
        'id': id,
        'name': name,
        'type': type,
        'attack_type': 'none',
        'lore_description': description,
        'tactical_summary': summary.isNotEmpty ? summary : _firstSentence(description),
      };

  static Map<String, dynamic> _passive({
    required String id,
    required String name,
    required String type,
    required String description,
    required String summary,
  }) =>
      {
        'id': id,
        'name': name,
        'type': type,
        'lore_description': description,
        'tactical_summary': summary.isNotEmpty ? summary : _firstSentence(description),
        'tactical_role': 'Utilidad',
      };

  static Map<String, dynamic> _spell(
    Map<String, dynamic> spell, {
    required String id,
    required int? spellDc,
    required int? spellAtk,
    required String castStat,
    required Map<String, String> actionDice,
    SrdSpell? srd,
  }) {
    final name = _str(spell['name']);
    final level = _int(spell['level']) ?? 0;
    final attackText = _str(spell['attack']);
    final saveText = _str(spell['saving_throw']);
    final description = _str(spell['description']);

    // Datos crudos de Nivel20 (fallback para homebrew fuera del SRD).
    var attackType = _attackType(attackText, saveText);

    // Dado: el del texto "attack"; los trucos prefieren el dado ya
    // escalado de actions[] si existe.
    var dice = _diceIn(attackText) ?? '';
    if (level == 0) dice = actionDice[_slug(name)] ?? dice;

    // Escalado por nivel de espacio: solo si la descripción lo da en
    // forma de dado parseable ("aumenta en 1d6 por cada nivel...").
    String scaling = '';
    if (level > 0) {
      final m = _scalingRegex.firstMatch(description);
      if (m != null) scaling = m.group(1)!.replaceAll(RegExp(r'\s+'), '');
    }

    var damageType = _damageType(attackText);
    final summary = _str(spell['summary']);
    var loreOverride = '';

    // Cruce con el SRD: sus datos limpios mandan sobre los de Nivel20.
    var spellLevel = level;
    if (srd != null) {
      attackType = srd.attackType;
      spellLevel = srd.level;
      final srdType = srd.damageType ?? '';
      if (srdType.isNotEmpty) {
        damageType = srdType[0].toUpperCase() + srdType.substring(1);
      }
      if (level == 0) {
        // Truco: se conserva el dado ya escalado al nivel del personaje
        // (si Nivel20 lo da); el SRD solo aporta el dado base.
        if (dice.isEmpty) dice = srd.damageDice ?? '';
        scaling = '';
      } else {
        dice = srd.damageDice ?? '';
        scaling = srd.isScalable ? (srd.scalingFormula ?? '') : '';
      }
      loreOverride = srd.description;
    }

    return {
      'id': id,
      'name': name,
      'type': 'spell',
      'related_stat': castStat,
      'attack_type': attackType,
      'success_description': '',
      'failure_description': '',
      'is_scalable': scaling.isNotEmpty,
      'base_level': spellLevel,
      'damage_dice': dice,
      'scaling_formula': scaling,
      'lore_description': loreOverride.isNotEmpty
          ? loreOverride
          : (summary.isNotEmpty ? summary : _firstSentence(description)),
      'tactical_summary': _spellTactics(
        attackType: attackType,
        saveText: saveText,
        summary: summary,
        dice: dice,
        damageType: damageType,
        spellDc: spellDc,
        spellAtk: spellAtk,
        castingUnit: _str(spell['casting_time_unit']),
        castingTime: _str(spell['casting_time']),
      ),
    };
  }

  /// "Contra salvación" -> save; "A distancia"/"Cuerpo a cuerpo" ->
  /// attack; resto -> none. Si Nivel20 no da texto de ataque pero sí una
  /// salvación ("Destreza mitad", "Carisma niega") cuenta como save.
  static String _attackType(String attackText, String saveText) {
    final a = attackText.toLowerCase();
    if (a.startsWith('contra salvación')) return 'save';
    if (a.startsWith('a distancia') || a.startsWith('cuerpo a cuerpo')) {
      return 'attack';
    }
    if (saveText.isNotEmpty) return 'save';
    return 'none';
  }

  /// Último tramo textual tras el dado: "A distancia 1d10 fuego" ->
  /// "Fuego". Vacío si no hay.
  static String _damageType(String attackText) {
    final m = RegExp(r'\d+d\d+(?:\s*[+-]\s*\d+)?\s+(\S.*)$').firstMatch(attackText);
    final t = m?.group(1)?.trim() ?? '';
    return t.isEmpty ? '' : t[0].toUpperCase() + t.substring(1);
  }

  static String _spellTactics({
    required String attackType,
    required String saveText,
    required String summary,
    required String dice,
    required String damageType,
    required int? spellDc,
    required int? spellAtk,
    required String castingUnit,
    required String castingTime,
  }) {
    final dc = spellDc != null ? ' ($spellDc)' : '';
    final String roll;
    switch (attackType) {
      case 'save':
        final stat = saveText.split(' ').first;
        final half = saveText.toLowerCase().contains('mitad');
        roll = 'Los objetivos tiran un d20'
            '${stat.isNotEmpty ? ' (prueba de $stat)' : ''}; '
            'si superan tu CD$dc '
            '${half ? 'reciben solo la mitad del daño' : 'evitan el efecto'}, '
            'si no la superan '
            '${half ? 'reciben todo el daño' : 'sufren todo el efecto'}';
      case 'attack':
        final bonus = spellAtk != null
            ? (spellAtk >= 0 ? '+$spellAtk' : '$spellAtk')
            : '+X';
        roll = 'Tiras un d20 y sumas $bonus; le dices el resultado al máster '
            'y él te dice si le has dado';
      default:
        final first = _firstSentence(summary);
        roll = 'No tienes que tirar nada'
            '${first.isNotEmpty ? ': ${_lowerFirst(first)}' : ''}';
    }
    final cost = switch (castingUnit) {
      'bonus_action' => ' | Gasta: acción adicional',
      'reaction' => ' | Gasta: reacción',
      'action' => ' | Gasta: acción',
      _ => castingTime.isNotEmpty ? ' | Tiempo: $castingTime' : '',
    };
    final damage = dice.isNotEmpty
        ? ' | Daño: $dice${damageType.isNotEmpty ? ' $damageType' : ''}'
        : '';
    return '$roll$damage$cost';
  }

  // ---------------------------------------------------------------------
  // ARMAS E INVENTARIO
  // ---------------------------------------------------------------------

  /// Armas declaradas en Nivel20: "items.armas[]" y el "attacks[]" de
  /// nivel raíz suelen duplicar las mismas armas equipadas, así que se
  /// combinan y se deduplican por nombre (slug), quedándose con la
  /// primera aparición.
  static List<Map<String, dynamic>> _weapons(Map<String, dynamic> root) {
    final sources = <Map<String, dynamic>>[
      ..._list(_map(root['items'])['armas']).map(_map),
      ..._list(root['attacks']).map(_map),
    ];
    final out = <Map<String, dynamic>>[];
    final usedIds = <String>{};
    final seenNames = <String>{};
    for (final w in sources) {
      final name = _str(w['name']);
      if (name.isEmpty) continue;
      if (!seenNames.add(_slug(name))) continue; // ya procesada (duplicado)

      final attack = _map(w['attack']);
      final dmg = _map(attack['damage']);
      final bonus = _int(_map(attack['to_hit'])['value']) ?? 0;

      final baseDice = _str(dmg['dice']);
      // Bono plano: lo que sobra de "1d6 -1" tras el dado ("-1").
      final flat = RegExp(r'([+-]\s*\d+)\s*$')
              .firstMatch(_str(dmg['value']))
              ?.group(1)
              ?.replaceAll(RegExp(r'\s+'), '') ??
          '';
      final dice = '$baseDice$flat';
      final type = _str(dmg['type']);

      final versatil = _diceIn(_str(_map(w['fields'])['versatil']));
      final conditional = <Map<String, dynamic>>[
        if (versatil != null)
          {
            'trigger': 'Ataque a dos manos',
            'dice': '${versatil.split(RegExp(r'[+-]')).first}$flat',
            'type': type.toLowerCase(),
          },
      ];

      // Datos que no tienen campo propio en Weapon (range, bono extra de
      // to_hit/damage, munición): se preservan como notas legibles en
      // "properties" en vez de perderse.
      final properties = <String>[
        ..._list(w['tags']).map((t) => _str(t)).where((t) => t.isNotEmpty),
      ];
      final range = _str(attack['range']);
      if (range.isNotEmpty) properties.add('Alcance: $range');
      final municion = _str(_map(w['fields'])['municion']);
      if (municion.isNotEmpty) properties.add('Munición: $municion');
      final toHitBonusText = _str(_map(attack['to_hit'])['bonus']);
      if (toHitBonusText.isNotEmpty) {
        properties.add('Bono de ataque adicional: $toHitBonusText');
      }
      final damageBonusText = _str(dmg['bonus']);
      if (damageBonusText.isNotEmpty) {
        properties.add('Bono de daño adicional: $damageBonusText');
      }

      final bonusText = bonus >= 0 ? '+$bonus' : '$bonus';
      var id = 'weapon-${_slug(name)}';
      var n = 2;
      while (!usedIds.add(id)) {
        id = 'weapon-${_slug(name)}-$n';
        n++;
      }

      out.add({
        'id': id,
        'name': name,
        'attack_bonus': bonus,
        'damage': {'base_dice': dice, 'base_type': type.toLowerCase()},
        'conditional_damage': conditional,
        'properties': properties,
        'homebrew_effect': '',
        'magic_charges': {'has_charges': false, 'max': 0, 'current': 0},
        'success_description': '',
        'failure_description': '',
        'lore_description': _str(w['description']),
        'tactical_summary':
            'Tiras un d20 y sumas $bonusText; le dices el resultado al máster '
            'y él te dice si le has dado | Daño: $dice'
            '${type.isNotEmpty ? ' $type' : ''}'
            '${versatil != null ? ' (${conditional.first['dice']} a dos manos)' : ''}',
        'is_unique': false,
      });
    }
    return out;
  }

  static List<Map<String, dynamic>> _mundaneItems(Map<String, dynamic> root) {
    final items = _map(root['items']);
    final out = <Map<String, dynamic>>[];
    for (final key in ['armaduras', 'equipo_de_aventuras', 'monturas_y_vehiculos']) {
      for (final i in _list(items[key]).map(_map)) {
        final name = _str(i['name']);
        if (name.isEmpty) continue;
        out.add({
          'name': name,
          'description': _str(i['description']),
          'quantity': _int(i['quantity']) ?? 1,
        });
      }
    }
    for (final p in _list(root['protections']).map(_map)) {
      final name = _str(p['name']);
      if (name.isEmpty) continue;
      out.add({
        'name': name,
        'description': _str(p['description']),
        'quantity': _int(p['quantity']) ?? 1,
      });
    }

    // Equipo libre: las menciones de monedas van a purse (ver _purse), no
    // acá. El resto, si trae varios objetos separados por coma o salto de
    // línea, se parte en un ítem por objeto en vez de uno genérico
    // "Equipo"; si queda una sola frase, se mantiene como antes.
    final free = _stripCurrencyMentions(_str(root['equipment']));
    final parts = free
        .split(RegExp(r'[\n,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length > 1) {
      for (final part in parts) {
        out.add({'name': part, 'description': '', 'quantity': 1});
      }
    } else if (parts.isNotEmpty) {
      out.add({'name': 'Equipo', 'description': parts.first, 'quantity': 1});
    }
    return out;
  }

  // ---------------------------------------------------------------------
  // MONEDAS
  // ---------------------------------------------------------------------

  /// Abreviatura o palabra de Nivel20 -> clave del modelo Purse. Solo
  /// oro/plata/cobre: el modelo no tiene campos para electro ni platino
  /// (ver nota de "Límites conocidos" al inicio del archivo).
  static const _currencyKeys = {
    'po': 'gold', 'oro': 'gold',
    'pp': 'silver', 'plata': 'silver',
    'pc': 'copper', 'cobre': 'copper',
  };

  static final RegExp _currencyRegex = RegExp(
    r'(\d+)\s*(?:piezas?|monedas?)?\s*(?:de\s+)?(po|pp|pc|oro|plata|cobre)\b',
    caseSensitive: false,
  );

  /// Suma las menciones de monedas en [equipment] y [notas] (regex sobre
  /// texto libre, ver _currencyRegex) en un único purse. Si la ficha no
  /// menciona monedas da 0/0/0; el parche de IA puede completar lo que
  /// esta regex no cubra.
  static Map<String, dynamic> _purse(Map<String, dynamic> root) {
    final equipment = _str(root['equipment']);
    final notas = _str(_map(root['fields'])['notas']);
    final out = {'gold': 0, 'silver': 0, 'copper': 0};
    for (final text in [equipment, notas]) {
      for (final m in _currencyRegex.allMatches(text)) {
        final key = _currencyKeys[m.group(2)!.toLowerCase()];
        final amount = int.tryParse(m.group(1)!);
        if (key != null && amount != null) out[key] = out[key]! + amount;
      }
    }
    return out;
  }

  /// Quita del texto las menciones de monedas que _purse ya contabilizó,
  /// para que no terminen duplicadas como "objeto" en mundane_items.
  static String _stripCurrencyMentions(String text) {
    return text
        .replaceAll(_currencyRegex, '')
        .replaceAll(RegExp(r'[,\s]*,[,\s]*'), ', ')
        .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '')
        .trim();
  }

  // ---------------------------------------------------------------------
  // LORE
  // ---------------------------------------------------------------------

  static Map<String, dynamic> _lore(Map<String, dynamic> root) {
    final fields = _map(root['fields']);
    final bg = _map(root['background']);
    final alignment = _str(fields['alineamiento']);
    final traits = _str(bg['traits']);
    return {
      'backstory': _str(fields['historia']),
      'personality_traits': [
        if (alignment.isNotEmpty) 'Alineamiento: $alignment',
        if (traits.isNotEmpty) traits,
      ].join('\n'),
      'ideals': _str(bg['ideals']),
      'bonds': _str(bg['bonds']),
      'flaws': _str(bg['flaws']),
    };
  }

  // ---------------------------------------------------------------------
  // UTILIDADES
  // ---------------------------------------------------------------------

  /// El JSON puede venir con o sin el envoltorio "printable_hash".
  static Map<String, dynamic> _unwrap(Map<String, dynamic> raw) {
    if (raw.containsKey('info')) return raw;
    final wrapped = raw['printable_hash'];
    if (wrapped is Map) return Map<String, dynamic>.from(wrapped);
    return raw;
  }

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<dynamic> _list(Object? v) => v is List ? v : const [];

  static String _str(Object? v) => v is String ? v.trim() : '';

  /// Número desde int/double o String numérico ("4"); null si no hay.
  static int? _int(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static String _firstSentence(String text) {
    final t = text.trim();
    if (t.isEmpty) return '';
    final m = RegExp(r'^[\s\S]*?[.!?](?=\s|$)').firstMatch(t);
    return (m?.group(0) ?? t.split('\n').first).trim();
  }

  static String _lowerFirst(String t) =>
      t.isEmpty ? t : t[0].toLowerCase() + t.substring(1);

  static const _accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  };

  /// "Rayo de Fuego " -> "rayo-de-fuego" (ids estables y comparación de
  /// nombres entre spell_books y actions).
  static String _slug(String text) {
    var t = text.toLowerCase().trim();
    _accents.forEach((k, v) => t = t.replaceAll(k, v));
    t = t.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return t.replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

/// Textos crudos de una ficha de Nivel20 para el prompt de enriquecimiento.
class Nivel20Sources {
  const Nivel20Sources({
    required this.name,
    required this.characterClass,
    required this.level,
    required this.feats,
    required this.customActions,
    required this.equipment,
  });

  /// Contexto mínimo del personaje para el prompt de parche.
  final String name;
  final String characterClass;
  final int level;

  /// Rasgos de clase, subclase, raza y personalizados (uno por línea).
  final String feats;

  /// Rasgos caseros de carpetas de acciones del jugador.
  final String customActions;

  /// Equipo libre y objetos sin clasificar.
  final String equipment;
}
