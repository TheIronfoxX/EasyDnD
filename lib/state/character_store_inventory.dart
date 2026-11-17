part of 'character_store.dart';

/// Inventario y datos de ficha editables: bolsa, códice, avatares,
/// armas (con su cantidad DENTRO de cada personaje — el fix del bug de
/// la app vieja), objetos mundanos y habilidades.
///
/// Mismo contrato que el resto del store: la UI llama sin validar y
/// cada método se cura solo.
extension CharacterStoreInventory on CharacterStore {
  // -------------------------------------------------------------------
  // Bolsa (oro/plata/cobre como stacks independientes, sin conversión
  // automática: si el jugador quiere cambiar moneda, lo hace a mano).
  // -------------------------------------------------------------------

  /// Añade monedas de un tipo. Ignora cantidades <= 0.
  void addCurrency(CurrencyType type, int amount) {
    final purse = activeCharacter?.purse;
    if (purse == null || amount <= 0) return;
    switch (type) {
      case CurrencyType.platinum:
        purse.platinum += amount;
      case CurrencyType.electrum:
        purse.electrum += amount;
      case CurrencyType.gold:
        purse.gold += amount;
      case CurrencyType.silver:
        purse.silver += amount;
      case CurrencyType.copper:
        purse.copper += amount;
    }
    _notifyAndPersist();
  }

  /// Gasta monedas de un tipo. Nunca deja el stack en negativo.
  void spendCurrency(CurrencyType type, int amount) {
    final purse = activeCharacter?.purse;
    if (purse == null || amount <= 0) return;
    switch (type) {
      case CurrencyType.platinum:
        purse.platinum = (purse.platinum - amount).clamp(0, purse.platinum);
      case CurrencyType.electrum:
        purse.electrum = (purse.electrum - amount).clamp(0, purse.electrum);
      case CurrencyType.gold:
        purse.gold = (purse.gold - amount).clamp(0, purse.gold);
      case CurrencyType.silver:
        purse.silver = (purse.silver - amount).clamp(0, purse.silver);
      case CurrencyType.copper:
        purse.copper = (purse.copper - amount).clamp(0, purse.copper);
    }
    _notifyAndPersist();
  }

  /// Fija un valor exacto para una denominación (edición a mano).
  /// Negativos se clampean a 0.
  void setCurrency(CurrencyType type, int value) {
    final purse = activeCharacter?.purse;
    if (purse == null) return;
    final safeValue = value < 0 ? 0 : value;
    switch (type) {
      case CurrencyType.platinum:
        purse.platinum = safeValue;
      case CurrencyType.electrum:
        purse.electrum = safeValue;
      case CurrencyType.gold:
        purse.gold = safeValue;
      case CurrencyType.silver:
        purse.silver = safeValue;
      case CurrencyType.copper:
        purse.copper = safeValue;
    }
    _notifyAndPersist();
  }

  // -------------------------------------------------------------------
  // Códice / Diario. Cada update es "todo o nada": recibe el texto
  // completo ya editado por el TextEditingController de la UI.
  // -------------------------------------------------------------------

  void updateUserTactics(String text) {
    final character = activeCharacter;
    if (character == null) return;
    character.userTactics = text;
    _notifyAndPersist();
  }

  void updateAdventureNotes(String text) {
    final character = activeCharacter;
    if (character == null) return;
    character.adventureNotes = text;
    _notifyAndPersist();
  }

  /// Añade una nota de sesión al diario del personaje activo. [now] es
  /// inyectable para tests. Devuelve la nota creada (o null sin ficha).
  SessionNote? addSessionNote({
    required String title,
    required String body,
    DateTime? now,
  }) {
    final character = activeCharacter;
    if (character == null) return null;
    final note = SessionNote(title: title.trim(), body: body, createdAt: now);
    character.sessionNotes.add(note);
    _notifyAndPersist();
    return note;
  }

