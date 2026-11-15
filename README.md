# EasyDnD

HUD de combate offline para D&D 5e pensado para la mesa de juego: roster de
fichas, economía de acciones, tiradas de dados, recursos, condiciones e
inventario, sin depender de conexión ni de servicios externos.

La app es un rework completo (`2.0.0`) con foco en datos sólidos, tests de
comportamiento y un sistema de diseño propio.

## Funcionalidad

- **Roster de fichas**: varias fichas guardadas en el dispositivo, con
  migración automática del roster de la versión vieja.
- **Importación con IA**: wizard en tres pasos (fuente → ficha cruda →
  preview) con validación y corrección de fichas ya existentes.
- **Importación desde Nivel20**: descarga la ficha cruda a partir del enlace.
- **Editor manual por secciones**: datos básicos, atributos, competencias,
  ranuras, habilidades, recursos, armas, objetos, lore y compañeros.
- **HUD de combate**: vida, economía de turno, condiciones, recursos,
  descansos, acciones, dados y una hoja de resolución de tiradas.
- **Inventario y ficha**: equipo, bolsa, monedas, compañeros y hoja de solo
  lectura.
- **Skins**: modo claro/oscuro, acento por presets o color libre (HSV) y
  tipografía elegible, todo persistido.

## Requisitos

- Flutter estable (el repo se desarrolla con la versión del canal stable
  instalada localmente).
- Dart incluido con Flutter.

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Para Android:

```bash
flutter run -d <device>
```

Para web:

```bash
flutter run -d chrome
flutter build web --release
```

> La app no requiere red en runtime. La descarga desde Nivel20 solo se usa
> durante la importación.

## Arquitectura

El código se organiza por capas, de adentro hacia afuera:

```
lib/
├── core/        # reglas puras y utilidades (dados, reglas D&D, resolución,
│   └── theme/   # tokens de diseño, paleta, tipografía, tema)
├── domain/      # modelos, validador y prompt de IA
├── data/        # repositorios, persistencia y extracción de Nivel20
├── state/       # CharacterStore (roster/combate/inventario) y SkinController
├── app/         # raíz de widgets (providers + MaterialApp)
├── features/    # UI por feature: hud, editor, import, skin
└── main.dart    # bootstrap: inicializa store y skin antes de pintar
```

Reglas que sostienen el diseño:

- Los widgets **no hardcodean colores ni fuentes**: todo sale de
  `Theme.of(context)`, `context.appColors` o los tokens de `core/theme`.
- Las reglas de juego viven en `core/` y `domain/`, sin depender de Flutter,
  para poder testearlas sin UI.
- La persistencia se encapsula en repositorios; el estado expone
  `ChangeNotifier` y la UI escucha con Provider.

## Persistencia

- `SharedPreferences` guarda fichas y preferencias. Las fichas son JSONs
  chicos, por eso se eligió sobre SQLite.
- El roster viejo (`roster` / `characters`) se migra una sola vez al
  arrancar. Las claves viejas no se borran.
- El skin usa claves propias (`easydnd.skin.*`) y migra
  `accent_color_argb` / `is_dark_mode` la primera vez.

## Assets e íconos

El ícono fuente vive en `assets/icon/icon.png`. Los íconos de Android y web
se regeneran con `flutter_launcher_icons`:

```bash
dart run flutter_launcher_icons
```

El splash de Android usa el color de fondo de la app (`#131009`) para evitar
el flash blanco antes del primer frame.

## Fichas de ejemplo

En `fichas/` hay fichas JSON reales útiles para pruebas manuales e
importación.

## Tests

La suite cubre reglas, modelos, validación, repositorios, stores y flujos de
UI de punta a punta contra el store real con `SharedPreferences` mockeado.

```bash
flutter test
```
