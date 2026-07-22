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
/// Saneado de JSON pegado desde una IA. ChatGPT/Claude casi nunca devuelven
/// JSON "puro": suele venir envuelto en un bloque de código Markdown
/// (```json ... ```) y/o con texto de cortesía antes o después
/// ("¡Aquí tienes tu personaje!", "Espero que lo disfrutes"...).
/// jsonDecode() no tolera nada de eso y revienta con un FormatException
/// genérico — este helper se queda solo con el objeto JSON real antes de
/// intentar decodificarlo, para que el "texto extra" deje de ser un
/// problema para el jugador.
String _sanitizeJsonText(String raw) {
  var text = raw.trim();

  // Quita vallas de código Markdown si las hay (```json ... ``` o ``` ... ```).
  final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false)
      .firstMatch(text);
  if (fenceMatch != null) {
    text = fenceMatch.group(1)!.trim();
  }

  // Se queda con lo que hay entre la primera '{' y la última '}',
  // por si aún queda texto de cortesía antes o después del objeto.
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end != -1 && end > start) {
    text = text.substring(start, end + 1);
  }

  return text;
}

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
      // Fichas guardadas antes de que CharacterModel tuviera "id" ya
      // recibieron un id de fallback dentro de fromJson (ver
      // CharacterModel._generateId). Lo persistimos de inmediato para
      // que ese id quede fijo desde ya — si no lo guardáramos aquí,
      // cada reinicio de la app generaría uno distinto y cualquier
      // dato namespaceado por personaje (como el layout del HUD)
      // perdería la referencia constantemente.
      await _persistRoster();
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
    final decoded = jsonDecode(_sanitizeJsonText(jsonText)) as Map<String, dynamic>;
    final imported = CharacterModel.fromJson(decoded);

    roster.add(imported);
    _activeIndex = roster.length - 1;
    notifyListeners();

    await _persistRoster();
    await _persistActiveIndex();
  }

  /// Sustituye el personaje en la posición `index` del roster por el
  /// resultado de parsear `jsonText`, en vez de añadir uno nuevo. Pensado
  /// para aplicar la corrección que devuelve la IA tras pegar el prompt de
  /// `generateAIPrompt()`: el personaje ya se creó (o ya existía) en esa
  /// posición del roster, así que aquí solo hace falta reemplazar esa
  /// entrada por la versión corregida, sin duplicarla.
  /// Si `index` queda fuera de rango (p.ej. el roster cambió entre medias
  /// por otra acción del jugador), cae al comportamiento de
  /// `importCharacterFromJsonString` y lo añade al final en vez de
  /// fallar silenciosamente.
  Future<void> replaceCharacterFromJsonString(int index, String jsonText) async {
    final decoded = jsonDecode(_sanitizeJsonText(jsonText)) as Map<String, dynamic>;
    final imported = CharacterModel.fromJson(decoded);

    if (index < 0 || index >= roster.length) {
      roster.add(imported);
      _activeIndex = roster.length - 1;
    } else {
      roster[index] = imported;
      _activeIndex = index;
    }
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

  /// Igual que pickAvatarForActiveCharacter pero solo toca
  /// "loreAvatarPath": la foto que se ve en LoreTab. Deliberadamente
  /// independiente de avatarPath (el del header) — así el jugador puede
  /// ponerle al personaje una "foto de perfil" (ej. retrato heroico) y
  /// una "foto de crónica" distinta (ej. una escena o un boceto) sin que
  /// cambiar una afecte a la otra.
  Future<void> pickLoreAvatarForActiveCharacter() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    activeCharacter.loreAvatarPath = picked.path;
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
  /// texto, con la estructura base (campos vacíos) ya incluida para que
  /// la IA solo tenga que rellenarla.
  ///
  /// Tiene dos modos de origen para los datos del personaje:
  /// - [rawSourceText] presente (viene de pegar un JSON crudo de Nivel20 ya
  ///   pasado por `Nivel20Extractor.cleanRawJsonString()`): el prompt
  ///   incluye ese texto directamente, sin pedirle a la IA que visite nada.
  /// - [rawSourceText] ausente: modo clásico, le pide a la IA que visite el
  ///   enlace de Nivel20 guardado (`basicInfo.nivel20Link`).
  String generateAIPrompt({String? rawSourceText}) {
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

 if (rawSourceText != null && rawSourceText.trim().isNotEmpty) {
  return 'Actúa como experto en D&D. A continuación tienes el texto ya '
      'extraído de una ficha de Nivel20 (no hace falta que visites '
      'ningún enlace):\n\n$rawSourceText\n\n'
      'Vas a convertir esta ficha de personaje de D&D en un JSON con un '
      'formato EXACTO. Debes seguir ESTRICTAMENTE la estructura del '
      'ejemplo que te doy más abajo.\n\n'
      'Aviso: seguramente en muchos rasgos captures la versión recortada '
      'del texto; a la mínima que sospeches que un rasgo está incompleto, '
      'dímelo y te paso el texto entero. Lo mismo con cualquier duda: en '
      'cuanto tengas alguna, pregúntame antes de asumir nada.\n\n'
      'REGLAS OBLIGATORIAS:\n\n'
      'NO añadas ningún campo, clave o sección que no exista en el JSON '
      'de ejemplo. La app que lo lee no soporta campos extra y se '
      'romperá.\n\n'
      'NO elimines ningún campo del ejemplo, aunque esté vacío (usa "", '
      '[] o 0 si no hay dato). Mantén los mismos tipos de dato (número '
      'vs string vs booleano vs array).\n\n'
      '"spell_slots" es un array con un objeto por cada nivel de conjuro '
      'que tenga espacios (level, max, current). NO incluyas niveles con '
      '0 espacios. Ignora "conjuros preparados"; solo importan los '
      'espacios.\n\n'
      'Cada conjuro y truco del personaje = una habilidad dentro de '
      '"abilities_by_action", clasificada según su tiempo de lanzamiento:\n'
      '"action" → conjuros de 1 acción (incluye todos los trucos, '
      'base_level: 0)\n'
      '"bonus_action" → conjuros de 1 acción adicional\n'
      '"reaction" → conjuros de reacción\n\n'
      'Los rasgos de clase/raza (no conjuros) van en "passive", salvo que '
      'sean reacciones activas (ej. "Suerte del Oscuro"), que van en '
      '"reaction".\n\n'
      'Cada pasiva (cada objeto dentro de "passive") debe incluir además '
      'el campo "tactical_role", clasificándola en una de estas tres '
      'categorías EXACTAS (respeta mayúsculas, sin variaciones ni '
      'sinónimos): "Ofensivo" (aumenta daño propio, habilita ataques o '
      'efectos ofensivos), "Defensivo" (resistencias, PG extra, '
      'protección propia o de aliados), "Utilidad" (recursos, '
      'exploración, rasgos base/definición que no encajan en las dos '
      'anteriores). Si una pasiva combina varios usos, elige la función '
      'PRINCIPAL, no inventes una cuarta categoría. Este campo es '
      'EXCLUSIVO de "passive": no lo añadas a habilidades de "action", '
      '"bonus_action" ni "reaction".\n\n'
      '"attack_type": obligatorio en cada habilidad de "action", '
      '"bonus_action" y "reaction" (NUNCA en "passive" — las pasivas no '
      'lo llevan). Determina si el modal de resolución te pide tirar un '
      'ataque, muestra la CD de salvación fija, o ninguna de las dos. '
      'Valores EXACTOS permitidos, sin variaciones: "save", "attack", '
      '"none".\n'
      '- "save" → el OBJETIVO es quien tira, contra tu CD. Úsalo si el '
      'texto del conjuro/rasgo menciona una "tirada de salvación de '
      '[característica]" que el objetivo debe superar (ej. "el objetivo '
      'debe superar una salvación de Destreza").\n'
      '- "attack" → quien tira eres TÚ, para impactar. Úsalo si el texto '
      'dice "ataque de conjuro" (a distancia o cuerpo a cuerpo) o si es '
      'un ataque de arma.\n'
      '- "none" → no hay ninguna tirada enfrentada. Úsalo para curación '
      'automática, buffs sobre ti mismo, utilidad sin resistencia, '
      'invocaciones, etc.\n'
      '- Si el conjuro tiene un daño/efecto principal automático (sin '
      'tirada) pero además dispara una salvación SECUNDARIA para un '
      'efecto extra (ej. "si impactas, el objetivo también debe salvar '
      'Fuerza o caer derribado"), usa el "attack_type" que corresponde '
      'al efecto PRINCIPAL y explica la salvación secundaria en '
      '"lore_description" y/o "tactical_summary" — no inventes un cuarto '
      'valor para esto.\n'
      '- Si después de leer el texto sigue sin estar claro cuál de los '
      'tres aplica, PREGÚNTAME antes de asumir; no adivines.\n'
      '- Las armas dentro de "inventory.weapons" NO llevan "attack_type" '
      '— ese campo no existe para ellas, siempre se resuelven como '
      'ataque.\n\n'
      '"damage_dice": el dado BASE de daño o curación directa, al nivel '
      'mínimo del conjuro (base_level). Formato ESTRICTO, sin '
      'excepciones: notación de dado con o sin bono plano ("1d8", '
      '"2d6+3", "8d6-2"), o si el efecto no tira dado pero sí suma un '
      'número fijo, un plano puro ("+3"). NUNCA una frase, nunca texto '
      'explicativo, nunca notas entre paréntesis. Si el conjuro/truco/'
      'ataque no hace daño ni cura, usa "" (string vacío) — pero si SÍ '
      'hace daño o cura, este campo tiene que llevar el dado, aunque '
      'parezca redundante con lore_description o tactical_summary.\n\n'
      '"is_scalable": true si el conjuro mejora al lanzarse con un '
      'espacio de nivel superior o al subir de nivel de personaje; false '
      'si no escala nunca.\n\n'
      '"scaling_formula": SOLO rellenar si is_scalable es true. Mismo '
      'formato estricto que damage_dice: un único término de dado con o '
      'sin bono plano ("1d8", "2d4+1"), o un plano puro ("+2"). Es lo que '
      'se SUMA por cada nivel por encima de base_level — el motor de la '
      'app lo parsea con una expresión regular exacta, así que una frase '
      'como "+1d8 por nivel de conjuro superior" o "sube con el nivel '
      'del lanzador" NO funciona: el motor lo descarta en silencio y el '
      'conjuro no escala nada en combate. Si is_scalable es false, deja '
      '"scaling_formula": "".\n'
      '- Toda la explicación en prosa de CÓMO o CUÁNDO escala (radiante '
      'extra a muertos vivientes, condiciones especiales, etc.) va en '
      '"lore_description" y/o "tactical_summary", nunca en '
      '"scaling_formula".\n'
      '- Ejemplo correcto para un conjuro de curación que sube 1d8 por '
      'nivel de espacio: "damage_dice": "1d8", "scaling_formula": '
      '"1d8". Ejemplo INCORRECTO (no uses esto): "damage_dice": "", '
      '"scaling_formula": "+1d8 por nivel de conjuro superior."\n\n'
      '"base_level": nivel de conjuro mínimo al que se lanza (0 para '
      'trucos). Es el punto de partida desde el que se cuentan los '
      'niveles extra al escalar.\n\n'
      '"lore_info": si Rasgos / Ideales / Vínculos / Defectos están en '
      'blanco, invéntalos de forma coherente con la historia. Si la '
      'historia es muy larga, resúmela en un párrafo de 4-6 frases para '
      '"backstory", sin perder los hitos clave.\n\n'
      '"purse": monedas del personaje (gold, silver, copper), como '
      'números enteros independientes. Si no hay dinero, usa 0.\n\n'
      '"ai_tips": una serie de consejos generados por ti sobre cómo se '
      'usa el personaje.\n\n'
      '"user_tactics" y "adventure_notes" son campos de texto libre del '
      'Códice. NO los rellenes con contenido inventado: déjalos siempre '
      'como "" salvo que se te pida explícitamente redactar algo.\n\n'
      'SISTEMA DE RECURSOS ("resources"): Este array es para "pools" de '
      'puntos especiales (Ki, Puntos de Hechicería, Furia, Inspiración '
      'Bárdica, Superioridad, Canalizar Divinidad, etc.).\n'
      'Analiza la clase y nivel del personaje según las reglas oficiales '
      'de D&D 5e para deducir el máximo ("max") si la ficha no lo dice '
      'explícitamente (Ej: Monje Nivel 5 = 5 Puntos de Ki. Bardo con '
      'Carisma 16 = 3 Inspiraciones).\n'
      'Un objeto por recurso: { "name", "current", "max" }. "current" '
      'arranca igual que "max". Si la clase no tiene recursos gastables, '
      'usa un array vacío [].\n\n'
      'INVENTARIO ("inventory"): Las armas van en "weapons". IMPORTANTE: '
      'Incluye el campo "is_unique": true si el arma es legendaria, '
      'artefacto u objeto mágico irrepetible. Si es común, "is_unique": '
      'false.\n\n'
      'El resto de equipo (pociones, cuerdas, herramientas, reliquias) '
      'va en el array "mundane_items". Cada objeto usa: { "name", '
      '"description", "quantity" }.\n\n'
      'Si algo es ambiguo, PREGÚNTAME antes de asumir nada. No inventes '
      'mecánicas. Si falta un dato que SÍ existe en el texto de la ficha '
      '(ej. ac, hp_max, un stat), pregúntamelo.\n\n'
      'Devuélveme el JSON completo, sin comentarios ni texto fuera del '
      'bloque de código, y sin markdown adicional (solo el JSON listo '
      'para parsear).\n\n'
      'FORMATO EXACTO A SEGUIR (ejemplo mínimo con todos los campos):\n'
      '$structureJson';
}

    final link = activeCharacter.basicInfo.nivel20Link ?? '';
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
  // Estado de los recursos de acción del turno (acción, adicional,
  // movimiento) del personaje activo. "type" acepta 'action' y 'bonus'
  // — cualquier otro valor no hace nada, así la UI puede llamarlo sin
  // validar antes.
  //
  // Refactor "Reacción -> Movimiento": el antiguo tercer caso ('reaction')
  // desaparece de aquí porque el movimiento ya no es un toggle
  // usado/disponible — se gestiona con setMovementRemaining(), ver abajo.
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
      default:
        return;
    }
    notifyListeners();
    _persistRoster();
  }

  /// Fija cuánto movimiento le queda al personaje en el turno en curso.
  /// Se clampea entre 0 y BasicInfo.speed (no tiene sentido ni negativo
  /// ni por encima de su velocidad máxima), así la UI (_MovementTile en
  /// turn_tab.dart) puede pasar cualquier número tecleado sin validar
  /// antes y confiar en que aquí se corrige solo.
  void setMovementRemaining(int value) {
    final character = activeCharacter;
    character.turnStatus.movementRemaining =
        value.clamp(0, character.basicInfo.speed);
    notifyListeners();
    _persistRoster();
  }

  /// Pone acción/adicional a `false` (disponibles de nuevo) y recarga el
  /// movimiento a tope según BasicInfo.speed. Pensada para el botón "Fin
  /// de Turno" de turn_tab.dart.
  void resetTurn() {
    final character = activeCharacter;
    final status = character.turnStatus;
    status.actionUsed = false;
    status.bonusActionUsed = false;
    status.movementRemaining = character.basicInfo.speed;
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
  // Gestión de Habilidades (Ability) — alta y baja rápida
  // Las habilidades del personaje activo NO viven en una lista plana:
  // están repartidas en cuatro categorías de economía de acciones dentro
  // de activeCharacter.abilitiesByAction (action/bonusAction/reaction/
  // passive) — ver ability_model.dart. addAbility()/removeAbility()
  // trabajan sobre esa estructura real en vez de asumir una lista única,
  // para no divergir del modelo de datos ni de longRest()/customRest(),
  // que ya recorren las cuatro listas por separado.
  // -------------------------------------------------------------------

  /// Devuelve la lista interna correspondiente a una categoría de la
  /// economía de acciones. Acepta 'action', 'bonusAction', 'reaction' y
  /// 'passive'; cualquier otro valor cae en 'action' por defecto para que
  /// la UI no tenga que validar antes de llamar.
  List<Ability> _abilityListForType(String actionType) {
    final abilities = activeCharacter.abilitiesByAction;
    switch (actionType) {
      case 'bonusAction':
        return abilities.bonusAction;
      case 'reaction':
        return abilities.reaction;
      case 'passive':
        return abilities.passive;
      case 'action':
      default:
        return abilities.action;
    }
  }

  /// Añade una habilidad nueva y sencilla (solo nombre + descripción) a la
  /// categoría indicada del personaje activo. Pensada para el formulario
  /// rápido de la UI: el resto de campos mecánicos de Ability (relatedStat,
  /// attackType, damageDice...) quedan con sus valores por defecto y se
  /// pueden refinar más adelante desde una pantalla de edición si hace
  /// falta. La descripción libre se guarda en `loreDescription`, el campo
  /// pensado justamente para texto de sabor/rol sin mecánica asociada.
  ///
  /// El id se genera a partir del nombre y la marca de tiempo actual para
  /// que dos habilidades homebrew con el mismo nombre nunca choquen (el id
  /// es la clave estable que usa el resto del provider, p.ej.
  /// consumeAbilityCharge, para identificar la habilidad).
  /// Añade una habilidad nueva al personaje activo. Los parámetros básicos
  /// (name, description, actionType) cubren el formulario simple; el resto
  /// son el bloque "Avanzado" opcional del modal de alta y llevan valores
  /// por defecto neutros para que el atajo simple siga funcionando igual
  /// que antes si la UI no los manda.
  ///
  /// - `type`: 'trait' o 'spell'. Se ignora (y se fuerza a 'passive') si
  ///   actionType == 'passive', porque una pasiva nunca es un conjuro
  ///   tirable — mismo criterio que ya usaba la versión simple de este
  ///   método.
  /// - `tacticalRole` solo tiene efecto en pasivas (agrupa el HUD por
  ///   Ofensivo/Defensivo/Utilidad); en cualquier otra categoría se
  ///   ignora, porque Ability.tacticalRole no se usa fuera de _PassivesSection.
  /// - `hasCharges`/`maxCharges`: si hasCharges es true se construye un
  ///   MagicCharges a tope de carga (current = max) vía
  ///   MagicCharges.fromJson(), reutilizando su propio parseo en vez de
  ///   asumir el constructor real de la clase (que vive en
  ///   weapon_model.dart y no tengo delante) — incluso si su forma
  ///   interna cambia, mientras siga leyendo has_charges/max/current esto
  ///   no se rompe.
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
    final trimmedName = name.trim();
    final list = _abilityListForType(actionType);
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
      scalingFormula: (trimmedScalingFormula == null || trimmedScalingFormula.isEmpty)
          ? null
          : trimmedScalingFormula,
      damageDice: (trimmedDamageDice == null || trimmedDamageDice.isEmpty) ? null : trimmedDamageDice,
      loreDescription: description.trim().isEmpty ? null : description.trim(),
      tacticalSummary:
          (trimmedTacticalSummary == null || trimmedTacticalSummary.isEmpty) ? null : trimmedTacticalSummary,
      // tacticalRole solo aplica a pasivas — en el resto de categorías
      // Ability lo acepta igualmente (es un campo libre) pero ninguna
      // pantalla lo lee fuera de _PassivesSection, así que forzarlo a
      // null evita guardar en el JSON un dato que nunca se va a mostrar.
      tacticalRole: isPassive && trimmedTacticalRole != null && trimmedTacticalRole.isNotEmpty
          ? trimmedTacticalRole
          : null,
      magicCharges: hasCharges
          ? MagicCharges.fromJson({
              'has_charges': true,
              'max': maxCharges,
              'current': maxCharges,
            })
          : null,
    );
    list.add(newAbility);
    notifyListeners();
    _persistRoster();
  }

  /// Actualiza una habilidad existente del personaje activo, identificada
  /// por su `id` (que se conserva — nunca se regenera al editar, para no
  /// romper referencias como Ability.magicCharges en SharedPreferences).
  /// Si `actionType` es distinto de la categoría original, la habilidad
  /// se mueve de lista (ej. pasar de "Acción" a "Pasiva"): se quita de su
  /// lista actual y se añade a la nueva, no se reordena in-place, así que
  /// puede perder su posición relativa dentro de la lista destino.
  ///
  /// No hace nada si el id no existe en ninguna de las cuatro categorías
  /// (habilidad borrada mientras el modal de edición seguía abierto, por
  /// ejemplo). Mismos parámetros y mismos valores por defecto que
  /// addAbility(); ver los comentarios de ahí para el detalle de cada uno.
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
    final abilities = activeCharacter.abilitiesByAction;

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
      id: abilityId,
      name: trimmedName.isEmpty ? existing.name : trimmedName,
      type: isPassive ? 'passive' : (type ?? existing.type),
      relatedStat: relatedStat,
      // successDescription/failureDescription no los expone el formulario
      // de edición — se conservan tal cual estaban en vez de vaciarlos.
      successDescription: existing.successDescription,
      failureDescription: existing.failureDescription,
      attackType: attackType,
      isScalable: isScalable,
      baseLevel: baseLevel,
      scalingFormula: (trimmedScalingFormula == null || trimmedScalingFormula.isEmpty)
          ? null
          : trimmedScalingFormula,
      damageDice: (trimmedDamageDice == null || trimmedDamageDice.isEmpty) ? null : trimmedDamageDice,
      loreDescription: description.trim().isEmpty ? null : description.trim(),
      tacticalSummary:
          (trimmedTacticalSummary == null || trimmedTacticalSummary.isEmpty) ? null : trimmedTacticalSummary,
      tacticalRole: isPassive && trimmedTacticalRole != null && trimmedTacticalRole.isNotEmpty
          ? trimmedTacticalRole
          : null,
      magicCharges: hasCharges
          ? MagicCharges.fromJson({
              'has_charges': true,
              'max': maxCharges,
              'current': maxCharges,
            })
          : null,
    );

    sourceList.remove(existing);
    _abilityListForType(actionType).add(updated);
    notifyListeners();
    _persistRoster();
  }

  /// Elimina una habilidad del personaje activo buscándola por su id en
  /// las cuatro categorías de la economía de acciones. No hace nada si el
  /// id no existe en ninguna, así la UI puede llamarlo sin validar antes
  /// (p.ej. tras una doble pulsación accidental sobre el botón de borrar).
  void removeAbility(String abilityId) {
    final abilities = activeCharacter.abilitiesByAction;
    for (final list in [
      abilities.action,
      abilities.bonusAction,
      abilities.reaction,
      abilities.passive,
    ]) {
      final index = list.indexWhere((a) => a.id == abilityId);
      if (index != -1) {
        list.removeAt(index);
        notifyListeners();
        _persistRoster();
        return;
      }
    }
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