  /// Edita título y cuerpo de una nota por id. Id inexistente = no-op.
  void updateSessionNote(String id, {String? title, String? body}) {
    final character = activeCharacter;
    if (character == null) return;
    final i = character.sessionNotes.indexWhere((n) => n.id == id);
    if (i < 0) return;
    final note = character.sessionNotes[i];
    if (title != null) note.title = title.trim();
    if (body != null) note.body = body;
    _notifyAndPersist();
  }

  void deleteSessionNote(String id) {
    final character = activeCharacter;
    if (character == null) return;
    final before = character.sessionNotes.length;
    character.sessionNotes.removeWhere((n) => n.id == id);
    if (character.sessionNotes.length != before) _notifyAndPersist();
  }

  /// Notas de IA: de solo lectura en el HUD actual, pero se expone
  /// igual para la integración que las regenere.
  void setAiTips(String text) {
    final character = activeCharacter;
    if (character == null) return;
    character.aiTips = text;
    _notifyAndPersist();
  }

  // -------------------------------------------------------------------
  // Avatares. El store SOLO fija la ruta: elegir la foto (ImagePicker)
  // es cosa de la UI, que le pasa el path ya resuelto.
  // -------------------------------------------------------------------

  /// Foto de perfil (header del HUD).
  void setAvatarPath(String? path) {
    final character = activeCharacter;
    if (character == null) return;
    character.avatarPath = path;
    _notifyAndPersist();
  }

  /// Foto de la pestaña Lore. Deliberadamente independiente de la de
  /// perfil: cambiar una no congela la otra.
  void setLoreAvatarPath(String? path) {
    final character = activeCharacter;
    if (character == null) return;
    character.loreAvatarPath = path;
    _notifyAndPersist();
  }

  // -------------------------------------------------------------------
  // Armas. Identificadas por su id estable (no por posición, a
  // diferencia de los objetos mundanos).
  // -------------------------------------------------------------------

  /// Añade un arma ya construida (diálogo de "Añadir Arma" de la UI).
  /// Si el arma es única, su cantidad se fuerza a 1 — el invariante del
  /// modelo, aplicado también en la puerta de entrada manual.
  void addNewWeapon(Weapon newWeapon) {
    final weapons = activeCharacter?.inventory.weapons;
    if (weapons == null) return;
    if (newWeapon.isUnique) newWeapon.quantity = 1;
    weapons.add(newWeapon);
    _notifyAndPersist();
  }

  /// Elimina el arma con el id indicado del inventario del personaje
  /// ACTIVO. No hay mapa global de cantidades que limpiar (ver
  /// weapon.dart): la cantidad viaja adentro del arma y muere con ella.
  void removeWeapon(String weaponId) {
    final weapons = activeCharacter?.inventory.weapons;
    if (weapons == null) return;
    final index = weapons.indexWhere((w) => w.id == weaponId);
    if (index == -1) return;
    weapons.removeAt(index);
    _notifyAndPersist();
  }

  /// Suma una copia del arma indicada, SOLO en el inventario del
  /// personaje activo. En la app vieja esto tocaba un mapa global por
  /// weaponId y dos personajes con el mismo arma compartían cantidad;
  /// ahora cada ficha tiene la suya.
  void incrementQuantity(String weaponId) {
    final weapon = _findWeapon(weaponId);
    if (weapon == null || weapon.isUnique) return; // única: siempre 1
    weapon.quantity++;
    _notifyAndPersist();
  }

  /// Resta una copia. Nunca baja de 0 (la app vieja permitía llegar a 0
  /// para "me quedé sin flechas").
  void decrementQuantity(String weaponId) {
    final weapon = _findWeapon(weaponId);
    if (weapon == null || weapon.isUnique) return;
    if (weapon.quantity > 0) weapon.quantity--;
    _notifyAndPersist();
  }

  // -------------------------------------------------------------------
  // Objetos mundanos (raciones, cuerda...), por posición en la lista.
  // -------------------------------------------------------------------

