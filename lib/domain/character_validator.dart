// Validación de fichas importadas (texto pegado de una IA o JSON de
// archivo).
//
// La filosofía es deliberadamente permisiva, en dos niveles:
//
// - ERROR bloqueante SOLO en lo que hace imposible construir una ficha
//   util: JSON indecodable, sin "basic_info", sin nombre, o con un
//   "hp_max" que no sea número. Cuatro cosas nomás — todo lo demás
//   tiene fallback en el modelo.
// - WARNING para el resto: atributos que faltan (valen 10), dados
//   malformados (el HUD no podrá tirarlos), condiciones desconocidas
//   (sin descripción en combate)... El wizard de importación (Etapa 3)
//   muestra la lista CON vista previa de la ficha antes de confirmar,
//   para que el jugador decida si la IA le entregó algo decente o si
//   conviene pedirle una corrección.
//
// El validador NO corrige nada por sí mismo: solo reporta. Quien aplica
// los fallbacks es CharacterModel.fromJson — mismo reparto que en la
// app vieja, solo que acá los umbrales están escritos en un solo lugar
// y con tests.

import 'dart:convert';

import '../core/dice.dart';
import '../core/dnd_rules.dart';
import '../core/json_sanitizer.dart';
import 'models/character.dart';

/// Qué tan grave es un problema detectado en la ficha.
enum ValidationSeverity {
  /// Bloquea la importación: sin esto la ficha no puede existir.
  error,

  /// La ficha entra igual, pero con fallbacks aplicados.
  warning,
}

class ValidationIssue {
  final ValidationSeverity severity;

  /// Dónde está el problema, como ruta estilo JSON:
  /// "basic_info.name", "inventory.weapons[Espada].damage.base_dice"...
  final String field;

  /// Qué pasa y qué fallback se aplicará. Redactado para mostrarse
  /// directo al jugador en el wizard de importación.
  final String message;

  const ValidationIssue({
    required this.severity,
    required this.field,
    required this.message,
  });

  bool get isError => severity == ValidationSeverity.error;
  bool get isWarning => severity == ValidationSeverity.warning;
}

class CharacterValidationResult {
  /// La ficha construida, o null si hubo errores bloqueantes.
  final CharacterModel? character;

  /// Todos los problemas encontrados, en el orden en que se detectaron
  /// (matches el orden de lectura del JSON, así la lista se lee
  /// natural en la UI).
  final List<ValidationIssue> issues;

  const CharacterValidationResult({
    required this.character,
    required this.issues,
  });

  bool get isOk => character != null;

  List<ValidationIssue> get errors =>
      issues.where((i) => i.isError).toList();

  List<ValidationIssue> get warnings =>
      issues.where((i) => i.isWarning).toList();
}

class CharacterValidator {
  CharacterValidator._(); // clase estática: no se instancia.

  /// Sanea, decodifica y valida un texto pegado (típicamente la
  /// respuesta de una IA, con vallas de código Markdown y cortesía
  /// alrededor — de eso se encarga sanitizeJsonText).
  static CharacterValidationResult parseAndValidate(String rawText) {
    final sanitized = sanitizeJsonText(rawText);
    dynamic decoded;
    try {
      decoded = jsonDecode(sanitized);
    } on FormatException catch (e) {
      return _blocked('json', 'El texto no contiene un JSON válido: ${e.message}');
    }
    if (decoded is! Map) {
      return _blocked(
        'json',
        'El JSON no es un objeto de ficha (¿llegó un array o un número suelto?).',
      );
    }
    // Pasada tolerante: corrige torpezas típicas de la IA (números entre
    // comillas, null por []...) antes de validar.
    return validateMap(normalizeCharacterJson(decoded.cast<String, dynamic>()));
  }

