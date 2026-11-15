// Importación de Nivel20 en el wizard: lógica pura + subwidget de acciones.
//
// Vive aparte de wizard_step_source.dart para no engordarlo. Cuando la
// fuente del Paso 1 es un enlace de Nivel20 o un JSON crudo de Nivel20
// pegado, el jugador elige entre:
//
// - Importar directo (sin IA): Nivel20Mapper + validador, salto al Paso 3.
// - Preparar prompt enriquecido: la ficha base ya mapeada viaja a la IA,
//   que solo completa lo que el mapeador no puede deducir.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/nivel20_extractor.dart';
import '../../domain/ai_prompt.dart';
import '../../domain/character_validator.dart';
import '../../domain/nivel20_mapper.dart';

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
  static CharacterValidationResult direct(Map<String, dynamic> raw) {
    try {
      final json = Nivel20Mapper.toJson(raw);
      return CharacterValidator.parseAndValidate(jsonEncode(json));
    } on FormatException catch (e) {
      return CharacterValidationResult(
        character: null,
        issues: [
          ValidationIssue(
            severity: ValidationSeverity.error,
            field: 'nivel20',
            message: e.message,
          ),
        ],
      );
    }
  }

  /// Opción b): prompt con la ficha base pre-calculada + textos crudos.
  static String enrichedPrompt(Map<String, dynamic> raw) {
    final base = const JsonEncoder.withIndent('  ').convert(Nivel20Mapper.toJson(raw));
    final sources = Nivel20Mapper.enrichmentSources(raw);
    return AiPrompt.forNivel20Enrichment(
      base,
      feats: sources.feats,
      customActions: sources.customActions,
      equipment: sources.equipment,
    );
  }

  /// Fusiona sobre la ficha base (Nivel20Mapper.toJson) un parche sparse
  /// que solo trae las claves opcionales "purse" y/o "companions" (ver
  /// AiPrompt.forNivel20Enrichment, puntos 5 y 6), sin pisar lo que el
  /// mapeador ya detectó:
  /// - "purse" en [patch] son monedas ADICIONALES: se suman (nunca se
  ///   restan ni reemplazan) sobre lo que ya traía la ficha base.
  /// - "companions" en [patch] se añaden los que no estén ya (comparando
  ///   por nombre), sin duplicar ni tocar los existentes.
  static Map<String, dynamic> mergeAiPatch(
    Map<String, dynamic> baseJson,
    Map<String, dynamic> patch,
  ) {
    final merged = Map<String, dynamic>.from(baseJson);

    final patchPurse = patch['purse'];
    if (patchPurse is Map) {
      final basePurse = Map<String, dynamic>.from(
        (merged['purse'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      for (final key in ['gold', 'silver', 'copper']) {
        final base = (basePurse[key] as num?)?.toInt() ?? 0;
        final patched = (patchPurse[key] as num?)?.toInt() ?? 0;
        basePurse[key] = base + patched;
      }
      merged['purse'] = basePurse;
    }

    final patchCompanions = patch['companions'];
    if (patchCompanions is List) {
      final baseCompanions = List<dynamic>.from(
        (merged['companions'] as List?) ?? const [],
      );
      final existingNames = baseCompanions
          .map((c) => (c as Map)['name']?.toString())
          .toSet();
      for (final c in patchCompanions) {
        if (c is! Map) continue;
        if (existingNames.add(c['name']?.toString())) {
          baseCompanions.add(c);
        }
      }
      merged['companions'] = baseCompanions;
    }

    return merged;
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
          'O bien pedirle a tu IA que complete lo que Nivel20 no trae '
          '(rasgos, recursos, equipo y textos).',
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
