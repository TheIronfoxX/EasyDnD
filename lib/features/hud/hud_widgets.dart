// Piezas visuales compartidas por las secciones del HUD (Etapa 5).
//
// La regla de la Etapa 1 sigue vigente hasta el design system de la
// Etapa 6: NINGÚN color hardcodeado. Todo sale de Theme.of(context), así
// los skins futuros no obligan a tocar cada tarjeta.
//
// Estas piezas son solo estructura — no saben de personajes ni de
// reglas. Eso las deja reutilizables para combate (5b), acciones (5c),
// inventario y ficha (5d).

import 'package:flutter/material.dart';

/// Tarjeta de sección con encabezado icono + título + acción opcional.
/// Es la unidad visual del tablero: una tarjeta por tema (vida, turno,
/// condiciones...) en vez de un muro de texto.
class HudSectionCard extends StatelessWidget {
  const HudSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;

  /// Acción del encabezado (recargar, agregar...). A la derecha del
  /// título, alineada con el texto.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Métrica compacta para filas de tres (CA / Velocidad / Dados de
/// golpe). Se estira dentro de un [Expanded]; el llamador decide el
/// ancho. Si [onTap] no es null se comporta como botón.
class HudStatTile extends StatelessWidget {
  const HudStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto de "no hay nada acá" para secciones que pueden quedar vacías
/// (condiciones, recursos, ranuras). No es un error: es un estado.
class HudEmptyHint extends StatelessWidget {
  const HudEmptyHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
