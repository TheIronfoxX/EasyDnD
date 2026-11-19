# Changelog

## 2.0.0 — rework

Reescritura completa de la app anterior.

### Novedades
- HUD de tres pestañas (Combate, Ficha, Mochila), cada una como índice de
  tarjetas que abren pantallas separadas.
- Combate: panel de estado, espacios de conjuro, recursos, acciones favoritas
  con lanzamiento rápido, conjuros agrupados por efecto, ataques y habilidades
  agrupados por lo que gastan.
- Hoja de resolución con explicación en español de cada tirada.
- Búsqueda de reglas.
- Importación desde Nivel20 (base determinista + parche de IA) o con IA.
- Editor de fichas de cuatro pestañas (Núcleo, Arsenal, Grimorio, Mochila).
- Respaldo JSON del roster, descarga en web y script para móvil.
- Tema único con cuatro mandos: claro/oscuro, forma, color principal y
  secundario.

### Cambios
- Los descansos y el seguimiento de turnos ya no están en la interfaz.
- El selector de temas, los presets y los temas propios se conservan en el
  código, pero ya no tienen entrada en la app (ADR-0007).
- Las fichas y el roster de la versión anterior se migran solos, sin borrar
  las claves viejas.
