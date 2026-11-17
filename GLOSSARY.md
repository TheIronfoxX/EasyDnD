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
La parte mutable de la ficha: PG actuales, PG temporales, salvaciones de muerte, ranuras gastadas, cargas, recursos, condiciones y turno, incluido el de cada compañero. Vive en la misma ficha que los datos estables y se reemplaza junto con ella.
_Avoid_: Estado de sesión, estado temporal

**Compañero**:
Mascota, invocación o aliado que acompaña a una ficha. Puede tener PG propios o ser apoyo invulnerable, y actúa con su propio turno, condiciones y acciones.
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

## Diario

**Nota de sesión**:
Entrada fechada, con título y cuerpo, del diario de una ficha. Convive con el texto libre de aventura del Códice, que no se migra.
_Avoid_: Entrada, log, apunte

**Diario**:
El conjunto de notas de sesión de una ficha.

## Presentación

**Pestañas del HUD**:
Las tres secciones de la navegación inferior: Combate (recursos, Conjuros, Ataques y habilidades, Estados, Compañeros), Ficha (Atributos, Habilidades, Historia) y Mochila (Armas, Objetos, Dinero, Notas). Cada pestaña es un índice de tarjetas y cada tarjeta abre su propia pantalla.
_Avoid_: Subpestañas, tablero

**Píldora de vida**:
El resumen pequeño de PG en la barra superior, visible en las tres pestañas. Al tocarla se abre la hoja de Vida (daño, curación, PG temporales, Defensa).

**Categoría**:
El rol de un poder en la lista sencilla: Daño, Defensa, Apoyo o Utilidad. La pone la IA de preparación (`power_role`) o se deduce (rol táctico de las pasivas, dados de daño o curación, palabras clave).
_Avoid_: Tipo, rol táctico (reservado a las pasivas)

**Frase en llano**:
Una frase corta, sin jerga, que explica qué hace un poder a quien nunca ha jugado (`plain_summary`). Si falta, se usa la primera frase de la descripción. Va acompañada de «Cuándo usarlo» (`when_to_use`) en el detalle del poder.

**Buscador de reglas**:
Pantalla que busca, sin conexión, entre los estados, los conjuros del reglamento empaquetado y los poderes de la ficha activa.

**Tema limpio**:
El único diseño de la app: superficies lisas, sin bordes ni ornamentos, letra Inter. El jugador solo elige claro/oscuro y el color de acento.

**Tema propio**:
Tema creado en el editor de temas. El código sigue en la app pero ya no tiene entrada ni construye el tema (ver ADR-0007).
_Avoid_: Skin personalizada

**Catálogo de temas**:
Los temas prehechos de la app. Siguen en el código, sin entrada, igual que los temas propios.

## Respaldo

**Exportación**:
Una ficha guardada como archivo JSON, sin sus avatares, para llevarla a otro dispositivo o conservarla.
_Avoid_: Compartir, dump

**Respaldo**:
Todo el roster guardado en un único archivo, sin avatares.
_Avoid_: Backup

**Restauración**:
El flujo que lee una exportación o un respaldo de EasyDnD y lo incorpora al roster, añadiéndolo o reemplazándolo por completo. A diferencia de la Importación, no tiene vista previa porque la fuente es la propia app.
_Avoid_: Importación (reservada a fuentes externas)

## Combate

**Poder**:
Cualquier capacidad de una ficha (rasgo, conjuro, habilidad de clase o racial) clasificada por su coste de acción.
_Avoid_: Habilidad (reservado a las 18 habilidades de competencia), ability

**Economía de acción**:
Los cuatro tipos de coste de un poder: acción, acción adicional, reacción y pasivo.

**Recurso**:
Un contador con nombre, valor actual y máximo que los poderes pueden gastar, con una regla de recuperación.

**Recuperación**:
Cuándo vuelve un recurso a su máximo: descanso corto, descanso largo o manual. En la interfaz los descansos ya no se ofrecen: se recupera a mano o con Recargar todo.

**Recargar todo**:
La opción del menú ⋮ que deja la ficha al máximo (PG, ranuras, cargas y recursos), igual que un descanso largo pero sin diálogo. No restaura a los compañeros: sus PG se curan a mano.
_Avoid_: Descanso (ya no hay descansos en la interfaz)

**Cargas**:
Usos limitados de un arma o poder que se restauran con descansos, distintos de los recursos compartidos.

**Hoja de resolución**:
La vista del HUD que resuelve la tirada de un poder o arma (ventaja, desventaja, dados, coste de recurso).

**PG temporales**:
Colchón de PG que absorbe el daño antes que los PG actuales. No se acumulan: se conserva el mayor. Se pierden con un descanso largo.
_Avoid_: PG extra, escudo

**Salvaciones de muerte**:
Contadores manuales de tres éxitos y tres fallos que cuentan con 0 PG. Tres éxitos dejan al personaje Estable; tres fallos, Muerto. Se reinician al recuperar PG.
_Avoid_: Death saves