  void addMundaneItem({
    required String name,
    String description = '',
    int quantity = 1,
  }) {
    final items = activeCharacter?.inventory.mundaneItems;
    if (items == null) return;
    items.add(
      MundaneItem(
        name: name,
        description: description,
        quantity: quantity < 1 ? 1 : quantity,
      ),
    );
    _notifyAndPersist();
  }

  /// Constructor rápido: objeto "Nuevo Objeto" listo para editar después.
  void addEmptyMundaneItem() => addMundaneItem(name: 'Nuevo Objeto');

  /// No-op si el índice está fuera de rango.
  void removeMundaneItem(int index) {
    final items = activeCharacter?.inventory.mundaneItems;
    if (items == null || index < 0 || index >= items.length) return;
    items.removeAt(index);
    _notifyAndPersist();
  }

  /// Fija una cantidad exacta. Negativos se clampean a 0.
  void updateMundaneItemQuantity(int index, int quantity) {
    final items = activeCharacter?.inventory.mundaneItems;
    if (items == null || index < 0 || index >= items.length) return;
    items[index].quantity = quantity < 0 ? 0 : quantity;
    _notifyAndPersist();
  }

  // -------------------------------------------------------------------
  // Habilidades (Ability): alta/baja/edición por id estable. La edición
  // NO regenera el id (rompería referencias) y puede mover la
  /// habilidad de categoría (ej. de "Acción" a "Pasiva").
  // -------------------------------------------------------------------

  /// Añade una habilidad nueva a la categoría indicada ('action',
  /// 'bonusAction', 'reaction', 'passive'; cualquier otro valor cae en
  /// 'action'). El formulario rápido cubre nombre + descripción (que se
  /// guarda en loreDescription); el resto son el bloque "Avanzado"
  /// opcional del modal de alta.
  ///
  /// - `type` se fuerza a 'passive' si la categoría es passive (una
  ///   pasiva nunca es un conjuro tirable).
  /// - `tacticalRole` solo aplica a pasivas (agrupa el HUD por
  ///   Ofensivo/Defensivo/Utilidad); en el resto se descarta para no
  ///   guardar un dato que ninguna pantalla lee.
  void addAbility({
    required String actionType,
    required String name,
    String description = '',
    String? type,
    String relatedStat = '',
    String attackType = 'attack',
    String? damageDice,
    String? tacticalSummary,
    String? tacticalRole,
    bool isScalable = false,
    int baseLevel = 0,
    String? scalingFormula,
    bool hasCharges = false,
    int maxCharges = 0,
  }) {
    final character = activeCharacter;
    if (character == null) return;

    final trimmedName = name.trim();
    final isPassive = actionType == 'passive';

    final trimmedDamageDice = damageDice?.trim();
    final trimmedTacticalSummary = tacticalSummary?.trim();
    final trimmedTacticalRole = tacticalRole?.trim();
    final trimmedScalingFormula = scalingFormula?.trim();

    final newAbility = Ability(
      id: 'ability_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmedName.isEmpty ? 'Nueva Habilidad' : trimmedName,
      type: isPassive ? 'passive' : (type ?? 'trait'),
      relatedStat: relatedStat,
      successDescription: '',
      failureDescription: '',
      attackType: attackType,
      isScalable: isScalable,
      baseLevel: baseLevel,
      scalingFormula:
          (trimmedScalingFormula == null || trimmedScalingFormula.isEmpty)
          ? null
          : trimmedScalingFormula,
      damageDice: (trimmedDamageDice == null || trimmedDamageDice.isEmpty)
          ? null
          : trimmedDamageDice,
      loreDescription: description.trim().isEmpty ? null : description.trim(),
      tacticalSummary:
          (trimmedTacticalSummary == null || trimmedTacticalSummary.isEmpty)
          ? null
          : trimmedTacticalSummary,
      tacticalRole:
          isPassive &&
              trimmedTacticalRole != null &&
              trimmedTacticalRole.isNotEmpty
          ? trimmedTacticalRole
          : null,
      magicCharges: hasCharges
          ? MagicCharges(hasCharges: true, max: maxCharges, current: maxCharges)
          : null,
    );
    character.abilitiesByAction.listFor(actionType).add(newAbility);
    _notifyAndPersist();
  }

