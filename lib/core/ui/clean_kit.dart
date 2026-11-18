// Kit visual del rework para novatos, estilo Nothing: monocromo, formas
// redondas, puntos por todas partes y el acento como única nota de color.
// Solo presentación (no saben de personajes ni de reglas) y todos los
// colores y letras salen del tema activo.
//
// - [CleanCard]: superficie muy redondeada sin borde.
// - [NavRowCard]: tarjeta-fila que abre una pantalla propia, con
//   medallón circular ([IconMedallion]) y flecha diagonal.
// - [CleanSectionTitle]: rótulo de grupo con punto de acento.
// - [CleanList]: lista sobre rejilla de puntos ([CleanBackdrop]) con
//   entrada escalonada ([StaggeredEntrance]).
// - [DotBar] / [DotRing]: barras y anillos hechos de puntos.

import 'dart:math' as math;

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

/// Fila-tarjeta de índice: medallón circular, título, resumen corto y
/// flecha diagonal en un círculo. Monocroma: el color de la cosa solo
/// asoma en el puntito del medallón. Se hunde un pelín al pulsarla.
class NavRowCard extends StatefulWidget {
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

  /// Color del puntito del medallón. `null` = acento.
  final Color? iconColor;

  /// Algo a la izquierda de la flecha (un número, unos puntos).
  final Widget? trailing;

  @override
  State<NavRowCard> createState() => _NavRowCardState();
}

class _NavRowCardState extends State<NavRowCard> {
  bool _pressed = false;

  static const _radius = BorderRadius.all(Radius.circular(28));

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = widget.iconColor ?? scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        child: Material(
          color: scheme.surface,
          borderRadius: _radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconMedallion(icon: widget.icon, tone: tone),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.subtitle != null &&
                            widget.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    widget.trailing!,
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta cuadrada de índice: medallón grande arriba, título y resumen
/// abajo. Va por parejas dentro de un [NavTilePair] para romper la pila
/// de filas iguales.
class NavTileCard extends StatefulWidget {
  const NavTileCard({
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
  final Color? iconColor;

  /// Esquina superior derecha (p. ej. un globito con un número).
  final Widget? trailing;

  @override
  State<NavTileCard> createState() => _NavTileCardState();
}

class _NavTileCardState extends State<NavTileCard> {
  bool _pressed = false;

  static const _radius = BorderRadius.all(Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = widget.iconColor ?? scheme.primary;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: AppDurations.fast,
      curve: Curves.easeOut,
      child: Material(
        color: scheme.surface,
        borderRadius: _radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) {
            if (_pressed != v) setState(() => _pressed = v);
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconMedallion(icon: widget.icon, tone: tone, size: 64),
                    if (widget.trailing != null) widget.trailing!,
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dos [NavTileCard] lado a lado con la misma altura. Con una sola,
/// cae a una [NavRowCard] ancha para no dejar un hueco.
class NavTilePair extends StatelessWidget {
  const NavTilePair({super.key, required this.tiles})
    : assert(tiles.length == 1 || tiles.length == 2);

  final List<NavTileCard> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.length == 1) {
      final t = tiles.first;
      return NavRowCard(
        key: t.key,
        icon: t.icon,
        title: t.title,
        subtitle: t.subtitle,
        iconColor: t.iconColor,
        trailing: t.trailing,
        onTap: t.onTap,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: tiles[1]),
          ],
        ),
      ),
    );
  }
}

/// Icono en un círculo rodeado por un anillo de puntos, con un puntito
/// del [tone] en la esquina: la "firma" de cada tarjeta de índice.
class IconMedallion extends StatelessWidget {
  const IconMedallion({
    super.key,
    required this.icon,
    required this.tone,
    this.size = 52,
  });

  final IconData icon;
  final Color tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: DotRing(
              color: scheme.onSurface.withValues(alpha: 0.35),
              dots: (size / 3.2).round(),
            ),
          ),
          Center(
            child: Container(
              width: size * 0.74,
              height: size * 0.74,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: size * 0.38, color: scheme.onSurface),
            ),
          ),
          Positioned(
            right: size * 0.06,
            top: size * 0.06,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: BoxDecoration(
                color: tone,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Anillo de [dots] puntos repartidos en círculo. Con [filled] < [dots],
/// los primeros [filled] van en [activeColor] (un medidor circular).
class DotRing extends StatelessWidget {
  const DotRing({
    super.key,
    required this.color,
    this.dots = 16,
    this.filled,
    this.activeColor,
    this.dotRadius = 1.4,
  });

  final Color color;
  final int dots;
  final int? filled;
  final Color? activeColor;
  final double dotRadius;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DotRingPainter(
      color: color,
      dots: dots,
      filled: filled,
      activeColor: activeColor,
      dotRadius: dotRadius,
    ),
  );
}

class _DotRingPainter extends CustomPainter {
  _DotRingPainter({
    required this.color,
    required this.dots,
    required this.filled,
    required this.activeColor,
    required this.dotRadius,
  });

  final Color color;
  final int dots;
  final int? filled;
  final Color? activeColor;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = dotRadius * 2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - stroke,
    );
    final track = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (filled != null && filled! > 0 && dots > 0) {
      final active = Paint()
        ..color = activeColor ?? color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      final sweep = 2 * math.pi * (filled! / dots).clamp(0.0, 1.0);
      canvas.drawArc(rect, -math.pi / 2, sweep, false, active);
    }
  }

