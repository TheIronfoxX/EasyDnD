// Iconos semánticos del HUD que cambian de familia según el tema
// (`tactical.icons.style`): redondeados, angulosos o de contorno.
//
// Solo cubre los iconos con significado de juego (arma, conjuro, dado...);
// los iconos utilitarios (cerrar, añadir, flechas) siguen siendo `Icons.*`.

import 'package:flutter/material.dart';

import '../theme/tactical_theme_tokens.dart';
import '../theme/theme_style_tokens.dart';

@immutable
class AppIcons {
  const AppIcons(this.style);

  final IconStyle style;

  static AppIcons of(BuildContext context) =>
      AppIcons(context.tactical.icons.style);

  IconData _pick(IconData rounded, IconData sharp, IconData outlined) =>
      switch (style) {
        IconStyle.rounded => rounded,
        IconStyle.sharp => sharp,
        IconStyle.outlined => outlined,
      };

  IconData get weapon => _pick(
    Icons.sports_martial_arts_rounded,
    Icons.sports_martial_arts_sharp,
    Icons.sports_martial_arts_outlined,
  );
  IconData get spell => _pick(
    Icons.auto_awesome_rounded,
    Icons.auto_awesome_sharp,
    Icons.auto_awesome_outlined,
  );
  IconData get ability => _pick(
    Icons.flash_on_rounded,
    Icons.flash_on_sharp,
    Icons.flash_on_outlined,
  );
  IconData get bolt =>
      _pick(Icons.bolt_rounded, Icons.bolt_sharp, Icons.bolt_outlined);
  IconData get dice =>
      _pick(Icons.casino_rounded, Icons.casino_sharp, Icons.casino_outlined);
  IconData get spellbook => _pick(
    Icons.auto_stories_rounded,
    Icons.auto_stories_sharp,
    Icons.auto_stories_outlined,
  );
  IconData get shield =>
      _pick(Icons.shield_rounded, Icons.shield_sharp, Icons.shield_outlined);
  IconData get backpack => _pick(
    Icons.backpack_rounded,
    Icons.backpack_sharp,
    Icons.backpack_outlined,
  );
  IconData get classFeature => _pick(
    Icons.military_tech_rounded,
    Icons.military_tech_sharp,
    Icons.military_tech_outlined,
  );
  IconData get brokenHeart => _pick(
    Icons.heart_broken_rounded,
    Icons.heart_broken_sharp,
    Icons.heart_broken_outlined,
  );
  IconData get notes => _pick(
    Icons.menu_book_rounded,
    Icons.menu_book_sharp,
    Icons.menu_book_outlined,
  );
  IconData get companion =>
      _pick(Icons.pets_rounded, Icons.pets_sharp, Icons.pets_outlined);
}
