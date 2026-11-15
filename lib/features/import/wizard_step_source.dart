// Paso 1 del wizard: conseguir el prompt.
//
// El jugador elige de dónde salen los datos de su personaje y la app arma
// el prompt maestro (AiPrompt) listo para copiar a su IA de confianza:
//
// - Vacía: no tiene nada digital; pega sus datos al final del prompt.
// - Pegar ficha: texto de la ficha (JSON crudo de Nivel20 — se limpia de
//   HTML — o texto copiado de un PDF).
// - Enlace Nivel20: la app descarga y limpia la ficha pública por él.
// - Ficha actual (solo modo corrección): arreglar la ficha ya importada
//   a partir de los problemas que el validador le encuentra.
//
// La app NUNCA le habla a ninguna IA: el jugador copia el prompt y lo
// pega donde quiera. La app es 100% offline.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/nivel20_extractor.dart';
import '../../data/spell_catalog.dart';
import 'nivel20_import.dart';
import '../../domain/ai_prompt.dart';
import '../../domain/character_validator.dart';
import '../../domain/models/character.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/design_tokens.dart';

/// Cómo llegan los datos del personaje al prompt.
enum ImportSourceMode {
  /// El jugador no tiene nada digital: la IA trabajará con lo que él
  /// pegue al final del prompt copiado.
  emptySheet('Vacía'),

  /// El jugador pega el texto de la ficha (JSON crudo de Nivel20, que se
  /// limpia de HTML, o texto de un PDF).
  pastedText('Pegar ficha'),

  /// El jugador pega el enlace de su ficha pública de Nivel20 y la app
  /// la descarga y limpia por él.
  nivel20Link('Enlace Nivel20'),

  /// Solo en modo corrección: la ficha ya importada del personaje que se
  /// quiere arreglar, con los problemas que le encuentre el validador.
  currentSheet('Ficha actual');

  const ImportSourceMode(this.label);
  final String label;
}

class WizardStepSource extends StatefulWidget {
  const WizardStepSource({
    super.key,
    required this.isReplace,
    this.replacedName,
    this.currentSheet,
    this.onNivel20LinkResolved,
    this.onDirectImport,
    this.onEnrichedChanged,
  });

  /// True cuando el wizard corre en modo corrección (reemplaza una ficha
  /// existente al confirmar).
  final bool isReplace;

  /// Nombre del personaje a reemplazar (modo corrección), para el banner.
  final String? replacedName;

  /// Ficha a corregir (modo corrección). Fuente del modo "Ficha actual".
  final CharacterModel? currentSheet;

  /// Avisa a la pantalla que se resolvió un enlace de Nivel20, para
  /// guardarlo en la ficha al confirmar.
  final void Function(String link)? onNivel20LinkResolved;

  /// Importación directa de Nivel20 (sin IA): entrega la ficha ya
  /// validada para saltar al Paso 3.
  final void Function(CharacterValidationResult result)? onDirectImport;

  /// Avisa a la pantalla de la ficha de Nivel20 cuyo prompt de parche
  /// está listo (para fusionar después la respuesta de la IA), o null si
  /// el texto de origen cambió y ese prompt ya no vale.
  final void Function(Map<String, dynamic>? raw)? onEnrichedChanged;

  @override
  State<WizardStepSource> createState() => _WizardStepSourceState();
}

class _WizardStepSourceState extends State<WizardStepSource> {
  ImportSourceMode _mode = ImportSourceMode.emptySheet;

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  // Estado de la extracción de Nivel20.
  bool _isExtracting = false;
  String? _extractError;
  String? _extractedFicha;

  bool _copied = false;

  /// True si el usuario pidió el prompt enriquecido de Nivel20.
  bool _enriched = false;
  String? _directError;

  // Caché del JSON de Nivel20 decodificado (evita re-parsear 60 KB en
  // cada build): se invalida cuando cambia el texto fuente.
  String? _rawKey;
  Map<String, dynamic>? _rawCache;

  @override
  void initState() {
    super.initState();
    // "Vacía" no tiene sentido corrigiendo una ficha que ya existe.
    if (widget.isReplace) _mode = ImportSourceMode.pastedText;
    // El prompt y las acciones de Nivel20 dependen del texto pegado: el
    // paso entero debe reconstruirse al escribir, no solo el campo.
    _sourceController.addListener(_onSourceChanged);
  }

