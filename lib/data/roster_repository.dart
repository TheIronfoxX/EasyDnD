// Único punto de acceso a SharedPreferences de toda la capa de datos.
//
// En la app vieja el provider tocaba SharedPreferences por todos lados
// (roster, índice activo, una clave suelta por cantidad de arma...) y
// las cantidades estaban indexadas SOLO por weaponId, sin namespace
// por personaje: dos fichas con un arma del mismo id compartían la
// cantidad. El rework:
//
//   - Guarda todo el roster como lista de JSON strings bajo UNA clave
//     nueva ("easydnd.roster.v3"), cantidades incluidas adentro de
//     cada arma → namespaceadas de facto por personaje.
//   - Migra el roster viejo ("character_roster_v2") al arrancar,
//     inyectando las cantidades desde las claves legacy
//     "weapon_quantity_<id>". La migración es NO destructiva (las
//     claves viejas se conservan) e idempotente (la presencia de la
//     clave nueva es el flag: si existe, ya se migró).
//   - En cuanto migra, persiste YA el resultado: los ids de fichas
//     legacy sin "id" se generan al vuelo y así quedan fijos desde el
//     primer arranque, sin regenerarse en cada reinicio.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/character.dart';

/// Lo que devuelve [RosterRepository.load] al arrancar la app.
class RosterSnapshot {
  final List<CharacterModel> roster;
  final int activeIndex;

  /// true solo en el arranque que ejecutó la migración legacy → v3.
  /// La UI puede mostrar un aviso "tus fichas fueron actualizadas"
  /// una única vez.
  final bool migratedFromLegacy;

  const RosterSnapshot({
    required this.roster,
    required this.activeIndex,
    required this.migratedFromLegacy,
  });
}

class RosterRepository {
  /// Clave del roster serializado (v3 = rework: armas con quantity y
  /// habilidades con magic_charges adentro del JSON de cada ficha).
  static const String rosterKey = 'easydnd.roster.v3';

  /// Clave del índice del personaje activo.
  static const String activeIndexKey = 'easydnd.active_index.v3';

  // --------------------- Legacy (app vieja) -------------------------
  static const String _legacyRosterKey = 'character_roster_v2';
  static const String _legacyActiveIndexKey = 'active_character_index';
  static const String _legacyQuantityPrefix = 'weapon_quantity_';

  final SharedPreferences _prefs;

  RosterRepository(this._prefs);

  /// Carga el roster. Tres caminos, en orden:
  ///
  /// 1. Clave v3 presente → decodificación directa (ruta normal).
  /// 2. Clave legacy presente → migrar (ver comentario de archivo) y
  ///    persistir el resultado bajo la clave v3.
  /// 3. Ninguna → instalación nueva: roster vacío.
  Future<RosterSnapshot> load() async {
    // Camino 1: ya existe el roster v3 (arranques normales post-migración).
    final storedV3 = _prefs.getStringList(rosterKey);
    if (storedV3 != null) {
      final roster = _decodeTolerant(storedV3);
      return RosterSnapshot(
        roster: roster,
        activeIndex: _clampedIndex(_prefs.getInt(activeIndexKey) ?? 0, roster.length),
        migratedFromLegacy: false,
      );
    }

    // Camino 3: instalación nueva, nada guardado bajo ninguna clave.
    final legacyStored = _prefs.getStringList(_legacyRosterKey);
    if (legacyStored == null) {
      // OJO sin `const`: una lista const es inmutable y el store
      // necesita poder hacer add() sobre roster al añadir el primer
      // personaje (el primer arranque pasa por acá).
      // ignore: prefer_const_constructors
      return RosterSnapshot(
        roster: [],
        activeIndex: 0,
        migratedFromLegacy: false,
      );
    }

    // Camino 2: primera ejecución del rework sobre datos de la app vieja.
    final roster = _decodeTolerant(legacyStored);
    _injectLegacyQuantities(roster);
    final activeIndex =
        _clampedIndex(_prefs.getInt(_legacyActiveIndexKey) ?? 0, roster.length);

    // Persistir YA bajo la clave nueva: fija los ids generados y hace
    // que el próximo arranque entre por el camino 1 (idempotencia).
    // Las claves legacy NO se tocan: si algo sale mal o el jugador
    // vuelve a instalar la app vieja, sus datos siguen ahí.
    await save(roster);
    await saveActiveIndex(activeIndex);

    return RosterSnapshot(
      roster: roster,
      activeIndex: activeIndex,
      migratedFromLegacy: true,
    );
  }

  /// Persiste el roster completo. Called por el store tras cada
  /// mutación (mismo compromiso que la app vieja: reescribir todo es
  /// barato para un roster local y evita sincronizar claves sueltas).
  Future<void> save(List<CharacterModel> roster) async {
    final encoded = roster.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList(rosterKey, encoded);
  }

  Future<void> saveActiveIndex(int index) async {
    await _prefs.setInt(activeIndexKey, index);
  }

  // ---------------------------------------------------------------------
  // Privados.
  // ---------------------------------------------------------------------

  /// Decodifica la lista de strings tolerando basura ENTRADA POR
  /// ENTRADA: una ficha corrupta se salta en vez de tirar todo el
  /// arranque (la app vieja reventaba entera si un solo string del
  /// roster no decodificaba). Perder una ficha ya corrupta es triste;
  /// perderlas todas por una es peor.
  List<CharacterModel> _decodeTolerant(List<String> rawEntries) {
    final roster = <CharacterModel>[];
    for (final raw in rawEntries) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          roster.add(CharacterModel.fromJson(decoded));
        }
      } catch (_) {
        // Entrada corrupta: se salta (ver comentario del método).
      }
    }
    return roster;
  }

  /// Migra las cantidades de las claves globales legacy
  /// ("weapon_quantity_<id>", compartidas entre personajes) al campo
  /// "quantity" de cada arma DENTRO de su ficha. Si un arma no tenía
  /// cantidad guardada, queda en el default 1 de Weapon.fromJson.
  void _injectLegacyQuantities(List<CharacterModel> roster) {
    for (final character in roster) {
      for (final weapon in character.inventory.weapons) {
        if (weapon.isUnique) continue; // única: siempre 1 por definición
        final stored = _prefs.getInt('$_legacyQuantityPrefix${weapon.id}');
        if (stored != null) weapon.quantity = stored;
      }
    }
  }

  int _clampedIndex(int raw, int length) {
    if (length == 0) return 0;
    return raw.clamp(0, length - 1);
  }
}
