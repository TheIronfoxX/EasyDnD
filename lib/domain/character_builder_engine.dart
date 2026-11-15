// Motor de reglas de creación de personajes D&D 5e. Puro Dart: sin
// Flutter ni catálogos con rootBundle (recibe SrdClass/SrdWeapon/... ya
// cargados), así es determinista y testeable sin widget tree.
//
// El modelo de ficha no tiene un campo propio para varias cosas que el
// motor calcula, así que se guardan donde el modelo ya tiene lugar:
// - salvaciones (competencia + total) → AbilityScore.description,
// - habilidades → Skill.modifier (ya con competencia/pericia sumada),
// - bono de ataque de conjuro → tactical_summary de cada conjuro,
// - recursos de clase → ResourcePoint.

import 'dart:math';

import 'models/ability.dart';
import 'models/character.dart';
import 'models/srd_class.dart';
import 'models/srd_equipment.dart';
import 'models/srd_spell.dart';
import 'models/stats.dart';
import 'models/weapon.dart';

/// Slugs de atributos del proyecto, en orden estándar.
const List<String> kAbilityKeys = ['str', 'dex', 'con', 'int', 'wis', 'cha'];

const Map<String, String> kAbilityNames = {
  'str': 'Fuerza',
  'dex': 'Destreza',
  'con': 'Constitución',
  'int': 'Inteligencia',
  'wis': 'Sabiduría',
  'cha': 'Carisma',
};

/// Las 18 habilidades de 5e y su atributo.
const Map<String, String> kSkillAbilities = {
  'Acrobacias': 'dex',
  'Trato con animales': 'wis',
  'Arcanos': 'int',
  'Atletismo': 'str',
  'Engaño': 'cha',
  'Historia': 'int',
  'Perspicacia': 'wis',
  'Intimidación': 'cha',
  'Investigación': 'int',
  'Medicina': 'wis',
  'Naturaleza': 'int',
  'Percepción': 'wis',
  'Interpretación': 'cha',
  'Persuasión': 'cha',
  'Religión': 'int',
  'Juego de manos': 'dex',
  'Sigilo': 'dex',
  'Supervivencia': 'wis',
};

/// Borrador de creación: todo lo que el motor necesita para calcular.
class CharacterCreationInput {
  final String name;
  final String race;
  final int level;
  final int speed;
  final SrdClass srdClass;

  /// Atributos base (antes de bonos raciales), claves de [kAbilityKeys].
  final Map<String, int> baseScores;
  final Map<String, int> racialBonuses;

  /// Habilidades competentes (nombres de [kSkillAbilities]).
  final Set<String> skillProficiencies;

  /// Habilidades con pericia (doble competencia), subconjunto de las anteriores.
  final Set<String> expertiseSkills;

  final List<SrdWeapon> weapons;

  /// Armadura corporal y/o escudo (category 'escudo').
  final List<SrdArmor> armors;
  final List<SrdSpell> spells;

  /// PG máximos tirados por el jugador; si es null se usa la media fija.
  final int? customHpMax;
  final int startingGold;

  const CharacterCreationInput({
    this.name = '',
    this.race = '',
    this.level = 1,
    this.speed = 30,
    required this.srdClass,
    this.baseScores = const {},
    this.racialBonuses = const {},
    this.skillProficiencies = const {},
    this.expertiseSkills = const {},
    this.weapons = const [],
    this.armors = const [],
    this.spells = const [],
    this.customHpMax,
    this.startingGold = 0,
  });
}

/// Estadísticas derivadas, calculadas en vivo.
class ComputedStats {
  final int level;
  final int proficiencyBonus;
  final Map<String, int> totals;
  final Map<String, int> mods;
  final int hpMax;
  final int ac;
  final Map<String, int> savingThrows;
  final Set<String> savingThrowProficiencies;
  final Map<String, int> skills;
  final int? spellSaveDc;
  final int? spellAttackBonus;
  final Map<int, int> spellSlots; // nivel de ranura → cantidad

