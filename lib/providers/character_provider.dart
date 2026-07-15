// lib/providers/character_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character_model.dart';
import '../models/weapon_model.dart';
import '../models/ability_model.dart';
import '../models/serialization_extensions.dart'; // toJson() de Weapon/Ability/StatsBlock/Skill
import '../data/mock_data.dart';

/// Estados Alterados / Condiciones — detalle mecánico estático de una
/// condición (Apresado, Envenenado, Derribado...). Es intencionadamente un
/// dato de solo lectura, independiente de cualquier CharacterModel: la
/// ficha solo guarda el *nombre* de la condición activa
/// (CharacterModel.activeConditions); este objeto es el que le da
/// significado a ese nombre.
class ConditionDetail {
  final String description;
  final bool causesDisadvantage;

  const ConditionDetail({
    required this.description,
    this.causesDisadvantage = false,
  });
}

/// Diccionario estático de Estados Alterados / Condiciones disponibles en
/// la app. La clave es el nombre exacto que se guarda en
/// CharacterModel.activeConditions — debe coincidir tal cual con lo que
/// use la UI (chips/checkboxes) para seleccionar/deseleccionar. `const` a
/// propósito: son datos de reglas, no estado de personaje, así que no hay
/// necesidad (ni forma) de editarlos desde la app.
const Map<String, ConditionDetail> conditionDetails = {
  'Apresado': ConditionDetail(
    description:
        'La velocidad del personaje se reduce a 0 y no puede beneficiarse '
        'de ningún bonificador a su velocidad.',
    causesDisadvantage: false,
  ),
  'Envenenado': ConditionDetail(
    description:
        'El personaje sufre desventaja en tiradas de ataque y '
        'pruebas de característica.',
    causesDisadvantage: true,
  ),
  'Derribado': ConditionDetail(
    description:
        'El personaje solo puede moverse a rastras, tiene desventaja en '
        'tiradas de ataque y los ataques cuerpo a cuerpo contra él tienen '
        'ventaja.',
    causesDisadvantage: true,
  ),
  'Asustado': ConditionDetail(
    description:
        'El personaje tiene desventaja en tiradas de ataque y pruebas de '
        'característica mientras la fuente de su miedo esté a la vista, y '
        'no puede acercarse voluntariamente a ella.',
    causesDisadvantage: true,
  ),
  'Cegado': ConditionDetail(
    description:
        'El personaje no puede ver y falla automáticamente cualquier '
        'prueba que requiera vista. Tiene desventaja en tiradas de ataque '
        'y los ataques contra él tienen ventaja.',
    causesDisadvantage: true,
  ),
  'Ensordecido': ConditionDetail(
    description:
        'El personaje no puede oír y falla automáticamente cualquier '
        'prueba que requiera oído.',
    causesDisadvantage: false,
  ),
  'Paralizado': ConditionDetail(
    description:
        'El personaje está incapacitado, no puede moverse ni hablar, y '
        'falla automáticamente las salvaciones de Fuerza y Destreza. Los '
        'ataques contra él tienen ventaja y cualquier impacto cuerpo a '
        'cuerpo a menos de 1,5 metros es crítico automático.',
    causesDisadvantage: false,
  ),
  'Inconsciente': ConditionDetail(
    description:
        'El personaje está incapacitado, no puede moverse ni hablar y no '
        'es consciente de su entorno. Suelta lo que sostenga y cae '
        'derribado.',
    causesDisadvantage: false,
  ),
  'Aturdido': ConditionDetail(
    description:
        'El personaje está incapacitado, no puede moverse y solo puede '
        'hablar de forma entrecortada. Falla automáticamente las '
        'salvaciones de Fuerza y Destreza, y los ataques contra él tienen '
        'ventaja.',
    causesDisadvantage: false,
  ),
  'Agarrado': ConditionDetail(
    description:
        'La velocidad del personaje se convierte en 0 y no puede '
        'beneficiarse de ningún bonificador a su velocidad.',
    causesDisadvantage: false,
  ),
  'Invisible': ConditionDetail(
    description:
        'El personaje es imposible de ver sin ayuda mágica o sentidos '
        'especiales. Tiene ventaja en tiradas de ataque y los ataques '
        'contra él tienen desventaja.',
    causesDisadvantage: false,
  ),
  'Incapacitado': ConditionDetail(
    description: 'El personaje no puede realizar acciones ni reacciones.',
    causesDisadvantage: false,
  ),
};

