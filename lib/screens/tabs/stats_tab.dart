import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/stats_model.dart';
import '../../providers/character_provider.dart';
import '../../theme/theme_notifier.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/themed_card.dart';
import '../../widgets/journal_number_text.dart';
import '../../widgets/resolution_modal.dart';

/// Fase 8 — Matriz de Habilidades.
///
/// Esta pantalla no existía como archivo independiente antes de la
/// Fase 8 (main_hud_screen.dart ya la importaba, pero el zip de la
/// Fase 7 nunca la trajo), así que se construye aquí desde cero
/// siguiendo el mismo lenguaje visual que el resto del HUD: ThemedCard
/// para el "cristal con glow", JournalNumberText para los números
/// grandes tipo matriz de puntos, y AppColors/ThemeNotifier para la
/// paleta oscura + acento libre.
///
/// Fase 9: el Grid de atributos se sustituyó por una lista vertical de
/// tarjetas horizontales (modificador a la izquierda, nombre+descripción
/// a la derecha), para que toda la pestaña fluya en una sola columna
/// junto con la sección de "HABILIDADES" de más abajo.
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final character = context.watch<CharacterProvider>().character;
    final accent = context.watch<ThemeNotifier>().accentColor;
    final stats = character.stats.asList;
    final skills = character.skills;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'ATRIBUTOS',
          style: TextStyle(color: accent, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'serif'),
        ),
        const SizedBox(height: 4),
        Text(
          'Las seis puntuaciones base de tu personaje.',
          style: TextStyle(color: context.appColors.textSecondary, fontSize: 12, fontFamily: 'serif'),
        ),
        const SizedBox(height: 16),
        ...stats.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AttributeRow(stat: s, accent: accent),
          ),
        ),
        _SectionDivider(accent: accent),
        if (skills.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Este personaje todavía no tiene habilidades registradas.',
              style: TextStyle(color: context.appColors.textSecondary, fontSize: 12.5, fontFamily: 'serif'),
            ),
          )
        else
          ...skills.map(
            (skill) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SkillRow(skill: skill, accent: accent),
            ),
          ),
      ],
    );
  }
}

/// Tarjeta horizontal de atributo: a la izquierda el modificador grande
/// tipo "matriz de puntos" (con el valor bruto debajo, pequeño); a la
/// derecha, expandido, el nombre y una descripción corta a dos líneas
/// como máximo (evita que fichas con textos largos rompan el layout).
class _AttributeRow extends StatelessWidget {
  final AbilityScore stat;
  final Color accent;

  const _AttributeRow({required this.stat, required this.accent});

  @override
  Widget build(BuildContext context) {
    return ThemedCard(
      accentColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JournalNumberText(text: stat.modFormatted, color: accent, fontSize: 28),
                const SizedBox(height: 3),
                Text(
                  '${stat.value}',
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 11.5, fontFamily: 'serif'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 42, color: accent.withOpacity(0.15)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.name.toUpperCase(),
                  style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    fontFamily: 'serif',
                  ),
                ),
                if (stat.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    stat.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 11.5, fontFamily: 'serif'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Separador entre la sección de atributos y la de habilidades: una
/// línea sutil a cada lado del título, tintada con el color de acento,
/// para no romper la estética de cristal/metal con un Divider plano de
/// Material por defecto.
class _SectionDivider extends StatelessWidget {
  final Color accent;

  const _SectionDivider({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: accent.withOpacity(0.25))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'HABILIDADES',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
                fontSize: 13,
                fontFamily: 'serif',
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: accent.withOpacity(0.25))),
        ],
      ),
    );
  }
}

/// Fila compacta de habilidad: nombre a la izquierda, modificador a la
/// derecha, dentro de un contenedor translúcido con glow leve. Tappable:
/// abre el mismo ResolutionModal que usan armas y conjuros, pero sin
/// daño/lore — las habilidades solo tiran d20 + modificador.
class _SkillRow extends StatelessWidget {
  final Skill skill;
  final Color accent;

  const _SkillRow({required this.skill, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          showResolutionModal(
            context: context,
            accent: accent,
            name: skill.name,
            modifier: skill.modifier,
            successDescription: '',
            failureDescription: '',
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(0.10), blurRadius: 14, spreadRadius: -4),
            ],
          ),
          child: Row(
            children: [
              // Chip con la stat asociada — solo contexto visual, no es tappable.
              Container(
                width: 34,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  skill.relatedStat.toUpperCase(),
                  style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  skill.name,
                  style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    fontFamily: 'serif',
                  ),
                ),
              ),
              Text(
                skill.modifierFormatted,
                style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 8),
              Icon(Icons.casino_outlined, color: accent.withOpacity(0.6), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}