  const ComputedStats({
    required this.level,
    required this.proficiencyBonus,
    required this.totals,
    required this.mods,
    required this.hpMax,
    required this.ac,
    required this.savingThrows,
    required this.savingThrowProficiencies,
    required this.skills,
    required this.spellSaveDc,
    required this.spellAttackBonus,
    required this.spellSlots,
  });
}

abstract final class CharacterBuilderEngine {
  // ------------------------- reglas básicas -------------------------

  static int proficiencyBonus(int level) => ((level.clamp(1, 20) - 1) ~/ 4) + 2;

  static int modifier(int total) => ((total - 10) / 2).floor();

  /// Puntos de golpe: nivel 1 = dado + CON (mín. 1); niveles 2..N = media
  /// fija + CON por nivel (mín. 1 por nivel).
  static int hitPoints({
    required int hitDie,
    required int level,
    required int conMod,
    int? customHpMax,
  }) {
    if (customHpMax != null) return max(1, customHpMax);
    var hp = max(1, hitDie + conMod);
    for (var l = 2; l <= level; l++) {
      hp += max(1, (hitDie ~/ 2) + 1 + conMod);
    }
    return hp;
  }

  static int armorClass({
    required String classId,
    required int dexMod,
    required int conMod,
    required int wisMod,
    SrdArmor? body,
    SrdArmor? shield,
  }) {
    final shieldBonus = shield?.baseAc ?? 0;
    if (body != null) {
      final dex = body.addDex ? min(dexMod, body.maxDexBonus ?? dexMod) : 0;
      return body.baseAc + dex + shieldBonus;
    }
    var ac = 10 + dexMod;
    if (classId == 'barbaro') ac += conMod;
    if (classId == 'monje' && shield == null) ac += wisMod;
    return ac + shieldBonus;
  }

  // ----------------------------- magia ------------------------------

  static const List<List<int>> _fullSlots = [
    [2], [3], [4, 2], [4, 3], [4, 3, 2], [4, 3, 3], [4, 3, 3, 1], [4, 3, 3, 2],
    [4, 3, 3, 3, 1], [4, 3, 3, 3, 2], [4, 3, 3, 3, 2, 1], [4, 3, 3, 3, 2, 1],
    [4, 3, 3, 3, 2, 1, 1], [4, 3, 3, 3, 2, 1, 1], [4, 3, 3, 3, 2, 1, 1, 1],
    [4, 3, 3, 3, 2, 1, 1, 1], [4, 3, 3, 3, 2, 1, 1, 1, 1],
    [4, 3, 3, 3, 3, 1, 1, 1, 1], [4, 3, 3, 3, 3, 2, 1, 1, 1],
    [4, 3, 3, 3, 3, 2, 2, 1, 1],
  ];

  static const List<List<int>> _halfSlots = [
    [], [2], [3], [3], [4, 2], [4, 2], [4, 3], [4, 3], [4, 3, 2], [4, 3, 2],
    [4, 3, 3], [4, 3, 3], [4, 3, 3, 1], [4, 3, 3, 1], [4, 3, 3, 2],
    [4, 3, 3, 2], [4, 3, 3, 3, 1], [4, 3, 3, 3, 1], [4, 3, 3, 3, 2],
    [4, 3, 3, 3, 2],
  ];

  static const List<List<int>> _thirdSlots = [
    [], [], [2], [3], [3], [3], [4, 2], [4, 2], [4, 2], [4, 3], [4, 3], [4, 3],
    [4, 3, 2], [4, 3, 2], [4, 3, 2], [4, 3, 3], [4, 3, 3], [4, 3, 3],
    [4, 3, 3, 1], [4, 3, 3, 1],
  ];