/// Todo lo mutable del combate vive aquí. Desde la Fase 12, el provider ya
/// no gestiona un único CharacterModel sino un `roster` completo — cada
/// entrada se serializa entera (CharacterModel.toJson()) y se persiste como
/// String JSON dentro de una lista en SharedPreferences. Esto sustituye al
/// esquema anterior de claves sueltas por campo (hp, cargas, ranuras...),
/// que solo tenía sentido con un personaje único: con varios en el roster,
/// esas claves globales se pisarían entre sí.
class CharacterProvider extends ChangeNotifier {
  static const _rosterPrefsKey = 'character_roster_v2';
  static const _activeIndexPrefsKey = 'active_character_index';

  // Hotfix (Objetivo 2, Fase 11): cantidad por ítem de inventario. Se
  // mantiene indexado por el id estable del arma, igual que antes.
  // NOTA: al no llevar prefijo de personaje, dos personajes con un arma
  // del mismo id compartirían cantidad — limitación conocida, fuera del
  // alcance de la Fase 12, pendiente de revisar si llega a ser un problema
  // real con el roster.
  final Map<String, int> _weaponQuantities = {};

  List<CharacterModel> roster = [];
  int _activeIndex = 0;
  bool _isReady = false;

  bool get isReady => _isReady;
  int get activeIndex => _activeIndex;

  /// El personaje activo del roster. Si el roster todavía no se ha
  /// cargado (antes de init()), cae en el mock para que el HUD tenga algo
  /// que pintar mientras tanto.
  CharacterModel get activeCharacter {
    if (roster.isEmpty) return loadMockCharacter();
    return roster[_activeIndex.clamp(0, roster.length - 1)];
  }

  /// Alias de compatibilidad: todo el código de tabs/HUD anterior a la
  /// Fase 12 usa `character` directamente. En vez de reescribir cada
  /// referencia, `character` pasa a ser un getter sobre `activeCharacter`.
  CharacterModel get character => activeCharacter;

  int quantityFor(String weaponId) => _weaponQuantities[weaponId] ?? 1;

  CharacterProvider();

  /// Se llama una vez al arrancar, antes de mostrar el HUD real. Carga el
  /// roster guardado la sesión anterior; si no hay nada guardado (primera
  /// vez que se abre la app), siembra el roster con el personaje de mock.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final storedRoster = prefs.getStringList(_rosterPrefsKey);
    if (storedRoster != null && storedRoster.isNotEmpty) {
      roster = storedRoster
          .map((raw) => CharacterModel.fromJson(
              jsonDecode(raw) as Map<String, dynamic>))
          .toList();
    } else {
      // Protocolo de inicio en frío: Kael ha sido despedido.
      roster = []; 
      await _persistRoster();
    }

    _activeIndex = prefs.getInt(_activeIndexPrefsKey) ?? 0;
    // Evitamos errores de índice si la lista está vacía
    if (roster.isNotEmpty && (_activeIndex < 0 || _activeIndex >= roster.length)) {
      _activeIndex = 0;
    } else if (roster.isEmpty) {
      _activeIndex = 0;
    }

