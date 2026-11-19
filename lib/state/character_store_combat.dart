part of 'character_store.dart';

/// Combate: HP, dados de golpe, descansos, ranuras de conjuro, cargas
/// mágicas, condiciones, economía de acción del turno, recursos y
/// compañeros.
///
/// Contrato de toda la extensión (heredado de la app vieja): la UI
/// puede llamar cualquier método SIN validar antes — cada uno se
/// autoprotege con guards (roster vacío, id inexistente, valor fuera
/// de rango) y clamps. Un botón deshabilitado igual llama, y nada
/// explota.
///
/// Con respecto a la app vieja, las cargas de armas/habilidades se
/// consumen por id estable (no por referencia al objeto): la UI nueva
/// reconstruye widgets a cada frame y las referencias sueltas eran una
/// fuente silenciosa de "gasté la carga del arma equivocada".
extension CharacterStoreCombat on CharacterStore {
  // -------------------------------------------------------------------
  // Vida.
  // -------------------------------------------------------------------

  /// Resta vida al personaje activo. Los PG temporales absorben primero;
  /// el resto baja currentHp (clampeado a 0, así un golpe sobredimensionado
  /// no deja el HP en negativo). Si el personaje ya estaba a 0 PG, el golpe
  /// cuenta como un fallo de salvación de muerte.
  void applyDamage(int amount) {
    final info = activeCharacter?.basicInfo;
    if (info == null) return;
    if (amount <= 0) return;
    final wasDown = info.currentHp <= 0;

    final absorbed = amount < info.tempHp ? amount : info.tempHp;
    info.tempHp -= absorbed;
    final rest = amount - absorbed;

    info.currentHp = (info.currentHp - rest).clamp(0, info.hpMax);
    if (wasDown && rest > 0) {
      info.deathSaveFailures = (info.deathSaveFailures + 1).clamp(0, 3);
    }
    _notifyAndPersist();
  }

  /// Suma vida al personaje activo. Nunca supera hpMax. Si estaba a 0 PG
  /// y se levanta, las salvaciones de muerte se reinician.
  void applyHealing(int amount) {
    final info = activeCharacter?.basicInfo;
    if (info == null) return;
    final wasDown = info.currentHp <= 0;
    info.currentHp = (info.currentHp + amount).clamp(0, info.hpMax);
    if (wasDown && info.currentHp > 0) _clearDeathSavesNoNotify(info);
    _notifyAndPersist();
  }

  /// Fija los PG temporales. Regla 5e: no se acumulan, se conserva el
  /// mayor entre el valor actual y el nuevo. Con [replace] se sobreescribe
  /// (corrección manual, p. ej. poner 0).
  void setTempHp(int amount, {bool replace = false}) {
    final info = activeCharacter?.basicInfo;
    if (info == null) return;
    final value = amount < 0 ? 0 : amount;
    info.tempHp = replace ? value : (value > info.tempHp ? value : info.tempHp);
    _notifyAndPersist();
  }

  /// Registra una salvación de muerte. Con 3 éxitos el personaje queda
  /// estable (se mantiene a 0 PG, contadores a la vista); con 3 fallos
  /// está muerto. La UI deriva ambos estados de los contadores.
  void addDeathSave({required bool success}) {
    final info = activeCharacter?.basicInfo;
    if (info == null) return;
    if (success) {
      info.deathSaveSuccesses = (info.deathSaveSuccesses + 1).clamp(0, 3);
    } else {
      info.deathSaveFailures = (info.deathSaveFailures + 1).clamp(0, 3);
    }
    _notifyAndPersist();
  }

  void resetDeathSaves() {
    final info = activeCharacter?.basicInfo;
    if (info == null) return;
    _clearDeathSavesNoNotify(info);
    _notifyAndPersist();
  }

  void _clearDeathSavesNoNotify(BasicInfo info) {
    info.deathSaveSuccesses = 0;
    info.deathSaveFailures = 0;
  }

