---
status: accepted
---
# Interfaz para novatos: tres índices, tema único y poderes por categoría

La interfaz anterior (cinco pestañas con subpestañas, menú ⋮ de once opciones, control de turno, descansos, temas con marcos y ornamentos) agobiaba al público objetivo, jugadores novatos. Se rehízo entera:

- **Navegación:** tres pestañas (Combate, Ficha, Mochila). Cada una es un índice de tarjetas grandes y cada tarjeta abre su propia pantalla; nada se apila. La vida pasa a una píldora en la barra superior (hoja de Vida al tocarla), salvo a 0 PG, cuando Combate muestra las salvaciones de muerte. El ⋮ queda en Recargar todo, Editar ficha y Ajustes; la lupa abre el buscador de reglas.
- **Quitado de la interfaz:** los descansos (corto, largo, personalizado, dados de golpe) y el control del turno (acción, adicional, reacción, movimiento), también en los compañeros. Los métodos del store se conservan; «Recargar todo» llama a `longRest()`.
- **Tema único:** `AppTheme.clean` (superficies lisas, sin bordes, Inter). El jugador solo elige claro/oscuro y acento. Presets, temas propios, tipografías y el editor de temas siguen en el código, sin entrada, y sus claves de `SharedPreferences` se conservan.
- **Poderes por categoría:** conjuros y habilidades se agrupan en Daño, Defensa, Apoyo y Utilidad, con una frase en llano por poder y una pantalla de detalle con «Usar». Se descartó destacar un «ataque principal» o «golpe más fuerte»: no se puede calcular con fiabilidad (área, salvaciones, efectos) y el usuario no lo quiso.

## Consequences

- `Ability` gana tres campos opcionales, `power_role`, `plain_summary` y `when_to_use`, con fallback silencioso (sin bump de `schema_version`, ver [ADR-0004](0004-validacion-en-frontera-fallbacks-y-versionado-de-esquema.md)). La categoría se deduce si falta (`lib/domain/power_category.dart`).
- La IA de preparación los rellena: los prompts de ficha completa los piden en cada habilidad, y el parche de Nivel20 los acepta en `classified_features` y en una clave nueva, `spell_notes`, que solo toca esos campos de texto de los conjuros (su mecánica sigue viniendo del SRD, ver [ADR-0001](0001-importacion-nivel20-mapper-determinista-y-parche-ia.md)).
- Las fichas importadas antes no traen frase en llano: la lista usa la primera frase de la descripción hasta que se reimporten o se corrijan con IA.
- Tests de UI reescritos contra la navegación nueva (`hud_novice_test.dart`, `powers_list_test.dart`); los de tiradas usan un arnés con los mismos constructores de `RollAction` que la app.
