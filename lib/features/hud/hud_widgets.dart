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
import '../../core/ui/stat_dial.dart';
import '../../core/ui/tactical_card.dart';

export '../../core/ui/character_avatar.dart';
export '../../core/ui/stat_dial.dart';
export '../../core/ui/tactical_card.dart';

/// Tarjeta de sección con encabezado icono + título + acción opcional.
/// Es la unidad visual del tablero: una tarjeta por tema (vida, turno,
/// condiciones...) en vez de un muro de texto.
///
/// Con el tema limpio, [TacticalCard] pinta una superficie lisa sin
/// borde; el encabezado es una etiqueta discreta.
class HudSectionCard extends StatelessWidget {
  const HudSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.tone,
  });

  final IconData icon;
  final String title;
  final Widget child;

  /// Color de rol de la sección (armas, conjuros...). `null` = acento.
  final Color? tone;

  /// Acción del encabezado (recargar, agregar...). A la derecha del
  /// título, alineada con el texto.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = Theme.of(context).visualDensity == VisualDensity.compact;
    return TacticalCard(
      margin: EdgeInsets.only(bottom: compact ? AppSpacing.md : AppSpacing.xl),
      tone: tone,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        compact ? AppSpacing.sm : AppSpacing.md,
        AppSpacing.md,
        compact ? AppSpacing.md : AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HudLabelHeader(
            icon: icon,
            title: title,
            trailing: trailing,
            tone: tone,
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Encabezado ligero: icono + título discreto + acción opcional.
class HudLabelHeader extends StatelessWidget {
  const HudLabelHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.tone,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tone ?? theme.colorScheme.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (trailing != null) trailing!,
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
    this.tone,
    this.emphasized = false,
    this.richValue = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? tone;
  final bool emphasized;
  final bool richValue;

  @override
  Widget build(BuildContext context) {
    return StatDial(
      icon: icon,
      label: label,
      value: value,
      tone: tone,
      onTap: onTap,
      emphasized: emphasized,
      richValue: richValue,
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
