// Shell del HUD (rework para novatos).
//
// AppBar limpia: avatar, nombre (toca → cambiar de personaje), una
// píldora pequeña con la vida (toca → hoja de Vida), la lupa del
// buscador de reglas y un ⋮ con solo tres cosas: Recargar todo, Editar
// ficha y Ajustes. Debajo, tres pestañas que son índices de tarjetas:
// Combate, Ficha y Mochila. Cada tarjeta abre su propia pantalla.
//
// El estado de la UI (pestaña elegida) es local; el store solo guarda la
// ficha y el índice activo. Borrar la última ficha cae en la bienvenida
// (el StartupGate escucha el mismo store).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/theme/tactical_theme_tokens.dart';
import '../../core/theme/telemetry.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/character_avatar.dart';
import '../../core/ui/clean_kit.dart';
import '../../domain/models/character.dart';
import '../../state/character_store.dart';
import '../editor/character_editor_screen.dart';
import 'backpack/backpack_tab.dart';
import 'combat/combat_tab.dart';
import 'hud_status_tab.dart';
import 'rules_search_screen.dart';
import 'settings_screen.dart';
import 'sheet/sheet_tab.dart';
import 'welcome_screen.dart';

/// Ancho desde el que la barra inferior pasa a ser un riel lateral.
const double kHudRailBreakpoint = 600;

enum _HudMenuAction { refillAll, edit, settings }

class _HudDestination {
  const _HudDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});

  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  int _tabIndex = 0;

  List<_HudDestination> _destinations(AppIcons icons) => [
    _HudDestination('Combate', icons.weapon, icons.weapon),
    const _HudDestination(
      'Ficha',
      Icons.person_outline_rounded,
      Icons.person_rounded,
    ),
    _HudDestination('Mochila', icons.backpack, icons.backpack),
  ];

  Future<void> _onMenuAction(
    _HudMenuAction action,
    CharacterModel character,
  ) async {
    switch (action) {
      case _HudMenuAction.refillAll:
        final store = context.read<CharacterStore>();
        // "Recargar todo" = lo que hacía el descanso largo, sin menús.
        store.longRest();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todo recargado: vida, ranuras, recursos y usos.'),
          ),
        );
      case _HudMenuAction.edit:
        await pushPage<void>(
          context,
          CharacterEditorScreen(character: character),
        );
      case _HudMenuAction.settings:
        await pushPage<void>(context, const SettingsScreen());
    }
  }

  void _openLife() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Consumer<CharacterStore>(
        builder: (context, store, _) {
          final c = store.activeCharacter;
          if (c == null) return const SizedBox(height: 120);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: HudHealthSection(character: c),
          );
        },
      ),
    );
  }

  void _openRoster(CharacterStore store) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Tus personajes',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
          ),
          for (var i = 0; i < store.roster.length; i++)
            InkWell(
              key: ValueKey('roster-$i'),
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(sheetContext).pop();
                store.switchCharacter(i);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: _RosterRow(
                  character: store.roster[i],
                  active: i == store.activeIndex,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CharacterStore>();
    final character = store.activeCharacter;
    if (character == null) return const WelcomeScreen();

    final info = character.basicInfo;
    final theme = Theme.of(context);
    final icons = AppIcons.of(context);
    final destinations = _destinations(icons);
    final wide = MediaQuery.sizeOf(context).width >= kHudRailBreakpoint;
    // "Mago 14 (Escuela de Evocación)" → "Mago 14": lo corto se lee mejor.
    final shortClass = info.characterClass.split('(').first.trim();

    final tabs = <Widget>[
      CombatTab(character: character),
      SheetTab(character: character),
      BackpackTab(character: character),
    ];
    final body = IndexedStack(index: _tabIndex, children: tabs);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: CharacterAvatar(
            avatarPath: character.avatarPath,
            name: info.name,
            size: 40,
            onTap: () => AvatarPickerHelper.showAvatarOptions(
              context,
              currentPath: character.avatarPath,
              onSelected: store.setAvatarPath,
            ),
          ),
        ),
        titleSpacing: AppSpacing.sm,
        title: InkWell(
          key: const ValueKey('roster-switch'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openRoster(store),
          child: Tooltip(
            message: 'Cambiar de personaje',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (shortClass.isNotEmpty)
                        Text(
                          shortClass,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
        actions: [
          _HpPill(info: info, onTap: _openLife),
          IconButton(
            key: const ValueKey('rules-search'),
            tooltip: 'Buscar reglas',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => pushPage<void>(context, const RulesSearchScreen()),
          ),
          PopupMenuButton<_HudMenuAction>(
            tooltip: 'Más opciones',
            onSelected: (action) => _onMenuAction(action, character),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _HudMenuAction.refillAll,
                child: _MenuRow(
                  icon: Icons.refresh_rounded,
                  label: 'Recargar todo',
                ),
              ),
              PopupMenuItem(
                value: _HudMenuAction.edit,
                child: _MenuRow(
                  icon: Icons.edit_rounded,
                  label: 'Editar ficha',
                ),
              ),
              PopupMenuItem(
                value: _HudMenuAction.settings,
                child: _MenuRow(icon: Icons.settings_rounded, label: 'Ajustes'),
              ),
            ],
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tabIndex,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _tabIndex = i),
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
    );
  }
}

/// La vida, en chiquitito: número y una barrita. Toca → hoja de Vida.
class _HpPill extends StatelessWidget {
  const _HpPill({required this.info, required this.onTap});

  final BasicInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tactical = context.tactical;
    final ratio = info.hpMax <= 0
        ? 0.0
        : (info.currentHp / info.hpMax).clamp(0.0, 1.0);
    final color = ratio <= 0.25 ? tactical.damage : tactical.heal;

    return Tooltip(
      message: 'Vida',
      child: InkWell(
        key: const ValueKey('hp-pill'),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '${info.currentHp}/${info.hpMax}'
                    '${info.tempHp > 0 ? ' +${info.tempHp}' : ''}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700)
                        .tabular,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 56,
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 3,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila del roster: nombre, clase/nivel y PG con una barra fina, para
/// elegir personaje sabiendo en qué estado quedó cada uno.
class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.character, required this.active});

  final CharacterModel character;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tactical = context.tactical;
    final info = character.basicInfo;
    final ratio = info.hpMax <= 0
        ? 0.0
        : (info.currentHp / info.hpMax).clamp(0.0, 1.0);
    final hpColor = ratio <= 0.25 ? tactical.damage : tactical.heal;
    final characterClass = info.characterClass.trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: active ? scheme.primary : tactical.metalBorder,
              borderRadius: BorderRadius.circular(
                context.tactical.shapes.pillRadius,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                Text(
                  [
                    if (characterClass.isNotEmpty) characterClass,
                    'Nv. ${info.level}',
                    'PG ${info.currentHp}/${info.hpMax}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)
                      .tabular,
                ),
                const SizedBox(height: AppSpacing.xs),
                LinearProgressIndicator(
                  value: ratio,
                  minHeight: 3,
                  color: hpColor,
                  borderRadius: BorderRadius.circular(
                    context.tactical.shapes.pillRadius,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (active)
            Icon(Icons.check_rounded, size: 18, color: scheme.primary),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