  /// Ranuras de conjuro por nivel de ranura ({1: 4, 2: 3}). Vacío si no hay.
  static Map<int, int> spellSlotsFor(String spellcastingType, int level) {
    final l = level.clamp(1, 20);
    List<int> row;
    switch (spellcastingType) {
      case 'full':
        row = _fullSlots[l - 1];
      case 'half':
        row = _halfSlots[l - 1];
      case 'third':
        row = _thirdSlots[l - 1];
      case 'pact':
        // Magia de pacto: pocas ranuras, todas del nivel máximo.
        final count = l == 1 ? 1 : (l < 11 ? 2 : (l < 17 ? 3 : 4));
        final slotLevel = l < 3 ? 1 : (l < 5 ? 2 : (l < 7 ? 3 : (l < 9 ? 4 : 5)));
        return {slotLevel: count};
      default:
        return const {};
    }
    return {for (var i = 0; i < row.length; i++) i + 1: row[i]};
  }

  // ---------------------------- recursos ----------------------------

  /// Usos de Furia del bárbaro por nivel (SRD 5.1).
  static int rageUses(int level) {
    if (level >= 20) return 99; // ilimitadas
    if (level >= 17) return 6;
    if (level >= 12) return 5;
    if (level >= 6) return 4;
    if (level >= 3) return 3;
    return 2;
  }

  /// Resuelve una fórmula de recurso: suma de productos de factores.
  /// Factores: enteros, `level`, `proficiency`, `<attr>_mod`,
  /// `rage_uses` y `max(a,b,...)` (cada argumento es otra fórmula).
  /// Ej.: "5*level", "max(1,1+cha_mod)". Nunca devuelve menos de 1.
  static int resolveFormula(String formula,
      {required int level, required Map<String, int> mods}) {
    late final int Function(String) eval;

    int factor(String raw) {
      final t = raw.trim().toLowerCase();
      final n = int.tryParse(t);
      if (n != null) return n;
      if (t.startsWith('max(') && t.endsWith(')')) {
        return _splitTopLevel(t.substring(4, t.length - 1), ',').map(eval).reduce(max);
      }
      if (t == 'level') return level;
      if (t == 'proficiency') return proficiencyBonus(level);
      if (t == 'rage_uses') return rageUses(level);
      if (t.endsWith('_mod') && mods.containsKey(t.substring(0, t.length - 4))) {
        return mods[t.substring(0, t.length - 4)]!;
      }
      throw FormatException('Factor desconocido en la fórmula "$formula": "$raw"');
    }

    eval = (String expr) => _splitTopLevel(expr, '+').map((term) {
          return _splitTopLevel(term, '*').map(factor).fold(1, (a, b) => a * b);
        }).fold(0, (a, b) => a + b);

    return max(1, eval(formula));
  }

