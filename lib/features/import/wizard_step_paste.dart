// Paso 2 del wizard: pegar la respuesta de la IA.
//
// El texto pegado puede traer vallas de código Markdown y cortesía
// alrededor ("¡Claro! Aquí tienes tu ficha..."): CharacterValidator lo
// sanea antes de decodificar. También se puede elegir directamente un
// archivo .json del dispositivo (en Android vía ruta, en la web vía
// bytes — por eso withData: true y nada de dart:io).
//
// La validación la dispara la barra "Continuar" de la pantalla; este
// paso solo pinta el campo, los errores bloqueantes del último intento
// y la vía del archivo.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/character_validator.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/design_tokens.dart';

class WizardStepPaste extends StatefulWidget {
  const WizardStepPaste({
    super.key,
    required this.controller,
    required this.errors,
  });

  final TextEditingController controller;

  /// Errores bloqueantes del último "Continuar". Vacía = sin intentos
  /// fallidos todavía.
  final List<ValidationIssue> errors;

  @override
  State<WizardStepPaste> createState() => _WizardStepPasteState();
}

class _WizardStepPasteState extends State<WizardStepPaste> {
  bool _isReadingFile = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        Text('Pegá la respuesta de la IA', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Cuando tu IA te devuelva el JSON de la ficha, pegalo acá '
          'completo (no pasa nada si viene con texto o vallas de código '
          'alrededor). También podés elegir un archivo .json.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),

        TextField(
          controller: widget.controller,
          maxLines: 10,
          minLines: 6,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: AppFonts.jetBrainsMono,
          ),
          decoration: InputDecoration(
            labelText: 'JSON de la ficha',
            hintText: '{ "basic_info": { "name": ... }, ... }',
            border: const OutlineInputBorder(),
            errorText: widget.errors.isEmpty
                ? null
                // El texto del error visible resume; el detalle va en la
                // lista de abajo.
                : 'El JSON no pasó la validación — mirá el detalle:',
            errorMaxLines: 2,
          ),
        ),

        if (widget.errors.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final error in widget.errors) _ErrorRow(issue: error),
          const SizedBox(height: 6),
          Text(
            'Corregí el JSON (o pedile a la IA que lo arregle) y volvé a '
            'intentar. El roster no se tocó: no se importó nada.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isReadingFile ? null : _pickFile,
            icon: _isReadingFile
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open_rounded),
            label: const Text('Elegir archivo .json'),
          ),
        ),
      ],
    );
  }

  /// Selector de archivos .json. En la web file_picker no da ruta: pide
  /// los bytes (withData: true) y los decodificamos acá mismo, así el
  /// mismo código sirve en Android y en navegador.
  Future<void> _pickFile() async {
    setState(() => _isReadingFile = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      // Selector cerrado sin elegir nada: cancela silenciosamente.
      final bytes = result?.files.single.bytes;
      if (bytes == null) return;

      widget.controller.text = utf8.decode(bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo elegido.')),
      );
    } finally {
      if (mounted) setState(() => _isReadingFile = false);
    }
  }
}

/// Un error bloqueante con su ruta de campo, en rojo.
class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.issue});

  final ValidationIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cancel_outlined, size: 16, color: scheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${issue.field} — ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: AppFonts.jetBrainsMono,
                      color: scheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: issue.message),
                ],
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
