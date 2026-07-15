import '../models/character_model.dart';

final Map<String, dynamic> mockCharacterData = {
  "basic_info": {
    "name": "Kaeľnar Ardinys",
    "race": "Kitsune",
    "characterClass": "Mago 14",
    "hp_max": 114,
    "ac": 15
  },
  "inventory": {
    "weapons": [
      {
        "id": "weapon-baston-fuego",
        "name": "Bastón de Fuego",
        "attack_bonus": 4,
        "damage": { "base_dice": "1d6-1", "base_type": "contundente" },
        "conditional_damage": [],
        "properties": ["Mágico"],
        "homebrew_effect": "",
        "magic_charges": { "has_charges": true, "max": 10, "current": 10 },
        "success_description": "El bastón golpea dejando un rastro de brasas.",
        "failure_description": "El golpe es interceptado y las chispas se apagan."
      },
      {
        "id": "weapon-ballesta-ligera",
        "name": "Ballesta Ligera",
        "attack_bonus": 7,
        "damage": { "base_dice": "1d8+2", "base_type": "perforante" },
        "conditional_damage": [],
        "properties": ["Munición", "Ligera", "Dos manos"],
        "homebrew_effect": "",
        "magic_charges": { "has_charges": false, "max": 0, "current": 0 },
        "success_description": "El virote se clava certero en el objetivo.",
        "failure_description": "La flecha se pierde en la oscuridad."
      }
    ]
  },
  "abilities_by_action": {
    "action": [
      {
        "id": "ability-forma-cambiante",
        "name": "Forma Cambiante",
        "type": "trait",
        "related_stat": "int",
        "success_description": "Tu cuerpo se contorsiona y reduce hasta tomar la forma ágil de un zorro.",
        "failure_description": "La transformación falla, dejándote desorientado.",
        "is_scalable": false,
        "base_level": 0,
        "damage_dice": "",
        "scaling_formula": "",
        "lore_description": "Puedes usar tu acción para polimorfarte en un zorro. Tus estadísticas, salvo el tamaño, son las mismas.",
        "tactical_summary": "Útil para infiltración (Sigilo agudizado en forma de zorro)."
      },
      {
        "id": "ability-bola-de-fuego",
        "name": "Bola de Fuego",
        "type": "spell",
        "related_stat": "int",
        "success_description": "Las llamas envuelven a tus enemigos entre gritos.",
        "failure_description": "El conjuro se disipa sin efecto visible.",
        "is_scalable": true,
        "base_level": 3,
        "damage_dice": "8d6",
        "scaling_formula": "1d6",
        "lore_description": "Un rayo brillante surge de tu dedo y explota en un estallido de llamas.",
        "tactical_summary": "Salvación de Destreza. 8d6 de daño de fuego (mitad si salva). +1d6 por nivel de ranura por encima de 3."
      }
    ],
    "bonus_action": [
      {
        "id": "ability-paso-brumoso",
        "name": "Paso Brumoso",
        "type": "spell",
        "related_stat": "int",
        "success_description": "Te desvaneces en una nube plateada y reapareces a distancia.",
        "failure_description": "La magia fluctúa y te mantienes en el mismo sitio.",
        "is_scalable": false,
        "base_level": 2,
        "damage_dice": "",
        "scaling_formula": "",
        "lore_description": "Rodeado brevemente por una bruma plateada, te teleportas hasta 30 pies a un lugar sin ocupar que puedas ver.",
        "tactical_summary": "Teletransporte de 30 pies como acción adicional. Requiere visión."
      }
    ],
    "reaction": [
      {
        "id": "ability-escudo",
        "name": "Escudo",
        "type": "spell",
        "related_stat": "int",
        "success_description": "Una barrera arcana detiene el golpe por completo.",
        "failure_description": "El escudo se forma un instante demasiado tarde.",
        "lore_description": "Una barrera invisible de fuerza mágica aparece y te protege del ataque entrante.",
        "tactical_summary": "+5 a la CA hasta el inicio de tu próximo turno. Inmune a Proyectil Mágico.",
        "magic_charges": { "has_charges": false, "max": 0, "current": 0 }
      }
    ],
    "passive": [
      { "id": "ability-astucia-arcana", "name": "Astucia Arcana", "type": "trait" },
      { "id": "ability-evocacion-potenciada", "name": "Evocación Potenciada (+5 daño)", "type": "trait" }
    ]
  },
  "stats": {
    "str": { "name": "Fuerza", "value": 8, "mod": -1, "description": "Mide el poder físico, el entrenamiento atlético y la capacidad de levantar peso." },
    "dex": { "name": "Destreza", "value": 14, "mod": 2, "description": "Mide la agilidad, los reflejos, el equilibrio y la coordinación motriz." },
    "con": { "name": "Constitución", "value": 18, "mod": 4, "description": "Mide la salud general, la resistencia al daño y la estamina vital." },
    "int": { "name": "Inteligencia", "value": 20, "mod": 5, "description": "Mide la agudeza mental, la capacidad de deducción y la memoria." },
    "wis": { "name": "Sabiduría", "value": 14, "mod": 2, "description": "Mide la intuición, la percepción de tu entorno y la conexión espiritual." },
    "cha": { "name": "Carisma", "value": 10, "mod": 0, "description": "Mide tu fuerza de personalidad, persuasión y capacidad de liderazgo." }
  },
  "spell_slots": [
    { "level": 1, "max": 4, "current": 4 },
    { "level": 2, "max": 3, "current": 3 },
    { "level": 3, "max": 3, "current": 3 },
    { "level": 4, "max": 3, "current": 3 },
    { "level": 5, "max": 2, "current": 2 },
    { "level": 6, "max": 1, "current": 1 },
    { "level": 7, "max": 1, "current": 1 }
  ],
  "skills": [
    { "name": "Acrobacias", "related_stat": "dex", "modifier": 2 },
    { "name": "Arcanos", "related_stat": "int", "modifier": 10 },
    { "name": "Atletismo", "related_stat": "str", "modifier": -1 },
    { "name": "Historia", "related_stat": "int", "modifier": 5 },
    { "name": "Investigación", "related_stat": "int", "modifier": 10 },
    { "name": "Percepción", "related_stat": "wis", "modifier": 2 },
    { "name": "Religión", "related_stat": "int", "modifier": 5 },
    { "name": "Sigilo", "related_stat": "dex", "modifier": 2 }
  ],
  "lore_info": {
    "backstory": "Kael nació en un remoto bosque encantado. Sus padres eran dos Kitsunes exiliados, los cuales vivían en forma animal ocultos del mundo de los hombres en un santuario. La paz de su infancia se rompió trágicamente una noche, cuando unos cazadores furtivos irrumpieron en su refugio. Kael, siendo apenas un niño, se vio forzado a presenciar cómo sus padres fueron masacrados. En un acto desesperado y final, su madre le lanzó un hechizo que lo envolvió en niebla y lo transportó a otro lugar, salvando su vida a costa de la suya. Consumido por el dolor y la pérdida, desde ese día juró venganza. Los años posteriores lo endurecieron en las calles, forzándolo a sobrevivir en las sombras. Una noche, mientras robaba comida de un campamento, fue interceptado por otro ladrón. Por culpa de Kael los pillaron, pero gracias a la confusión generada y a sus incipientes habilidades arcanas, pudieron huir. Hoy en día, su destreza en la evocación mágica no es solo un talento, sino un arma afilada en espera de la sangre de los furtivos que destrozaron su hogar.",
    "personality_traits": "Frío y metódico en apariencia, evaluando constantemente su entorno como si esperara una emboscada en cualquier instante. Detrás de su fachada impasible, bulle un fuego alimentado por el trauma.",
    "ideals": "Venganza. El mundo está plagado de cazadores crueles, y él se ha convertido en la tormenta arcana que purgará su malicia de la faz de la tierra.",
    "bonds": "El recuerdo fragmentado de aquel santuario oculto y la cálida magia de la niebla materna que aún lo envuelve en sus momentos de mayor desesperación.",
    "flaws": "Su juramento de venganza lo ciega. Ante el menor indicio de un cazador furtivo o un injusto opresor, su racionalidad de mago erudito desaparece, dejando paso a una ira temeraria y destructiva."
  }
};

// Esta es la función vital que tu provider estaba buscando a gritos
CharacterModel loadMockCharacter() {
  return CharacterModel.fromJson(mockCharacterData);
}