# EasyDnD

HUD de combate offline para D&D 5e: el jugador mantiene fichas de personaje y las usa en mesa durante el combate. Las fichas se crean importándolas (principalmente desde Nivel20) o editándolas a mano.

## Fichas

**Ficha**:
El registro completo de un personaje (datos básicos, atributos, poderes, armas, objetos, recursos, lore, compañeros).
_Avoid_: Personaje (para el registro), hoja, character sheet

**Roster**:
El conjunto de fichas guardadas en el dispositivo; puede estar vacío.
_Avoid_: Lista de personajes, party

**Ficha activa**:
La ficha del roster con la que se está jugando en el HUD.
_Avoid_: Personaje actual

**Estado de combate**:
La parte mutable de la ficha: PG actuales, ranuras gastadas, cargas, recursos, condiciones y turno. Vive en la misma ficha que los datos estables y se reemplaza junto con ella.
_Avoid_: Estado de sesión, estado temporal

**Compañero**:
Mascota, invocación o aliado con PG propios que acompaña a una ficha.
_Avoid_: Pet, minion

## Creación de fichas

**Editor**:
La pantalla de edición manual de una ficha, dividida en cuatro pestañas: Núcleo, Arsenal, Grimorio y Mochila. Es uno de los dos flujos principales para dar forma a una ficha.

**Importación**:
El flujo que convierte una fuente externa en una ficha de EasyDnD, con vista previa y validación antes de guardarla. Tiene dos vías: la de Nivel20, principal, y la de IA de ficha completa, secundaria, para fuentes que no son Nivel20. Junto con el Editor, es uno de los flujos principales para dar forma a una ficha.
_Avoid_: Alta, carga

**Corrección**:
Paso transversal a ambas vías de importación que devuelve a la IA una ficha con sus problemas de validación para que la repare.

**Ficha base**:
La ficha que se construye de forma determinista a partir de los datos de Nivel20, sin intervención de IA.

**Parche**:
Un conjunto parcial de enriquecimientos (clasificación de rasgos, recursos, equipo, textos, monedas, compañeros) que se fusiona sobre una ficha base sin sustituirla.
_Avoid_: Enriquecimiento (como nombre del objeto), patch

**Motor de reglas SRD**:
El cálculo de las reglas de D&D 5e que sostiene al editor: bonos de ataque, competencias, fórmulas de usos y valores derivados de las armas.
_Avoid_: Builder, creador de personajes

## Combate

**Poder**:
Cualquier capacidad de una ficha (rasgo, conjuro, habilidad de clase o racial) clasificada por su coste de acción.
_Avoid_: Habilidad (reservado a las 18 habilidades de competencia), ability

**Economía de acción**:
Los cuatro tipos de coste de un poder: acción, acción adicional, reacción y pasivo.

**Recurso**:
Un contador con nombre, valor actual y máximo que los poderes pueden gastar, con una regla de recuperación.

**Recuperación**:
Cuándo vuelve un recurso a su máximo: descanso corto, descanso largo o manual.

**Descanso**:
Evento que restaura PG, ranuras, cargas y recursos según su recuperación; puede ser corto, largo o personalizado.

**Cargas**:
Usos limitados de un arma o poder que se restauran con descansos, distintos de los recursos compartidos.

**Hoja de resolución**:
La vista del HUD que resuelve la tirada de un poder o arma (ventaja, desventaja, dados, coste de recurso).