  /// Valida un mapa ya decodificado. Expuesto aparte para tests y para
  /// el editor manual (Etapa 4), que valida en memoria sin pasar por
  /// texto.
  static CharacterValidationResult validateMap(Map<String, dynamic> json) {
    // ------------------- ERRORES BLOQUEANTES -------------------
    final basicRaw = json['basic_info'];
    if (basicRaw is! Map) {
      return _blocked('basic_info', 'La ficha no tiene el objeto "basic_info".');
    }
    final basic = basicRaw;

    final name = basic['name'];
    if (name is! String || name.trim().isEmpty) {
      return _blocked('basic_info.name', 'El personaje no tiene nombre.');
    }

    final hpMax = basic['hp_max'];
    if (hpMax is! num) {
      return _blocked('basic_info.hp_max', '"hp_max" falta o no es un número.');
    }

    // ----------------------- WARNINGS --------------------------
    final issues = <ValidationIssue>[];
    void warn(String field, String message) => issues.add(ValidationIssue(
          severity: ValidationSeverity.warning,
          field: field,
          message: message,
        ));

    _warnBasicInfo(basic, warn);
    _warnStats(json, warn);
    _warnWeapons(json, warn);
    _warnAbilities(json, warn);
    _warnConditions(json, warn);

    // Sin errores bloqueantes → construir la ficha (fromJson aplica
    // los fallbacks que los warnings anunciaron). Si el modelo revienta
    // con algo que no anticipamos, se reporta como error bloqueante en
    // vez de tirar la app.
    try {
      final model = CharacterModel.fromJson(json);
      return CharacterValidationResult(character: model, issues: issues);
    } catch (e) {
      return _blocked('json', 'No se pudo construir la ficha: $e');
    }
  }

