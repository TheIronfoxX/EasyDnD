// Pestaña Mochila: armas, objetos, dinero y notas, cada uno en su
// pantalla.

import 'package:flutter/material.dart';

import '../../../core/theme/tactical_theme_tokens.dart';
import '../../../core/ui/app_icons.dart';
import '../../../core/ui/clean_kit.dart';
import '../../../domain/models/character.dart';
import '../hud_inventory_tab.dart';
import '../hud_notes_tab.dart';
import '../hud_pages.dart';

class BackpackTab extends StatelessWidget {
  const BackpackTab({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final icons = AppIcons.of(context);
    final inv = character.inventory;
    final gold = character.purse.totalInGold;
    final goldText = gold == gold.roundToDouble()
        ? gold.toStringAsFixed(0)
        : gold.toStringAsFixed(2);
    final notes = character.sessionNotes.length;
    return CleanList(
      children: [
        NavRowCard(
          key: const ValueKey('nav-weapons'),
          icon: icons.weapon,
          iconColor: context.tactical.weapon,
          title: 'Armas',
          subtitle: inv.weapons.isEmpty
              ? 'Ninguna'
              : inv.weapons.map((w) => w.name).join(', '),
          onTap: () => pushCharacterPage(
            context,
            title: 'Armas',
            builder: (context, c) => [HudWeaponsSection(character: c)],
          ),
        ),
        NavRowCard(
          key: const ValueKey('nav-items'),
          icon: icons.backpack,
          title: 'Objetos',
          subtitle: inv.mundaneItems.isEmpty
              ? 'Ninguno'
              : '${inv.mundaneItems.length} en la mochila',
          onTap: () => pushCharacterPage(
            context,
            title: 'Objetos',
            builder: (context, c) => [HudItemsSection(character: c)],
          ),
        ),
        NavRowCard(
          key: const ValueKey('nav-money'),
          icon: Icons.paid_rounded,
          iconColor: context.tactical.coinGold,
          title: 'Dinero',
          subtitle: 'Equivale a $goldText po',
          onTap: () => pushCharacterPage(
            context,
            title: 'Dinero',
            builder: (context, c) => [HudPurseSection(character: c)],
          ),
        ),
        NavRowCard(
          key: const ValueKey('nav-notes'),
          icon: icons.notes,
          title: 'Notas',
          subtitle: notes == 0 ? 'Diario de sesiones' : '$notes notas',
          onTap: () => pushCharacterPage(
            context,
            title: 'Notas',
            scrollable: false,
            builder: (context, c) => [HudNotesTab(character: c)],
          ),
        ),
      ],
    );
  }
}
