---
status: accepted
---
# Validación en la frontera, fallbacks silenciosos y `schema_version` para cambios incompatibles

La validación de fichas ocurre solo donde entran datos: la importación (ambas vías) y el guardado del editor, vía `CharacterValidator`. La política es deliberadamente permisiva: solo son errores bloqueantes los que impiden construir una ficha útil (JSON indecodable, sin `basic_info`, sin nombre, `hp_max` no numérico); el resto son avisos y `CharacterModel.fromJson` aplica el fallback. El roster ya guardado se carga con tolerancia (`RosterRepository._decodeTolerant`) y no vuelve a pasar por el validador.

Los cambios **aditivos** al modelo se resuelven con fallbacks silenciosos en `fromJson` (por ejemplo `speed` = 30, `hitDieSides` inferido de la clase), sin tocar la forma del JSON, para que las fichas exportadas y el roster antiguo sigan cargando.

`schema_version` (hoy 2, solo escrito, nunca leído) queda **reservado para cambios incompatibles**. Cuando llegue el primero, se resuelve con una migración explícita en `RosterRepository` al cargar, siguiendo el patrón de la migración legacy (no destructiva e idempotente).

## Consequences

- El mecanismo de migración por versión **no existe todavía**: hay que construirlo con el primer cambio incompatible, no antes.
- Un dato inválido que ya esté guardado nunca bloquea la carga del roster; en el peor caso se muestra con valores de fallback.
- Relacionado: [ADR-0002](0002-parche-devuelve-resumen-de-cambios-como-avisos.md) sigue el mismo criterio de avisos no bloqueantes.