  // -------------------------------------------------------------------
  // Dados de golpe (descanso corto).
  // -------------------------------------------------------------------

  /// Gasta hasta [diceCount] dados de golpe para recuperar vida. Por
  /// cada dado se tira 1d(hitDieSides) + mod. de Constitución (nunca
  /// menos de 1 por dado, regla estándar de 5e) y todo se aplica de una
  /// vez a currentHp.
  ///
  /// [diceCount] se clampea a los dados realmente disponibles, y
  /// [random] es inyectable para que los tests sean determinísticos.
  /// Devuelve el total curado, para que la UI lo muestre sin
  /// recalcularlo.
  int spendHitDice(int diceCount, {Random? random}) {
    final character = activeCharacter;
    if (character == null) return 0;
    final info = character.basicInfo;

    final actualCount = diceCount.clamp(0, info.hitDiceCurrent);
    if (actualCount <= 0) return 0;

    final conMod = character.stats.con.mod;
    // Red de seguridad: un hit_die_sides explícito de 0 o negativo en
    // el JSON haría reventar nextInt(); se cae a d8 (el más común).
    final sides = info.hitDieSides > 0 ? info.hitDieSides : 8;
    final rng = random ?? Random();

    var totalHealed = 0;
    for (var i = 0; i < actualCount; i++) {
      final roll = rng.nextInt(sides) + 1; // 1..sides
      final healedByDie = (roll + conMod) < 1 ? 1 : (roll + conMod);
      totalHealed += healedByDie;
    }

    info.hitDiceCurrent -= actualCount;
    info.currentHp = (info.currentHp + totalHealed).clamp(0, info.hpMax);

    _notifyAndPersist();
    return totalHealed;
  }

  // -------------------------------------------------------------------
  // Descansos.
  // -------------------------------------------------------------------

  /// Descanso largo: vida al máximo, todas las ranuras de conjuro
  /// recargadas, todas las cargas mágicas (armas y habilidades) a tope
  /// y la mitad de los dados de golpe recuperados (regla estándar de
  /// 5e, redondeando hacia arriba).
  void longRest() {
    final character = activeCharacter;
    if (character == null) return;

    character.basicInfo.currentHp = character.basicInfo.hpMax;
    character.basicInfo.tempHp = 0;
    _clearDeathSavesNoNotify(character.basicInfo);
    _restoreAllSpellSlotsNoNotify(character);
    _restoreAllWeaponCharges(character);
    _restoreAllAbilityCharges(character);
    _restoreResources(character, const {'short_rest', 'long_rest'});
    _restoreHalfHitDice(character);

    _notifyAndPersist();
  }

  /// Descanso a la carta: ejecuta solo lo marcado por el jugador en el
  /// modal de "Descanso Personalizado".
  void customRest({
    bool healMax = false,
    bool restoreSpells = false,
    bool restoreCharges = false,
  }) {
    final character = activeCharacter;
    if (character == null) return;

    if (healMax) {
      character.basicInfo.currentHp = character.basicInfo.hpMax;
      _clearDeathSavesNoNotify(character.basicInfo);
    }
    if (restoreSpells) _restoreAllSpellSlotsNoNotify(character);
    if (restoreCharges) {
      _restoreAllWeaponCharges(character);
      _restoreAllAbilityCharges(character);
      _restoreResources(character, const {'short_rest', 'long_rest'});
    }

    _notifyAndPersist();
  }

  /// Descanso corto: restaura los recursos con recovery 'short_rest'.
  /// Los dados de golpe se gastan aparte (spendHitDice), porque el
  /// jugador decide cuántos.
  void shortRest() {
    final character = activeCharacter;
    if (character == null) return;
    _restoreResources(character, const {'short_rest'});
    _notifyAndPersist();
  }

  // Descansos — helpers privados (sin notify: el descanso público
  // notifica y persiste una sola vez al final).

