// El estado central de la app: roster de fichas, personaje activo y
// todas las mutaciones de combate/inventario.
//
// En la app vieja esto era un dios-objeto de ~1.600 líneas mezclado con
// WebSocket, ImagePicker y SharedPreferences por todos lados. El rework
// lo parte en tres archivos `part` (roster, combate, inventario) que
// comparten la MISMA librería y por eso pueden tocar los privados del
// store: sigue siendo UN solo ChangeNotifier (una sola fuente de verdad
// para la UI), pero navegable por tema en vez de un muro monolítico.
//
// Lo que NO vive acá:
// - Persistencia: RosterRepository es el único que toca SharedPreferences.
// - Plugins (ImagePicker, file_picker): eso es UI; el store recibe
//   rutas y textos ya resueltos por pantallas.
// - Red: no hay. App 100% offline.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/dnd_rules.dart';
import '../data/roster_repository.dart';
import '../domain/character_validator.dart';
import '../domain/models/ability.dart';
import '../domain/models/character.dart';
import '../domain/models/session_note.dart';
import '../domain/models/weapon.dart';

part 'character_store_combat.dart';
part 'character_store_inventory.dart';
part 'character_store_roster.dart';

class CharacterStore extends ChangeNotifier {
  final RosterRepository _repository;

  /// El roster completo. Público a propósito: la UI lo lee para pintar
  /// listas (selector de personajes, etc.) sin getters decorativos.
  List<CharacterModel> roster = [];

  int _activeIndex = 0;

  /// False hasta que init() termina. La StartupGate (Etapa 5) lo usa
  /// para decidir entre splash y contenido real.
  bool _isReady = false;

  /// True solo en el arranque donde se migró el roster de la app vieja
  /// a la clave nueva. La UI puede mostrar "tus fichas fueron
  /// actualizadas" una única vez.
  bool _migratedFromLegacy = false;

  CharacterStore(this._repository);

  /// El personaje activo, o null si el roster está vacío. A propósito
  /// NULLABLE: la app vieja fabricaba un personaje mock para que el
  /// HUD nunca tuviera que lidiar con el vacío, y eso sostenía una
  /// ilusión frágil. La UI nueva muestra la bienvenida cuando esto es
  /// null, y cada método de mutación se autoprotege (no-op).
  CharacterModel? get activeCharacter {
    if (_activeIndex < 0 || _activeIndex >= roster.length) return null;
    return roster[_activeIndex];
  }

  int get activeIndex => _activeIndex;
  bool get isReady => _isReady;
  bool get migratedFromLegacy => _migratedFromLegacy;

  /// Arranque: carga el roster (con migración legacy si hace falta).
  /// Se llama una sola vez desde main() antes de pintar la primera
  /// pantalla; idempotente por las dudas.
  Future<void> init() async {
    if (_isReady) return;
    final snapshot = await _repository.load();
    roster = snapshot.roster;
    _activeIndex = snapshot.activeIndex;
    _migratedFromLegacy = snapshot.migratedFromLegacy;
    _isReady = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Privados compartidos por los tres `part` (misma librería).
  // ---------------------------------------------------------------------

  /// El corazón de cada mutación: avisa a la UI y persiste el roster
  /// COMPLETO en SharedPreferences. Fire-and-forget a propósito:
  /// ninguna acción de combate (un golpe, una carga gastada) puede
  /// quedarse esperando al disco. Si la app muere antes del flush, se
  /// pierde como mucho la última acción — mismo compromiso que la app
  /// vieja, ahora concentrado en un solo lugar.
  void _notifyAndPersist() {
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    await _repository.save(roster);
    await _repository.saveActiveIndex(_activeIndex);
  }

  /// Busca un arma del personaje activo por su id estable.
  Weapon? _findWeapon(String weaponId) {
    final weapons = activeCharacter?.inventory.weapons;
    if (weapons == null) return null;
    for (final weapon in weapons) {
      if (weapon.id == weaponId) return weapon;
    }
    return null;
  }

  /// Busca una habilidad del personaje activo por su id estable,
  /// barriendo las cuatro categorías de la economía de acciones.
  Ability? _findAbility(String abilityId) {
    final abilities = activeCharacter?.abilitiesByAction;
    if (abilities == null) return null;
    for (final ability in abilities.all) {
      if (ability.id == abilityId) return ability;
    }
    return null;
  }
}
