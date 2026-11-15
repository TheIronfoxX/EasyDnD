// El prompt maestro de importación: la única fuente de verdad del texto
// que el jugador le pasa a su IA de confianza (ChatGPT, Claude...) para que
// convierta una ficha de D&D en el JSON que lee esta app.
//
// En la app vieja vivía en el asset `assets/promt.txt` (más una segunda
// copia RESUMIDA dentro de CharacterProvider.generateAIPrompt, que fue
// perdiendo reglas con el tiempo). El rework consolida TODO en este
// archivo: un solo cuerpo maestro y cuatro variantes de encabezado según
// de dónde vengan los datos del personaje.
//
// El texto de las constantes es un porte VERBATIM del prompt afinado en
// mesa por el jugador: cada regla existe porque la IA se equivocaba ahí
// (escalado que no parsea, jerga de D&D en tactical_summary, velocidad
// en pies...). Si se va a retocar, hacerlo sabiendo que es un artefacto
// probado, no texto decorativo.
//
// Es clase estática pura, sin estado: se puede llamar desde cualquier capa
// y se testea como cualquier función de texto.

/// Constructor privado: solo se usan los miembros estáticos.
class AiPrompt {
  AiPrompt._();

  // ---------------------------------------------------------------------
  // CUERPO MAESTRO (portado verbatim de assets/promt.txt).
  // ---------------------------------------------------------------------

  /// Presentación del encargo.
  static const String _intro =
      '''Vas a convertir la ficha de un personaje de D&D en un JSON con un formato EXACTO.
Te voy a pasar la ficha (PDF, texto, enlace a la plataforma Nivel20 o imagen) y tú debes generar el JSON siguiendo ESTRICTAMENTE la estructura del ejemplo de abajo.''';

  /// Aviso al modelo: preguntar antes de asumir rasgos incompletos.
  static const String _warning =
      '''Aviso, seguramente muchos de los rasgos pilles la version recortada, a la minima que sospeches de uno, dimelo y te lo paso entero, lo mismo con las dudas, a la minima mandalo porfaplis
Tambien, si de algun rasgo te falta informacion, NO DUDES EN PREGUNTAR ESTO ES MUY IMPORTANTE A LA MINIMA PREGUNTA''';

