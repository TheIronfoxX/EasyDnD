// Kit visual del rework para novatos: piezas planas, con aire y sin
// ornamentos. Solo presentación (no saben de personajes ni de reglas) y
// todos los colores salen del tema activo.
//
// - [CleanCard]: superficie redondeada sin borde.
// - [NavRowCard]: tarjeta-fila grande que abre una pantalla propia.
// - [CleanSectionTitle]: rótulo de grupo en letra normal.
// - [CleanPage]: pantalla estándar con AppBar simple y lista centrada.

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Ancho máximo del contenido en pantallas grandes: las filas no se
/// estiran hasta el borde de una tablet.
const double kCleanMaxWidth = 720;

class CleanCard extends StatelessWidget {
  const CleanCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.margin = const EdgeInsets.only(bottom: AppSpacing.md),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// `null` = superficie del tema.
  final Color? color;

  static const _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? scheme.surface,
        borderRadius: _radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Fila-tarjeta de índice: icono en burbuja, título, resumen corto y
/// flecha. Toda la tarjeta es tocable.
class NavRowCard extends StatelessWidget {
  const NavRowCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Color de la burbuja del icono. `null` = acento.
  final Color? iconColor;

  /// Algo a la izquierda de la flecha (un número, unos puntos).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = iconColor ?? theme.colorScheme.primary;
    return CleanCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tone),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Rótulo de grupo: letra normal, color secundario, con aire arriba.
class CleanSectionTitle extends StatelessWidget {
  const CleanSectionTitle(this.text, {super.key, this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color ?? theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Lista estándar de una pestaña o pantalla: padding cómodo y ancho
/// máximo centrado.
class CleanList extends StatelessWidget {
  const CleanList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kCleanMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: children,
        ),
      ),
    );
  }
}

/// Pantalla dedicada: AppBar con título y atrás, y una sola cosa dentro.
class CleanPage extends StatelessWidget {
  const CleanPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: CleanList(children: children),
    );
  }
}

/// Abre [page] como pantalla propia.
Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