  /// Actualiza la habilidad con [abilityId] (id conservado). Si
  /// [actionType] cambió, la habilidad se muda de lista. No-op si el
  /// id no existe en ninguna categoría (borrada mientras el modal de
  /// edición seguía abierto, por ejemplo).
  ///
  /// successDescription/failureDescription no los edita el formulario:
  /// se conservan tal cual estaban.
  void updateAbility({
    required String abilityId,
    required String actionType,
    required String name,
    String description = '',
    String? type,
    String relatedStat = '',
    String attackType = 'attack',
    String? damageDice,
    String? tacticalSummary,
    String? tacticalRole,
    bool isScalable = false,
    int baseLevel = 0,
    String? scalingFormula,
    bool hasCharges = false,
    int maxCharges = 0,
  }) {
    final character = activeCharacter;
    if (character == null) return;
    final abilities = character.abilitiesByAction;

    Ability? existing;
    List<Ability>? sourceList;
    for (final list in [
      abilities.action,
      abilities.bonusAction,
      abilities.reaction,
      abilities.passive,
    ]) {
      final index = list.indexWhere((a) => a.id == abilityId);
      if (index != -1) {
        existing = list[index];
        sourceList = list;
        break;
      }
    }
    if (existing == null || sourceList == null) return;

    final isPassive = actionType == 'passive';
    final trimmedName = name.trim();

    final trimmedDamageDice = damageDice?.trim();
    final trimmedTacticalSummary = tacticalSummary?.trim();
    final trimmedTacticalRole = tacticalRole?.trim();
    final trimmedScalingFormula = scalingFormula?.trim();

    final updated = Ability(
      id: abilityId, // NUNCA se regenera al editar.
      name: trimmedName.isEmpty ? existing.name : trimmedName,
      type: isPassive ? 'passive' : (type ?? existing.type),
      relatedStat: relatedStat,
      successDescription: existing.successDescription,
      failureDescription: existing.failureDescription,
      attackType: attackType,
      isScalable: isScalable,
      baseLevel: baseLevel,
      scalingFormula:
          (trimmedScalingFormula == null || trimmedScalingFormula.isEmpty)
          ? null
          : trimmedScalingFormula,
      damageDice: (trimmedDamageDice == null || trimmedDamageDice.isEmpty)
          ? null
          : trimmedDamageDice,
      loreDescription: description.trim().isEmpty ? null : description.trim(),
      tacticalSummary:
          (trimmedTacticalSummary == null || trimmedTacticalSummary.isEmpty)
          ? null
          : trimmedTacticalSummary,
      tacticalRole:
          isPassive &&
              trimmedTacticalRole != null &&
              trimmedTacticalRole.isNotEmpty
          ? trimmedTacticalRole
          : null,
      magicCharges: hasCharges
          ? MagicCharges(hasCharges: true, max: maxCharges, current: maxCharges)
          : null,
    );

    sourceList.remove(existing);
    abilities.listFor(actionType).add(updated);
    _notifyAndPersist();
  }

  /// Elimina la habilidad con el id indicado, barriendo las cuatro
  /// categorías. No-op si no existe (doble pulsación en borrar, etc.).
  void removeAbility(String abilityId) {
    final character = activeCharacter;
    if (character == null) return;
    final abilities = character.abilitiesByAction;
    for (final list in [
      abilities.action,
      abilities.bonusAction,
      abilities.reaction,
      abilities.passive,
    ]) {
      final index = list.indexWhere((a) => a.id == abilityId);
      if (index != -1) {
        list.removeAt(index);
        _notifyAndPersist();
        return;
      }
    }
  }
}
