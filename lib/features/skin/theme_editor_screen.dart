// Editor de temas: edita un [CustomTheme] completo con vista previa en
// vivo. Trabaja sobre un borrador local; nada toca el SkinController
// hasta "Guardar". Salir con cambios sin guardar pide confirmación.
//
// Cubre todo lo que define un tema del catálogo: nombre, claro/oscuro,
// tipografía, paleta estructural, colores de juego, metal y cabecera,
// monedas, formas, sombra, radios Material, tarjetas, componentes,
// trama de fondo, pips, iconos y dados, cabeceras, movimiento y densidad.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/custom_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/font_presets.dart';
import '../../core/theme/tactical_theme_tokens.dart';
import '../../core/theme/theme_style_tokens.dart';
import '../../core/ui/pip_shape.dart';
import '../../core/ui/stat_dial.dart';
import '../../core/ui/tactical_background.dart';
import '../../core/ui/tactical_card.dart';
import '../../state/skin_controller.dart';
import 'hsv_color_picker_dialog.dart';
import 'theme_editor_controls.dart';

/// Abre el editor sobre [theme] (nuevo o existente).
Future<void> openThemeEditor(BuildContext context, CustomTheme theme) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ThemeEditorScreen(initial: theme)),
  );
}

class ThemeEditorScreen extends StatefulWidget {
  const ThemeEditorScreen({super.key, required this.initial});

  final CustomTheme initial;

  @override
  State<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends State<ThemeEditorScreen> {
  late CustomTheme _draft = widget.initial;
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.name,
  );
  bool _dirty = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _update(CustomTheme next) => setState(() {
    _draft = next;
    _dirty = true;
  });

  void _t(TacticalThemeTokens Function(TacticalThemeTokens t) f) =>
      _update(_draft.copyWith(tactical: f(_draft.tactical)));

  void _p(AppPalette Function(AppPalette p) f) =>
      _update(_draft.copyWith(palette: f(_draft.palette)));

