// Shell del HUD de combate (Etapa 5).
//
// La estructura definitiva: una AppBar con la identidad de la ficha
// activa, el selector de roster y el menú de mantenimiento (editar,
// corregir con IA, importar, crear o eliminar una ficha), y una
// NavigationBar con los tres tabs del juego — Combate, Ficha e
// Inventario.
//
// El estado de la UI (tab seleccionado) es local: el store guarda la
// ficha y el índice activo, no qué pestaña estaba mirando el jugador.
// Borrar la última ficha cae en la bienvenida sin reiniciar la app
// (el StartupGate escucha el mismo store).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/character.dart';
import '../../state/character_store.dart';
import '../editor/character_editor_screen.dart';
import '../import/import_wizard_screen.dart';
import '../skin/skin_screen.dart';
import 'hud_combat_tab.dart';
import 'hud_dialogs.dart';
import 'hud_inventory_tab.dart';
import 'hud_sheet_tab.dart';
import 'hud_widgets.dart';
import 'welcome_screen.dart';
import '../../core/theme/design_tokens.dart';

/// Acciones del menú de mantenimiento de la AppBar.
enum _HudMenuAction {
  edit,
  correctWithAi,
  importNew,
  createNew,
  appearance,
  delete,
}

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});

  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  int _tabIndex = 0;

  Future<void> _openEditor(CharacterModel character) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CharacterEditorScreen(character: character),
      ),
    );
  }

  Future<void> _openWizard({int? replaceIndex}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImportWizardScreen(replaceIndex: replaceIndex),
      ),
    );
  }

  Future<void> _onMenuAction(
    _HudMenuAction action,
    CharacterModel character,
  ) async {
    switch (action) {
      case _HudMenuAction.edit:
        await _openEditor(character);
      case _HudMenuAction.correctWithAi:
        await _openWizard(
          replaceIndex: context.read<CharacterStore>().activeIndex,
        );
      case _HudMenuAction.importNew:
        await _openWizard();
      case _HudMenuAction.createNew:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CharacterEditorScreen(),
          ),
        );
      case _HudMenuAction.appearance:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SkinScreen()));
      case _HudMenuAction.delete:
        await _deleteCharacter(character);
    }
  }

  /// Borrado con confirmación. El índice se captura ANTES del diálogo:
  /// mientras está abierto nadie más puede cambiar el roster, pero si
  /// algo lo hiciera el store igual ignora índices fuera de rango.
  Future<void> _deleteCharacter(CharacterModel character) async {
    final store = context.read<CharacterStore>();
    final messenger = ScaffoldMessenger.of(context);
    final index = store.activeIndex;
    final name = character.basicInfo.name;

    final confirmed = await showDeleteCharacterDialog(context, name: name);
    if (!confirmed || !mounted) return;

    store.deleteCharacter(index);

    // Con el roster vacío la app vuelve a la bienvenida; ahí el aviso
    // sobra. Con fichas restantes, confirma que el borrado se hizo.
    if (store.roster.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ficha de $name eliminada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CharacterStore>();
    final character = store.activeCharacter;

    // La StartupGate ya decide entre bienvenida y HUD, pero el shell no
    // asume que el árbol de arriba siempre estuvo mirando el store: si
    // el roster se vació en el medio, cae a la bienvenida igual.
    if (character == null) return const WelcomeScreen();

    final info = character.basicInfo;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final identity = [
      if (info.race.trim().isNotEmpty) info.race.trim(),
      if (info.characterClass.trim().isNotEmpty) info.characterClass.trim(),
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 60,
        // El degradé sale del acento del skin, no de un color fijo: así
        // el header acompaña cualquier preset sin tocar nada acá.
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.16),
                scheme.surface,
              ],
            ),
          ),
        ),
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (identity.isNotEmpty)
              Text(
                identity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          _RosterSelector(store: store, onSelected: store.switchCharacter),
          PopupMenuButton<_HudMenuAction>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) => _onMenuAction(action, character),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _HudMenuAction.edit,
                child: _MenuRow(
                  icon: Icons.edit_rounded,
                  label: 'Editar ficha',
                ),
              ),
              PopupMenuItem(
                value: _HudMenuAction.correctWithAi,
                child: _MenuRow(
                  icon: Icons.published_with_changes_rounded,
                  label: 'Corregir con IA',
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _HudMenuAction.importNew,
                child: _MenuRow(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Importar otra ficha',
                ),
              ),
              PopupMenuItem(
                value: _HudMenuAction.createNew,
                child: _MenuRow(
                  icon: Icons.person_add_rounded,
                  label: 'Crear ficha a mano',
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _HudMenuAction.appearance,
                child: _MenuRow(
                  icon: Icons.palette_outlined,
                  label: 'Apariencia',
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _HudMenuAction.delete,
                child: _MenuRow(
                  icon: Icons.delete_forever_rounded,
                  label: 'Eliminar ficha',
                  destructive: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          HudCombatTab(character: character),
          HudSheetTab(character: character),
          HudInventoryTab(character: character),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Combate',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge_rounded),
            label: 'Ficha',
          ),
          NavigationDestination(
            icon: Icon(Icons.backpack_outlined),
            selectedIcon: Icon(Icons.backpack_rounded),
            label: 'Inventario',
          ),
        ],
      ),
    );
  }


}

/// Selector de personaje activo. Lista el roster completo con una tilde
/// en el actual; el store ignora índices inválidos, así que la UI no
/// tiene que revalidar nada.
class _RosterSelector extends StatelessWidget {
  const _RosterSelector({required this.store, required this.onSelected});

  final CharacterStore store;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Cambiar de personaje',
      icon: const Icon(Icons.groups_rounded),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (var i = 0; i < store.roster.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    store.roster[i].basicInfo.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (i == store.activeIndex)
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: color == null ? null : TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}
