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
///
/// Fase 10 (rework estético): el modificador de atributo pasó de un
/// bloque de texto plano a una insignia circular con degradado y glow,
/// las tarjetas de habilidad ganaron un borde degradado sutil y un
/// splash de color propio al tocarlas, y el header de sección ahora
/// lleva un icono para anclar la jerarquía visual sin recurrir a un
/// Divider de Material por defecto.
///
/// Fase 11: los atributos volvieron a un grid (3 columnas x 2 filas),
/// pero como tarjetas cuadradas (_AttributeTile) en vez del grid plano
/// original — insignia circular arriba, nombre y valor abajo. La
/// descripción larga que cabía en la fila horizontal se movió a un
/// Tooltip con long-press para no romper el cuadrado.
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
        _SectionHeader(
          icon: Icons.auto_awesome_outlined,
          title: 'ATRIBUTOS',
          subtitle: 'Las seis puntuaciones base de tu personaje.',
          accent: accent,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, i) => _AttributeTile(stat: stats[i], accent: accent),
        ),
        _SectionDivider(accent: accent),
        if (skills.isEmpty)
          _EmptySkillsNotice(accent: accent)
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

/// Header reutilizable de sección: icono en cápsula con tinte de acento,
/// título y subtítulo. Sustituye al bloque de Text sueltos que abría la
/// pestaña, dándole un ancla visual consistente con el resto del HUD.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: accent.withOpacity(0.25), width: 1),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: context.appColors.textSecondary, fontSize: 12, fontFamily: 'serif'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta cuadrada de atributo (grid 3x2). El modificador vive en una
/// insignia circular con degradado radial del color de acento y glow
/// suave, coronando el nombre de la stat y su valor bruto. La
/// descripción larga que cabía en la fila horizontal ya no entra aquí
/// por diseño — si el usuario la necesita, la tarjeta es tappable y
/// muestra un tooltip con long-press en vez de romper el cuadrado.
class _AttributeTile extends StatelessWidget {
  final AbilityScore stat;
  final Color accent;

  const _AttributeTile({required this.stat, required this.accent});

  @override
  Widget build(BuildContext context) {
    final tile = ThemedCard(
      accentColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [accent.withOpacity(0.22), accent.withOpacity(0.02)],
              ),
              border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
              boxShadow: [
                BoxShadow(color: accent.withOpacity(0.25), blurRadius: 10, spreadRadius: -3),
              ],
            ),
            child: JournalNumberText(text: stat.modFormatted, color: accent, fontSize: 19),
          ),
          const SizedBox(height: 6),
          Text(
            stat.name.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${stat.value}',
            style: TextStyle(color: context.appColors.textSecondary, fontSize: 10.5, fontFamily: 'serif'),
          ),
        ],
      ),
    );

    if (stat.description.isEmpty) return tile;

    return Tooltip(
      message: stat.description,
      triggerMode: TooltipTriggerMode.longPress,
      child: tile,
    );
  }
}

/// Separador entre la sección de atributos y la de habilidades: una
/// línea sutil a cada lado del título, tintada con el color de acento,
/// con un icono de dados sobre el texto para no romper la estética de
/// cristal/metal con un Divider plano de Material por defecto.
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.casino_outlined, color: accent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'HABILIDADES',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                    fontSize: 13,
                    fontFamily: 'serif',
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Container(height: 1, color: accent.withOpacity(0.25))),
        ],
      ),
    );
  }
}

/// Aviso de estado vacío para habilidades, envuelto en su propia
/// tarjeta translúcida en vez de un Text suelto flotando en el layout.
class _EmptySkillsNotice extends StatelessWidget {
  final Color accent;

  const _EmptySkillsNotice({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.12), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: accent.withOpacity(0.7), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Este personaje todavía no tiene habilidades registradas.',
              style: TextStyle(color: context.appColors.textSecondary, fontSize: 12.5, fontFamily: 'serif'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila compacta de habilidad: nombre a la izquierda, modificador a la
/// derecha, dentro de un contenedor translúcido con borde degradado y
/// glow leve. Tappable: abre el mismo ResolutionModal que usan armas y
/// conjuros, pero sin daño/lore — las habilidades solo tiran d20 +
/// modificador. El splash e highlight del InkWell ahora usan el color
/// de acento en vez del gris genérico de Material.
class _SkillRow extends StatelessWidget {
  final Skill skill;
  final Color accent;

  const _SkillRow({required this.skill, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withOpacity(0.16), accent.withOpacity(0.0)],
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: Material(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          splashColor: accent.withOpacity(0.15),
          highlightColor: accent.withOpacity(0.08),
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
              borderRadius: BorderRadius.circular(9),
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
                    border: Border.all(color: accent.withOpacity(0.2), width: 0.8),
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
      ),
    );
  }
}