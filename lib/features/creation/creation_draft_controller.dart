// Estado mutable del asistente de creación, desacoplado de la UI: solo
// guarda las decisiones del jugador y delega todo cálculo en
// CharacterBuilderEngine.

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/dice.dart';
import '../../domain/character_builder_engine.dart';
import '../../domain/character_validator.dart';
import '../../domain/models/character.dart';
import '../../domain/models/srd_class.dart';
import '../../domain/models/srd_equipment.dart';
import '../../domain/models/srd_spell.dart';

enum AbilityMethod { standardArray, pointBuy, rolled, manual }

/// La ficha construida no superó la validación (errores o avisos).
class CharacterCreationException implements Exception {
  final List<String> problems;
  CharacterCreationException(this.problems);

  @override
  String toString() => 'CharacterCreationException: ${problems.join('; ')}';
}

/// Resultado de [CreationDraftController.buildPreview]: la ficha generada
/// más los avisos no bloqueantes del validador, para mostrarlos antes de
/// confirmar el alta (igual que el wizard de importación).
class CharacterPreview {
  final CharacterModel character;
  final List<ValidationIssue> warnings;
  const CharacterPreview(this.character, this.warnings);

  /// Forma que consume la vista previa compartida con la importación.
  CharacterValidationResult get validationResult =>
      CharacterValidationResult(character: character, issues: warnings);
}

/// LEGADO — a retirar en una limpieza posterior. Pertenece al asistente de
/// creación multi-paso, descartado a favor del editor de 4 pestañas y la
/// importación desde Nivel20. Ninguna pantalla lo usa; no extenderlo.
class CreationDraftController extends ChangeNotifier {
  static const List<int> standardArray = [15, 14, 13, 12, 10, 8];
  static const int pointBuyBudget = 27;
  static const Map<int, int> pointBuyCost = {
    8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9,
  };

  // Identidad
  String _name = '';
  String _race = '';
  String _subclass = '';
  String _background = '';
  int _level = 1;
  int _speed = 30;

  SrdClass? _class;

  AbilityMethod _method = AbilityMethod.standardArray;
  Map<String, int> _base = _defaultsFor(AbilityMethod.standardArray);
  final Map<String, int> _racial = {for (final k in kAbilityKeys) k: 0};

  final Set<String> _skills = {};
  final Set<String> _expertise = {};
  final List<SrdWeapon> _weapons = [];
  SrdArmor? _bodyArmor;
  SrdArmor? _shield;
  final List<SrdSpell> _spells = [];
  int? _customHpMax;
  int _startingGold = 0;

  static Map<String, int> _defaultsFor(AbilityMethod m) {
    switch (m) {
      case AbilityMethod.standardArray:
        return {for (var i = 0; i < 6; i++) kAbilityKeys[i]: standardArray[i]};
      case AbilityMethod.pointBuy:
        return {for (final k in kAbilityKeys) k: 8};
      case AbilityMethod.rolled:
      case AbilityMethod.manual:
        return {for (final k in kAbilityKeys) k: 10};
    }
  }

  // ----------------------------- lectura ----------------------------

  String get name => _name;
  String get race => _race;
  String get subclass => _subclass;
  String get background => _background;
  int get level => _level;
  int get speed => _speed;
  SrdClass? get srdClass => _class;
  AbilityMethod get method => _method;
  Map<String, int> get baseScores => Map.unmodifiable(_base);
  Map<String, int> get racialBonuses => Map.unmodifiable(_racial);
  Set<String> get skillProficiencies => Set.unmodifiable(_skills);
  Set<String> get expertiseSkills => Set.unmodifiable(_expertise);
  List<SrdWeapon> get weapons => List.unmodifiable(_weapons);
  List<SrdArmor> get armors =>
      List.unmodifiable([if (_bodyArmor != null) _bodyArmor!, if (_shield != null) _shield!]);
  List<SrdSpell> get spells => List.unmodifiable(_spells);
  int? get customHpMax => _customHpMax;
  int get startingGold => _startingGold;

  /// Pericias disponibles: 2 si la clase tiene el rasgo "Pericia" a este
  /// nivel (Pícaro 1, Bardo 3), 0 en otro caso.
  int get expertiseSlots {
    final cls = _class;
    if (cls == null) return 0;
    final has = cls.coreFeatures.any((f) => f.name == 'Pericia' && f.level <= _level);
    return has ? 2 : 0;
  }

