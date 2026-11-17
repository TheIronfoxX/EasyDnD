---
status: accepted
---
# Formato de respaldo JSON sin avatares y sin dependencias de compartir

Un respaldo es un JSON `{ "easydnd_backup": 1, "characters": [ ... ] }` y una exportación es el JSON de la ficha tal cual, el mismo que entiende `CharacterValidator`. Se guarda con `FilePicker.saveFile` y, si falla, se copia al portapapeles; no se añadieron `share_plus` ni `path_provider`. Los avatares (`avatar_path`, `lore_avatar_path`) se vacían al exportar porque son rutas locales del dispositivo y en otro quedarían rotas; incluir las imágenes en el archivo se descartó por tamaño y complejidad.

## Consequences

- Al restaurar en otro dispositivo las fichas llegan sin foto.
- Si el `id` de una ficha restaurada ya existe en el roster, se le genera uno nuevo (importar dos veces ya no duplica ids).
- «Reemplazar todo» descarta el roster actual con su estado de combate, coherente con [ADR-0005](0005-estado-de-combate-en-modelo-unico-y-reemplazo-completo.md).
- Una entrada corrupta dentro de un respaldo se omite sin afectar al resto.
- El formato se versiona con `easydnd_backup`; relacionado con [ADR-0004](0004-validacion-en-frontera-fallbacks-y-versionado-de-esquema.md).
