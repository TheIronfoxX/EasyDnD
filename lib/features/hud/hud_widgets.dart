// Piezas visuales compartidas por las secciones del HUD (Etapa 5;
// rediseño "pergamino" en 8b).
//
// NINGÚN color hardcodeado: todo sale de Theme.of(context), así los
// skins no obligan a tocar cada tarjeta.
//
// [HudSectionCard] es un panel de pergamino: superficie con un degradé
// sutil, borde gastado y el icono en una placa tintada con el acento.
// [HudStatTile] es una plaqueta con borde para métricas sueltas.
//
// Estas piezas son solo estructura — no saben de personajes ni de
// reglas. Eso las deja reutilizables para combate, acciones, inventario
// y ficha.

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
export '../../core/ui/character_avatar.dart';

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
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outline),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface,
            Color.alphaBlend(
              scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              scheme.surface,
            ),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.30),
                  ),
                ),
                child: Icon(icon, size: 16, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.md),
          child,
        ],
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
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
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
                Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(height: AppSpacing.xs),
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
                    color: scheme.outline,
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