  /// Nivel máximo de ranura al nivel actual (0 = solo trucos / sin magia).
  int get maxSpellLevel {
    final slots = stats?.spellSlots.keys;
    if (slots == null || slots.isEmpty) return 0;
    return slots.reduce(max);
  }

  int get skillChoicesLeft => (_class?.skillChoicesCount ?? 0) - _skills.length;

  /// Puntos de compra gastados con los atributos base actuales.
  int get pointsSpent => _pointCost(_base);
  int get pointsRemaining => pointBuyBudget - pointsSpent;

  bool get isPointBuyValid =>
      _base.values.every(pointBuyCost.containsKey) && pointsSpent <= pointBuyBudget;

  static int _pointCost(Map<String, int> scores) =>
      scores.values.fold(0, (sum, v) => sum + (pointBuyCost[v] ?? 999));

  CharacterCreationInput? get input {
    final cls = _class;
    if (cls == null) return null;
    return CharacterCreationInput(
      name: _name,
      race: _race,
      subclass: _subclass,
      background: _background,
      level: _level,
      speed: _speed,
      srdClass: cls,
      baseScores: _base,
      racialBonuses: _racial,
      skillProficiencies: _skills,
      expertiseSkills: _expertise,
      weapons: _weapons,
      armors: armors,
      spells: _spells,
      customHpMax: _customHpMax,
      startingGold: _startingGold,
    );
  }

  /// Estadísticas calculadas en vivo; null mientras no haya clase.
  ComputedStats? get stats {
    final i = input;
    return i == null ? null : CharacterBuilderEngine.compute(i);
  }

  /// Lo que impide construir la ficha ahora mismo (vacío = listo).
  List<String> get problems {
    final p = <String>[];
    final cls = _class;
    if (_name.trim().isEmpty) p.add('Falta el nombre del personaje.');
    if (cls == null) {
      p.add('Falta elegir una clase.');
    } else if (_skills.length != cls.skillChoicesCount) {
      p.add('Elige exactamente ${cls.skillChoicesCount} habilidades de clase '
          '(llevas ${_skills.length}).');
    }
    if (_method == AbilityMethod.pointBuy && !isPointBuyValid) {
      p.add('La compra de puntos gasta $pointsSpent de $pointBuyBudget.');
    }
    return p;
  }

  bool get canBuild => problems.isEmpty;

  // ---------------------------- identidad ---------------------------

  void setName(String v) => _set(() => _name = v);
  void setRace(String v) => _set(() => _race = v);
  void setSubclass(String v) => _set(() => _subclass = v);
  void setBackground(String v) => _set(() => _background = v);
  void setLevel(int v) => _set(() {
        _level = v.clamp(1, 20);
        _pruneSpellsToClass();
        _pruneExpertise();
      });
  void setSpeed(int v) => _set(() => _speed = v.clamp(5, 120));
  void setCustomHpMax(int? v) => _set(() => _customHpMax = v);
  void setStartingGold(int v) => _set(() => _startingGold = max(0, v));

  // ------------------------------ clase -----------------------------

  void selectClass(SrdClass cls) => _set(() {
        _class = cls;
        _skills.removeWhere((s) => !cls.skillOptions.contains(s));
        while (_skills.length > cls.skillChoicesCount) {
          _skills.remove(_skills.last);
        }
        _expertise.removeWhere((s) => !_skills.contains(s));
        _pruneSpellsToClass();
        _pruneExpertise();
      });

  void _pruneExpertise() {
    while (_expertise.length > expertiseSlots) {
      _expertise.remove(_expertise.last);
    }
  }

  void _pruneSpellsToClass() {
    final cls = _class;
    if (cls == null) return;
    _spells.removeWhere((s) => cls.spellListTag == null || !s.classes.contains(cls.spellListTag));
  }

  // ---------------------------- atributos ---------------------------

  void setMethod(AbilityMethod m) => _set(() {
        _method = m;
        _base = _defaultsFor(m);
      });

