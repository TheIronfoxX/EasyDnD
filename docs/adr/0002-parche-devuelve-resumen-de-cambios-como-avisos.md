---
status: accepted
---
# El parche de IA devuelve un resumen estructurado que la vista previa muestra como avisos

Los `classified_features` del parche se emparejan con los poderes de la ficha base por nombre normalizado; si no hay coincidencia se **crea** un poder nuevo (`patch-<slug>`), porque así se cubren las acciones caseras que el mapper no conoce. El coste es que una IA que renombre un rasgo ("Furia" por "Furia del bárbaro") deja el original pasivo más un duplicado activo, y hoy el parche descarta en silencio cualquier valor mal formado o fuera de rango.

Decidimos mantener la creación por nombre y cambiar `Nivel20Patch.apply` para que devuelva un resultado estructurado: la ficha fusionada, los poderes creados y las entradas ignoradas por mal formadas o fuera de rango. La vista previa de importación los muestra como avisos **no bloqueantes**, con el mismo patrón que los avisos del validador, para que el usuario detecte duplicados por renombre antes de confirmar.

Refuerzo en origen: `ai_prompt.dart` debe instruir a la IA para que respete los nombres exactos de los rasgos originales siempre que sea posible. El prompt de enriquecimiento ya pide el nombre "EXACTO como en el texto"; hay que mantener esa instrucción y no relajarla.

## Considered Options

- **Rechazar rasgos sin coincidencia**: evita duplicados por renombre pero pierde las acciones caseras, que son justo lo que el mapper no sabe clasificar.
- **Seguir ignorando en silencio**: descartado; esconde tanto los duplicados como los datos perdidos.

## Consequences

- Estado al escribir este ADR: **sin implementar**. Hoy `apply` devuelve solo el `CharacterModel` y no informa de nada.
- Cambiar el tipo de retorno de `apply` afecta a `nivel20_import.dart` y a `nivel20_srd_patch_test.dart`.
- Complementa a [ADR-0001](0001-importacion-nivel20-mapper-determinista-y-parche-ia.md).