  void _restoreAllSpellSlotsNoNotify(CharacterModel character) {
    for (final slot in character.spellSlots.slots) {
      slot.current = slot.max;
    }
  }

  void _restoreResources(CharacterModel character, Set<String> recoveries) {
    for (final resource in character.resources) {
      if (recoveries.contains(resource.recovery)) {
        resource.current = resource.max;
      }
    }
  }

  void _restoreAllWeaponCharges(CharacterModel character) {
    for (final weapon in character.inventory.weapons) {
      if (weapon.magicCharges.hasCharges) weapon.magicCharges.restoreAll();
    }
  }

  void _restoreAllAbilityCharges(CharacterModel character) {
    for (final ability in character.abilitiesByAction.all) {
      if (ability.magicCharges.hasCharges) ability.magicCharges.restoreAll();
    }
  }

  /// Recupera hasta la mitad de los dados de golpe máximos
  /// (redondeando hacia arriba, mínimo 1), como marca 5e para el
  /// descanso largo.
  void _restoreHalfHitDice(CharacterModel character) {
    final info = character.basicInfo;
    if (info.hitDiceMax <= 0) return;
    final recovered = (info.hitDiceMax / 2).ceil().clamp(1, info.hitDiceMax);
    info.hitDiceCurrent = (info.hitDiceCurrent + recovered).clamp(
      0,
      info.hitDiceMax,
    );
  }

  // -------------------------------------------------------------------
  // Ranuras de conjuro.
  // -------------------------------------------------------------------

  /// Gasta una ranura del nivel indicado. No-op si no tiene ranuras de
  /// ese nivel o ya están a cero.
  void consumeSpellSlot(int level) {
    final slot = activeCharacter?.spellSlots.forLevel(level);
    if (slot == null || slot.current <= 0) return;
    slot.current -= 1;
    _notifyAndPersist();
  }

  /// Recupera UNA ranura del nivel indicado (el espejo de
  /// [consumeSpellSlot]). No-op si el nivel no existe o ya está lleno.
  /// Lo usa el ajuste fino del HUD cuando el jugador deshace un gasto;
  /// [restoreAllSpellSlots] sigue siendo el botón de recarga total.
  void restoreSpellSlot(int level) {
    final slot = activeCharacter?.spellSlots.forLevel(level);
    if (slot == null || slot.current >= slot.max) return;
    slot.current += 1;
    _notifyAndPersist();
  }

  /// Alias con el nombre que usa la sección "RANURAS DE MAGIA" del HUD.
  void spendSpellSlot(int level) => consumeSpellSlot(level);

  /// Recarga todas las ranuras del personaje activo.
  void restoreAllSpellSlots() {
    final character = activeCharacter;
    if (character == null) return;
    _restoreAllSpellSlotsNoNotify(character);
    _notifyAndPersist();
  }

  // -------------------------------------------------------------------
  // Cargas mágicas (armas y habilidades), por id estable.
  // -------------------------------------------------------------------

  void consumeWeaponCharge(String weaponId) {
    final weapon = _findWeapon(weaponId);
    if (weapon == null) return;
    if (weapon.magicCharges.hasCharges && weapon.magicCharges.current > 0) {
      weapon.magicCharges.consumeCharge();
      _notifyAndPersist();
    }
  }

  void restoreWeaponCharges(String weaponId) {
    final weapon = _findWeapon(weaponId);
    if (weapon == null) return;
    weapon.magicCharges.restoreAll();
    _notifyAndPersist();
  }

  void consumeAbilityCharge(String abilityId) {
    final ability = _findAbility(abilityId);
    if (ability == null) return;
    if (ability.magicCharges.hasCharges && ability.magicCharges.current > 0) {
      ability.magicCharges.consumeCharge();
      _notifyAndPersist();
    }
  }

  void restoreAbilityCharges(String abilityId) {
    final ability = _findAbility(abilityId);
    if (ability == null) return;
    ability.magicCharges.restoreAll();
    _notifyAndPersist();
  }