  /// TODAS las reglas del formato: campos, spell_slots, habilidades por
  /// economía de acciones, tactical_role, attack_type, damage_dice,
  /// escalado, lenguaje llano, recursos, inventario, monedas, velocidad,
  /// CD de salvación... y el cierre ("devuélveme el JSON completo").
  static const String _rules =
      '''REGLAS OBLIGATORIAS:

NO añadas ningún campo, clave o sección que no exista en el JSON de ejemplo. La app que lo lee no soporta campos extra y se romperá.

NO elimines ningún campo del ejemplo, aunque esté vacío (usa "", [] o 0 si no hay dato). Mantén los mismos tipos de dato (número vs string vs booleano vs array).

"spell_slots" es un array con un objeto por cada nivel de conjuro que tenga espacios (level, max, current). NO incluyas niveles con 0 espacios. Ignora "conjuros preparados"; solo importan los espacios.

Cada conjuro y truco del personaje = una habilidad dentro de "abilities_by_action", clasificada según su tiempo de lanzamiento:

"action" → conjuros de 1 acción (incluye todos los trucos, base_level: 0)
      Cosa importante, si alguno de los rasgos especifica una accion especifico, tambien hay que añadirlos aqui
      Un monje por ejemplo aqui deberia tener una tirada de daño basico, que seria su puñetazo

"bonus_action" → conjuros de 1 acción adicional

"reaction" → conjuros de reacción

Los rasgos de clase/raza (no conjuros) van en "passive", salvo que sean reacciones activas (ej. "Suerte del Oscuro"), que van en "reaction".

Cada pasiva (cada objeto dentro de "passive") debe incluir además el campo "tactical_role", clasificándola en una de estas tres categorías EXACTAS (respeta mayúsculas, sin variaciones ni sinónimos): "Ofensivo" (aumenta daño propio, habilita ataques o efectos ofensivos), "Defensivo" (resistencias, PG extra, protección propia o de aliados), "Utilidad" (recursos, exploración, rasgos base/definición que no encajan en las dos anteriores). Si una pasiva combina varios usos, elige la función PRINCIPAL, no inventes una cuarta categoría. Este campo es EXCLUSIVO de "passive": no lo añadas a habilidades de "action", "bonus_action" ni "reaction".

"attack_type": obligatorio en cada habilidad de "action", "bonus_action" y "reaction" (NUNCA en "passive" — las pasivas no lo llevan). Determina si el modal de resolución te pide tirar un ataque, muestra la CD de salvación fija, o ninguna de las dos. Valores EXACTOS permitidos, sin variaciones: "save", "attack", "none".
   - "save" → el OBJETIVO es quien tira, contra tu CD. Úsalo si el texto del conjuro/rasgo menciona una "tirada de salvación de [característica]" que el objetivo debe superar (ej. "el objetivo debe superar una salvación de Destreza").
   - "attack" → quien tira eres TÚ, para impactar. Úsalo si el texto dice "ataque de conjuro" (a distancia o cuerpo a cuerpo) o si es un ataque de arma.
   - "none" → no hay ninguna tirada enfrentada. Úsalo para curación automática, buffs sobre ti mismo, utilidad sin resistencia, invocaciones, etc.
   - Si el conjuro tiene un daño/efecto principal automático (sin tirada) pero además dispara una salvación SECUNDARIA para un efecto extra (ej. "si impactas, el objetivo también debe salvar Fuerza o caer derribado"), usa el "attack_type" que corresponde al efecto PRINCIPAL y explica la salvación secundaria en "lore_description" y/o "tactical_summary" — no inventes un cuarto valor para esto.
   - Si después de leer el texto sigue sin estar claro cuál de los tres aplica, PREGÚNTAME antes de asumir; no adivines.
   - Las armas dentro de "inventory.weapons" NO llevan "attack_type" — ese campo no existe para ellas, siempre se resuelven como ataque.

"damage_dice": el dado BASE de daño o curación directa, al nivel mínimo del conjuro (base_level). Formato ESTRICTO, sin excepciones: notación de dado con o sin bono plano ("1d8", "2d6+3", "8d6-2"), o si el efecto no tira dado pero sí suma un número fijo, un plano puro ("+3"). NUNCA una frase, nunca texto explicativo, nunca notas entre paréntesis. Si el conjuro/truco/ataque no hace daño ni cura, usa "" (string vacío) — pero si SÍ hace daño o cura, este campo tiene que llevar el dado, aunque parezca redundante con lore_description o tactical_summary.

"is_scalable": true si el conjuro mejora al lanzarse con un espacio de nivel superior o al subir de nivel de personaje; false si no escala nunca.

"scaling_formula": SOLO rellenar si is_scalable es true. Mismo formato estricto que damage_dice: un único término de dado con o sin bono plano ("1d8", "2d4+1"), o un plano puro ("+2"). Es lo que se SUMA por cada nivel por encima de base_level — el motor de la app lo parsea con una expresión regular exacta, así que una frase como "+1d8 por nivel de conjuro superior" o "sube con el nivel del lanzador" NO funciona: el motor lo descarta en silencio y el conjuro no escala nada en combate. Si is_scalable es false, deja "scaling_formula": "".
   - Toda la explicación en prosa de CÓMO o CUÁNDO escala (radiante extra a muertos vivientes, condiciones especiales, etc.) va en "lore_description" y/o "tactical_summary", nunca en "scaling_formula".
   - Ejemplo correcto para un conjuro de curación que sube 1d8 por nivel de espacio: "damage_dice": "1d8", "scaling_formula": "1d8". Ejemplo INCORRECTO (no uses esto): "damage_dice": "", "scaling_formula": "+1d8 por nivel de conjuro superior."

"base_level": nivel de conjuro mínimo al que se lanza (0 para trucos). Es el punto de partida desde el que se cuentan los niveles extra al escalar.

IMPORTANTE — a quién va dirigida la app: quien la usa en mesa NO tiene por qué saber jerga de D&D. No puedes dar por hecho que sabe qué es un "ataque a distancia", una "tirada de salvación", "CaC", ni qué significa que algo "escale". "tactical_summary" y "lore_description" tienen que decirle, en la práctica, qué dados coger y qué hacer con ellos — no limitarse a nombrar el mecanismo.

"tactical_summary": resumen corto de UNA o dos frases que le dice a la persona QUÉ HACER CON LOS DADOS, sin usar jerga de D&D (nada de "TS", "CaC", "ataque a distancia", "CD" a secas...). Escríbelo como si se lo explicaras a alguien que no ha jugado nunca: quién tira, qué dado, contra qué se compara, y qué pasa según el resultado. Formato:

   "[Frase en lenguaje llano sobre la tirada] | [Daño/Curación]: [dado] [Tipo]"

   - La parte de la tirada depende de attack_type, usa estas plantillas como base y adáptalas a cada caso concreto (rellena corchetes, no dejes el texto genérico):
     - attack_type "save" → "El enemigo (o todos los que estén en el área) tira un d20; si supera tu CD [dile el número si lo sabes, ej. "(13)"], [qué pasa en ese caso, ej. "solo recibe la mitad"]. Si no la supera, [qué pasa, ej. "recibe todo el daño"]."
     - attack_type "attack" → "Tiras un d20 y sumas +X [tu bonificador de ataque]; le dices el resultado al máster y él te dice si le has dado."
     - attack_type "none" → "No tienes que tirar nada, [qué ocurre directamente, ej. "el objetivo se cura al tocarlo", "el efecto pasa automáticamente"]."
   - La parte de "[Daño/Curación]" es "Daño:" o "Curación:" seguido del dado tal cual está en "damage_dice" (más "+ Mod" si el texto original suma el modificador de característica) y el tipo de daño en una palabra ("Fuego", "Cortante", "Radiante"...). Si no hay daño ni curación (buffs, utilidad pura), omite esta segunda mitad y deja solo la frase de la tirada.
   - Cuando el attack_type sea "save", usa el número real de la CD del personaje (el mismo que calcules para "spell_save_dc" en "basic_info") en vez de dejar el corchete genérico — ej. "si supera tu CD (14)".
   - Ejemplos de referencia (síguelos al pie de la letra, en tono y nivel de detalle):
     - Bola de Fuego: "Los enemigos en el área tiran un d20; si superan tu CD reciben solo la mitad del daño, si no la superan reciben todo el daño | Daño: 8d6 Fuego"
     - Rayo de Fuego: "Tiras un d20 y sumas +10; le dices el resultado al máster y él te dice si le has dado | Daño: 2d10 Fuego"
     - Curar Heridas: "No tienes que tirar nada, el objetivo se cura al tocarlo | Curación: 1d8 + Mod"
     - Un arma cuerpo a cuerpo: "Tiras un d20 y sumas +4; le dices el resultado al máster y él te dice si le has dado | Daño: 1d6 - 1 Contundente"

añade tmb al final lo q2ue gasta (accion, accion adicional... , si alguna cosa gasta movimiento o recursos tmb)


"lore_description": aquí va la explicación más larga y con más chicha, pero sigue sin ser un manual de mecánica — no repitas "tira 1d8", ni expliques CD, ni cómo funciona una tirada de salvación como concepto (eso ya lo hace el modal de resolución de la app con "tactical_summary" y "attack_type"). Este campo es para que la persona entienda, en un par de frases, QUÉ hace el hechizo/rasgo en la ficción y en qué situación conviene usarlo: qué le pasa al objetivo, qué efectos secundarios tiene, condiciones especiales, sabor narrativo. Escribe en lenguaje llano, sin dar por sentado vocabulario de D&D.

ARMAS ("inventory.weapons") — "lore_description" y "tactical_summary": cada arma también lleva estos dos campos, con el mismo criterio de lenguaje llano que las habilidades (nada de jerga D&D). Diferencias respecto a las habilidades, porque un arma nunca tiene "attack_type" (siempre se resuelve como ataque):
   - "tactical_summary" de un arma sigue siempre la plantilla de attack_type "attack": "Tiras un d20 y sumas +X; le dices el resultado al máster y él te dice si le has dado | Daño: [damage.base_dice] [damage.base_type]". La X es el "attack_bonus" del arma. Si el arma tiene daño condicional (ej. a dos manos) o un homebrew_effect que cambie la tirada o el daño, añádelo en una frase corta al final del tactical_summary (ej. "| Daño: 1d8+4 Cortante (1d10+4 a dos manos)").
   - "lore_description" de un arma es 1-2 frases de sabor: de dónde viene, qué aspecto tiene, por qué es especial o qué la hace destacar — igual que harías con el lore de un rasgo, pero centrado en el objeto. Si "homebrew_effect" no está vacío y es un efecto pasivo/ambiental (no algo que cambie la tirada), descríbelo aquí en vez de en tactical_summary.
   - Si el arma es mundana y no tiene nada especial que contar, un lore_description breve y genérico está bien (ej. "Una espada larga de manufactura estándar, bien cuidada."); nunca lo dejes en "".
   - Recuerda que siguen sin llevar "attack_type": ese campo no existe para armas, solo se añaden estos dos campos nuevos.

"ai_tips", una serie de consejos generados por ti sobre como se usa el personaje

"user_tactics" y "adventure_notes" son campos de texto libre del Códice. NO los rellenes con contenido inventado: déjalos siempre como "" salvo que yo te pida explícitamente redactar algo.

SISTEMA DE RECURSOS ("resources"): Este array es para "pools" de puntos especiales (Ki, Puntos de Hechicería, Furia, Inspiración Bárdica, Superioridad, Canalizar Divinidad, etc.).

Analiza la clase y nivel del personaje según las reglas oficiales de D&D 5e para deducir el máximo ("max") si la ficha no lo dice explícitamente (Ej: Monje Nivel 5 = 5 Puntos de Ki. Bardo con Carisma 16 = 3 Inspiraciones).

Un objeto por recurso: { "name", "current", "max" }. "current" arranca igual que "max". Si la clase no tiene recursos gastables, usa un array vacío [].

INVENTARIO ("inventory"): - Las armas van en "weapons". IMPORTANTE: Incluye el campo "is_unique": true si el arma es legendaria, artefacto u objeto mágico irrepetible. Si es común, "is_unique": false.

El resto de equipo (pociones, cuerdas, herramientas, reliquias) va en el array "mundane_items". Cada objeto usa: { "name", "description", "quantity" }.

"purse": monedas del personaje (gold, silver, copper), como números enteros independientes. Si no hay dinero, usa 0.

"speed": velocidad de movimiento base del personaje, en PIES por turno (NO en metros). Es un número entero, múltiplo de 5 (rango razonable 5-120). Parte de la velocidad base de su raza (Humano/Elfo/Semielfo/Semiorco/Tiefling/Dracónido = 30, Enano/Halfling/Gnomo = 25 o 30 según la edición de la ficha) y aplícale cualquier modificador de clase o rasgo que la aumente o reduzca (ej. Monje sin armadura pesada +10 o más, Bárbaro +10, armadura pesada sin la Fuerza requerida -10). Si la ficha original trae la velocidad en metros, conviértela a pies (9 m = 30 pies, 1,5 m = 5 pies) antes de escribirla; si ya viene en pies, úsala tal cual. Si el personaje tiene varias velocidades (andando, volando, nadando, escalando) usa aquí SOLO la de caminar/terrestre — no hay campos separados para las demás en este formato.

"spell_save_dc": la CD de salvación de conjuros del personaje, dentro de "basic_info", como número entero. Se calcula: 8 + bonificador de competencia (según el nivel total del personaje: +2 en niveles 1-4, +3 en 5-8, +4 en 9-12, +5 en 13-16, +6 en 17-20) + modificador de la característica de lanzamiento de conjuros de su clase (Carisma para Paladín/Bardo/Hechicero/Brujo, Sabiduría para Clérigo/Druida/Explorador, Inteligencia para Mago/Artífice).
   - Si el personaje tiene varias clases de lanzador (multiclase), pregúntame cuál característica usar antes de asumir una — no la adivines.
   - Si el personaje NO es lanzador de conjuros de ninguna clase (no tiene "spell_slots" ni conjuros en "abilities_by_action"), usa 0.
   - Si te falta algún dato para calcularla (nivel real, o no tienes claro cuál es la característica de lanzamiento), PREGÚNTAME antes de poner un número — no lo dejes a ojo.

Si algo es ambiguo, PREGÚNTAME antes de asumir nada. No inventes mecánicas. Si falta un dato que SÍ existe en el JSON (ej. ac, hp_max, un stat), pregúntamelo.

Devuélveme el JSON completo, sin comentarios ni texto fuera del bloque de código.''';