    _isReady = true;
    notifyListeners();
  }

  Future<void> _persistRoster() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = roster.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_rosterPrefsKey, encoded);
  }

  Future<void> _persistActiveIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeIndexPrefsKey, _activeIndex);
  }

  Future<void> _persistQuantity(String weaponId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('weapon_quantity_$weaponId', quantityFor(weaponId));
  }

  // -------------------------------------------------------------------
  // Fase 12 — Roster
  // -------------------------------------------------------------------

  /// Cambia el personaje activo del roster. No hace nada si el índice
  /// está fuera de rango, así el picker de la UI puede llamarlo sin
  /// validar antes.
  void switchCharacter(int index) {
    if (index < 0 || index >= roster.length) return;
    _activeIndex = index;
    notifyListeners();
    _persistActiveIndex();
  }

  /// Protocolo de Autodestrucción: Elimina un personaje del roster.
  /// Reajusta el índice activo automáticamente para no dejar al HUD apuntando al vacío.
  void deleteCharacter(int index) {
    if (index < 0 || index >= roster.length) return;

    // Eliminamos el objetivo de la base de datos
    roster.removeAt(index);

    // Reajuste de coordenadas del HUD
    if (roster.isEmpty) {
      // Si el roster se vacía, la WelcomeScreen entrará en acción
      _activeIndex = 0; 
    } else if (index <= _activeIndex) {
      // Si borramos el personaje activo o uno anterior, 
      // desplazamos el índice para no salirnos de los límites.
      _activeIndex = (_activeIndex - 1).clamp(0, roster.length - 1);
    }

    // Sincronizamos el servidor
    notifyListeners();
    _persistRoster();
    _persistActiveIndex();
  }

  /// Abre el selector de archivos del sistema, lee un .json del
  /// dispositivo, lo convierte a CharacterModel, lo añade al roster y lo
  /// deja como personaje activo. Si el usuario cancela el picker o el
  /// archivo no es un JSON válido, no hace nada (se podría añadir manejo
  /// de errores más fino en la UI si hace falta feedback visual).
  /// Contrapunto de importCharacterFromJson() para cuando el usuario no
  /// tiene el .json como archivo en el dispositivo (p.ej. lo copió de un
  /// chat o de una web) y prefiere pegar el texto directamente. Lanza
  /// FormatException si el texto no es JSON válido — la UI decide cómo
  /// mostrar ese error (ver character_selection_screen.dart).
  Future<void> importCharacterFromJsonString(String jsonText) async {
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    final imported = CharacterModel.fromJson(decoded);

    roster.add(imported);
    _activeIndex = roster.length - 1;
    notifyListeners();

    await _persistRoster();
    await _persistActiveIndex();
  }


  /// Abre la galería, y si el usuario elige una foto, la asigna como
  /// avatar del personaje activo y persiste el roster entero (el
  /// avatarPath vive dentro del CharacterModel serializado).
  Future<void> pickAvatarForActiveCharacter() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    activeCharacter.avatarPath = picked.path;
    notifyListeners();
    await _persistRoster();
  }

  // -------------------------------------------------------------------
  // Integración Nivel20 — enlace a la ficha externa + generador de
  // prompt para que una IA externa (ChatGPT, Claude...) visite ese
  // enlace y devuelva el personaje ya estructurado como nuestro JSON.
  // -------------------------------------------------------------------

  /// Guarda (o sustituye) el enlace de Nivel20 del personaje activo.
  void updateNivel20Link(String url) {
    activeCharacter.basicInfo.nivel20Link = url;
    notifyListeners();
    _persistRoster();
  }

  /// Construye el prompt listo para copiar y pegar en cualquier IA de
  /// texto: le pide que visite el enlace de Nivel20 guardado y devuelva
  /// los datos del personaje en nuestro formato JSON, con la estructura
  /// base (campos vacíos) ya incluida para que la IA solo tenga que
  /// rellenarla.
  String generateAIPrompt() {
    final link = activeCharacter.basicInfo.nivel20Link ?? '';

    const emptyStructure = {
      'basic_info': {
        'name': '',
        'race': '',
        'characterClass': '',
        'hp_max': 0,
        'hp_current': 0,
        'ac': 0,
      },
      'inventory': {
        'weapons': [],
        'mundane_items': [],
      },
      'abilities_by_action': {
        'action': [],
        'bonus_action': [],
        'reaction': [],
        'passive': [],
      },
      'stats': {},
      'spell_slots': [],
      'skills': [],
      'lore_info': {
        'backstory': '',
        'personality_traits': '',
        'ideals': '',
        'bonds': '',
        'flaws': '',
      },
      'purse': {
        'gold': 0,
        'silver': 0,
        'copper': 0,
      },
    };

    final structureJson = jsonEncode(emptyStructure);

    return 'Actúa como experto en D&D. Visita el siguiente enlace de la '
        'plataforma Nivel20: $link. Extrae todos los datos del personaje y '
        'devuélvelos estrictamente en este formato JSON (sin markdown '
        'adicional, solo el JSON listo para parsear): $structureJson.';
  }

  // -------------------------------------------------------------------
  // Hotfix (Objetivo 2): cantidad de inventario
  // -------------------------------------------------------------------

  void incrementQuantity(String weaponId) {
    _weaponQuantities[weaponId] = quantityFor(weaponId) + 1;
    notifyListeners();
    _persistQuantity(weaponId);
  }

  void decrementQuantity(String weaponId) {
    final next = quantityFor(weaponId) - 1;
    _weaponQuantities[weaponId] = next < 0 ? 0 : next;
    notifyListeners();
    _persistQuantity(weaponId);
  }

  // -------------------------------------------------------------------
  // Paso 1 (Vertical Slice) — Gestión de Oro
  // Cada denominación (oro/plata/cobre) es un stack independiente dentro
  // de activeCharacter.purse. No hay conversión automática entre ellas:
  // si el jugador quiere cambiar 10 pp por 1 po, lo hace manualmente
  // desde la propia UI (una resta y una suma).
  // -------------------------------------------------------------------

  /// Añade monedas de un tipo concreto a la bolsa del personaje activo.
  /// Ignora cantidades <= 0 para que la UI pueda llamarlo sin validar.
  void addCurrency(CurrencyType type, int amount) {
    if (amount <= 0) return;
    final purse = activeCharacter.purse;
    switch (type) {
      case CurrencyType.gold:
        purse.gold += amount;
        break;
      case CurrencyType.silver:
        purse.silver += amount;
        break;
      case CurrencyType.copper:
        purse.copper += amount;
        break;
    }
    notifyListeners();
    _persistRoster();
  }

  /// Gasta/resta monedas de un tipo concreto. Nunca deja el stack en
  /// negativo: si se intenta gastar más de lo que hay, se queda a 0.
  void spendCurrency(CurrencyType type, int amount) {
    if (amount <= 0) return;
    final purse = activeCharacter.purse;
    switch (type) {
      case CurrencyType.gold:
        final result = purse.gold - amount;
        purse.gold = result < 0 ? 0 : result;
        break;
      case CurrencyType.silver:
        final result = purse.silver - amount;
        purse.silver = result < 0 ? 0 : result;
        break;
      case CurrencyType.copper:
        final result = purse.copper - amount;
        purse.copper = result < 0 ? 0 : result;
        break;
    }
    notifyListeners();
    _persistRoster();
  }

  /// Fija un valor exacto para una denominación (p.ej. tras editar la
  /// cantidad a mano en un diálogo). Cualquier valor negativo se clampea
  /// a 0 en vez de rechazarse, para no obligar a la UI a validar antes.
  void setCurrency(CurrencyType type, int value) {
    final safeValue = value < 0 ? 0 : value;
    final purse = activeCharacter.purse;
    switch (type) {
      case CurrencyType.gold:
        purse.gold = safeValue;
        break;
      case CurrencyType.silver:
        purse.silver = safeValue;
        break;
      case CurrencyType.copper:
        purse.copper = safeValue;
        break;
    }
    notifyListeners();
    _persistRoster();
  }

  // -------------------------------------------------------------------
  // Paso 2 (Vertical Slice) — Códice / Diario
  // Los tres campos (aiTips, userTactics, adventureNotes) viven en la raíz
  // de activeCharacter, igual que loreInfo. Cada update es "todo o nada":
  // recibe el texto completo ya editado (la UI de codex_screen.dart
  // trabaja con un TextEditingController local y solo llama a estos
  // métodos on-change / on-save), así que no hace falta lógica de merge.
  // -------------------------------------------------------------------

  /// Sustituye las notas tácticas del jugador para el personaje activo.
  void updateUserTactics(String text) {
    activeCharacter.userTactics = text;
    notifyListeners();
    _persistRoster();
  }

  /// Sustituye el diario de aventura del personaje activo.
  void updateAdventureNotes(String text) {
    activeCharacter.adventureNotes = text;
    notifyListeners();
    _persistRoster();
  }

  /// Sustituye las notas de IA del personaje activo. De solo lectura en
  /// la UI actual (codex_screen.dart no muestra un campo editable para
  /// esto), pero se expone igualmente para cuando exista una integración
  /// que regenere estos consejos automáticamente.
  void setAiTips(String text) {
    activeCharacter.aiTips = text;
    notifyListeners();
    _persistRoster();
  }

  // -------------------------------------------------------------------
  // Paso 3 (Vertical Slice) — Sistema Genérico de Recursos
  // Puntos de Ki, Hechicería, Furia por día, etc. Cada ResourcePoint se
  // busca por nombre dentro de activeCharacter.resources — si no existe
  // (p.ej. la UI quedó desincronizada tras borrar el recurso desde otro
  // lado), el método no hace nada en vez de reventar.
  // -------------------------------------------------------------------

  ResourcePoint? _findResource(String name) {
    for (final r in activeCharacter.resources) {
      if (r.name == name) return r;
    }
    return null;
  }

  /// Gasta un punto del recurso indicado. Nunca baja de 0.
  void decrementResource(String name) {
    final resource = _findResource(name);
    if (resource == null) return;
    final next = resource.current - 1;
    resource.current = next < 0 ? 0 : next;
    notifyListeners();
    _persistRoster();
  }

  /// Recupera un punto del recurso indicado. Nunca supera su "max".
  void incrementResource(String name) {
    final resource = _findResource(name);
    if (resource == null) return;
    final next = resource.current + 1;
    resource.current = next > resource.max ? resource.max : next;
    notifyListeners();
    _persistRoster();
  }

  /// Recarga todos los recursos del personaje activo a su máximo. Pensada
  /// para engancharse al Protocolo de Descanso (longRest/customRest) más
  /// adelante; se expone ya como método público independiente para que la
  /// UI pueda ofrecer un botón de "recargar todo" sin esperar a esa
  /// integración.
  void restoreAllResources() {
    for (final resource in activeCharacter.resources) {
      resource.current = resource.max;
    }
    notifyListeners();
    _persistRoster();
  }

  // -------------------------------------------------------------------
  // Action Economy Tracker
  // Estado de los tres recursos de acción del turno (acción, adicional,
  // reacción) del personaje activo. "type" acepta 'action', 'bonus' y
  // 'reaction' — cualquier otro valor no hace nada, así la UI puede
  // llamarlo sin validar antes.
  // -------------------------------------------------------------------

  /// Invierte el estado de uso del recurso de turno indicado.
  void toggleAction(String type) {
    final status = activeCharacter.turnStatus;
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
    notifyListeners();
    _persistRoster();
  }

  /// Pone los tres recursos de turno a `false` (disponibles de nuevo).
  /// Pensada para el botón "Fin de Turno" de turn_tab.dart.
  void resetTurn() {
    final status = activeCharacter.turnStatus;
    status.actionUsed = false;
    status.bonusActionUsed = false;
    status.reactionUsed = false;
    notifyListeners();
    _persistRoster();
  }

  // -------------------------------------------------------------------
  // Mundane Items Inventory
  // Objetos no mágicos (raciones, cuerda, antorchas...) del personaje
  // activo. Se identifican por posición en la lista, igual que las armas,
  // así que removeMundaneItem/updateMundaneItemQuantity reciben el índice
  // dentro de activeCharacter.inventory.mundaneItems.
  // -------------------------------------------------------------------

  /// Añade un objeto mundano nuevo al inventario del personaje activo.
  void addMundaneItem({
    required String name,
    String description = '',
    int quantity = 1,
  }) {
    activeCharacter.inventory.mundaneItems.add(
      MundaneItem(
        name: name,
        description: description,
        quantity: quantity < 1 ? 1 : quantity,
      ),
    );
    notifyListeners();
    _persistRoster();
  }

  /// Elimina el objeto mundano en la posición indicada. No hace nada si
  /// el índice está fuera de rango, así la UI puede llamarlo sin validar.
  void removeMundaneItem(int index) {
    final items = activeCharacter.inventory.mundaneItems;
    if (index < 0 || index >= items.length) return;
    items.removeAt(index);
    notifyListeners();
    _persistRoster();
  }

  /// Fija una cantidad exacta para el objeto mundano en la posición
  /// indicada. Nunca deja la cantidad en negativo: valores menores a 0
  /// se clampean a 0 en vez de rechazarse.
  void updateMundaneItemQuantity(int index, int quantity) {
    final items = activeCharacter.inventory.mundaneItems;
    if (index < 0 || index >= items.length) return;
    items[index].quantity = quantity < 0 ? 0 : quantity;
    notifyListeners();
    _persistRoster();
  }

  // -------------------------------------------------------------------
  // Paso 7 (Vertical Slice) — Constructores rápidos de inventario
  // Altas directas de arma/objeto mundano desde la UI (diálogo de
  // "Añadir"), sin pasar por el flujo de importación de ficha completa.
  // -------------------------------------------------------------------

  /// Añade un arma ya construida (típicamente desde el diálogo de
  /// "Añadir Arma" de inventory_tab.dart) al inventario del personaje
  /// activo.
  void addNewWeapon(Weapon newWeapon) {
    activeCharacter.inventory.weapons.add(newWeapon);
    notifyListeners();
    _persistRoster();
  }

  /// Constructor rápido: añade un objeto mundano "placeholder" listo
  /// para que el jugador lo edite después (nombre "Nuevo Objeto",
  /// cantidad 1, sin descripción). Pensada para el caso en que el
  /// jugador quiere un ítem en la lista ya mismo y prefiere rellenar los
  /// detalles más tarde en vez de pararse a escribirlos en el diálogo.
  void addEmptyMundaneItem() {
    addMundaneItem(name: 'Nuevo Objeto');
  }

  // -------------------------------------------------------------------
  // Combate — todo el estado mutable vive en activeCharacter y cada
  // mutación se cierra persistiendo el roster completo.
  // -------------------------------------------------------------------

  void applyDamage(int amount) {
    final info = activeCharacter.basicInfo;
    info.currentHp = (info.currentHp - amount).clamp(0, info.hpMax);
    notifyListeners();
    _persistRoster();
  }

  void applyHealing(int amount) {
    final info = activeCharacter.basicInfo;
    info.currentHp = (info.currentHp + amount).clamp(0, info.hpMax);
    notifyListeners();
    _persistRoster();
  }

  void consumeWeaponCharge(Weapon weapon) {
    if (weapon.magicCharges.hasCharges && weapon.magicCharges.current > 0) {
      weapon.magicCharges.consumeCharge();
      notifyListeners();
      _persistRoster();
    }
  }

  void restoreWeaponCharges(Weapon weapon) {
    weapon.magicCharges.restoreAll();
    notifyListeners();
    _persistRoster();
  }

  /// Alias público con el nombre pedido para la sección "RANURAS DE
  /// MAGIA" de turn_tab.dart. Mismo comportamiento que consumeSpellSlot
  /// (que se mantiene porque resolution_modal.dart depende de ese
  /// nombre).
  void spendSpellSlot(int level) => consumeSpellSlot(level);

  void consumeSpellSlot(int level) {
    final slot = activeCharacter.spellSlots.forLevel(level);
    if (slot == null || slot.current <= 0) return;
    slot.current -= 1;
    notifyListeners();
    _persistRoster();
  }

  void restoreAllSpellSlots() {
    for (final slot in activeCharacter.spellSlots.slots) {
      slot.current = slot.max;
    }
    notifyListeners();
    _persistRoster();
  }

  void consumeAbilityCharge(Ability ability) {
    if (ability.magicCharges.hasCharges && ability.magicCharges.current > 0) {
      ability.magicCharges.consumeCharge();
      notifyListeners();
      _persistRoster();
    }
  }

  // -------------------------------------------------------------------
  // Fase 7 — Protocolo de Descanso
  // -------------------------------------------------------------------

  void _restoreHpToMax() {
    activeCharacter.basicInfo.currentHp = activeCharacter.basicInfo.hpMax;
  }

  void _restoreAllWeaponCharges() {
    for (final weapon in activeCharacter.inventory.weapons) {
      if (weapon.magicCharges.hasCharges) {
        weapon.magicCharges.restoreAll();
      }
    }
  }

  void _restoreAllAbilityCharges() {
    final abilities = activeCharacter.abilitiesByAction;
    for (final list in [
      abilities.action,
      abilities.bonusAction,
      abilities.reaction,
      abilities.passive,
    ]) {
      for (final ability in list) {
        if (ability.magicCharges.hasCharges) {
          ability.magicCharges.restoreAll();
        }
      }
    }
  }

  void _restoreAllSpellSlotsNoNotify() {
    for (final slot in activeCharacter.spellSlots.slots) {
      slot.current = slot.max;
    }
  }

  /// Reinicio total: vida al máximo, todos los espacios de conjuro
  /// recargados y todas las cargas mágicas (armas y habilidades) a tope.
  void longRest() {
    _restoreHpToMax();
    _restoreAllWeaponCharges();
    _restoreAllAbilityCharges();
    _restoreAllSpellSlotsNoNotify();
    notifyListeners();
    _persistRoster();
  }

  /// Descanso a la carta: ejecuta solo las acciones marcadas por el
  /// jugador en el modal de "Descanso Personalizado".
  void customRest({
    bool healMax = false,
    bool restoreSpells = false,
    bool restoreCharges = false,
  }) {
    if (healMax) _restoreHpToMax();
    if (restoreSpells) _restoreAllSpellSlotsNoNotify();
    if (restoreCharges) {
      _restoreAllWeaponCharges();
      _restoreAllAbilityCharges();
    }
    notifyListeners();
    _persistRoster();
  }

  // -------------------------------------------------------------------
  // Estados Alterados / Condiciones
  // El detalle mecánico de cada condición vive en el diccionario estático
  // `conditionDetails` (arriba). El personaje solo guarda los *nombres*
  // de sus condiciones activas en activeCharacter.activeConditions —
  // nombres que deben coincidir exactamente con las claves de
  // `conditionDetails` para que la UI pueda resolver descripción y
  // desventaja.
  // -------------------------------------------------------------------

  /// Activa/desactiva una condición sobre el personaje activo. Si la
  /// condición ya estaba activa, la quita; si no lo estaba, la añade. No
  /// valida contra `conditionDetails` a propósito: así una condición
  /// "casera" que el jugador escriba a mano desde la UI (si algún día se
  /// permite) no se pierde solo por no estar en el diccionario, aunque
  /// entonces no aportará descripción ni desventaja.
  void toggleCondition(String condition) {
    final conditions = activeCharacter.activeConditions;
    if (conditions.contains(condition)) {
      conditions.remove(condition);
    } else {
      conditions.add(condition);
    }
    notifyListeners();
    _persistRoster();
  }

  /// True si alguna condición activa del personaje impone desventaja
  /// (Envenenado, Derribado, Asustado, Cegado...). Condiciones activas
  /// que no están en `conditionDetails` (p.ej. una escrita a mano y no
  /// reconocida) se ignoran para este cálculo en vez de romperlo.
  bool get hasDisadvantage {
    for (final condition in activeCharacter.activeConditions) {
      final detail = conditionDetails[condition];
      if (detail != null && detail.causesDisadvantage) return true;
    }
    return false;
  }

  /// Utilidad rápida para el caso más común de daño por condición: resta
  /// vida al personaje activo igual que applyDamage. Se expone con
  /// nombre propio para que la UI de "Envenenado" pueda llamarla
  /// directamente sin tener que pasar por el flujo genérico de daño.
  void applyPoisonDamage(int damage) {
    applyDamage(damage);
  }

  // -------------------------------------------------------------------
  // Aliados Tácticos — Mascotas / Invocaciones / Compañeros
  // Se identifican por posición en la lista, igual que armas y objetos
  // mundanos, así que removeCompanion/updateCompanionHp reciben el
  // índice dentro de activeCharacter.companions.
  // -------------------------------------------------------------------

  /// Añade un aliado nuevo al roster táctico del personaje activo.
  void addCompanion(Companion pet) {
    activeCharacter.companions.add(pet);
    notifyListeners();
    _persistRoster();
  }

  /// Elimina el aliado en la posición indicada. No hace nada si el
  /// índice está fuera de rango, así la UI puede llamarlo sin validar.
  void removeCompanion(int index) {
    final companions = activeCharacter.companions;
    if (index < 0 || index >= companions.length) return;
    companions.removeAt(index);
    notifyListeners();
    _persistRoster();
  }

  /// Suma/resta vida al aliado en la posición indicada (amount negativo
  /// = daño, positivo = curación). Clampea entre 0 y su maxHp y no hace
  /// nada si el aliado no gestiona vida (hasHp == false) o el índice
  /// está fuera de rango.
  void updateCompanionHp(int index, int amount) {
    final companions = activeCharacter.companions;
    if (index < 0 || index >= companions.length) return;
    final pet = companions[index];
    if (!pet.hasHp) return;
    pet.currentHp = (pet.currentHp + amount).clamp(0, pet.maxHp);
    notifyListeners();
    _persistRoster();
  }
}