  // -------------------------------------------------------------------
  // Condiciones (Estados Alterados).
  // -------------------------------------------------------------------

  /// Activa/desactiva una condición sobre el personaje activo. No
  /// valida contra el catálogo a propósito: una condición "casera"
  /// que el jugador escriba a mano no se pierde, aunque no aporte
  /// descripción ni desventaja.
  void toggleCondition(String condition) {
    final conditions = activeCharacter?.activeConditions;
    if (conditions == null) return;
    if (conditions.contains(condition)) {
      conditions.remove(condition);
    } else {
      conditions.add(condition);
    }
    _notifyAndPersist();
  }

  /// Marca o desmarca con la estrella un poder (por id) del personaje
  /// activo.
  void toggleFavoritePower(String powerId) {
    final favorites = activeCharacter?.favoritePowers;
    if (favorites == null || powerId.isEmpty) return;
    if (!favorites.remove(powerId)) favorites.add(powerId);
    _notifyAndPersist();
  }

  /// true si alguna condición activa impone desventaja (Envenenado,
  /// Derribado, Asustado, Cegado...). Condiciones desconocidas se
  /// ignoran en vez de romper el cálculo.
  bool get hasDisadvantage {
    final conditions = activeCharacter?.activeConditions;
    if (conditions == null) return false;
    for (final condition in conditions) {
      final detail = DndRules.conditions[condition];
      if (detail != null && detail.causesDisadvantage) return true;
    }
    return false;
  }

  // -------------------------------------------------------------------
  // Economía de acción del turno.
  // -------------------------------------------------------------------

  /// Invierte el estado de uso de la acción ('action'), la acción
  /// adicional ('bonus') o la reacción ('reaction'); cualquier otro
  /// valor no hace nada.
  void toggleAction(String type) {
    final status = activeCharacter?.turnStatus;
    if (status == null) return;
    switch (type) {
      case 'action':
        status.actionUsed = !status.actionUsed;
        break;
      case 'bonus':
        status.bonusActionUsed = !status.bonusActionUsed;
        break;
      case 'reaction':
        status.reactionUsed = !status.reactionUsed;
        break;
      default:
        return;
    }
    _notifyAndPersist();
  }

  /// Fija el movimiento restante del turno. Se clampea entre 0 y la
  /// velocidad base del personaje (la UI puede pasar cualquier número
  /// tecleado sin validar).
  void setMovementRemaining(int value) {
    final character = activeCharacter;
    if (character == null) return;
    character.turnStatus.movementRemaining = value.clamp(
      0,
      character.basicInfo.speed,
    );
    _notifyAndPersist();
  }

  /// "Fin de turno": acción, adicional y reacción disponibles de nuevo,
  /// movimiento recargado a tope según la velocidad del personaje.
  void resetTurn() {
    final character = activeCharacter;
    if (character == null) return;
    final status = character.turnStatus;
    status.actionUsed = false;
    status.bonusActionUsed = false;
    status.reactionUsed = false;
    status.movementRemaining = character.basicInfo.speed;
    for (final pet in character.companions) {
      _resetCompanionTurnNoNotify(pet);
    }
    _notifyAndPersist();
  }

  // -------------------------------------------------------------------
  // Recursos genéricos (Ki, Hechicería, Furia, Inspiración...).
  // -------------------------------------------------------------------

  ResourcePoint? _findResource(String name) {
    final resources = activeCharacter?.resources;
    if (resources == null) return null;
    for (final resource in resources) {
      if (resource.name == name) return resource;
    }
    return null;
  }

  /// Gasta un punto del recurso indicado. Nunca baja de 0. No-op si el
  /// recurso no existe (la UI quedó desincronizada tras borrarlo).
  void decrementResource(String name) {
    final resource = _findResource(name);
    if (resource == null) return;
    resource.current = (resource.current - 1).clamp(0, resource.max);
    _notifyAndPersist();
  }

