// El wizard de importación con IA, en tres pasos:
//
//   1. Prompt    — armás y copiás el prompt para tu IA de confianza.
//   2. Respuesta — pegás el JSON que te devolvió (o elegís un .json).
//   3. Revisión  — vista previa de la ficha + avisos del validador, y
//                  recién ahí se confirma la importación.
//
// Modos de arranque:
// - Alta ([replaceIndex] null): la ficha confirmada se AÑADE al roster.
// - Corrección ([replaceIndex] != null): la ficha confirmada REEMPLAZA la
//   entrada indicada, así la respuesta de la IA no duplica al personaje
//   que ya estaba (en la app vieja este flujo no tenía UI de destino y
//   terminaba creando fichas repetidas).
//
// Reparto de responsabilidades:
// - La pantalla es la máquina de estados: paso actual, controller del
//   texto pegado, resultado de la validación y el commit final al store.
// - Cada paso es un widget con su propia lógica local (modos de fuente,
//   extracción de Nivel20, lectura de archivos, portapapeles).
// - La validación NO toca el roster: usa CharacterValidator directo; el
//   roster solo se muta al confirmar (addCharacter / replaceCharacter).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/spell_catalog.dart';
import '../../domain/nivel20_patch.dart';
import '../../domain/character_validator.dart';
import '../../state/character_store.dart';
import 'nivel20_import.dart';
import 'wizard_step_paste.dart';
import 'wizard_step_preview.dart';
import 'wizard_step_source.dart';
import '../../core/theme/design_tokens.dart';

class ImportWizardScreen extends StatefulWidget {
  const ImportWizardScreen({super.key, this.replaceIndex});

  /// Índice del roster a REEMPLAZAR al confirmar (modo corrección).
  /// Null = modo alta.
  final int? replaceIndex;

