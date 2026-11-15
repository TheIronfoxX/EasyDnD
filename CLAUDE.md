# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

EasyDnD: an offline combat HUD for D&D 5e, built with Flutter. Roster of
character sheets, action economy, dice rolls, resources, conditions, and
inventory — no network dependency at runtime (the only network use is
downloading a sheet from Nivel20 during import). Codebase and comments are
in Spanish; this is a personal/solo project, currently `2.0.0` ("rework"),
a full rewrite of an older single-file app.

## Commands

```bash
flutter pub get          # install deps
flutter analyze          # static analysis (flutter_lints)
flutter test             # run full test suite
flutter test test/hud_sheet_tab_test.dart   # run a single test file
flutter test --plain-name "some test name"  # run a single test by name
flutter run               # run on a connected device/emulator
flutter run -d chrome     # run on web
flutter build web --release
dart run flutter_launcher_icons   # regenerate app/web icons from assets/icon/icon.png
```

There is no CI config in this repo; `flutter analyze` + `flutter test` are
the pre-merge bar.

## Architecture

Layered, inside-out, under `lib/`:

```
core/      reglas puras y utilidades (dados, reglas D&D, resolución, tema) — no Flutter deps besides theme
  theme/   design tokens, palette, fonts, ThemeData — the only place colors/fonts are decided
  ui/      shared presentational widgets with no business logic
domain/    models, validator, AI import prompt — pure Dart, no Flutter
data/      repositories, persistence (SharedPreferences), Nivel20 extraction, spell catalog
state/     CharacterStore (roster/combat/inventory) and SkinController — ChangeNotifier, exposed via Provider
app/       widget root (MultiProvider + MaterialApp)
features/  UI per feature: hud, editor, import, skin
main.dart  bootstrap: builds and inits the store + skin controller before the first frame
```

### State: `CharacterStore` is one `ChangeNotifier` split by `part` files

`lib/state/character_store.dart` declares the class; `character_store_roster.dart`,
`character_store_combat.dart`, and `character_store_inventory.dart` are `part of`
the same library and extend it with per-topic methods. This is intentional: it's
**one** source of truth for the UI (single `ChangeNotifier`, single `notifyListeners`),
just split by file so no single file becomes a 1600-line god-object (that was the old
app's failure mode). When adding store behavior, add a method to the relevant `part`
file rather than creating a new store or a new provider.

- `activeCharacter` is nullable on purpose — an empty roster is a real, representable
  state (shows a welcome screen), not papered over with a mock character.
- Every mutation funnels through `_notifyAndPersist()`: notify listeners synchronously,
  persist to `SharedPreferences` fire-and-forget. Combat actions must never block on disk I/O.
- The store never touches plugins directly (`image_picker`, `file_picker`) — screens resolve
  paths/text first and pass resolved values in.

### Persistence: `RosterRepository` is the only `SharedPreferences` access point

Whole roster is serialized as a list of JSON strings under one key (`easydnd.roster.v3`).
Legacy keys from the old app (`character_roster_v2`, per-weapon `weapon_quantity_<id>`)
are migrated once at startup, non-destructively (old keys are left in place) and
idempotently (presence of the new key means migration already ran). `SkinController`
follows the same pattern with its own `easydnd.skin.*` keys and a one-time legacy migration.
Don't add other call sites for `SharedPreferences` — route through the existing repositories.

### Models carry the same JSON shape as the old app

`CharacterModel` (`lib/domain/models/character.dart`) intentionally mirrors the old
app's JSON (`basic_info`, `inventory`, `abilities_by_action`, `stats`, `spell_slots`,
`skills`, `lore_info`, `purse`, `resources`, `turn_status`, `active_conditions`,
`companions`) so existing exported sheets and the old roster migrate transparently.
New fields get silent, sensible fallbacks when missing from older JSON (e.g. `speed`
defaults to 9, `hitDieSides` is inferred from `characterClass` text) rather than
bumping the shape for minor additions. `schema_version: 2` at the root exists for
future breaking migrations. Most model fields are deliberately non-`final`: the HUD
mutates HP, charges, slots, and conditions in place during combat and relies on the
store to notify/persist afterward.

### Theming: never hardcode colors or fonts in widgets

Widgets must read `Theme.of(context)` or `context.appColors` (an extension in
`lib/core/theme/app_theme_colors.dart`) — never a literal `Color(...)` or font name.
`AppPalette` (`lib/core/theme/app_palette.dart`) is the source of truth for semantic
colors per brightness; the player's chosen accent color and font preset come from
`SkinController` and get threaded through `AppTheme.light()/dark()`
(`lib/core/theme/app_theme.dart`), which builds a Material 3 `ColorScheme.fromSeed`
from the accent and then overrides surfaces/text with the semantic palette so the
"dark parchment" look survives Material's seeding algorithm. Fonts are bundled
(`assets/fonts/`, see `pubspec.yaml`) rather than fetched, because the app is offline
and web's CanvasKit renderer doesn't resolve generic font family fallbacks.

### Rules and resolution logic stay Flutter-free

`core/dnd_rules.dart`, `core/dice.dart`, `core/resolution.dart`, and everything in
`domain/` (models, `character_validator.dart`, `ai_prompt.dart`) have no Flutter
dependency, so game-rule logic is testable without a widget tree.

## Testing conventions

- `test/fakes/fake_random.dart`: deterministic `Random` substitute for dice-roll
  tests — feed it a fixed `outcomes` list.
- `test/fakes/test_fichas.dart`: `buildFichaJson(...)` builds a minimal-but-complete
  character JSON covering every section the store/repository touch (weapon with
  charges, ability with charges, slots, resources, turn state, conditions, companion).
  Reuse it rather than hand-rolling fixture JSON; override only the fields a given
  test cares about.
- Repository/store tests mock `SharedPreferences` rather than hitting a real store.
- UI tests (`hud_*_test.dart`, `skin_screen_test.dart`, etc.) drive widgets against
  the real `CharacterStore`/`SkinController`, not fakes of them — only the
  persistence layer underneath is faked.

## Token discipline
- Read targeted line ranges instead of whole files when inspecting existing code.
- Do not run `flutter pub get` unless `pubspec.yaml` was modified.
