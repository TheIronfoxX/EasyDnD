import 'package:flutter/material.dart';
import '../models/ability_model.dart'; // Ajusta la ruta si tu import real es distinta.

// ============================================================================
// TacticalAbilityCard
// ----------------------------------------------------------------------------
// Visor de escaneo táctico para una `Ability`. Prioriza la lectura rápida en
// combate: cabecera + resumen táctico siempre visibles, todo lo demás
// ("paranoia") queda oculto tras un ExpansionTile.
//
// 100% reactivo al tema: no hay ni un solo Color(...) ni Colors.xxx fijo,
// todo sale de Theme.of(context).colorScheme.
//
// Tipado 1:1 contra ability_model.dart:
// - tacticalSummary, loreDescription y scalingFormula son String? (pueden no
//   venir en el JSON) — se tratan como tal, sin castear a String a lo loco.
// - successDescription y failureDescription son String no-nulos (el
//   constructor los exige, aunque puedan llegar vacíos si el JSON no los
//   trae y el modelo los defaultea a '').
// - hasResolvableScaling y scalingFormula vienen de ability.scaling
//   (SpellScaling) a través de los getters de compatibilidad del modelo.
// ============================================================================

class TacticalAbilityCard extends StatelessWidget {
  final Ability ability;

  const TacticalAbilityCard({super.key, required this.ability});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final String name = ability.name;
    final String type = ability.type;
    final String relatedStat = ability.relatedStat;
    final magicCharges = ability.magicCharges;
    final bool hasCharges = magicCharges.hasCharges;
    final String tacticalSummary =
        (ability.tacticalSummary != null && ability.tacticalSummary!.trim().isNotEmpty)
            ? ability.tacticalSummary!
            : 'Sin resumen táctico registrado.';
    final bool hasScaling = ability.hasResolvableScaling;
    final String? loreDescription = ability.loreDescription;
    final bool hasLore = loreDescription != null && loreDescription.trim().isNotEmpty;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.12), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TacticalHeader(
                  name: name,
                  type: type,
                  relatedStat: relatedStat,
                  hasCharges: hasCharges,
                  currentCharges: hasCharges ? magicCharges.current : 0,
                  maxCharges: hasCharges ? magicCharges.max : 0,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 12),
                _TacticalSummaryBlock(
                  summary: tacticalSummary,
                  hasScaling: hasScaling,
                  // hasResolvableScaling ya garantiza formula != null, pero
                  // el fallback '' evita un crash si la lógica del modelo
                  // cambiara en el futuro.
                  scalingFormula: ability.scalingFormula ?? '',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ],
            ),
          ),
          Theme(
            // Quita el divisor por defecto que añade ExpansionTile.
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              collapsedIconColor: colorScheme.onSurfaceVariant,
              iconColor: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHigh,
              collapsedBackgroundColor: Colors.transparent,
              title: Text(
                'Detalles',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              children: [
                if (hasLore) ...[
                  _LoreBlock(
                    loreDescription: loreDescription,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 14),
                ],
                _ResolutionBlock(
                  successDescription: ability.successDescription,
                  failureDescription: ability.failureDescription,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Cabecera: nombre + badges (tipo, stat) + indicador de cargas
// ============================================================================
class _TacticalHeader extends StatelessWidget {
  final String name;
  final String type;
  final String relatedStat;
  final bool hasCharges;
  final int currentCharges;
  final int maxCharges;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _TacticalHeader({
    required this.name,
    required this.type,
    required this.relatedStat,
    required this.hasCharges,
    required this.currentCharges,
    required this.maxCharges,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                name,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (hasCharges) ...[
              const SizedBox(width: 8),
              _ChargesIndicator(
                current: currentCharges,
                max: maxCharges,
                colorScheme: colorScheme,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _TacticalBadge(
              label: type,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              textTheme: textTheme,
            ),
            _TacticalBadge(
              label: relatedStat.toUpperCase(),
              backgroundColor: colorScheme.tertiaryContainer,
              foregroundColor: colorScheme.onTertiaryContainer,
              textTheme: textTheme,
            ),
          ],
        ),
      ],
    );
  }
}

class _TacticalBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final TextTheme textTheme;

  const _TacticalBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      labelStyle: textTheme.labelSmall?.copyWith(
        color: foregroundColor,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      backgroundColor: backgroundColor,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: -2),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// Puntitos de energía: cargas actuales vs máximas.
class _ChargesIndicator extends StatelessWidget {
  final int current;
  final int max;
  final ColorScheme colorScheme;

  const _ChargesIndicator({
    required this.current,
    required this.max,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final safeMax = max <= 0 ? 1 : max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(safeMax, (index) {
        final filled = index < current;
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? colorScheme.tertiary : colorScheme.outlineVariant,
            ),
          ),
        );
      }),
    );
  }
}

// ============================================================================
// Bloque táctico: el resumen que se lee en 2 segundos.
// ============================================================================
class _TacticalSummaryBlock extends StatelessWidget {
  final String summary;
  final bool hasScaling;
  final String scalingFormula;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _TacticalSummaryBlock({
    required this.summary,
    required this.hasScaling,
    required this.scalingFormula,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.radar_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (hasScaling) ...[
            const SizedBox(height: 8),
            Text(
              'Escala: $scalingFormula',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Lore — tono narrativo, en cursiva.
// ============================================================================
class _LoreBlock extends StatelessWidget {
  final String loreDescription;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _LoreBlock({
    required this.loreDescription,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      loreDescription,
      style: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
        height: 1.45,
      ),
    );
  }
}

// ============================================================================
// Resolución: éxito / fallo, cada uno con su icono semántico.
// ============================================================================
class _ResolutionBlock extends StatelessWidget {
  final String successDescription;
  final String failureDescription;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ResolutionBlock({
    required this.successDescription,
    required this.failureDescription,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESOLUCIÓN',
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        _ResolutionRow(
          icon: Icons.check_circle_rounded,
          iconColor: colorScheme.tertiary,
          description: successDescription,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(height: 6),
        _ResolutionRow(
          icon: Icons.shield_moon_rounded,
          iconColor: colorScheme.error,
          description: failureDescription,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _ResolutionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String description;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ResolutionRow({
    required this.icon,
    required this.iconColor,
    required this.description,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}