  static CharacterValidationResult _blocked(String field, String message) {
    return CharacterValidationResult(
      character: null,
      issues: [
        ValidationIssue(
          severity: ValidationSeverity.error,
          field: field,
          message: message,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Warning helpers. Trabaja sobre el JSON crudo (no sobre el modelo,
  // que ya escondió los datos ausentes detrás de sus fallbacks).
  // ---------------------------------------------------------------------

  static void _warnBasicInfo(
    Map basic,
    void Function(String, String) warn,
  ) {
    final characterClass = basic['characterClass'];
    final level = basic['level'];

    // Nivel: sin "level" numérico Y sin número pegado a la clase, la
    // competencia y los dados de golpe quedan en el mínimo.
    if (level is! num) {
      final hasDigitsInClass =
          characterClass is String && RegExp(r'\d').hasMatch(characterClass);
      if (!hasDigitsInClass) {
        warn('basic_info.level',
            'No se puede determinar el nivel; se asume 1 (competencia y dados de golpe quedarán cortos).');
      }
    }

    final hpMax = basic['hp_max'] as num;
    final hpCurrent = basic['hp_current'];
    if (hpCurrent is num && (hpCurrent < 0 || hpCurrent > hpMax)) {
      warn('basic_info.hp_current',
          '"hp_current" ($hpCurrent) queda fuera del rango 0-$hpMax; se ajustará en el primer cambio de vida.');
    }

    final speed = basic['speed'];
    if (speed is! num) {
      warn('basic_info.speed',
          'Sin "speed"; se asume 30 pies (velocidad humana estándar).');
    } else if (speed < 5 || speed > 120) {
      warn('basic_info.speed',
          '"speed" ($speed) fuera del rango 5-120 pies; ¿está en metros '
          'o es un error de la IA?');
    }

    if (basic['hit_die_sides'] is! num) {
      warn('basic_info.hit_die_sides',
          'Sin "hit_die_sides"; se infiere de la clase (d6/d8/d10/d12).');
    }
  }

  /// La CD de salvación depende de tener ranuras, así que se valida
  /// junto al resto del equipo de lanzador.
  static void _warnStats(
    Map<String, dynamic> json,
    void Function(String, String) warn,
  ) {
    final stats = json['stats'];
    if (stats is! Map ||
        ['str', 'dex', 'con', 'int', 'wis', 'cha']
            .any((k) => stats[k] is! Map)) {
      warn('stats',
          'Atributos incompletos; los que falten valen 10 (modificador +0).');
    }

    final slots = json['spell_slots'];
    final basic = json['basic_info'] as Map;
    if (slots is List && slots.isNotEmpty && basic['spell_save_dc'] is! num) {
      warn('basic_info.spell_save_dc',
          'Tiene ranuras de conjuro pero no "spell_save_dc"; el HUD no podrá mostrar la CD de salvación.');
    }
  }

  static void _warnWeapons(
    Map<String, dynamic> json,
    void Function(String, String) warn,
  ) {
    final inventory = json['inventory'];
    if (inventory is! Map) return;
    final weapons = inventory['weapons'];
    if (weapons is! List) {
      warn('inventory.weapons', 'Falta el inventario de armas.');
      return;
    }

    for (final raw in weapons) {
      if (raw is! Map) continue;
      final name = raw['name'] ?? 'sin nombre';
      final label = 'inventory.weapons[$name]';

      if (raw['id'] == null) {
        warn('$label.id',
            '"$name" no trae "id"; se genera uno al vuelo (no recomendado para objetos con cantidad).');
      }

      final damage = raw['damage'];
      final baseDice = damage is Map ? damage['base_dice'] : null;
      if (baseDice is String && baseDice.isNotEmpty) {
        if (DiceExpression.tryParse(baseDice) == null) {
          warn('$label.damage.base_dice',
              '"$name": el dado de daño "$baseDice" no es una notación válida; el HUD no podrá tirarlo.');
        }
      }

      final charges = raw['magic_charges'];
      if (charges is Map &&
          charges['has_charges'] == true &&
          charges['current'] is num &&
          charges['max'] is num &&
          (charges['current'] as num) > (charges['max'] as num)) {
        warn('$label.magic_charges',
            '"$name": más cargas actuales que el máximo; se dejará como está hasta el primer uso.');
      }

      if (raw['is_unique'] == true &&
          raw['quantity'] is num &&
          (raw['quantity'] as num) > 1) {
        warn('$label.quantity',
            '"$name" es única pero trae quantity ${(raw['quantity'])}; se fuerza a 1.');
      }
    }
  }

  static void _warnAbilities(
    Map<String, dynamic> json,
    void Function(String, String) warn,
  ) {
    final abilities = json['abilities_by_action'];
    if (abilities is! Map) {
      warn('abilities_by_action', 'La ficha no trae habilidades.');
      return;
    }

    var total = 0;
    for (final entry in abilities.entries) {
      final list = entry.value;
      if (list is! List) continue;
      total += list.length;

      for (final raw in list) {
        if (raw is! Map) continue;
        final name = raw['name'] ?? 'sin nombre';
        final label = 'abilities_by_action.${entry.key}[$name]';

        final damageDice = raw['damage_dice'];
        if (damageDice is String && damageDice.isNotEmpty) {
          if (DiceExpression.tryParse(damageDice) == null) {
            warn('$label.damage_dice',
                '"$name": el dado "$damageDice" no es una notación válida; el HUD no podrá tirarlo.');
          }
        }

        // Escalado prometido pero irresoluble: el motor lo descarta en
        // silencio, mejor que el jugador lo sechea antes de importar.
        if (raw['is_scalable'] == true) {
          final formula = raw['scaling_formula'];
          final resolvable =
              formula is String && DiceExpression.tryParse(formula) != null;
          if (!resolvable) {
            warn('$label.scaling_formula',
                '"$name" es escalable pero su fórmula ("$formula") no es resoluble; no escalará en combate.');
          }
        }

        final attackType = raw['attack_type'];
        if (attackType is String &&
            attackType.isNotEmpty &&
            !['save', 'attack', 'none'].contains(attackType)) {
          warn('$label.attack_type',
              '"$name": "attack_type" desconocido ("$attackType"); se asume "attack".');
        }
      }
    }

    if (total == 0) {
      warn('abilities_by_action',
          'La ficha no trae habilidades (acción/adicional/reacción/pasiva).');
    }
  }

  static void _warnConditions(
    Map<String, dynamic> json,
    void Function(String, String) warn,
  ) {
    final conditions = json['active_conditions'];
    if (conditions is! List) return;

    for (final condition in conditions) {
      if (condition is String && !DndRules.conditions.containsKey(condition)) {
        warn('active_conditions',
            '"$condition" no está en el catálogo de condiciones; no tendrá descripción ni aviso de desventaja.');
      }
    }
  }
}
