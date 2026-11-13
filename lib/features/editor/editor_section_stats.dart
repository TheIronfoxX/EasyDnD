// Sección "Atributos" del editor: los seis valores (STR/DEX/CON/INT/
// WIS/CHA) con sus modificadores.
//
// El modificador es un campo aparte a propósito: el estándar de 5e es
// (valor - 10) / 2 redondeando para abajo, pero la ficha es la fuente
// de verdad (homebrew, ítems que pisan el mod...) y el HUD confía en
// lo guardado. El botón "usar estándar" aplica la fórmula con un toque
// — y para poder sobreescribir lo VISIBLE (no solo el borrador) los
// mods van con controllers propios.

import 'package:flutter/material.dart';

import '../../domain/models/character.dart';
import '../../domain/models/stats.dart';
import 'editor_fields.dart';
import '../../core/theme/design_tokens.dart';

class EditorSectionStats extends StatefulWidget {
  const EditorSectionStats({super.key, required this.draft});

  final CharacterModel draft;

  @override
  State<EditorSectionStats> createState() => _EditorSectionStatsState();
}

class _EditorSectionStatsState extends State<EditorSectionStats> {
  /// Un controller por modificador: "usar estándar" tiene que poder
  /// sobreescribir el texto del campo, y TextFormField con
  /// initialValue no se refresca solo.
  late final List<TextEditingController> _modControllers;

  @override
  void initState() {
    super.initState();
    _modControllers = [
      for (final score in widget.draft.stats.asList)
        TextEditingController(text: score.mod.toString()),
    ];
  }

  @override
  void dispose() {
    for (final controller in _modControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// El modificador estándar de 5e para [value]: (valor - 10) / 2
  /// redondeando para ABAJO (el ~/ de enteros ya hace floor).
  int _standardMod(int value) => (value - 10) ~/ 2;

  void _applyStandard(int index, AbilityScore score) {
    final standard = _standardMod(score.value);
    score.mod = standard;
    _modControllers[index].text = standard.toString();
  }

  void _handleModChanged(int index, AbilityScore score, int? value) {
    if (value != null) score.mod = value;
    // El botón de estándar aparece/desaparece según el valor.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scores = widget.draft.stats.asList;
    final statKeys = kStatLabels.keys.toList(growable: false);

    return EditorSectionScaffold(
      title: 'Atributos',
      help:
          'El modificador es el número que usa el HUD. El estándar '
          'de 5e sale de (valor − 10) / 2, pero lo podés pisar si tu '
          'ficha lo dice (homebrew).',
      children: [
        for (var i = 0; i < scores.length; i++)
          _ScoreCard(
            key: ValueKey('score-${statKeys[i]}'),
            label: kStatLabels[statKeys[i]]!,
            statKey: statKeys[i],
            score: scores[i],
            modController: _modControllers[i],
            onValueChanged: (value) {
              if (value != null) {
                scores[i].value = value;
                setState(() {});
              }
            },
            onModChanged: (value) => _handleModChanged(i, scores[i], value),
            onApplyStandard: () => _applyStandard(i, scores[i]),
            standardMod: _standardMod(scores[i].value),
          ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    super.key,
    required this.label,
    required this.statKey,
    required this.score,
    required this.modController,
    required this.onValueChanged,
    required this.onModChanged,
    required this.onApplyStandard,
    required this.standardMod,
  });

  /// Etiqueta en español ("Fuerza").
  final String label;

  /// Clave del shape ("str"), para los tests.
  final String statKey;

  final AbilityScore score;
  final TextEditingController modController;

  final ValueChanged<int?> onValueChanged;
  final ValueChanged<int?> onModChanged;
  final VoidCallback onApplyStandard;

  /// Mod estándar calculado para el valor ACTUAL (para el botón).
  final int standardMod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modDiffers = score.mod != standardMod;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          14,
          AppSpacing.md,
          14,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
                Text(
                  score.modFormatted,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: EditorIntField(
                    key: ValueKey('value-$statKey'),
                    label: 'Valor',
                    value: score.value,
                    onChanged: onValueChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('mod-$statKey'),
                    controller: modController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Modificador',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      final parsed = int.tryParse(text);
                      if (parsed != null) onModChanged(parsed);
                    },
                  ),
                ),
              ],
            ),
            if (modDiffers)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: ValueKey('standard-$statKey'),
                    onPressed: onApplyStandard,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: Text(
                      'Usar estándar (${standardMod >= 0 ? '+' : ''}$standardMod)',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