  /// Parte por [sep] ignorando los separadores dentro de paréntesis.
  static List<String> _splitTopLevel(String s, String sep) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (c == sep && depth == 0) {
        parts.add(s.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(s.substring(start));
    return parts;
  }

  // ---------------------------- cálculo -----------------------------

  static ComputedStats compute(CharacterCreationInput input) {
    final cls = input.srdClass;
    final level = input.level.clamp(1, 20);
    final prof = proficiencyBonus(level);

    final totals = <String, int>{};
    final mods = <String, int>{};
    for (final k in kAbilityKeys) {
      final total = (input.baseScores[k] ?? 10) + (input.racialBonuses[k] ?? 0);
      totals[k] = total;
      mods[k] = modifier(total);
    }

    SrdArmor? body;
    SrdArmor? shield;
    for (final a in input.armors) {
      if (a.category == 'escudo') {
        shield ??= a;
      } else {
        body ??= a;
      }
    }

    final saveProfs = cls.savingThrows.toSet();
    final saves = {
      for (final k in kAbilityKeys) k: mods[k]! + (saveProfs.contains(k) ? prof : 0),
    };

    final skills = <String, int>{};
    kSkillAbilities.forEach((name, ability) {
      var bonus = mods[ability]!;
      if (input.expertiseSkills.contains(name)) {
        bonus += prof * 2;
      } else if (input.skillProficiencies.contains(name)) {
        bonus += prof;
      }
      skills[name] = bonus;
    });

    final spellAbility = cls.spellcastingAbility;
    final spellMod = spellAbility == null ? null : mods[spellAbility];

    return ComputedStats(
      level: level,
      proficiencyBonus: prof,
      totals: totals,
      mods: mods,
      hpMax: hitPoints(
        hitDie: cls.hitDie,
        level: level,
        conMod: mods['con']!,
        customHpMax: input.customHpMax,
      ),
      ac: armorClass(
        classId: cls.id,
        dexMod: mods['dex']!,
        conMod: mods['con']!,
        wisMod: mods['wis']!,
        body: body,
        shield: shield,
      ),
      savingThrows: saves,
      savingThrowProficiencies: saveProfs,
      skills: skills,
      spellSaveDc: spellMod == null ? null : 8 + prof + spellMod,
      spellAttackBonus: spellMod == null ? null : prof + spellMod,
      spellSlots: spellSlotsFor(cls.spellcastingType, level),
    );
  }

  // ----------------------------- armas ------------------------------

  static String _signed(int n) => n == 0 ? '' : (n > 0 ? '+$n' : '$n');

  static bool _isProficient(SrdClass cls, SrdWeapon w) {
    final profs = cls.weaponProficiencies.map(normalizeSpellName).toSet();
    final category = w.category == 'marcial' ? 'armas marciales' : 'armas sencillas';
    return profs.contains(category) || profs.contains(normalizeSpellName(w.name));
  }

  /// Convierte un arma SRD en [Weapon] con bono de ataque y daño resueltos.
  static Weapon buildWeapon(SrdWeapon w, SrdClass cls, ComputedStats stats) {
    final String abilityKey;
    if (w.hasProperty('Sutil')) {
      abilityKey = stats.mods['dex']! > stats.mods['str']! ? 'dex' : 'str';
    } else if (w.rangeType == 'ranged') {
      abilityKey = 'dex';
    } else {
      abilityKey = 'str';
    }
    final mod = stats.mods[abilityKey]!;
    final proficient = _isProficient(cls, w);
    final dice = w.damageDice;
    final type = w.damageType;
    final dmgType = type ?? 'sin daño';

    final conditional = <ConditionalDamage>[];
    if (w.versatileDice != null && dice != null) {
      conditional.add(ConditionalDamage(
        trigger: 'A dos manos (versátil)',
        dice: '${w.versatileDice}${_signed(mod)}',
        type: dmgType,
      ));
    }

    return Weapon(
      id: 'weapon_${w.id}',
      name: w.name,
      attackBonus: mod + (proficient ? stats.proficiencyBonus : 0),
      // Sin dado (Red) no se le suma el modificador.
      damage: WeaponDamage(
        baseDice: dice == null ? '0d0' : '$dice${_signed(mod)}',
        baseType: dmgType,
      ),
      conditionalDamage: conditional,
      properties: List.of(w.properties),
      homebrewEffect: '',
      magicCharges: MagicCharges(hasCharges: false, max: 0, current: 0),
      successDescription: dice == null
          ? 'El ataque impacta.'
          : 'Impacta e inflige $dice${_signed(mod)} de daño $dmgType.',
      failureDescription: 'El ataque falla.',
      tacticalSummary:
          '${w.category} · ${w.rangeType == 'ranged' ? 'distancia' : 'cuerpo a cuerpo'} · ${w.rangeText}'
          '${proficient ? '' : ' · sin competencia'}',
    );
  }

  // ---------------------------- rasgos ------------------------------

  static Ability _featureToAbility(SrdClass cls, SrdClassFeature f) {
    final passive = f.actionType == 'passive';
    return Ability(
      id: 'feature_${cls.id}_${normalizeSpellName(f.name).replaceAll(' ', '_')}',
      name: f.name,
      type: 'trait',
      relatedStat: '',
      successDescription: f.description,
      failureDescription: '',
      // Exclusión mutua: pasivas con tactical_role, activas con attack_type.
      attackType: 'none',
      tacticalRole: passive ? (f.tacticalRole ?? 'utility') : null,
      loreDescription: f.description,
      tacticalSummary: '${cls.name} nivel ${f.level}',
    );
  }

  static String _categoryKey(String actionType) =>
      actionType == 'bonus_action' ? 'bonusAction' : actionType;

  static Ability _spellToAbility(SrdSpell s, SrdClass cls, ComputedStats stats) {
    final (ability, category) = s.toAbility(relatedStat: cls.spellcastingAbility ?? 'int');
    // toAbility usa el reloj en el id; aquí se necesita determinista.
    ability.id = 'spell_${normalizeSpellName(s.name).replaceAll(' ', '_')}';
    if (ability.attackType == 'save' && stats.spellSaveDc != null) {
      ability.tacticalSummary = '${ability.tacticalSummary} · CD ${stats.spellSaveDc}';
    } else if (ability.attackType == 'attack' && stats.spellAttackBonus != null) {
      ability.tacticalSummary = '${ability.tacticalSummary} · Ataque ${_signed(stats.spellAttackBonus!)}';
    }
    return ability;
  }

  // ------------------------- ficha completa -------------------------

  static CharacterModel build(CharacterCreationInput input) {
    final cls = input.srdClass;
    final stats = compute(input);
    final level = stats.level;

    AbilityScore score(String key) {
      final saving = stats.savingThrows[key]!;
      final isProf = stats.savingThrowProficiencies.contains(key);
      return AbilityScore(
        name: kAbilityNames[key]!,
        value: stats.totals[key]!,
        mod: stats.mods[key]!,
        description:
            'Salvación ${saving >= 0 ? '+$saving' : '$saving'}${isProf ? ' (competente)' : ''}',
      );
    }

    final abilities = AbilitiesByAction(action: [], bonusAction: [], reaction: [], passive: []);
    final resources = <ResourcePoint>[];
    for (final f in cls.coreFeatures.where((f) => f.level <= level)) {
      abilities.listFor(_categoryKey(f.actionType)).add(_featureToAbility(cls, f));
      final r = f.resource;
      if (r != null) {
        final uses = resolveFormula(r.maxFormula, level: level, mods: stats.mods);
        resources.add(ResourcePoint(name: r.name, current: uses, max: uses));
      }
    }
    for (final s in input.spells) {
      final (_, category) = s.toAbility();
      abilities.listFor(category).add(_spellToAbility(s, cls, stats));
    }

    final mundane = <MundaneItem>[
      for (final a in input.armors)
        MundaneItem(
          name: a.name,
          description: 'CA ${a.category == 'escudo' ? '+${a.baseAc}' : a.baseAc} · ${a.category}'
              '${a.stealthDisadvantage ? ' · desventaja en Sigilo' : ''}',
          quantity: 1,
        ),
    ];

    return CharacterModel(
      basicInfo: BasicInfo(
        name: input.name.trim(),
        race: input.race,
        characterClass: cls.name,
        hpMax: stats.hpMax,
        currentHp: stats.hpMax,
        ac: stats.ac,
        level: level,
        speed: input.speed,
        spellSaveDc: stats.spellSaveDc,
        hitDieSides: cls.hitDie,
        hitDiceMax: level,
        hitDiceCurrent: level,
      ),
      inventory: Inventory(
        weapons: [for (final w in input.weapons) buildWeapon(w, cls, stats)],
        mundaneItems: mundane,
      ),
      abilitiesByAction: abilities,
      stats: StatsBlock(
        str: score('str'),
        dex: score('dex'),
        con: score('con'),
        intelligence: score('int'),
        wis: score('wis'),
        cha: score('cha'),
      ),
      spellSlots: SpellSlots(slots: [
        for (final e in stats.spellSlots.entries)
          SpellSlot(level: e.key, max: e.value, current: e.value),
      ]),
      skills: [
        for (final e in kSkillAbilities.entries)
          Skill(name: e.key, relatedStat: e.value, modifier: stats.skills[e.key]!),
      ],
      loreInfo: LoreInfo(backstory: '', personalityTraits: '', ideals: '', bonds: '', flaws: ''),
      purse: Purse(gold: input.startingGold),
      resources: resources,
    );
  }
}