  /// Título de la sección de ejemplo.
  static const String _exampleHeader =
      '''FORMATO EXACTO A SEGUIR (ejemplo mínimo con todos los campos):''';

  /// Ejemplo mínimo con TODOS los campos del shape (Kaelen el Luminoso).
  static const String _exampleJson =
      '''{
  "basic_info": {
    "name": "Kaelen el Luminoso",
    "race": "Humano",
    "characterClass": "Paladín 5",
    "hp_max": 44,
    "ac": 18,
    "speed": 30,
    "spell_save_dc": 14
  },
  "purse": {
    "gold": 120,
    "silver": 50,
    "copper": 0
  },
  "ai_tips": "",
  "user_tactics": "",
  "adventure_notes": "",
  "resources": [
    {
      "name": "Imposición de Manos",
      "current": 25,
      "max": 25
    },
    {
      "name": "Canalizar Divinidad",
      "current": 1,
      "max": 1
    },
    {
      "name": "Sentido Divino",
      "current": 4,
      "max": 4
    }
  ],
  "inventory": {
    "weapons": [
      {
        "id": "weapon-justicia-radiante",
        "name": "Justicia Radiante (Espada Larga +1)",
        "attack_bonus": 7,
        "damage": {
          "base_dice": "1d8+4",
          "base_type": "cortante"
        },
        "conditional_damage": [
          {
            "condition": "Ataque a dos manos",
            "damage_dice": "1d10+4",
            "damage_type": "cortante"
          }
        ],
        "properties": [
          "Versátil",
          "Mágica"
        ],
        "homebrew_effect": "Emite luz tenue en un radio de 10 pies cuando se desenvaina.",
        "magic_charges": {
          "has_charges": false,
          "max": 0,
          "current": 0
        },
        "success_description": "La hoja bendita atraviesa la armadura del enemigo.",
        "failure_description": "El tajo es bloqueado ruidosamente.",
        "lore_description": "Reliquia forjada con el fragmento de una estrella caída, transmitida por generaciones dentro de la Orden de la Llama Sagrada. Su hoja nunca se mancha de sangre por mucho que la use.",
        "tactical_summary": "Tiras un d20 y sumas +7; le dices el resultado al máster y él te dice si le has dado | Daño: 1d8+4 Cortante (1d10+4 a dos manos)",
        "is_unique": true
      },
      {
        "id": "weapon-jabalina",
        "name": "Jabalina",
        "attack_bonus": 6,
        "damage": {
          "base_dice": "1d6+3",
          "base_type": "perforante"
        },
        "conditional_damage": [],
        "properties": [
          "Arrojadiza",
          "Alcance (30/120 pies)"
        ],
        "homebrew_effect": "",
        "magic_charges": {
          "has_charges": false,
          "max": 0,
          "current": 0
        },
        "success_description": "La jabalina impacta con fuerza.",
        "failure_description": "El proyectil pasa de largo.",
        "lore_description": "Una jabalina de manufactura estándar, pensada para lanzarse antes de que el combate llegue al cuerpo a cuerpo.",
        "tactical_summary": "Tiras un d20 y sumas +6; le dices el resultado al máster y él te dice si le has dado | Daño: 1d6+3 Perforante",
        "is_unique": false
      }
    ],
    "mundane_items": [
      {
        "name": "Símbolo Sagrado",
        "description": "Un emblema de plata del dios Sol, usado como foco para conjuros.",
        "quantity": 1
      },
      {
        "name": "Armadura de Cota de Malla",
        "description": "Una armadura pesada y ruidosa que requiere Fuerza 13 para llevarse.",
        "quantity": 1
      },
      {
        "name": "Poción de Curación",
        "description": "Restaura 2d4+2 puntos de golpe al beberse.",
        "quantity": 3
      }
    ]
  },
  "stats": {
    "str": {
      "name": "Fuerza",
      "value": 16,
      "mod": 3,
      "description": "Mide la fuerza física y la capacidad atlética."
    },
    "dex": {
      "name": "Destreza",
      "value": 10,
      "mod": 0,
      "description": "Mide la agilidad, los reflejos y la coordinación."
    },
    "con": {
      "name": "Constitución",
      "value": 14,
      "mod": 2,
      "description": "Mide la resistencia física y la salud."
    },
    "int": {
      "name": "Inteligencia",
      "value": 8,
      "mod": -1,
      "description": "Mide el conocimiento y la lógica."
    },
    "wis": {
      "name": "Sabiduría",
      "value": 12,
      "mod": 1,
      "description": "Mide la intuición y la percepción."
    },
    "cha": {
      "name": "Carisma",
      "value": 16,
      "mod": 3,
      "description": "Mide la fuerza de personalidad."
    }
  },
  "spell_slots": [
    {
      "level": 1,
      "max": 4,
      "current": 4
    },
    {
      "level": 2,
      "max": 2,
      "current": 2
    }
  ],
  "skills": [
    {
      "name": "Acrobacias",
      "related_stat": "dex",
      "modifier": 0
    },
    {
      "name": "Arcanos",
      "related_stat": "int",
      "modifier": -1
    },
    {
      "name": "Atletismo",
      "related_stat": "str",
      "modifier": 6
    },
    {
      "name": "Engañar",
      "related_stat": "cha",
      "modifier": 3
    },
    {
      "name": "Historia",
      "related_stat": "int",
      "modifier": -1
    },
    {
      "name": "Interpretación",
      "related_stat": "cha",
      "modifier": 3
    },
    {
      "name": "Intimidar",
      "related_stat": "cha",
      "modifier": 6
    },
    {
      "name": "Investigación",
      "related_stat": "int",
      "modifier": -1
    },
    {
      "name": "Juego de Manos",
      "related_stat": "dex",
      "modifier": 0
    },
    {
      "name": "Medicina",
      "related_stat": "wis",
      "modifier": 4
    },
    {
      "name": "Naturaleza",
      "related_stat": "int",
      "modifier": -1
    },
    {
      "name": "Percepción",
      "related_stat": "wis",
      "modifier": 1
    },
    {
      "name": "Perspicacia",
      "related_stat": "wis",
      "modifier": 4
    },
    {
      "name": "Persuasión",
      "related_stat": "cha",
      "modifier": 6
    },
    {
      "name": "Religión",
      "related_stat": "int",
      "modifier": 2
    },
    {
      "name": "Sigilo",
      "related_stat": "dex",
      "modifier": 0
    },
    {
      "name": "Supervivencia",
      "related_stat": "wis",
      "modifier": 1
    },
    {
      "name": "Trato con Animales",
      "related_stat": "wis",
      "modifier": 1
    }
  ],
  "abilities_by_action": {
    "action": [
      {
        "id": "ability-curar-heridas",
        "name": "Curar Heridas",
        "type": "spell",
        "related_stat": "cha",
        "attack_type": "none",
        "success_description": "Una luz cálida cierra las heridas del objetivo.",
        "failure_description": "La magia se disipa sin efecto.",
        "is_scalable": true,
        "base_level": 1,
        "damage_dice": "1d8",
        "scaling_formula": "1d8",
        "lore_description": "Una criatura a la que tocas recupera puntos de golpe. Puedes lanzarlo con un espacio de nivel más alto para curar más si el aliado está muy malherido.",
        "tactical_summary": "No tienes que tirar nada, el objetivo se cura al tocarlo | Curación: 1d8 + Mod"
      }
    ],
    "bonus_action": [
      {
        "id": "ability-castigo-atronador",
        "name": "Castigo Atronador",
        "type": "spell",
        "related_stat": "cha",
        "attack_type": "none",
        "success_description": "El arma resuena con un trueno, derribando al enemigo.",
        "failure_description": "El impacto atronador es resistido.",
        "is_scalable": false,
        "base_level": 1,
        "damage_dice": "2d6",
        "scaling_formula": "",
        "lore_description": "Encantas tu próximo golpe de arma para que estalle en trueno al impactar. Además del daño, el enemigo puede acabar tumbado en el suelo. Requiere concentración mientras esperas ese golpe.",
        "tactical_summary": "No tienes que tirar nada, el trueno estalla solo al golpear con el arma; además el enemigo tira un d20 y si no supera tu CD (14) cae al suelo | Daño: 2d6 Trueno"
      }
    ],
    "reaction": [],
    "passive": [
      {
        "id": "ability-castigo-divino",
        "name": "Castigo Divino",
        "type": "class_feature",
        "lore_description": "Cuando golpeas a un enemigo cuerpo a cuerpo, puedes sacrificar un espacio de conjuro para que el golpe arda con luz divina y haga más daño. Es aún más potente contra muertos vivientes o demonios.",
        "tactical_summary": "No tienes que tirar nada extra: si acabas de golpear con el arma, puedes gastar un espacio de conjuro para sumar 2d8 de daño Radiante (nivel 1), +1d8 por cada nivel de espacio adicional, y +1d8 más si el enemigo es un muerto viviente o infernal.",
        "tactical_role": "Ofensivo"
      },
      {
        "id": "ability-ataque-adicional",
        "name": "Ataque Adicional",
        "type": "trait",
        "lore_description": "Tu entrenamiento te permite golpear más de una vez en el mismo turno.",
        "tactical_summary": "Cuando ataques, hazlo 2 veces en vez de 1.",
        "tactical_role": "Ofensivo"
      },
      {
        "id": "ability-salud-divina",
        "name": "Salud Divina",
        "type": "trait",
        "lore_description": "La magia divina que fluye por ti te protege de cualquier enfermedad.",
        "tactical_summary": "No puedes enfermar nunca.",
        "tactical_role": "Defensivo"
      }
    ]
  },
  "lore_info": {
    "backstory": "Nacido en una familia de herreros humildes, Kaelen juró proteger a los débiles tras presenciar el saqueo de su aldea. Fue acogido por la Orden de la Llama Sagrada, donde canalizó su ira en disciplina y fe. Empuña la reliquia 'Rompeamaneceres', forjada supuestamente con la luz de una estrella caída. Su fe es absoluta, lo que le hace en ocasiones demasiado rígido para entender la escala de grises del mundo.",
    "personality_traits": "Juzgo a los demás por sus actos, no por sus palabras. Cuando me doy un propósito, nada puede apartarme de él.",
    "ideals": "Responsabilidad. Es el deber de los fuertes proteger a los débiles.",
    "bonds": "Mi orden y mi escudo son la única familia que me queda.",
    "flaws": "Soy inflexible en mi visión de la ley, lo que a menudo me granjea enemigos innecesarios."
  }
}''';

