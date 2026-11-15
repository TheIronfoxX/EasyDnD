---
status: accepted
---
# Importación de Nivel20: ficha base determinista + parche de IA aditivo

La ficha de Nivel20 se construye siempre con `Nivel20Mapper` (determinista, sin IA). La IA nunca recibe ni devuelve la ficha: solo clasifica rasgos, extrae recursos, desglosa equipo y redacta textos, y responde con un parche de claves opcionales que `Nivel20Patch` fusiona sobre la ficha base sin tocar nada más. Se eligió así para que los números (atributos, PG, CA, ranuras, armas, conjuros SRD) no dependan de lo que invente un modelo.

Las monedas del parche son **adicionales y se suman** en el merge (nunca restan ni reemplazan). La deduplicación no vive en el merge sino en el prompt: `AiPrompt.forNivel20Enrichment` debe decirle a la IA qué monedas ya detectó el mapper para que devuelva solo las que falten (platino, electro, menciones narrativas que el regex no captura). Mantener la suma simple deja el merge predecible y testeable sin IA.

## Resolution

- El parche y el mapper cubren las **cinco denominaciones** de `Purse` (platino, oro, electro, plata, cobre): el regex del mapper, la clave `purse` del parche, el merge aditivo y el esquema e instrucciones del prompt se extienden en bloque. El comentario de cabecera de `nivel20_mapper.dart` que dice que `Purse` no tiene campos de electro ni platino se corrige.
- `AiPrompt.forNivel20Enrichment` debe **inyectar explícitamente** los valores del `purse` ya detectados por el mapper, no solo afirmar que se detectaron. Como `enrichmentSources` entrega el texto de equipo en crudo (con las menciones de monedas dentro), sin esos valores la IA puede releerlas y devolverlas, y el merge aditivo las contaría dos veces.
- El merge sigue siendo solo suma (nunca resta ni reemplaza).

## Consequences

- Estado al momento de escribir este ADR: **nada de lo anterior está implementado**. Hoy el prompt solo dice de forma genérica que la app "ya detectó las monedas del EQUIPO y las notas", y el regex, la clave `purse` y el merge solo manejan oro, plata y cobre.
- La implementación queda para cuando termine la auditoría. Debe cubrirse con tests en `nivel20_srd_patch_test.dart` y `nivel20_mapper_test.dart`.
