---
status: accepted
---
# Importación con IA de ficha completa: soportada pero secundaria

La importación con IA de ficha completa (`AiPrompt.forEmptySheet` y `forEmbeddedSource`) se mantiene como vía para fuentes que no son Nivel20, pero deja de ser un flujo principal: los principales son el editor de cuatro pestañas y la importación desde Nivel20 (ver [ADR-0001](0001-importacion-nivel20-mapper-determinista-y-parche-ia.md)). No se le añaden funcionalidades nuevas salvo mantenimiento crítico; las mejoras de importación van a la vía de Nivel20.

`AiPrompt.forCorrection` se conserva como herramienta transversal para validar y reparar la salida de ambas vías.

## Consequences

- El prompt maestro de ficha completa (~500 líneas) y sus tests siguen vivos y deben mantenerse al día con el modelo `CharacterModel`, aunque no evolucione.
- Si en el futuro se retira esta vía, `forCorrection` debe seguir sirviendo a la vía de Nivel20.