  /// Cuerpo maestro completo: presentación + aviso + reglas + ejemplo.
  /// Es lo que ve la IA en TODAS las variantes; lo único que cambia entre
  /// ellas es de dónde salen los datos del personaje.
  static String get _masterBody =>
      '$_intro\n\n$_warning\n$_rules\n\n$_exampleHeader\n$_exampleJson';

  // ---------------------------------------------------------------------
  // VARIANTES — cada flujo del wizard arma su prompt con una de estas.
  // ---------------------------------------------------------------------

  /// Ficha vacía: el jugador pega los datos de su personaje al final del
  /// prompt antes de mandárselo a la IA (modo "no tengo nada digital").
  static String forEmptySheet() {
    return '$_masterBody\n\n'
        '--- PEGA AQUÍ LOS DATOS DE TU PERSONAJE (texto de la ficha, copia '
        'de PDF, lo que tengas) ---';
  }

  /// Ficha ya extraída como texto (JSON crudo de Nivel20 limpio de HTML,
  /// o texto pegado a mano desde un PDF). La IA no visita ningún enlace:
  /// todo lo que necesita va incluido arriba de las reglas.
  static String forEmbeddedSource(String source) {
    final clean = source.trim();
    return 'Actúa como experto en D&D 5e. A continuación tienes el texto '
        'de la ficha del personaje (no hace falta que visites ningún '
        'enlace):\n\n$clean\n\n'
        'Vas a convertir esta ficha de personaje en un JSON con un formato '
        'EXACTO. Debes seguir ESTRICTAMENTE la estructura del ejemplo que '
        'te doy más abajo.\n\n$_warning\n$_rules\n\n'
        '$_exampleHeader\n$_exampleJson';
  }

