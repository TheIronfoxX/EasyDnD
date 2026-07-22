import 'dart:io';

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
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: _LoreAvatar(
                  // Si el jugador nunca ha tocado la foto de Lore, cae en la
                  // de perfil (avatarPath) como valor por defecto — pero solo
                  // como fallback de lectura: pickLoreAvatarForActiveCharacter
                  // escribe en loreAvatarPath, nunca en avatarPath, así que
                  // editar una no toca la otra.
                  imagePath: character.loreAvatarPath ?? character.avatarPath,
                  accent: accent,
                  name: character.basicInfo.name,
                ),
              ),
            ),
          ),
          Padding(
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
          ),
        ],
      ),
    );
  }
}

/// Foto de crónica: retrato en formato tarjeta (con bordes redondeados y
/// glow del acento, igual que ThemedCard), centrado y de ancho limitado
/// (ver ConstrainedBox en LoreTab) — no ocupa toda la pantalla, pero sigue
/// siendo más grande que un avatar de header. Tappable para abrir la
/// galería y guardar en loreAvatarPath (vía
/// CharacterProvider.pickLoreAvatarForActiveCharacter), sin tocar
/// avatarPath. Si loreAvatarPath es null, imagePath ya viene resuelto por
/// LoreTab con el fallback a avatarPath (foto de perfil); si ninguna de
/// las dos existe, se pintan las iniciales sobre un fondo de acento, en
/// vez de dejar un hueco vacío.
class _LoreAvatar extends StatelessWidget {
  final String? imagePath;
  final Color accent;
  final String name;

  const _LoreAvatar({required this.imagePath, required this.accent, required this.name});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<CharacterProvider>().pickLoreAvatarForActiveCharacter(),
      child: AspectRatio(
        // Proporción de retrato (más alto que ancho), no un cuadrado de
        // avatar — pensado para que la foto "respire" como portada, pero
        // limitada en ancho (ver ConstrainedBox en LoreTab) para que no
        // ocupe toda la pantalla.
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(color: accent.withOpacity(0.18), blurRadius: 20, spreadRadius: -4),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(accent.withOpacity(0.12), context.appColors.surfaceLight),
                    image: imagePath != null
                        ? DecorationImage(image: FileImage(File(imagePath!)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: imagePath == null
                      ? Center(
                          child: Text(
                            _initials,
                            style: TextStyle(color: accent, fontSize: 64, fontWeight: FontWeight.w800, fontFamily: 'serif'),
                          ),
                        )
                      : null,
                ),
                // Degradado inferior para que el nombre y el icono de
                // cámara se lean bien encima de cualquier foto, clara u
                // oscura.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 90,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0), Colors.black.withOpacity(0.65)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'serif',
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withOpacity(0.7), width: 1),
                    ),
                    child: Icon(Icons.photo_camera, size: 14, color: accent),
                  ),
                ),
              ],
            ),
          ),
        ),
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