  @override
  State<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends State<ImportWizardScreen> {
  static const _stepLabels = ['Prompt', 'Respuesta', 'Revisión'];

  int _step = 0;

  /// Texto pegado en el paso 2 (la respuesta de la IA). Vive acá y no en
  /// el paso, para que la barra inferior pueda validarlo al continuar.
  final TextEditingController _responseController = TextEditingController();

  /// Errores bloqueantes del último intento de validación del paso 2.
  List<ValidationIssue> _responseErrors = const [];

  /// Ficha ya validada que muestra el paso 3.
  CharacterValidationResult? _result;

  /// Enlace de Nivel20 resuelto en el paso 1 (si usó ese modo). Al
  /// confirmar se guarda en la ficha importada, para que el HUD pueda
  /// ofrecer "abrir en Nivel20" más adelante sin que el jugador lo
  /// vuelva a pegar a mano.
  String? _nivel20Link;

  /// True si el Paso 3 se alcanzó por "Importar directo (sin IA)": el
  /// botón Atrás vuelve al Paso 1, no al de pegar la respuesta.
  bool _directImport = false;

  /// Ficha de Nivel20 cuyo prompt de parche se preparó en el Paso 1. Si
  /// está, la respuesta pegada en el Paso 2 se interpreta como parche y se
  /// fusiona sobre la ficha base; si pegan una ficha completa se valida
  /// como siempre (modo clásico).
  Map<String, dynamic>? _patchBase;

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  void _onDirectImport(CharacterValidationResult result) {
    setState(() {
      _result = result;
      _responseErrors = const [];
      _directImport = true;
      _step = 2;
    });
  }

  void _onBack() => setState(() {
    _step = (_step == 2 && _directImport) ? 0 : _step - 1;
    _directImport = false;
  });

  void _onEnrichedChanged(Map<String, dynamic>? raw) => _patchBase = raw;

  void _onNivel20LinkResolved(String link) {
    _nivel20Link = link;
  }

  /// "Continuar" del paso 2: valida el texto pegado. Si pasó, avanza al
  /// paso 3 con la ficha construida; si no, queda en el paso 2 con los
  /// errores visibles y el roster intacto.
  Future<void> _validateAndAdvance() async {
    final text = _responseController.text.trim();
    if (text.isEmpty) {
      setState(
        () => _responseErrors = [
          const ValidationIssue(
            severity: ValidationSeverity.error,
            field: 'json',
            message:
                'Pegá primero el JSON que te devolvió la IA '
                '(o elegí un archivo).',
          ),
        ],
      );
      return;
    }

    final patchBase = _patchBase;
    CharacterValidationResult result;
    if (patchBase != null && Nivel20Patch.tryDecode(text) != null) {
      final srd = await SpellCatalog.load();
      if (!mounted) return;
      result = Nivel20Import.applyPatch(patchBase, text, srd: srd);
    } else {
      result = CharacterValidator.parseAndValidate(text);
    }
    if (result.isOk) {
      setState(() {
        _result = result;
        _responseErrors = const [];
        _directImport = false;
        _step = 2;
      });
    } else {
      setState(() => _responseErrors = result.errors);
    }
  }

  void _confirmImport() {
    final result = _result;
    if (result == null || !result.isOk) return;

    final store = context.read<CharacterStore>();
    final character = result.character!;
    if (_nivel20Link != null) {
      // Solo si la ficha no trae su propio enlace (la IA no suele
      // incluirlo en el JSON de respuesta).
      character.basicInfo.nivel20Link ??= _nivel20Link;
    }

    final replaceIndex = widget.replaceIndex;
    if (replaceIndex != null) {
      store.replaceCharacter(replaceIndex, character);
    } else {
      store.addCharacter(character);
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CharacterStore>();
    final replaceIndex = widget.replaceIndex;
    final isReplace =
        replaceIndex != null &&
        replaceIndex >= 0 &&
        replaceIndex < store.roster.length;
    final replacedName = isReplace
        ? store.roster[replaceIndex].basicInfo.name
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isReplace ? 'Corregir ficha con IA' : 'Importar ficha'),
      ),
      body: Column(
        children: [
          WizardStepIndicator(current: _step, labels: _stepLabels),
          const Divider(height: 1),
          Expanded(
            // El Paso 1 se mantiene montado (Offstage) aunque se avance:
            // así "Atrás" devuelve al jugador su JSON o enlace tal como
            // lo dejó, y puede elegir la otra vía sin volver a pegarlo.
            child: Stack(
              fit: StackFit.expand,
              children: [
                Offstage(
                  offstage: _step != 0,
                  child: TickerMode(
                    enabled: _step == 0,
                    child: WizardStepSource(
                      key: const ValueKey('wizard-step-source'),
                      isReplace: isReplace,
                      replacedName: replacedName,
                      currentSheet:
                          isReplace ? store.roster[replaceIndex] : null,
                      onNivel20LinkResolved: _onNivel20LinkResolved,
                      onDirectImport: _onDirectImport,
                      onEnrichedChanged: _onEnrichedChanged,
                    ),
                  ),
                ),
                if (_step != 0)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: switch (_step) {
                      1 => WizardStepPaste(
                        key: const ValueKey('wizard-step-paste'),
                        controller: _responseController,
                        errors: _responseErrors,
                      ),
                      _ => WizardStepPreview(
                        key: const ValueKey('wizard-step-preview'),
                        result: _result!,
                        isReplace: isReplace,
                        replacedName: replacedName,
                        onConfirm: _confirmImport,
                      ),
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          _BottomBar(
            step: _step,
            isReplace: isReplace,
            replacedName: replacedName,
            onBack: _onBack,
            onContinue: () => setState(() => _step = 1),
            onValidateAndAdvance: _validateAndAdvance,
            onConfirm: _confirmImport,
          ),
        ],
      ),
    );
  }
}

/// Barra inferior persistente: el CTA principal de cada paso queda al
/// alcance del pulgar mientras el contenido hace scroll arriba.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.isReplace,
    required this.replacedName,
    required this.onBack,
    required this.onContinue,
    required this.onValidateAndAdvance,
    required this.onConfirm,
  });

  final int step;
  final bool isReplace;
  final String? replacedName;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onValidateAndAdvance;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final Widget primary;
    switch (step) {
      case 0:
        primary = FilledButton(
          onPressed: onContinue,
          child: const Text('Continuar'),
        );
      case 1:
        primary = FilledButton(
          onPressed: onValidateAndAdvance,
          child: const Text('Continuar'),
        );
      default:
        primary = FilledButton.icon(
          onPressed: onConfirm,
          icon: const Icon(Icons.download_done_rounded),
          label: Text(
            isReplace
                ? 'Reemplazar a ${replacedName ?? 'la ficha'}'
                : 'Importar personaje',
          ),
        );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          if (step > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: OutlinedButton(
                onPressed: onBack,
                child: const Text('Atrás'),
              ),
            ),
          Expanded(child: primary),
        ],
      ),
    );
  }
}

/// Indicador de pasos: tres puntos numerados unidos por líneas que se
/// van "encendiendo". Rehecho en M3 con colorScheme (Etapa 6 lo reskinnea
/// cambiando tokens, sin tocar este layout).
class WizardStepIndicator extends StatelessWidget {
  const WizardStepIndicator({super.key, required this.current, required this.labels});

  final int current;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Divider(
                  color: i <= current ? scheme.primary : scheme.outlineVariant,
                  thickness: 2,
                ),
              ),
            Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= current
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    border: Border.all(
                      color: i <= current
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: i < current
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: scheme.onPrimary,
                        )
                      : Text(
                          '${i + 1}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: i <= current
                                ? scheme.onPrimary
                                : scheme.outline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  labels[i],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: i <= current ? scheme.primary : scheme.outline,
                    fontWeight: i == current ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