  @override
  bool shouldRepaint(_DotRingPainter old) =>
      old.color != color ||
      old.dots != dots ||
      old.filled != filled ||
      old.activeColor != activeColor ||
      old.dotRadius != dotRadius;
}

/// Barra hecha de [count] puntos: los que caben en [value] (0..1) van en
/// [color], el resto apagados. Sustituye a las barras de progreso.
class DotBar extends StatelessWidget {
  const DotBar({
    super.key,
    required this.value,
    required this.color,
    this.count = 10,
    this.dotSize = 4,
    this.gap = 2,
  });

  final double value;
  final Color color;
  final int count;
  final double dotSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final off = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
    final width = count * (dotSize + gap) - gap;
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      width: width,
      height: dotSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dotSize),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: off)),
            FractionallySizedBox(
              widthFactor: v,
              child: ColoredBox(color: color),
            ),
          ],
        ),
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
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(
              color: color ?? theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Lista estándar de una pestaña o pantalla: padding cómodo, ancho
/// máximo centrado, un resplandor muy suave del acento arriba y una
/// entrada escalonada de las tarjetas la primera vez que se pintan.
class CleanList extends StatelessWidget {
  const CleanList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CleanBackdrop(
      child: Align(
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
            children: [
              for (var i = 0; i < children.length; i++)
                StaggeredEntrance(index: i, child: children[i]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fondo liso: sin trama. Se conserva el widget como punto único donde
/// ponerla si algún día vuelve una textura.
class CleanBackdrop extends StatelessWidget {
  const CleanBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Aparece subiendo y fundiéndose, con un retraso según su [index]. Solo
/// anima al montarse; los repintados posteriores no lo repiten.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final steps = index.clamp(0, 6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + 50 * steps),
      curve: Interval(steps * 0.12, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
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

/// Ficha numérica de un vistazo: número grande en un anillo de puntos, un
/// puntito de [tone] y la etiqueta debajo (más una línea opcional [sub]).
/// Sirve para atributos, monedas y cualquier cifra suelta.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.tone,
    this.sub,
    this.help,
    this.ring = 64,
  });

  final String value;
  final String label;
  final String? sub;
  final String? help;
  final Color tone;

  /// Diámetro del anillo.
  final double ring;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tile = Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: ring,
            height: ring,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DotRing(
                    color: scheme.onSurface.withValues(alpha: 0.25),
                    dots: (ring / 2.7).round(),
                    dotRadius: 1.3,
                  ),
                ),
                Positioned(
                  top: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: tone,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value, style: theme.textTheme.titleLarge),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontSize: 10,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
    return help == null
        ? tile
        : Tooltip(
            message: help!,
            triggerMode: TooltipTriggerMode.tap,
            child: tile,
          );
  }
}

/// Reparte [tiles] en filas de [perRow] columnas del mismo ancho.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles, this.perRow = 3});

  final List<Widget> tiles;
  final int perRow;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += perRow) {
      final chunk = tiles.skip(i).take(perRow).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              for (var j = 0; j < perRow; j++) ...[
                if (j > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: j < chunk.length ? chunk[j] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