  /// Modo enlace: le pide a la IA que visite la ficha pública de Nivel20 y
  /// extraiga los datos por su cuenta.
  static String forNivel20Link(String link) {
    return 'Actúa como experto en D&D 5e. Visita el siguiente enlace de la '
        'plataforma Nivel20 y extrae todos los datos del '
        'personaje:\n\n$link\n\n'
        'Vas a convertirlos en un JSON con un formato EXACTO. Debes seguir '
        'ESTRICTAMENTE la estructura del ejemplo que te doy más '
        'abajo.\n\n$_warning\n$_rules\n\n'
        '$_exampleHeader\n$_exampleJson';
  }

  /// Modo corrección: la ficha YA está importada en el formato correcto
  /// pero el validador detectó problemas (warnings). El prompt incluye la
  /// ficha actual + la lista de problemas para que la IA devuelva la
  /// versión corregida COMPLETA, que el wizard aplica con
  /// CharacterStore.replaceCharacter — sin duplicar la entrada.
  static String forCorrection(String characterJson, List<String> problems) {
    final problemList = problems.map((p) => '- $p').join('\n');
    return 'Actúa como experto en D&D 5e. La siguiente ficha de personaje '
        'YA está en el formato JSON que usa esta app, pero al importarla '
        'se detectaron estos problemas:\n\n$problemList\n\n'
        'Ficha actual (JSON):\n\n${characterJson.trim()}\n\n'
        'Corrige los problemas listados arriba y devuélveme la ficha '
        'COMPLETA corregida: sin campos nuevos, sin eliminar campos, y '
        'manteniendo intacto todo lo que ya estaba bien (en particular '
        '"user_tactics" y "adventure_notes", que son notas del '
        'jugador).\n\n$_warning\n$_rules\n\n'
        '$_exampleHeader\n$_exampleJson';
  }

