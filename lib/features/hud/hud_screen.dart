// Shell del HUD de combate (Etapa 5a).
//
// La estructura definitiva: una AppBar con la identidad de la ficha
// activa, el selector de roster y el menú de mantenimiento (editar,
// corregir con IA, importar o crear otra ficha), y una NavigationBar
// con los tres tabs del juego — Combate, Ficha e Inventario.
//
// Los cuerpos de los tabs son provisorios en esta sub-etapa: el
// tablero real llega en 5b, las acciones con dados en 5c y el
// inventario/ficha en 5d. Lo que SÍ queda cerrado acá es la
// navegación entre pantallas y el cambio de personaje activo.
//
// El estado de la UI (tab seleccionado) es local: el store guarda la
// ficha y el índice activo, no qué pestaña estaba mirando el jugador.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/character.dart';
import '../../state/character_store.dart';
import '../editor/character_editor_screen.dart';
import '../import/import_wizard_screen.dart';
import 'welcome_screen.dart';

/// Acciones del menú de mantenimiento de la AppBar.
enum _HudMenuAction { edit, correctWithAi, importNew, createNew }

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
    final identity = [
      if (info.race.trim().isNotEmpty) info.race.trim(),
      if (info.characterClass.trim().isNotEmpty) info.characterClass.trim(),
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            child: Text(
              _initials(info.name),
              style: const TextStyle(fontWeight: FontWeight.w700),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (identity.isNotEmpty)
              Text(
                identity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _HudSectionPlaceholder(
            icon: Icons.shield_rounded,
            title: 'Tablero de combate',
            description:
                'Acá va la hoja viva: PG, CA, velocidad, '
                'economía de turno y condiciones.',
          ),
          _HudSectionPlaceholder(
            icon: Icons.badge_outlined,
            title: 'Hoja de personaje',
            description:
                'Atributos, competencias, historia y códice '
                'de la ficha activa.',
          ),
          _HudSectionPlaceholder(
            icon: Icons.backpack_rounded,
            title: 'Inventario y compañeros',
            description: 'Armas, objetos, bolsa y aliados del personaje.',
          ),
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

  /// "Rook" → "R", "Rook el Intacto" → "RI". Sin paquete de caracteres:
  /// alcanza con la primera letra de la primera y la última palabra.
  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words.first.substring(0, 1) + words.last.substring(0, 1))
        .toUpperCase();
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
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// Cuerpo provisorio de un tab. Cada sub-etapa siguiente lo reemplaza
/// por la sección real sin tocar el shell.
class _HudSectionPlaceholder extends StatelessWidget {
  const _HudSectionPlaceholder({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
