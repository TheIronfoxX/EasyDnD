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
    final t = context.tactical;
    final purse = character.purse;
    final coins = <(String, int, Color)>[
      if (purse.platinum > 0) ('PPT', purse.platinum, t.coinPlatinum),
      ('PO', purse.gold, t.coinGold),
      if (purse.electrum > 0) ('PE', purse.electrum, t.coinElectrum),
      ('PP', purse.silver, t.coinSilver),
      ('PC', purse.copper, t.coinCopper),
    ];
    return CleanList(
      children: [
        StatGrid(
          key: const ValueKey('coins-grid'),
          perRow: coins.length,
          tiles: [
            for (final c in coins)
              StatTile(value: '${c.$2}', label: c.$1, tone: c.$3, ring: 48),
          ],
        ),
        NavTilePair(
          tiles: [
            NavTileCard(
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
            NavTileCard(
              key: const ValueKey('nav-items'),
              icon: icons.backpack,
              iconColor: context.tactical.coinCopper,
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
          ],
        ),
        NavTilePair(
          tiles: [
            NavTileCard(
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
            NavTileCard(
              key: const ValueKey('nav-notes'),
              icon: icons.notes,
              iconColor: context.tactical.spell,
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
        ),
      ],
    );
  }
}