  /// Enriquecimiento de una ficha de Nivel20 ya mapeada de forma
  /// determinista: la IA recibe el JSON base (con atributos, PG, CA,
  /// velocidad, ranuras y CD ya calculados por la app) más los textos
  /// crudos que la app no sabe clasificar, y se limita a completarlos.
  static String forNivel20Enrichment(
    String baseJson, {
    String feats = '',
    String customActions = '',
    String equipment = '',
  }) {
    String section(String title, String body) =>
        '$title\n${body.trim().isEmpty ? '(sin datos)' : body.trim()}';

    return 'Actúa como experto en D&D 5e. Te paso una ficha de personaje '
        'ya convertida automáticamente al formato JSON de mi app. Los '
        'números ya están calculados y son correctos: tu trabajo es SOLO '
        'completar lo que la app no puede deducir.\n\n'
        'FICHA BASE (JSON):\n\n${baseJson.trim()}\n\n'
        '${section('RASGOS (texto original de Nivel20):', feats)}\n\n'
        '${section('ACCIONES CASERAS DEL JUGADOR (texto original):', customActions)}\n\n'
        '${section('EQUIPO (texto original):', equipment)}\n\n'
        'NO MODIFIQUES, bajo ningún concepto: "basic_info" (nombre, raza, '
        'clase, nivel, hp_max, hp_current, ac, speed, spell_save_dc, dados '
        'de golpe), "stats", "skills", "spell_slots", "purse", ni el '
        '"attack_bonus" y el "damage" de las armas. Tampoco cambies ni '
        'borres ningún campo existente, ni añadas campos que no estén en '
        'la ficha base. Si crees que algún número está mal, ignóralo y '
        'avísame fuera del JSON.\n\n'
        'LO ÚNICO QUE DEBES HACER:\n\n'
        '1. Clasificar las habilidades de "abilities_by_action" según lo '
        'que gastan: "action", "bonus_action", "reaction" o "passive" '
        '(mueve cada una a su categoría correcta, sin duplicarlas ni '
        'perder ninguna). Las pasivas llevan "tactical_role" con uno de '
        'estos valores EXACTOS: "Ofensivo", "Defensivo" o "Utilidad". '
        'Las de action, bonus_action y reaction llevan "attack_type" '
        '("save", "attack" o "none") y NUNCA "tactical_role"; las pasivas '
        'NUNCA llevan "attack_type".\n'
        '2. Rellenar "resources" con los rasgos de usos limitados (Forma '
        'cambiante, Recuperación arcana, Supernova, etc.) como '
        '{ "name", "current", "max" }, con "current" igual a "max". Si '
        'no hay ninguno, deja [].\n'
        '3. Desglosar el EQUIPO en objetos individuales dentro de '
        '"inventory.mundane_items" ({ "name", "description", "quantity" }), '
        'reemplazando el objeto genérico "Equipo" si existe. No inventes '
        'objetos que no aparezcan en el texto.\n'
        '4. Redactar "tactical_summary" y "lore_description" de cada '
        'habilidad que los tenga vacíos o pobres, en lenguaje llano y sin '
        'jerga de D&D, como si se lo explicaras a quien nunca ha jugado: '
        '"tactical_summary" dice qué hacer con los dados (formato "[frase '
        'sobre la tirada] | Daño/Curación: [dado] [Tipo]", con la CD real '
        'de la ficha) y qué gasta (acción, acción adicional, reacción, '
        'movimiento o recursos); "lore_description" explica en un par de '
        'frases qué hace en la ficción y cuándo conviene usarlo.\n\n'
        'No toques "user_tactics" ni "adventure_notes". Si algo es '
        'ambiguo, PREGÚNTAME antes de asumir. Devuélveme el JSON '
        'completo, sin comentarios ni texto fuera del bloque de código.';
  }
}