  void _onSourceChanged() {
    if (!mounted) return;
    if (_enriched) widget.onEnrichedChanged?.call(null);
    setState(() {
      _enriched = false;
      _directError = null;
    });
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // PROMPT ACTUAL (función pura del estado del paso)
  // ---------------------------------------------------------------------

  /// El prompt armado según el modo, o null si todavía falta algo
  /// (texto vacío, enlace sin descargar, ficha sin problemas...).
  String? get _prompt {
    switch (_mode) {
      case ImportSourceMode.emptySheet:
        return AiPrompt.forEmptySheet();

      case ImportSourceMode.pastedText:
        final text = _sourceController.text.trim();
        if (text.isEmpty) return null;
        // Si pegó el JSON crudo de Nivel20, se limpia de HTML antes de
        // incrustarlo: la IA recibe texto legible en vez de sopa de tags.
        if (_nivel20Raw != null && _enriched) {
          return Nivel20Import.enrichedPrompt(_nivel20Raw!);
        }
        if (text.startsWith('{')) {
          try {
            return AiPrompt.forEmbeddedSource(
              Nivel20Extractor.cleanRawJsonString(text),
            );
          } on FormatException {
            return null; // JSON roto: el hint del campo lo avisa.
          }
        }
        return AiPrompt.forEmbeddedSource(text);

      case ImportSourceMode.nivel20Link:
        final ficha = _extractedFicha;
        if (ficha == null || ficha.isEmpty) return null;
        if (_nivel20Raw != null && _enriched) {
          return Nivel20Import.enrichedPrompt(_nivel20Raw!);
        }
        return AiPrompt.forEmbeddedSource(ficha);

      case ImportSourceMode.currentSheet:
        final sheet = widget.currentSheet;
        if (sheet == null) return null;
        final problems = _currentSheetProblems;
        if (problems == null || problems.isEmpty) return null;
        return AiPrompt.forCorrection(
          const JsonEncoder.withIndent('  ').convert(sheet.toJson()),
          problems,
        );
    }
  }

  /// JSON de Nivel20 disponible en el modo actual (pegado o descargado),
  /// o null si no hay ficha de Nivel20 lista.
  Map<String, dynamic>? get _nivel20Raw {
    final String? source = switch (_mode) {
      ImportSourceMode.pastedText => _sourceController.text,
      ImportSourceMode.nivel20Link => _extractedFicha,
      _ => null,
    };
    if (source == null || source.trim().isEmpty) return null;
    if (source != _rawKey) {
      _rawKey = source;
      _rawCache = Nivel20Import.parseRaw(source);
    }
    return _rawCache;
  }

  /// Problemas detectables HOY en la ficha guardada (la revalidamos
  /// contra su JSON canónico). Los warnings de "campo ausente" ya no
  /// aplican — los fallbacks quedaron cocidos al importar — pero los de
  /// calidad de datos (dados malformados, condiciones desconocidas...)
  /// persisten en el JSON y vuelven a detectarse.
  List<String>? get _currentSheetProblems {
    final sheet = widget.currentSheet;
    if (sheet == null) return null;
    final result = CharacterValidator.validateMap(sheet.toJson());
    return result.issues
        .map((issue) => '${issue.field}: ${issue.message}')
        .toList();
  }

  // ---------------------------------------------------------------------
  // ACCIONES
  // ---------------------------------------------------------------------

  Future<void> _extractNivel20() async {
    final link = _linkController.text.trim();
    setState(() {
      _isExtracting = true;
      _extractError = null;
    });

    try {
      final ficha = await Nivel20Extractor.extractInfoText(link);
      if (!mounted) return;
      setState(() {
        _extractedFicha = ficha;
        _isExtracting = false;
      });
      widget.onNivel20LinkResolved?.call(link);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _extractError = e.toString().replaceFirst('Exception: ', '');
        _isExtracting = false;
      });
    }
  }

  Future<void> _importDirect() async {
    final raw = _nivel20Raw;
    if (raw == null) return;
    final srd = await SpellCatalog.load();
    if (!mounted) return;
    final result = Nivel20Import.direct(raw, srd: srd);
    if (result.isOk) {
      setState(() => _directError = null);
      widget.onDirectImport?.call(result);
    } else {
      setState(() => _directError = result.errors.map((e) => e.message).join('\n'));
    }
  }

  void _prepareEnriched() {
    widget.onEnrichedChanged?.call(_nivel20Raw);
    setState(() {
      _enriched = true;
      _copied = false;
    });
  }

  Future<void> _copyPrompt() async {
    final prompt = _prompt;
    if (prompt == null) return;

    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  // ---------------------------------------------------------------------
  // LAYOUT
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final modes = widget.isReplace
        ? [
            ImportSourceMode.pastedText,
            ImportSourceMode.nivel20Link,
            ImportSourceMode.currentSheet,
          ]
        : [
            ImportSourceMode.emptySheet,
            ImportSourceMode.pastedText,
            ImportSourceMode.nivel20Link,
          ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        Text(
          'Conseguí el prompt para tu IA',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Copiá este prompt y pegalo en tu IA de confianza (ChatGPT, '
          'Claude, la que sea). Te va a devolver el JSON de tu ficha.',
          style: theme.textTheme.bodyMedium,
        ),
        if (widget.isReplace) ...[
          const SizedBox(height: 14),
          _ReplaceBanner(name: widget.replacedName),
        ],
        const SizedBox(height: AppSpacing.lg),

        SegmentedButton<ImportSourceMode>(
          segments: [
            for (final mode in modes)
              ButtonSegment(value: mode, label: Text(mode.label)),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) {
            // Nada de copiar un prompt que ya no corresponde a lo visible.
            if (_enriched) widget.onEnrichedChanged?.call(null);
            setState(() {
              _mode = selection.first;
              _copied = false;
              _enriched = false;
              _directError = null;
            });
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        switch (_mode) {
          ImportSourceMode.emptySheet => const _EmptySheetHint(),
          ImportSourceMode.pastedText => _PastedTextField(
            controller: _sourceController,
          ),
          ImportSourceMode.nivel20Link => _Nivel20LinkField(
            controller: _linkController,
            isExtracting: _isExtracting,
            error: _extractError,
            hasFicha: _extractedFicha != null,
            onExtract: _extractNivel20,
          ),
          ImportSourceMode.currentSheet => _CurrentSheetCard(
            problems: _currentSheetProblems,
          ),
        },
        if (_nivel20Raw != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Nivel20ImportChoice(
            enriched: _enriched,
            error: _directError,
            onDirect: _importDirect,
            onEnrich: _prepareEnriched,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),

        _PromptPreview(prompt: _prompt, copied: _copied, onCopy: _copyPrompt),
      ],
    );
  }
}

/// Banner del modo corrección: deja explícito qué va a pasar al confirmar.
class _ReplaceBanner extends StatelessWidget {
  const _ReplaceBanner({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.secondary),
      ),
      child: Row(
        children: [
          Icon(
            Icons.published_with_changes_rounded,
            color: scheme.onSecondaryContainer,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Vas a corregir la ficha de ${name ?? 'tu personaje'}: la '
              'versión que confirmes al final REEMPLAZA la actual, no se '
              'guarda aparte.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hint del modo "Vacía": los datos van al final del prompt copiado.
class _EmptySheetHint extends StatelessWidget {
  const _EmptySheetHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Modo ficha vacía', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No tenés nada digital de tu personaje. Copiá el prompt de '
              'abajo, y ANTES de mandárselo a la IA pegá los datos de tu '
              'ficha (los que tengas: PDF, apuntes, lo que sea) donde dice '
              '"PEGA AQUÍ LOS DATOS DE TU PERSONAJE".',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo del modo "Pegar ficha".
class _PastedTextField extends StatefulWidget {
  const _PastedTextField({required this.controller});

  final TextEditingController controller;

  @override
  State<_PastedTextField> createState() => _PastedTextFieldState();
}

class _PastedTextFieldState extends State<_PastedTextField> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isJson = widget.controller.text.trimLeft().startsWith('{');
    final isBrokenJson = isJson && _jsonIsBroken();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          maxLines: 6,
          minLines: 4,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: AppFonts.jetBrainsMono,
          ),
          decoration: InputDecoration(
            labelText: 'Texto de la ficha',
            hintText:
                'Pegá acá el JSON crudo de Nivel20 o el texto de la '
                'ficha (de un PDF, de tus apuntes...)',
            border: const OutlineInputBorder(),
            errorText: isBrokenJson
                ? 'Eso empieza como JSON pero no decodifica: revisá que '
                      'esté copiado completo.'
                : null,
            errorMaxLines: 3,
          ),
          // Cualquier edición invalida el prompt copiado (se regenera
          // solo; el "¡Copiado!" también se apaga).
          onChanged: (_) => setState(() {}),
        ),
        if (isJson && !isBrokenJson)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: AppSpacing.xs),
            child: Text(
              'Detectamos JSON de Nivel20: se limpia el HTML de las '
              'descripciones antes de armar el prompt.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  bool _jsonIsBroken() {
    try {
      // Solo chequeo de decodificabilidad; la limpieza completa la hace
      // el getter del prompt.
      jsonDecode(widget.controller.text);
      return false;
    } catch (_) {
      return true;
    }
  }
}

/// Campo + estado de la extracción del modo "Enlace Nivel20".
class _Nivel20LinkField extends StatelessWidget {
  const _Nivel20LinkField({
    required this.controller,
    required this.isExtracting,
    required this.error,
    required this.hasFicha,
    required this.onExtract,
  });

  final TextEditingController controller;
  final bool isExtracting;
  final String? error;
  final bool hasFicha;
  final VoidCallback onExtract;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Enlace de tu ficha de Nivel20',
            hintText: 'https://nivel20.com/games/.../characters/...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isExtracting ? null : onExtract,
            icon: isExtracting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_rounded),
            label: Text(
              isExtracting
                  ? 'Descargando tu ficha…'
                  : hasFicha
                  ? 'Volver a descargar'
                  : 'Descargar ficha',
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          _StatusCard(
            icon: Icons.error_outline_rounded,
            color: scheme.error,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(error!),
                const SizedBox(height: 6),
                // Reintentar es volver a tocar "Descargar ficha".
                Text(
                  'Fijate que la ficha esté marcada como pública en Nivel20. '
                  'También podés abrir el enlace en el navegador, copiar el '
                  'JSON y usar el modo "Pegar ficha".',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
        if (hasFicha && error == null) ...[
          const SizedBox(height: 10),
          _StatusCard(
            icon: Icons.check_circle_outline_rounded,
            color: scheme.primary,
            child: Text(
              'Ficha descargada y limpiada: ya va incluida en el prompt.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

/// Tarjeta del modo "Ficha actual": lista los problemas encontrados.
class _CurrentSheetCard extends StatelessWidget {
  const _CurrentSheetCard({required this.problems});

  final List<String>? problems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (problems == null) return const SizedBox.shrink();

    if (problems!.isEmpty) {
      return _StatusCard(
        icon: Icons.verified_rounded,
        color: scheme.primary,
        child: Text(
          'El validador no le encuentra problemas corregibles a la ficha '
          'guardada. Si igual querés regenerarla, usá "Pegar ficha" o '
          '"Enlace Nivel20" con la fuente original.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Problemas detectados en la ficha guardada:',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final problem in problems!)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(problem, style: theme.textTheme.bodySmall),
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

/// Card de estado genérica (éxito / error) con icono y color.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Vista previa del prompt armado + botón copiar. El prompt completo se
/// muestra en monospace y es seleccionable por si el jugador prefiere
/// copiar a mano un pedazo.
class _PromptPreview extends StatelessWidget {
  const _PromptPreview({
    required this.prompt,
    required this.copied,
    required this.onCopy,
  });

  final String? prompt;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prompt para tu IA', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 280),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: prompt == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'El prompt aparece acá cuando completes el modo de '
                      'arriba.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: SelectableText(
                    prompt!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: AppFonts.jetBrainsMono,
                      height: 1.4,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: prompt == null ? null : onCopy,
            icon: Icon(
              copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 18,
            ),
            label: Text(
              copied
                  ? '¡Copiado! Ya lo tenés en el portapapeles'
                  : 'Copiar prompt',
            ),
          ),
        ),
      ],
    );
  }
}
