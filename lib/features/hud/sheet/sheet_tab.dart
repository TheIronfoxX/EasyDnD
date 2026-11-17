// Pestaña Ficha: lo que define al personaje, cada cosa en su pantalla.

import 'package:flutter/material.dart';

import '../../../core/ui/app_icons.dart';
import '../../../core/ui/clean_kit.dart';
import '../../../domain/models/character.dart';
import '../hud_pages.dart';
import '../hud_sheet_tab.dart';

class SheetTab extends StatelessWidget {
  const SheetTab({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final icons = AppIcons.of(context);
    final info = character.basicInfo;
    final mod = character.stats.modFor('dex');
    return CleanList(
      children: [
        NavRowCard(
          key: const ValueKey('nav-attributes'),
          icon: Icons.insights_rounded,
          title: 'Atributos',
          subtitle: 'Fuerza, Destreza, Constitución…',
          onTap: () => pushCharacterPage(
            context,
            title: 'Atributos',
            builder: (context, c) => [
              Text(
                'Defensa ${c.basicInfo.ac} · Iniciativa '
                '${mod >= 0 ? '+$mod' : '$mod'} · Te mueves '
                '${c.basicInfo.speed} ft por turno',
              ),
              const SizedBox(height: 12),
              HudAttributesSection(stats: c.stats),
            ],
          ),
        ),
        NavRowCard(
          key: const ValueKey('nav-skills'),
          icon: icons.ability,
          title: 'Habilidades',
          subtitle: 'Sigilo, Percepción, Persuasión…',
          onTap: () => pushCharacterPage(
            context,
            title: 'Habilidades',
            builder: (context, c) => [HudSkillsSection(skills: c.skills)],
          ),
        ),
        NavRowCard(
          key: const ValueKey('nav-story'),
          icon: Icons.menu_book_rounded,
          title: 'Historia',
          subtitle: info.race.trim().isEmpty
              ? 'Trasfondo y personalidad'
              : '${info.race.trim()} · trasfondo y personalidad',
          onTap: () => pushCharacterPage(
            context,
            title: 'Historia',
            builder: (context, c) => [
              HudLoreSection(character: c),
              HudCodexSection(character: c),
            ],
          ),
        ),
      ],
    );
  }
}
