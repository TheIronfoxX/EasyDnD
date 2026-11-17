// Recursos genéricos y ranuras de conjuro del personaje activo.
//
// Viven aparte del tablero de Estado: los recursos se consultan en
// Personaje → Recursos y las ranuras encabezan la pestaña Conjuros.

import 'package:flutter/material.dart';

import '../../core/ui/pip_shape.dart';
import 'hud_widgets.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/tactical_theme_tokens.dart';
import '../../core/theme/telemetry.dart';

/// Puntos grandes que se tocan: uno lleno gasta, uno vacío recupera.
/// Sustituye a los botones −/+ para que gastar sea un solo gesto obvio.
/// Solo el último lleno y el primer vacío llevan tooltip (son los que
/// cambian), así cada mensaje es único. Con muchos usos (> [maxPips])
/// cae al stepper clásico, porque una fila de 20 puntos no cabe.
class TapPips extends StatelessWidget {
  const TapPips({
    super.key,
    required this.current,
    required this.max,
    required this.tone,
    required this.spendTooltip,
    required this.recoverTooltip,
    required this.onSpend,
    required this.onRecover,
    this.maxPips = 10,
  });

  final int current;
  final int max;
  final Color tone;
  final String spendTooltip;
  final String recoverTooltip;
  final VoidCallback onSpend;
  final VoidCallback onRecover;
  final int maxPips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (max <= 0) return const SizedBox.shrink();

    if (max > maxPips) {
      return Row(
        children: [
          Text(
            '$current / $max',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)
                .tabular,
          ),
          const SizedBox(width: AppSpacing.sm),
          TacticalStepper(
            tone: tone,
            decrementTooltip: spendTooltip,
            incrementTooltip: recoverTooltip,
            onDecrement: current <= 0 ? null : onSpend,
            onIncrement: current >= max ? null : onRecover,
          ),
        ],
      );
    }

    final shape = context.tactical.pipShape;
    return Wrap(
      children: [
        for (var i = 0; i < max; i++)
          Builder(
            builder: (context) {
              final filled = i < current;
              final button = InkResponse(
                radius: 20,
                onTap: filled ? onSpend : onRecover,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: PipGlyph(
                      shape: shape,
                      filled: filled,
                      color: tone,
                      size: 18,
                      outline: theme.colorScheme.outline,
                    ),
                  ),
                ),
              );
              final message = i == current - 1
                  ? spendTooltip
                  : i == current
                  ? recoverTooltip
                  : null;
              return message == null
                  ? button
                  : Tooltip(message: message, child: button);
            },
          ),
      ],
    );
  }
}