  /// Gasta [cost] puntos del recurso indicado (mínimo 0). No-op si no
  /// existe.
  void spendResource(String name, int cost) {
    final resource = _findResource(name);
    if (resource == null || cost <= 0) return;
    resource.current = (resource.current - cost).clamp(0, resource.max);
    _notifyAndPersist();
  }

  /// Recupera un punto del recurso indicado. Nunca supera su "max".
  void incrementResource(String name) {
    final resource = _findResource(name);
    if (resource == null) return;
    resource.current = (resource.current + 1).clamp(0, resource.max);
    _notifyAndPersist();
  }

  /// Recarga todos los recursos del personaje activo a su máximo.
  void restoreAllResources() {
    final resources = activeCharacter?.resources;
    if (resources == null) return;
    for (final resource in resources) {
      resource.current = resource.max;
    }
    _notifyAndPersist();
  }

  // -------------------------------------------------------------------
  // Compañeros / mascotas / invocaciones (por posición en la lista).
  // -------------------------------------------------------------------

  void addCompanion(Companion pet) {
    final companions = activeCharacter?.companions;
    if (companions == null) return;
    companions.add(pet);
    _notifyAndPersist();
  }

  /// No-op si el índice está fuera de rango (doble tap en borrar, etc.).
  void removeCompanion(int index) {
    final companions = activeCharacter?.companions;
    if (companions == null || index < 0 || index >= companions.length) return;
    companions.removeAt(index);
    _notifyAndPersist();
  }

  /// Suma/resta vida al compañero indicado (negativo = daño). Clampea
  /// entre 0 y su maxHp; no-op si no gestiona vida (hasHp == false).
  void updateCompanionHp(int index, int amount) {
    final companions = activeCharacter?.companions;
    if (companions == null || index < 0 || index >= companions.length) return;
    final pet = companions[index];
    if (!pet.hasHp) return;
    pet.currentHp = (pet.currentHp + amount).clamp(0, pet.maxHp);
    _notifyAndPersist();
  }

  // Compañeros por id (la UI de combate los direcciona así).

  Companion? companionById(String id) {
    final list = activeCharacter?.companions;
    if (list == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Daño (negativo) o curación (positivo) por id, con clamp. No-op si
  /// el id no existe o el compañero no gestiona vida.
  void applyCompanionHp(String id, int amount) {
    final pet = companionById(id);
    if (pet == null || !pet.hasHp) return;
    pet.currentHp = (pet.currentHp + amount).clamp(0, pet.maxHp);
    _notifyAndPersist();
  }

  /// Alterna acción, adicional o reacción gastada ('action' | 'bonus' |
  /// 'reaction'). Clave desconocida = no-op.
  void toggleCompanionAction(String id, String kind) {
    final pet = companionById(id);
    if (pet == null) return;
    switch (kind) {
      case 'action':
        pet.turn.actionUsed = !pet.turn.actionUsed;
      case 'bonus':
        pet.turn.bonusActionUsed = !pet.turn.bonusActionUsed;
      case 'reaction':
        pet.turn.reactionUsed = !pet.turn.reactionUsed;
      default:
        return;
    }
    _notifyAndPersist();
  }

  void toggleCompanionCondition(String id, String condition) {
    final pet = companionById(id);
    if (pet == null) return;
    if (!pet.conditions.remove(condition)) pet.conditions.add(condition);
    _notifyAndPersist();
  }

  void resetCompanionTurn(String id) {
    final pet = companionById(id);
    if (pet == null) return;
    _resetCompanionTurnNoNotify(pet);
    _notifyAndPersist();
  }

  void _resetCompanionTurnNoNotify(Companion pet) {
    pet.turn
      ..actionUsed = false
      ..bonusActionUsed = false
      ..reactionUsed = false
      ..movementRemaining = pet.speed;
  }
}
