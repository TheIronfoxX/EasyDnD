// Piezas compartidas por los pasos del asistente de creación.

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Título de sección dentro de un paso.
class CreationSectionTitle extends StatelessWidget {
  const CreationSectionTitle(this.text, {super.key, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.titleMedium),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Control − valor + (las keys son `<keyPrefix>-dec` y `<keyPrefix>-inc`).
/// Un callback nulo deshabilita ese botón.
class CreationStepper extends StatelessWidget {
  const CreationStepper({
    super.key,
    required this.keyPrefix,
    required this.value,
    required this.onDec,
    required this.onInc,
  });

  final String keyPrefix;
  final String value;
  final VoidCallback? onDec;
  final VoidCallback? onInc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('$keyPrefix-dec'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          onPressed: onDec,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 36),
          child: Text(
            value,
            key: Key('$keyPrefix-value'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: Key('$keyPrefix-inc'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: onInc,
        ),
      ],
    );
  }
}

String signed(int n) => n >= 0 ? '+$n' : '$n';
