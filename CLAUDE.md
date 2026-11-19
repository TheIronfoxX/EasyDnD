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
core/      reglas puras y utilidades (dados, reglas D&D, resolución, json_sanitizer) — no Flutter deps besides theme
  theme/   design tokens, palette, fonts, accent/font/theme presets, tactical tokens, ThemeData — the only place colors/fonts are decided
  ui/      shared presentational widgets with no business logic
domain/    models (incl. srd_* catalog models), validator, AI import prompt, CharacterBuilderEngine,
           Nivel20Mapper/Nivel20Patch — pure Dart, no Flutter
data/      repositories, persistence (SharedPreferences), Nivel20 extraction, SRD catalogs (class, equipment, spell)
state/     CharacterStore (roster/combat/inventory) and SkinController — ChangeNotifier, exposed via Provider
app/       widget root (MultiProvider + MaterialApp)
features/  UI per feature: hud (3 tabs: Combate, Ficha, Mochila), editor (4 tabs: Núcleo, Arsenal, Grimorio, Mochila), import, skin (legacy, no entry point)
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
defaults to 30 (feet), `hitDieSides` is inferred from `characterClass` text) rather than
bumping the shape for minor additions. `schema_version: 2` at the root exists for
future breaking migrations. Most model fields are deliberately non-`final`: the HUD
mutates HP, charges, slots, and conditions in place during combat and relies on the
store to notify/persist afterward.

### Theming: never hardcode colors or fonts in widgets

Widgets must read `Theme.of(context)` or `context.appColors` (an extension in
`lib/core/theme/app_theme_colors.dart`) — never a literal `Color(...)` or font name.
The app has ONE design, the clean theme: `AppTheme.clean(brightness, accent)`
(`lib/core/theme/app_theme.dart` + palettes/tokens in `clean_theme.dart`) — Nothing
OS–style: monochrome black/white palette with the accent (default signal red) as the
only color, very rounded surfaces, dot-grid backdrop, circular medallions with dotted
rings, dot bars (`DotBar`/`DotRing` in `clean_kit.dart`). Fonts: JetBrains Mono for
`titleLarge` and up and `labelSmall`/`labelMedium`, Inter for everything else. `SkinController.lightTheme/
darkTheme` always build it from four independent knobs the player sets in Ajustes →
Tema: light/dark (the only thing that decides the background — fixed neutral palettes,
plain, no pattern), shape (`CleanThemeStyle`: Limpio/Grimorio/Escarcha — silhouette only,
via the `CleanShape` extension in `clean_shape.dart`: corner scale, bevel, card outline;
surfaces ask `context.cleanShape.surface(16)`/`radius(16)` with the Limpio radius instead
of hardcoding one), primary color (accent) and secondary color (`colorScheme.secondary`,
`tactical.spell`; defaults to/recommends harmonies of the primary via `SecondaryColors`).
It still goes through `AppTheme.fromParts` (brightness + `AppPalette` +
`TacticalThemeTokens`), so `context.tactical` role colors (`weapon`, `spell`, `heal`,
`damage`...) keep working. Fonts are bundled (`assets/fonts/`) because the app is
offline and web's CanvasKit renderer doesn't resolve generic font fallbacks.

The old theme system — preset catalog (`theme_presets.dart`), player-made
`CustomTheme`s, font presets, `SkinScreen`/`MyThemesScreen`/`ThemeEditorScreen` —
is kept in the code (and its `easydnd.skin.*` keys are preserved) but has no entry
point and no longer builds the theme. Don't delete it without asking (ADR-0007).

### HUD: three index tabs, one screen per topic

`features/hud/hud_screen.dart` is the shell: app bar (avatar, name → roster sheet,
rules search, ⋮ = Recargar todo / Editar ficha / Ajustes) and three tabs —
`combat/combat_tab.dart`, `sheet/sheet_tab.dart`, `backpack/backpack_tab.dart`.
Combate, top to bottom: one status panel — `hero_header.dart` row (emblem, class ·
level, `motto` only if set, ✎ → emblem/motto editor), HP row `actual/máx` with −1/+1
(tap → life sheet, key `hp-pill`), and Armadura / Iniciativa / Velocidad as plain
numbers whose plain-Spanish explanation is a tap tooltip (the spell DC lives on the
Conjuros page, not here). Then "Espacios de conjuro" as `SpellSlotsGrid`
(`combat/spell_slots_grid.dart`, shared with the Conjuros page: 3 columns of tinted tiles,
big level, `actual/máx`, segmented bar) and "Recursos", one card each (name,
`actual/máx`, thin bar, −/+), both with ↻ in the section title. Then one Acciones card
(Favoritas + the filterable list as flat rows with quick-cast; Conjuros / Ataques links
in its header push their pages via `pushCharacterPage`), then Estados/Compañeros rows. Vista Guiada / Compacta (Ajustes) reuses `SkinController.compactHud`.
The Conjuros and Ataques y habilidades pages live in `combat/power_pages.dart`
(`openSpellsPage`/`openAbilitiesPage`): one card per group of flat `PowerRow`s with
quick-cast. Spells: the spell save DC card and the slot grid on top, then grouped by what
they do — Ataque / Curación / Estados / Utilidad, classified by `spellEffectOf` in
`domain/spell_effect.dart`. Abilities: a category filter (Daño/Defensa/Apoyo/Utilidad),
then grouped by what they spend (Armas, Acción, Adicional, Reacción), passives folded.
Rows and `groupedPowerList` live in `combat/powers.dart`; categorization and the plain-language fallback live in
`domain/power_category.dart`. Rolls are built by `hud_roll_actions.dart` and
resolved by `hud_resolution_sheet.dart`, which opens with a plain-Spanish sentence
(`explainRoll`). Rests and turn tracking are intentionally absent from the UI (store
methods remain) — do not add a turn tracker. Shared visual pieces for new screens:
`core/ui/clean_kit.dart` (`CleanCard`, `NavRowCard`, `CleanSectionTitle`, `CleanPage`).
Target audience is novice players: plain Spanish, one action per row, no jargon
without explanation.

### Rules and resolution logic stay Flutter-free

`core/dnd_rules.dart`, `core/dice.dart`, `core/resolution.dart`, and everything in
`domain/` (models, `character_validator.dart`, `ai_prompt.dart`) have no Flutter
dependency, so game-rule logic is testable without a widget tree.

### Import: deterministic base + AI patch

Nivel20 import builds the base sheet with `Nivel20Mapper` (no AI); the AI only returns a
sparse "patch" that `Nivel20Patch` merges on top. The full-sheet AI import
(`AiPrompt.forEmptySheet`/`forEmbeddedSource`) is supported but secondary; `forCorrection`
serves both paths. `CharacterBuilderEngine` is only the SRD rules/calculation engine behind
the editor (the multi-step creation wizard was dropped). Details and pending work: ADR-0001
to ADR-0003; `power_role`/`plain_summary`/`when_to_use`/`spell_notes`: ADR-0007.

## Domain language and decisions

- `GLOSSARY.md` — canonical domain terms (Ficha, Estado de combate, Poder, Importación, Parche…). Use them.
- `docs/adr/` — architecture decisions (import strategy, validation/versioning, combat state).
  Read the relevant ADR before changing import, validation or store replace semantics.

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

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`TheIronfoxX/EasyDnD`), via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
