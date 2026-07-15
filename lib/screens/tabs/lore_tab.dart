import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/character_provider.dart';
import '../../theme/theme_notifier.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/themed_card.dart';

/// Fase 10 — Pestaña de Lore: lectura de los 5 campos narrativos clásicos
/// de ficha (trasfondo, rasgos, ideales, vínculos, defectos). Sigue el
/// mismo lenguaje visual que StatsTab/TurnTab — ThemedCard para el
/// "cristal con glow" y AppColors/ThemeNotifier para la paleta. Es de
/// solo lectura: no hay edición todavía.
class LoreTab extends StatelessWidget {
  const LoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final character = context.watch<CharacterProvider>().character;
    final accent = context.watch<ThemeNotifier>().accentColor;
    final lore = character.loreInfo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CRÓNICA',
            style: TextStyle(color: accent, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'serif'),
          ),
          const SizedBox(height: 4),
          Text(
            'La historia y el carácter detrás de la hoja de personaje.',
            style: TextStyle(color: context.appColors.textSecondary, fontSize: 12, fontFamily: 'serif'),
          ),
          const SizedBox(height: 16),
          _LoreSection(title: 'Trasfondo', icon: Icons.auto_stories, text: lore.backstory, accent: accent),
          _LoreSection(title: 'Rasgos de Personalidad', icon: Icons.face_retouching_natural, text: lore.personalityTraits, accent: accent),
          _LoreSection(title: 'Ideales', icon: Icons.local_fire_department, text: lore.ideals, accent: accent),
          _LoreSection(title: 'Vínculos', icon: Icons.link, text: lore.bonds, accent: accent),
          _LoreSection(title: 'Defectos', icon: Icons.warning_amber_rounded, text: lore.flaws, accent: accent),
        ],
      ),
    );
  }
}

/// Tarjeta de una sección de lore: cabecera con icono + título en el
/// color de acento, cuerpo en texto secundario con interlineado cómodo.
/// Si el campo viene vacío (ficha vieja pre-Fase-10), se omite la tarjeta
/// entera en vez de mostrar un hueco sin contenido.
class _LoreSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String text;
  final Color accent;

  const _LoreSection({required this.title, required this.icon, required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ThemedCard(
        accentColor: accent,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    fontSize: 13,
                    fontFamily: 'serif',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 13.5,
                fontFamily: 'serif',
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}