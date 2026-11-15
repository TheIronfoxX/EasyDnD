---
status: accepted
---
# Estado de combate en el modelo único y edición por reemplazo completo

El estado de combate (PG actuales, ranuras gastadas, cargas, recursos, condiciones, turno) vive en el mismo modelo que los datos estables de la ficha. El editor trabaja sobre una copia (`copy()`) y, al guardar, sustituye la ficha entera con `CharacterStore.replaceCharacter`; la corrección con IA hace lo mismo con la ficha devuelta (`replaceCharacterFromText`), porque `AiPrompt.forCorrection` envía el JSON completo, estado incluido. No hay lógica de fusión: el estado en vivo de la ficha reemplazada se pierde a favor del de la copia o de la respuesta. Se eligió por simplicidad y coherencia con el modelo único mutable.

## Edge case deliberado

Si el índice dejó de ser válido (la ficha se borró o el roster cambió mientras el editor o el wizard estaban abiertos), `replaceCharacter` llama a `addCharacter` en vez de fallar. Así no se pierde el trabajo, pero una corrección que llega tarde puede **duplicar** la ficha en lugar de sustituirla.

## Consequences

- Editar o corregir en pleno combate puede pisar cambios de estado hechos entretanto en el HUD.
- La duplicación por índice obsoleto se acepta; el usuario puede borrar la copia sobrante.
- Relacionado: [ADR-0004](0004-validacion-en-frontera-fallbacks-y-versionado-de-esquema.md).