  Future<void> _save() async {
    final name = _name.text.trim();
    final theme = _draft.copyWith(name: name.isEmpty ? 'Mi tema' : name);
    final navigator = Navigator.of(context);
    await context.read<SkinController>().saveCustomTheme(theme);
    _dirty = false;
    navigator.pop();
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Los cambios de este tema no se han guardado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            key: const ValueKey('discard-theme'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppTheme.fromCustom(
      _draft,
      fontPreset: FontPresets.byId(_draft.fontPresetId),
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          _dirty = false;
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar tema'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilledButton.icon(
                key: const ValueKey('save-theme'),
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final preview = Theme(
              data: previewTheme,
              child: const _ThemePreviewPanel(),
            );
            final simple = context.watch<SkinController>().simpleThemeEditor;
            final editor = Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      key: const ValueKey('editor-mode'),
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.auto_fix_high_rounded),
                          label: Text('Sencillo'),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.tune_rounded),
                          label: Text('Avanzado'),
                        ),
                      ],
                      selected: {simple},
                      onSelectionChanged: (sel) => context
                          .read<SkinController>()
                          .setSimpleThemeEditor(sel.first),
                    ),
                  ),
                ),
                Expanded(
                  child: simple ? _buildSimple(context) : _buildEditor(context),
                ),
              ],
            );
            // Ancho: vista previa a la izquierda; teléfono: arriba.
            if (constraints.maxWidth >= 840) {
              return Row(
                children: [
                  Expanded(child: preview),
                  const VerticalDivider(width: 1),
                  Expanded(child: editor),
                ],
              );
            }
            return Column(
              children: [
                SizedBox(
                  height: (constraints.maxHeight * 0.38).clamp(220, 340),
                  child: preview,
                ),
                const Divider(height: 1),
                Expanded(child: editor),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Editor sencillo: pocas decisiones grandes. El fondo rehace la paleta
  /// entera y la redondez toca todas las formas a la vez.
  Widget _buildSimple(BuildContext context) {
    final theme = Theme.of(context);
    final t = _draft.tactical;

    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return ListView(
      key: const ValueKey('theme-editor-simple'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        TextField(
          key: const ValueKey('theme-name'),
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nombre del tema'),
          onChanged: (_) => setState(() => _dirty = true),
        ),
        title('Ambiente'),
        SegmentedButton<Brightness>(
          segments: const [
            ButtonSegment(
              value: Brightness.dark,
              icon: Icon(Icons.dark_mode_rounded),
              label: Text('Oscuro'),
            ),
            ButtonSegment(
              value: Brightness.light,
              icon: Icon(Icons.light_mode_rounded),
              label: Text('Claro'),
            ),
          ],
          selected: {_draft.brightness},
          // Cambiar el modo invierte la luz del fondo y rehace la paleta.
          onSelectionChanged: (sel) {
            if (sel.first == _draft.brightness) return;
            final hsl = HSLColor.fromColor(_draft.palette.background);
            final flipped = hsl
                .withLightness(sel.first == Brightness.dark ? 0.08 : 0.93)
                .toColor();
            _update(_draft.withBackground(flipped));
          },
        ),
        ThemeColorRow(
          key: const ValueKey('simple-background'),
          label: 'Color de fondo',
          hint: 'Superficies, bordes y textos se ajustan solos',
          color: _draft.palette.background,
          onChanged: (c) => _update(_draft.withBackground(c)),
        ),
        ThemeColorRow(
          key: const ValueKey('simple-accent'),
          label: 'Color de acento',
          hint: 'Botones, iconos y barra inferior',
          color: t.primary,
          onChanged: (c) => _t((t) => t.copyWith(primary: c)),
        ),
        title('Colores de juego'),
        _SwatchStrip(
          entries: [
            ('Armas', t.weapon, (Color c) => _t((t) => t.copyWith(weapon: c))),
            ('Conjuros', t.spell, (Color c) => _t((t) => t.copyWith(spell: c))),
            (
              'Habilidad',
              t.ability,
              (Color c) => _t((t) => t.copyWith(ability: c)),
            ),
            ('Curar', t.heal, (Color c) => _t((t) => t.copyWith(heal: c))),
            ('Daño', t.damage, (Color c) => _t((t) => t.copyWith(damage: c))),
          ],
        ),
        title('Forma'),
        ThemeSliderRow(
          label: 'Redondez',
          value: _draft.roundness.clamp(0, 24),
          min: 0,
          max: 24,
          divisions: 24,
          format: (v) => v == 0 ? 'Recta' : '${v.round()} px',
          onChanged: (v) => _update(_draft.withRoundness(v)),
        ),
        title('Indicadores'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final shape in PipShape.values)
              ChoiceChip(
                key: ValueKey('simple-pip-${shape.name}'),
                tooltip: _pipLabels[shape],
                showCheckmark: false,
                label: PipGlyph(
                  shape: shape,
                  filled: true,
                  color: t.primary,
                  size: 16,
                ),
                selected: t.pipShape == shape,
                onSelected: (_) => _t((t) => t.copyWith(pipShape: shape)),
              ),
          ],
        ),
        title('Fondo decorativo'),
        ThemeChoiceRow<BackgroundPatternStyle>(
          label: 'Dibujo',
          values: BackgroundPatternStyle.values,
          selected: t.backgroundPattern,
          labelOf: (v) => _patternLabels[v] ?? v.name,
          onChanged: (v) => _t((t) => t.copyWith(backgroundPattern: v)),
        ),
        ThemeSliderRow(
          label: 'Intensidad',
          value: t.background.patternOpacity,
          min: 0,
          max: 2,
          divisions: 20,
          format: (v) => v == 0 ? 'Apagado' : '${(v * 100).round()} %',
          onChanged: (v) => _t(
            (t) => t.copyWith(
              background: BackgroundTokens(
                patternOpacity: v,
                patternScale: t.background.patternScale,
              ),
            ),
          ),
        ),
        title('Letra'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final f in FontPresets.all)
              ChoiceChip(
                label: Text(f.label),
                tooltip: f.description,
                selected: FontPresets.byId(_draft.fontPresetId).id == f.id,
                onSelected: (_) => _update(_draft.copyWith(fontPresetId: f.id)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          '¿Quieres tocar bordes, sombras, cabeceras, monedas o animaciones? '
          'Cambia a Avanzado: lo que hayas hecho aquí se conserva.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildEditor(BuildContext context) {
    final t = _draft.tactical;
    final p = _draft.palette;
    String px(double v) => '${v.round()} px';
    String pct(double v) => '${(v * 100).round()} %';
    String x(double v) => '×${v.toStringAsFixed(2)}';

    return ListView(
      key: const ValueKey('theme-editor-list'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        _Section(
          title: 'General',
          icon: Icons.tune_rounded,
          initiallyExpanded: true,
          children: [
            // Aire para la etiqueta flotante del campo.
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('theme-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre del tema'),
              onChanged: (_) => setState(() => _dirty = true),
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<Brightness>(
              segments: const [
                ButtonSegment(
                  value: Brightness.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Oscuro'),
                ),
                ButtonSegment(
                  value: Brightness.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Claro'),
                ),
              ],
              selected: {_draft.brightness},
              onSelectionChanged: (s) =>
                  _update(_draft.copyWith(brightness: s.first)),
            ),
            ThemeChoiceRow<String>(
              label: 'Tipografía',
              values: [for (final f in FontPresets.all) f.id],
              selected: FontPresets.byId(_draft.fontPresetId).id,
              labelOf: (id) => FontPresets.byId(id).label,
              onChanged: (id) => _update(_draft.copyWith(fontPresetId: id)),
            ),
          ],
        ),
        _Section(
          title: 'Colores base',
          icon: Icons.format_paint_rounded,
          children: [
            ThemeColorRow(
              label: 'Fondo',
              color: p.background,
              onChanged: (c) => _p((p) => p.copyWith(background: c)),
            ),
            ThemeColorRow(
              label: 'Superficie',
              hint: 'Tarjetas y paneles',
              color: p.surface,
              onChanged: (c) => _p((p) => p.copyWith(surface: c)),
            ),
            ThemeColorRow(
              label: 'Superficie alta',
              hint: 'Campos, chips, celdas',
              color: p.surfaceElevated,
              onChanged: (c) => _p((p) => p.copyWith(surfaceElevated: c)),
            ),
            ThemeColorRow(
              label: 'Bordes',
              color: p.border,
              onChanged: (c) => _p((p) => p.copyWith(border: c)),
            ),
            ThemeColorRow(
              label: 'Texto principal',
              color: p.textPrimary,
              onChanged: (c) => _p((p) => p.copyWith(textPrimary: c)),
            ),
            ThemeColorRow(
              label: 'Texto secundario',
              color: p.textSecondary,
              onChanged: (c) => _p((p) => p.copyWith(textSecondary: c)),
            ),
            ThemeColorRow(
              label: 'Error',
              color: p.danger,
              onChanged: (c) => _p((p) => p.copyWith(danger: c)),
            ),
            ThemeColorRow(
              label: 'Éxito',
              color: p.success,
              onChanged: (c) => _p((p) => p.copyWith(success: c)),
            ),
          ],
        ),
        _Section(
          title: 'Colores de juego',
          icon: Icons.palette_rounded,
          children: [
            ThemeColorRow(
              label: 'Acento',
              hint: 'Botones, iconos y barra inferior',
              color: t.primary,
              onChanged: (c) => _t((t) => t.copyWith(primary: c)),
            ),
            ThemeColorRow(
              label: 'Armas',
              color: t.weapon,
              onChanged: (c) => _t((t) => t.copyWith(weapon: c)),
            ),
            ThemeColorRow(
              label: 'Conjuros',
              color: t.spell,
              onChanged: (c) => _t((t) => t.copyWith(spell: c)),
            ),
            ThemeColorRow(
              label: 'Habilidades',
              color: t.ability,
              onChanged: (c) => _t((t) => t.copyWith(ability: c)),
            ),
            ThemeColorRow(
              label: 'Curación',
              color: t.heal,
              onChanged: (c) => _t((t) => t.copyWith(heal: c)),
            ),
            ThemeColorRow(
              label: 'Daño',
              color: t.damage,
              onChanged: (c) => _t((t) => t.copyWith(damage: c)),
            ),
          ],
        ),
        _Section(
          title: 'Metal y cabecera',
          icon: Icons.gradient_rounded,
          children: [
            ThemeColorRow(
              label: 'Borde metálico',
              color: t.metalBorder,
              onChanged: (c) => _t((t) => t.copyWith(metalBorder: c)),
            ),
            ThemeColorRow(
              label: 'Brillo del canto',
              color: t.metalHighlight,
              onChanged: (c) => _t((t) => t.copyWith(metalHighlight: c)),
            ),
            ThemeColorRow(
              label: 'Superficie elevada',
              hint: 'Parte alta del degradado de tarjeta',
              color: t.surfaceRaised,
              onChanged: (c) => _t((t) => t.copyWith(surfaceRaised: c)),
            ),
            ThemeColorRow(
              label: 'Cabecera (inicio)',
              color: t.headerStart,
              onChanged: (c) => _t((t) => t.copyWith(headerStart: c)),
            ),
            ThemeColorRow(
              label: 'Cabecera (final)',
              color: t.headerEnd,
              onChanged: (c) => _t((t) => t.copyWith(headerEnd: c)),
            ),
          ],
        ),
        _Section(
          title: 'Monedas',
          icon: Icons.toll_rounded,
          children: [
            ThemeColorRow(
              label: 'Platino',
              color: t.coinPlatinum,
              onChanged: (c) => _t((t) => t.copyWith(coinPlatinum: c)),
            ),
            ThemeColorRow(
              label: 'Oro',
              color: t.coinGold,
              onChanged: (c) => _t((t) => t.copyWith(coinGold: c)),
            ),
            ThemeColorRow(
              label: 'Electro',
              color: t.coinElectrum,
              onChanged: (c) => _t((t) => t.copyWith(coinElectrum: c)),
            ),
            ThemeColorRow(
              label: 'Plata',
              color: t.coinSilver,
              onChanged: (c) => _t((t) => t.copyWith(coinSilver: c)),
            ),
            ThemeColorRow(
              label: 'Cobre',
              color: t.coinCopper,
              onChanged: (c) => _t((t) => t.copyWith(coinCopper: c)),
            ),
          ],
        ),
        _Section(
          title: 'Formas y bordes',
          icon: Icons.crop_square_rounded,
          children: [
            ThemeShapeEditor(
              label: 'Tarjetas',
              spec: ShapeSpec.fromBorder(t.cardShape),
              onChanged: (s) => _t((t) => t.copyWith(cardShape: s.toBorder())),
            ),
            ThemeShapeEditor(
              label: 'Placas internas',
              spec: ShapeSpec.fromBorder(t.insetShape),
              onChanged: (s) => _t((t) => t.copyWith(insetShape: s.toBorder())),
            ),
            ThemeShapeEditor(
              label: 'Botones y chips',
              spec: ShapeSpec.fromBorder(t.buttonShape),
              onChanged: (s) =>
                  _t((t) => t.copyWith(buttonShape: s.toBorder())),
            ),
            ThemeSliderRow(
              label: 'Grosor de borde',
              value: t.borderWidth,
              min: 0,
              max: 4,
              divisions: 16,
              format: (v) => '${v.toStringAsFixed(2)} px',
              onChanged: (v) => _t((t) => t.copyWith(borderWidth: v)),
            ),
            ThemeChoiceRow<ShadowStyle>(
              label: 'Sombra',
              values: ShadowStyle.values,
              selected: t.shadowStyle,
              labelOf: (v) => _shadowLabels[v]!,
              onChanged: (v) => _t((t) => t.copyWith(shadowStyle: v)),
            ),
          ],
        ),
        _Section(
          title: 'Radios de diálogos y menús',
          icon: Icons.rounded_corner_rounded,
          children: [
            for (final (label, value, apply) in [
              (
                'Diálogos',
                t.shapes.dialogRadius,
                (ShapeTokens s, double v) => _shapes(s, dialog: v),
              ),
              (
                'Hojas inferiores',
                t.shapes.sheetRadius,
                (ShapeTokens s, double v) => _shapes(s, sheet: v),
              ),
              (
                'Campos de texto',
                t.shapes.inputRadius,
                (ShapeTokens s, double v) => _shapes(s, input: v),
              ),
              (
                'Tooltips',
                t.shapes.tooltipRadius,
                (ShapeTokens s, double v) => _shapes(s, tooltip: v),
              ),
              (
                'Botón flotante',
                t.shapes.fabRadius,
                (ShapeTokens s, double v) => _shapes(s, fab: v),
              ),
            ])
              ThemeSliderRow(
                label: label,
                value: value,
                min: 0,
                max: 40,
                divisions: 40,
                format: px,
                onChanged: (v) =>
                    _t((t) => t.copyWith(shapes: apply(t.shapes, v))),
              ),
            ThemeSwitchRow(
              label: 'Píldoras redondas',
              hint: 'Etiquetas y barras con extremos circulares',
              value: t.shapes.pillRadius >= 100,
              onChanged: (v) => _t(
                (t) => t.copyWith(
                  shapes: _shapes(t.shapes, pill: v ? AppRadii.pill : 4),
                ),
              ),
            ),
            ThemeSliderRow(
              label: 'Elevación de menús y diálogos',
              value: t.shapes.overlayElevation,
              min: 0,
              max: 24,
              divisions: 24,
              format: (v) => v.round().toString(),
              onChanged: (v) =>
                  _t((t) => t.copyWith(shapes: _shapes(t.shapes, overlay: v))),
            ),
          ],
        ),
        _Section(
          title: 'Tarjetas',
          icon: Icons.dashboard_rounded,
          children: [
            ThemeChoiceRow<CardGradientStyle>(
              label: 'Relleno',
              values: CardGradientStyle.values,
              selected: t.cards.gradient,
              labelOf: (v) => _gradientLabels[v]!,
              onChanged: (v) =>
                  _t((t) => t.copyWith(cards: _cards(t, gradient: v))),
            ),
            ThemeSliderRow(
              label: 'Brillo del canto superior',
              value: t.cards.highlightAlpha,
              min: 0,
              max: 1,
              divisions: 20,
              format: pct,
              onChanged: (v) =>
                  _t((t) => t.copyWith(cards: _cards(t, highlight: v))),
            ),
            ThemeSwitchRow(
              label: 'Franja de color lateral',
              value: t.cards.toneStripe,
              onChanged: (v) =>
                  _t((t) => t.copyWith(cards: _cards(t, stripe: v))),
            ),
            ThemeSwitchRow(
              label: 'Doble filete',
              hint: 'Segundo borde interior, como un códice',
              value: t.cards.doubleBorder,
              onChanged: (v) =>
                  _t((t) => t.copyWith(cards: _cards(t, double_: v))),
            ),
          ],
        ),
        _Section(
          title: 'Componentes',
          icon: Icons.widgets_rounded,
          children: [
            ThemeChoiceRow<HeaderStyle>(
              label: 'Cabecera de sección',
              values: HeaderStyle.values,
              selected: t.components.header,
              labelOf: (v) => _headerLabels[v]!,
              onChanged: (v) =>
                  _t((t) => t.copyWith(components: _components(t, header: v))),
            ),
            ThemeChoiceRow<ButtonStyleKind>(
              label: 'Botón principal',
              values: ButtonStyleKind.values,
              selected: t.components.button,
              labelOf: (v) => _buttonLabels[v]!,
              onChanged: (v) =>
                  _t((t) => t.copyWith(components: _components(t, button: v))),
            ),
            ThemeChoiceRow<ButtonStyleKind?>(
              label: 'Botón secundario',
              values: const [null, ...ButtonStyleKind.values],
              selected: t.components.secondaryButton,
              labelOf: (v) =>
                  v == null ? 'Contorno (por defecto)' : _buttonLabels[v]!,
              onChanged: (v) => _t(
                (t) => t.copyWith(
                  components: _components(t, secondary: v, setSecondary: true),
                ),
              ),
            ),
            ThemeChoiceRow<BarStyle>(
              label: 'Barras (PG, movimiento)',
              values: BarStyle.values,
              selected: t.components.bar,
              labelOf: (v) => _barLabels[v]!,
              onChanged: (v) =>
                  _t((t) => t.copyWith(components: _components(t, bar: v))),
            ),
            ThemeSwitchRow(
              label: 'Halo en las barras',
              value: t.components.barGlow,
              onChanged: (v) =>
                  _t((t) => t.copyWith(components: _components(t, glow: v))),
            ),
          ],
        ),
        _Section(
          title: 'Fondo',
          icon: Icons.texture_rounded,
          children: [
            ThemeChoiceRow<BackgroundPatternStyle>(
              label: 'Trama',
              values: BackgroundPatternStyle.values,
              selected: t.backgroundPattern,
              labelOf: (v) => _patternLabels[v] ?? v.name,
              onChanged: (v) => _t((t) => t.copyWith(backgroundPattern: v)),
            ),
            ThemeSliderRow(
              label: 'Intensidad de la trama',
              value: t.background.patternOpacity,
              min: 0,
              max: 2,
              divisions: 20,
              format: pct,
              onChanged: (v) => _t(
                (t) => t.copyWith(
                  background: BackgroundTokens(
                    patternOpacity: v,
                    patternScale: t.background.patternScale,
                  ),
                ),
              ),
            ),
            ThemeSliderRow(
              label: 'Tamaño de la trama',
              value: t.background.patternScale,
              min: 0.5,
              max: 2,
              divisions: 15,
              format: x,
              onChanged: (v) => _t(
                (t) => t.copyWith(
                  background: BackgroundTokens(
                    patternOpacity: t.background.patternOpacity,
                    patternScale: v,
                  ),
                ),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Pips, iconos y dados',
          icon: Icons.casino_rounded,
          children: [
            ThemeChoiceRow<PipShape>(
              label: 'Forma de los pips',
              values: PipShape.values,
              selected: t.pipShape,
              labelOf: (v) => _pipLabels[v]!,
              onChanged: (v) => _t((t) => t.copyWith(pipShape: v)),
            ),
            ThemeChoiceRow<IconStyle>(
              label: 'Estilo de iconos',
              values: IconStyle.values,
              selected: t.icons.style,
              labelOf: (v) => _iconLabels[v]!,
              onChanged: (v) =>
                  _t((t) => t.copyWith(icons: _icons(t, style: v))),
            ),
            ThemeChoiceRow<DiceMedallionShape>(
              label: 'Medallón del dado',
              values: DiceMedallionShape.values,
              selected: t.icons.diceShape,
              labelOf: (v) => _diceLabels[v]!,
              onChanged: (v) =>
                  _t((t) => t.copyWith(icons: _icons(t, dice: v))),
            ),
            ThemeChoiceRow<FontWeight>(
              label: 'Grosor del número del dado',
              values: FontWeight.values,
              selected: t.icons.diceNumberWeight,
              labelOf: _weightLabel,
              onChanged: (v) =>
                  _t((t) => t.copyWith(icons: _icons(t, weight: v))),
            ),
            ThemeSliderRow(
              label: 'Espaciado del número del dado',
              value: t.icons.diceNumberSpacing,
              min: -2,
              max: 4,
              divisions: 24,
              format: (v) => v.toStringAsFixed(2),
              onChanged: (v) =>
                  _t((t) => t.copyWith(icons: _icons(t, spacing: v))),
            ),
          ],
        ),
        _Section(
          title: 'Títulos',
          icon: Icons.title_rounded,
          children: [
            ThemeChoiceRow<String>(
              label: 'Fuente de títulos',
              values: kHeaderFontFamilies,
              selected: kHeaderFontFamilies.contains(t.headerFont.family)
                  ? t.headerFont.family
                  : kHeaderFontFamilies.first,
              labelOf: (f) => f,
              onChanged: (f) => _t(
                (t) => t.copyWith(
                  headerFont: HeaderFontStyle(
                    family: f,
                    letterSpacing: t.headerFont.letterSpacing,
                    weight: t.headerFont.weight,
                  ),
                ),
              ),
            ),
            Text(
              'La fuente de títulos se aplica con la tipografía "Diario"; '
              'las demás tipografías usan su propia fuente.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            ThemeChoiceRow<FontWeight>(
              label: 'Grosor de títulos',
              values: FontWeight.values,
              selected: t.headerFont.weight,
              labelOf: _weightLabel,
              onChanged: (w) => _t(
                (t) => t.copyWith(
                  headerFont: HeaderFontStyle(
                    family: t.headerFont.family,
                    letterSpacing: t.headerFont.letterSpacing,
                    weight: w,
                  ),
                ),
              ),
            ),
            ThemeSliderRow(
              label: 'Espaciado de letras',
              value: t.headerFont.letterSpacing,
              min: -1,
              max: 4,
              divisions: 50,
              format: (v) => v.toStringAsFixed(1),
              onChanged: (v) => _t(
                (t) => t.copyWith(
                  headerFont: HeaderFontStyle(
                    family: t.headerFont.family,
                    letterSpacing: v,
                    weight: t.headerFont.weight,
                  ),
                ),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Movimiento y densidad',
          icon: Icons.animation_rounded,
          children: [
            ThemeSliderRow(
              label: 'Velocidad de animaciones',
              value: t.motion.durationScale,
              min: 0,
              max: 3,
              divisions: 30,
              format: (v) => v == 0 ? 'Sin animación' : x(v),
              onChanged: (v) =>
                  _t((t) => t.copyWith(motion: _motion(t, scale: v))),
            ),
            ThemeChoiceRow<String>(
              label: 'Curva de los diales',
              values: ThemeCurves.all.keys.toList(),
              selected: ThemeCurves.nameOf(t.motion.dialCurve, 'easeOutCubic'),
              labelOf: (n) => n,
              onChanged: (n) => _t(
                (t) => t.copyWith(
                  motion: _motion(
                    t,
                    dial: ThemeCurves.byName(n, t.motion.dialCurve),
                  ),
                ),
              ),
            ),
            ThemeChoiceRow<String>(
              label: 'Curva de las tiradas',
              values: ThemeCurves.all.keys.toList(),
              selected: ThemeCurves.nameOf(
                t.motion.resolveCurve,
                'easeOutBack',
              ),
              labelOf: (n) => n,
              onChanged: (n) => _t(
                (t) => t.copyWith(
                  motion: _motion(
                    t,
                    resolve: ThemeCurves.byName(n, t.motion.resolveCurve),
                  ),
                ),
              ),
            ),
            ThemeSliderRow(
              label: 'Densidad (relleno de tarjetas y botones)',
              value: t.density.scale,
              min: 0.6,
              max: 1.6,
              divisions: 20,
              format: x,
              onChanged: (v) =>
                  _t((t) => t.copyWith(density: DensityTokens(scale: v))),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Ayudas para reconstruir los sub-tokens inmutables.
// ---------------------------------------------------------------------

ShapeTokens _shapes(
  ShapeTokens s, {
  double? dialog,
  double? sheet,
  double? input,
  double? tooltip,
  double? fab,
  double? pill,
  double? overlay,
}) => ShapeTokens(
  dialogRadius: dialog ?? s.dialogRadius,
  sheetRadius: sheet ?? s.sheetRadius,
  inputRadius: input ?? s.inputRadius,
  tooltipRadius: tooltip ?? s.tooltipRadius,
  fabRadius: fab ?? s.fabRadius,
  pillRadius: pill ?? s.pillRadius,
  overlayElevation: overlay ?? s.overlayElevation,
);

CardTokens _cards(
  TacticalThemeTokens t, {
  CardGradientStyle? gradient,
  double? highlight,
  bool? stripe,
  bool? double_,
}) => CardTokens(
  gradient: gradient ?? t.cards.gradient,
  highlightAlpha: highlight ?? t.cards.highlightAlpha,
  toneStripe: stripe ?? t.cards.toneStripe,
  doubleBorder: double_ ?? t.cards.doubleBorder,
);

ComponentTokens _components(
  TacticalThemeTokens t, {
  HeaderStyle? header,
  ButtonStyleKind? button,
  BarStyle? bar,
  bool? glow,
  ButtonStyleKind? secondary,
  bool setSecondary = false,
}) => ComponentTokens(
  header: header ?? t.components.header,
  button: button ?? t.components.button,
  bar: bar ?? t.components.bar,
  barGlow: glow ?? t.components.barGlow,
  secondaryButton: setSecondary ? secondary : t.components.secondaryButton,
);

IconTokens _icons(
  TacticalThemeTokens t, {
  IconStyle? style,
  DiceMedallionShape? dice,
  FontWeight? weight,
  double? spacing,
}) => IconTokens(
  style: style ?? t.icons.style,
  diceShape: dice ?? t.icons.diceShape,
  diceNumberWeight: weight ?? t.icons.diceNumberWeight,
  diceNumberSpacing: spacing ?? t.icons.diceNumberSpacing,
);

MotionTokens _motion(
  TacticalThemeTokens t, {
  double? scale,
  Curve? dial,
  Curve? resolve,
}) => MotionTokens(
  durationScale: scale ?? t.motion.durationScale,
  dialCurve: dial ?? t.motion.dialCurve,
  resolveCurve: resolve ?? t.motion.resolveCurve,
);

String _weightLabel(FontWeight w) => switch (w.value) {
  100 => 'Fina (100)',
  200 => 'Extraligera (200)',
  300 => 'Ligera (300)',
  400 => 'Normal (400)',
  500 => 'Media (500)',
  600 => 'Seminegrita (600)',
  700 => 'Negrita (700)',
  800 => 'Extranegrita (800)',
  _ => 'Negra (900)',
};

const _shadowLabels = {
  ShadowStyle.softWarm: 'Suave y cálida',
  ShadowStyle.hudGlow: 'Halo del acento',
  ShadowStyle.hardMartial: 'Dura, desplazada',
  ShadowStyle.none: 'Sin sombra',
};

const _gradientLabels = {
  CardGradientStyle.raisedToSurface: 'Degradado (claro arriba)',
  CardGradientStyle.flat: 'Plano',
  CardGradientStyle.surfaceToRaised: 'Degradado (claro abajo)',
};

const _headerLabels = {
  HeaderStyle.ornament: 'Ornamento',
  HeaderStyle.plate: 'Placa',
  HeaderStyle.underline: 'Subrayado',
  HeaderStyle.brackets: 'Corchetes',
  HeaderStyle.minimal: 'Mínima',
};

const _buttonLabels = {
  ButtonStyleKind.filled: 'Relleno',
  ButtonStyleKind.tonal: 'Tonal',
  ButtonStyleKind.outlined: 'Contorno',
  ButtonStyleKind.flat: 'Plano',
};

const _barLabels = {
  BarStyle.smooth: 'Continua',
  BarStyle.segmented: 'Segmentada',
  BarStyle.thin: 'Fina',
};

const _pipLabels = {
  PipShape.circle: 'Círculo',
  PipShape.diamond: 'Rombo',
  PipShape.square: 'Cuadrado',
  PipShape.leaf: 'Hoja',
  PipShape.star: 'Estrella',
  PipShape.bolt: 'Rayo',
  PipShape.paw: 'Huella',
  PipShape.heart: 'Corazón',
  PipShape.flame: 'Llama',
};

const _iconLabels = {
  IconStyle.rounded: 'Redondeados',
  IconStyle.sharp: 'Afilados',
  IconStyle.outlined: 'Contorno',
};

const _diceLabels = {
  DiceMedallionShape.hexagon: 'Hexágono',
  DiceMedallionShape.circle: 'Círculo',
  DiceMedallionShape.diamond: 'Rombo',
  DiceMedallionShape.square: 'Cuadrado',
};

const _patternLabels = {
  BackgroundPatternStyle.codexFrame: 'Marco de códice',
  BackgroundPatternStyle.parchmentRules: 'Pauta de pergamino',
  BackgroundPatternStyle.constellations: 'Constelaciones',
  BackgroundPatternStyle.astrolabeGrid: 'Retícula de astrolabio',
  BackgroundPatternStyle.forgedDiagonal: 'Diagonal forjada',
  BackgroundPatternStyle.organicVeins: 'Nervaduras',
  BackgroundPatternStyle.frostCrystals: 'Cristales de hielo',
  BackgroundPatternStyle.cryptArches: 'Arcos de cripta',
  BackgroundPatternStyle.dragonScales: 'Escamas de dragón',
  BackgroundPatternStyle.deepWaves: 'Olas',
  BackgroundPatternStyle.brickWall: 'Ladrillo',
  BackgroundPatternStyle.vellumDots: 'Puntos de vitela',
  BackgroundPatternStyle.glitchNoise: 'Señal perdida',
  BackgroundPatternStyle.skzooPaws: 'Huellas',
  BackgroundPatternStyle.purpleOcean: 'Mar de luces',
  BackgroundPatternStyle.citrusGrove: 'Cítricos',
  BackgroundPatternStyle.kitsuneSmoke: 'Luna y humo',
  BackgroundPatternStyle.silkSmoke: 'Sol y humo',
  BackgroundPatternStyle.bambooHeraldry: 'Bambú heráldico',
  BackgroundPatternStyle.eclipseOrbits: 'Órbitas de eclipse',
  BackgroundPatternStyle.bandAndBuns: 'Niebla y bandas',
  BackgroundPatternStyle.runicLattice: 'Retícula rúnica',
  BackgroundPatternStyle.elvenFiligree: 'Filigrana élfica',
};

/// Fila de muestras de color con etiqueta; tocar una abre el picker.
class _SwatchStrip extends StatelessWidget {
  const _SwatchStrip({required this.entries});

  final List<(String, Color, ValueChanged<Color>)> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final (label, color, onChanged) in entries)
          Expanded(
            child: InkWell(
              key: ValueKey('swatch-$label'),
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: () async {
                final picked = await showDialog<Color>(
                  context: context,
                  builder: (_) => HsvColorPickerDialog(initialColor: color),
                );
                if (picked != null) onChanged(picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Sección plegable del editor.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        children: children,
      ),
    );
  }
}

/// Vista previa: un trocito de HUD pintado con el tema del borrador.
class _ThemePreviewPanel extends StatelessWidget {
  const _ThemePreviewPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tactical = context.tactical;

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: TacticalScaffoldBackground(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: ShapeDecoration(
                gradient: tactical.headerGradient,
                shape: tactical.insetBorder(tactical.metalBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Rook el Intacto',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    'Guerrero 5',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TacticalCard(
              tone: tactical.heal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    icon: Icons.favorite_rounded,
                    title: 'Vida',
                    tone: tactical.heal,
                    trailing: TonePill(label: 'Herido', tone: tactical.damage),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text('34', style: theme.textTheme.displaySmall),
                      Text(
                        ' / 42 PG',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      const ArmorShield(value: '18', size: 52),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  VitalBar(value: 0.8, color: tactical.heal),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Curar'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Daño'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TacticalCard(
              tone: tactical.spell,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Poderes',
                    tone: tactical.spell,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      TonePill(label: 'Arma', tone: tactical.weapon),
                      TonePill(label: 'Conjuro', tone: tactical.spell),
                      TonePill(label: 'Habilidad', tone: tactical.ability),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ResourcePips(current: 3, max: 5, color: tactical.ability),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      for (final coin in [
                        tactical.coinPlatinum,
                        tactical.coinGold,
                        tactical.coinElectrum,
                        tactical.coinSilver,
                        tactical.coinCopper,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: PipGlyph(
                            shape: PipShape.circle,
                            filled: true,
                            color: coin,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
