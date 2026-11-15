// Instrumentos numéricos del rework estético: [StatDial] (lectura),
// [TacticalStepper] (−/+ compacto) y [ResourcePips] (cargas ● ● ○).
//
// Todos los números usan cifras tabulares (ver telemetry.dart) para que
// los cambios en combate no muevan el layout.

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/tactical_palette.dart';
import '../theme/telemetry.dart';

/// Instrumento de lectura: icono, valor grande y etiqueta. Se estira al
/// ancho que le dé el padre. Con [onTap] se comporta como botón.
class StatDial extends StatelessWidget {
  const StatDial({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone,
    this.onTap,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// Color de rol del instrumento. `null` = neutro.
  final Color? tone;
  final VoidCallback? onTap;

  /// Valor más grande: para el dato estrella de una fila (la CA).
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tactical = context.tactical;
    final tone = this.tone;
    final valueStyle =
        (emphasized ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.w800, color: tone)
            .tabular;

    return AnimatedContainer(
      duration: AppDurations.normal,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tone == null
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.40)
            : Color.alphaBlend(
                tone.withValues(alpha: 0.10),
                scheme.surfaceContainerHighest.withValues(alpha: 0.40),
              ),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: tone == null
              ? tactical.metalBorder.withValues(alpha: 0.75)
              : tone.withValues(alpha: 0.45),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: tone ?? scheme.onSurfaceVariant),
                  const SizedBox(height: AppSpacing.xs),
                ],
                AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: Text(
                    value,
                    key: ValueKey(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.4,
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

/// Paso −/+ compacto dentro de una cápsula con borde metálico. El centro
/// es libre ([child]): un número, pips, una etiqueta. Un callback null
/// deshabilita su botón.
class TacticalStepper extends StatelessWidget {
  const TacticalStepper({
    super.key,
    required this.onDecrement,
    required this.onIncrement,
    this.child,
    this.decrementTooltip,
    this.incrementTooltip,
    this.decrementKey,
    this.incrementKey,
    this.decrementIcon = Icons.remove_rounded,
    this.incrementIcon = Icons.add_rounded,
    this.tone,
  });

  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final Widget? child;
  final String? decrementTooltip;
  final String? incrementTooltip;
  final Key? decrementKey;
  final Key? incrementKey;
  final IconData decrementIcon;
  final IconData incrementIcon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tactical = context.tactical;

    Widget button(
      IconData icon,
      VoidCallback? onPressed,
      String? tooltip,
      Key? key,
    ) {
      return IconButton(
        key: key,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        color: tone ?? scheme.primary,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: tactical.metalBorder.withValues(alpha: 0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(decrementIcon, onDecrement, decrementTooltip, decrementKey),
          if (child != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: child,
            ),
          button(incrementIcon, onIncrement, incrementTooltip, incrementKey),
        ],
      ),
    );
  }
}

/// Cargas como puntos: llenos los disponibles, huecos los gastados
/// (● ● ○). Con más de [maxPips] se degrada a una barra fina, que escala
/// sin romper la fila.
class ResourcePips extends StatelessWidget {
  const ResourcePips({
    super.key,
    required this.current,
    required this.max,
    this.color,
    this.size = 9,
    this.maxPips = 10,
  });

  final int current;
  final int max;
  final Color? color;
  final double size;
  final int maxPips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = current <= 0 ? scheme.error : (color ?? scheme.primary);
    if (max <= 0) return const SizedBox.shrink();

    if (max > maxPips) {
      return SizedBox(
        width: 56,
        child: TweenAnimationBuilder<double>(
          duration: AppDurations.normal,
          tween: Tween(end: (current / max).clamp(0.0, 1.0)),
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 5,
            color: tone,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
      );
    }

    return ExcludeSemantics(
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: [
          for (var i = 0; i < max; i++)
            AnimatedContainer(
              duration: AppDurations.normal,
              curve: Curves.easeOut,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < current ? tone : tone.withValues(alpha: 0),
                border: Border.all(
                  color: i < current ? tone : scheme.outline,
                  width: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