  /// Asigna un atributo base según el método. Devuelve false (sin cambios)
  /// si el valor no es legal: fuera de rango, o compra de puntos que
  /// excedería los 27. En array estándar, si otro atributo ya tenía ese
  /// valor, se intercambian.
  bool setBaseScore(String ability, int value) {
    if (!kAbilityKeys.contains(ability)) return false;
    switch (_method) {
      case AbilityMethod.standardArray:
        if (!standardArray.contains(value)) return false;
        final other = _base.entries.where((e) => e.key != ability && e.value == value);
        _set(() {
          if (other.isNotEmpty) _base[other.first.key] = _base[ability]!;
          _base[ability] = value;
        });
        return true;
      case AbilityMethod.pointBuy:
        if (!pointBuyCost.containsKey(value)) return false;
        final next = {..._base, ability: value};
        if (_pointCost(next) > pointBuyBudget) return false;
        _set(() => _base[ability] = value);
        return true;
      case AbilityMethod.rolled:
        if (value < 3 || value > 18) return false;
        _set(() => _base[ability] = value);
        return true;
      case AbilityMethod.manual:
        if (value < 1 || value > 30) return false;
        _set(() => _base[ability] = value);
        return true;
    }
  }

  /// 4d6 descartando el menor, por atributo. Pasa a método `rolled`.
  void rollAbilityScores([Random? random]) {
    final expression = DiceExpression.tryParse('4d6')!;
    int roll() {
      final dice = [...expression.rollDetailed(random: random).groups.single.dice]..sort();
      return dice.skip(1).fold(0, (a, b) => a + b);
    }

    _set(() {
      _method = AbilityMethod.rolled;
      _base = {for (final k in kAbilityKeys) k: roll()};
    });
  }

  void setRacialBonus(String ability, int bonus) {
    if (!kAbilityKeys.contains(ability)) return;
    _set(() => _racial[ability] = bonus);
  }

  // ---------------------------- competencias ------------------------

  /// Marca/desmarca una habilidad de clase. false si no está entre las
  /// opciones de la clase o ya se agotaron las elecciones.
  bool toggleSkill(String skill) {
    final cls = _class;
    if (cls == null || !cls.skillOptions.contains(skill)) return false;
    if (_skills.contains(skill)) {
      _set(() {
        _skills.remove(skill);
        _expertise.remove(skill);
      });
      return true;
    }
    if (_skills.length >= cls.skillChoicesCount) return false;
    _set(() => _skills.add(skill));
    return true;
  }

  /// Pericia (solo sobre habilidades ya competentes). false si no aplica.
  bool toggleExpertise(String skill) {
    if (!_skills.contains(skill)) return false;
    if (!_expertise.contains(skill) && _expertise.length >= expertiseSlots) return false;
    _set(() => _expertise.contains(skill) ? _expertise.remove(skill) : _expertise.add(skill));
    return true;
  }

  // ----------------------------- equipo -----------------------------

  void toggleWeapon(SrdWeapon w) => _set(() {
        final i = _weapons.indexWhere((x) => x.id == w.id);
        i >= 0 ? _weapons.removeAt(i) : _weapons.add(w);
      });

  /// Un escudo y una armadura corporal como máximo: elegir otra
  /// armadura del mismo tipo reemplaza la anterior; elegir la misma la quita.
  void toggleArmor(SrdArmor a) => _set(() {
        if (a.category == 'escudo') {
          _shield = _shield?.id == a.id ? null : a;
        } else {
          _bodyArmor = _bodyArmor?.id == a.id ? null : a;
        }
      });

  void toggleSpell(SrdSpell s) => _set(() {
        final i = _spells.indexWhere((x) => x.name == s.name);
        i >= 0 ? _spells.removeAt(i) : _spells.add(s);
      });

  // ---------------------------- resultado ---------------------------

  /// Construye la ficha y la valida SIN exigir que esté libre de avisos:
  /// devuelve la ficha con los avisos no bloqueantes para la revisión del
  /// Paso 5. Lanza [CharacterCreationException] si el borrador está
  /// incompleto o si el validador reporta errores estructurales.
  CharacterPreview buildPreview() {
    final pending = problems;
    final i = input;
    if (pending.isNotEmpty || i == null) throw CharacterCreationException(pending);

    final result = CharacterValidator.validateMap(CharacterBuilderEngine.build(i).toJson());
    if (!result.isOk) {
      throw CharacterCreationException(
        [for (final issue in result.errors) '${issue.field}: ${issue.message}'],
      );
    }
    return CharacterPreview(result.character!, result.warnings);
  }

  /// Como [buildPreview], pero además exige cero avisos (una ficha creada
  /// aquí no debería tener ninguno).
  CharacterModel buildValidatedCharacter() {
    final preview = buildPreview();
    if (preview.warnings.isNotEmpty) {
      throw CharacterCreationException(
        [for (final w in preview.warnings) '${w.field}: ${w.message}'],
      );
    }
    return preview.character;
  }

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }
}
