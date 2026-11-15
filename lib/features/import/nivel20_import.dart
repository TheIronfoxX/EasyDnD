// Importación de Nivel20 en el wizard: lógica pura + subwidget de acciones.
//
// Vive aparte de wizard_step_source.dart para no engordarlo. Cuando la
// fuente del Paso 1 es un enlace de Nivel20 o un JSON crudo de Nivel20
// pegado, el jugador elige entre:
//
// - Importar directo (sin IA): Nivel20Mapper + validador, salto al Paso 3.
// - Preparar prompt enriquecido: la IA NO recibe la ficha, solo contexto
//   mínimo y los textos crudos, y devuelve un "parche" (Nivel20Patch) que
//   se fusiona sobre la ficha base del mapeador.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/nivel20_extractor.dart';
import '../../domain/ai_prompt.dart';
import '../../domain/character_validator.dart';
import '../../domain/models/srd_spell.dart';
import '../../domain/nivel20_mapper.dart';
import '../../domain/nivel20_patch.dart';

/// Lógica pura (sin widgets) del camino Nivel20 del wizard.
class Nivel20Import {
  Nivel20Import._();

  /// Decodifica [text] (JSON de Nivel20, crudo o ya limpio) y devuelve el
  /// mapa si realmente parece una ficha de Nivel20; null en cualquier
  /// otro caso (texto libre, JSON roto, JSON de EasyDnD...).
  static Map<String, dynamic>? parseRaw(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{')) return null;
    try {
      final cleaned = Nivel20Extractor.cleanRawJsonString(trimmed);
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      return Nivel20Mapper.looksLikeNivel20(decoded) ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Opción a): mapea y valida por el mismo camino que la respuesta de la
  /// IA (parseAndValidate), para que el Paso 3 reciba lo de siempre.
  ///
  /// [srd] es el catálogo de conjuros SRD con el que se cruzan los
  /// conjuros importados (ver Nivel20Mapper).
  static CharacterValidationResult direct(
    Map<String, dynamic> raw, {
    List<SrdSpell> srd = const [],
  }) {
    try {
      final json = Nivel20Mapper.toJson(raw, srd: srd);
      return CharacterValidator.parseAndValidate(jsonEncode(json));
    } on FormatException catch (e) {
      return _error(e.message);
    }
  }

  /// Opción b), segunda mitad: fusiona la respuesta de la IA ([patchText],
  /// un parche) sobre la ficha base del mapeador y valida el resultado.
  /// Si el texto no es un parche válido devuelve un error bloqueante.
  static CharacterValidationResult applyPatch(
    Map<String, dynamic> raw,
    String patchText, {
    List<SrdSpell> srd = const [],
  }) {
    final patch = Nivel20Patch.tryDecode(patchText);
    if (patch == null) {
      return _error(
        'La respuesta no es un parche válido: pega el JSON con '
        '"classified_features", "resources", "inventory" y/o "lore_info".',
      );
    }
    try {
      final base = Nivel20Mapper.map(raw, srd: srd);
      final merged = Nivel20Patch.apply(base, patch);
      return CharacterValidator.validateMap(merged.toJson());
    } on FormatException catch (e) {
      return _error(e.message);
    }
  }

  static CharacterValidationResult _error(String message) =>
      CharacterValidationResult(
        character: null,
        issues: [
          ValidationIssue(
            severity: ValidationSeverity.error,
            field: 'nivel20',
            message: message,
          ),
        ],
      );

  /// Opción b): prompt de parche con contexto mínimo + textos crudos
  /// (sin la ficha ni los conjuros).
  static String enrichedPrompt(Map<String, dynamic> raw) {
    final sources = Nivel20Mapper.enrichmentSources(raw);
    return AiPrompt.forNivel20Enrichment(
      name: sources.name,
      characterClass: sources.characterClass,
      level: sources.level,
      feats: sources.feats,
      customActions: sources.customActions,
      equipment: sources.equipment,
    );
  }
}

/// Las dos acciones del Paso 1 cuando hay una ficha de Nivel20 lista.
class Nivel20ImportChoice extends StatelessWidget {
  const Nivel20ImportChoice({
    super.key,
    required this.enriched,
    required this.error,
    required this.onDirect,
    required this.onEnrich,
  });

  /// True si el prompt mostrado abajo ya es el enriquecido.
  final bool enriched;

  /// Errores bloqueantes de la importación directa, si los hubo.
  final String? error;

  final VoidCallback onDirect;
  final VoidCallback onEnrich;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ficha de Nivel20 lista', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Puedes importarla directamente, sin IA: los números '
          '(atributos, PG, CA, ranuras, conjuros, armas) se leen tal cual. '
          'O bien pedirle a tu IA un parche con lo que Nivel20 no trae '
          '(rasgos, recursos, equipo y textos): no ve ni toca tus números.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onDirect,
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Importar directo (sin IA)'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onEnrich,
            icon: Icon(enriched ? Icons.check_rounded : Icons.auto_awesome_rounded),
            label: Text(
              enriched
                  ? 'Prompt enriquecido listo (abajo)'
                  : 'Preparar prompt de IA (enriquecido)',
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
        ],
      ],
    );
  }
}
