// Estado mutable del asistente de creación, desacoplado de la UI: solo
// guarda las decisiones del jugador y delega todo cálculo en
// CharacterBuilderEngine.

import 'dart:math';

import 'package:flutter/foundation.dart';

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

class CreationDraftController extends ChangeNotifier {
  static const List<int> standardArray = [15, 14, 13, 12, 10, 8];
  static const int pointBuyBudget = 27;
  static const Map<int, int> pointBuyCost = {
    8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9,
  };

  // Identidad
  String _name = '';
  String _race = '';
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
  void setLevel(int v) => _set(() {
        _level = v.clamp(1, 20);
        _pruneSpellsToClass();
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
      });

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
    final rng = random ?? Random();
    int roll() {
      final dice = List.generate(4, (_) => rng.nextInt(6) + 1)..sort();
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

  /// Construye la ficha final y la pasa por [CharacterValidator]. Lanza
  /// [CharacterCreationException] si el borrador está incompleto o si la
  /// validación da errores o avisos (una ficha creada aquí no debería
  /// tener ninguno).
  CharacterModel buildValidatedCharacter() {
    final pending = problems;
    final i = input;
    if (pending.isNotEmpty || i == null) throw CharacterCreationException(pending);

    final result = CharacterValidator.validateMap(CharacterBuilderEngine.build(i).toJson());
    if (result.issues.isNotEmpty || result.character == null) {
      throw CharacterCreationException(
        [for (final issue in result.issues) '${issue.field}: ${issue.message}'],
      );
    }
    return result.character!;
  }

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }
}
