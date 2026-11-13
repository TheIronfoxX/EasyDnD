// Hoja de resolución de tiradas (Etapa 5c).
//
// Es la evolución del "Protocolo de Dados" de la app vieja, pero en tres
// fases explícitas para no tirar daño cuando el ataque falla:
//
//   setup  → método (digital/manual), ventaja y (si aplica) nivel de
//            ranura; se tira el d20 o se declara la salvación del
//            objetivo.
//   attack → se ve el d20 y el jugador decide FALLO o IMPACTO.
//   damage → solo si impactó y la acción tiene daño; digital o manual,
//            con el escalado por nivel ya aplicado.
//
// La hoja NO conoce el store: recibe todo resuelto en un [RollAction] y
// avisa por callbacks cuándo gastar una ranura o una carga. Así el mismo
// widget sirve para armas, conjuros y rasgos, y se testea sin pref ni
// personaje de por medio.
//
// Cambio consciente respecto de la app vieja: las habilidades con
// attack_type 'none' (ej. Escudo) ya no muestran una tirada de ataque
// sin sentido; muestran su efecto y un botón "Usar" que consume el
// recurso. El modelo ya distinguía los tres tipos, el HUD viejo los
// trataba a todos como ataque.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dice.dart';
import '../../core/resolution.dart';

/// Cargas/usos de un arma o habilidad, tal como las ve la hoja.
class RollCharges {
  final int current;
  final int max;

  const RollCharges({required this.current, required this.max});
}

/// Ranura de conjuro disponible para esta tirada. Es una copia de la
/// ficha: la hoja lleva su propio contador para reflejar el gasto sin
/// esperar a que la pantalla de abajo se reconstruya.
class RollSlotOption {
  final int level;
  final int current;
  final int max;

  const RollSlotOption({
    required this.level,
    required this.current,
    required this.max,
  });
}

/// Todo lo que la hoja necesita saber de una acción, ya resuelto.
///
/// [attackType] usa el mismo vocabulario del modelo: 'attack' (tira el
/// personaje), 'save' (tira el objetivo contra [saveDc]) o 'none' (efecto
/// directo, sin tirada).
class RollAction {
  final String name;

  /// "Arma", "Conjuro" o "Rasgo". Solo para el encabezado.
  final String kindLabel;
  final IconData icon;
  final int modifier;
  final String attackType;
  final String? damageDice;
  final String? damageType;
  final String successDescription;
  final String failureDescription;
  final String? loreDescription;
  final String? tacticalSummary;
  final bool isScalable;
  final int baseLevel;
  final String? scalingFormula;
  final int? saveDc;
  final RollCharges? charges;
  final List<RollSlotOption> slotOptions;
  final VoidCallback? onConsumeCharge;
  final ValueChanged<int>? onConsumeSlot;

  const RollAction({
    required this.name,
    required this.kindLabel,
    required this.icon,
    required this.modifier,
    this.attackType = 'attack',
    this.damageDice,
    this.damageType,
    this.successDescription = '',
    this.failureDescription = '',
    this.loreDescription,
    this.tacticalSummary,
    this.isScalable = false,
    this.baseLevel = 0,
    this.scalingFormula,
    this.saveDc,
    this.charges,
    this.slotOptions = const [],
    this.onConsumeCharge,
    this.onConsumeSlot,
  });

  /// Cualquier conjuro de nivel 1+ gasta ranura; un truco (nivel 0) no.
  /// isScalable solo decide si se puede elegir un nivel superior.
  bool get usesSpellSlot => baseLevel >= 1;

  bool get isSavingThrow => attackType == 'save';
  bool get isPlainUse => attackType == 'none';

  /// La acción inflige daño solo si la fórmula parsea. Una fórmula
  /// rota se comporta como "sin daño" en vez de reventar a mitad de
  /// combate.
  bool get hasDamage =>
      damageDice != null && DiceFormula.tryParse(damageDice!) != null;

  bool get hasCharges => charges != null;
}

/// Abre la hoja. [random] es inyectable para tests determinísticos.
Future<void> showResolutionSheet(
  BuildContext context,
  RollAction action, {
  Random? random,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ResolutionSheet(action: action, random: random),
  );
}

enum _Phase { setup, attack, damage }

enum _RollMode { digital, manual }

class ResolutionSheet extends StatefulWidget {
  const ResolutionSheet({super.key, required this.action, this.random});

  final RollAction action;
  final Random? random;

  @override
  State<ResolutionSheet> createState() => _ResolutionSheetState();
}

class _ResolutionSheetState extends State<ResolutionSheet> {
  _Phase _phase = _Phase.setup;
  _RollMode _mode = _RollMode.digital;
  AdvantageMode _advantage = AdvantageMode.normal;

  final _manualDie1 = TextEditingController();
  final _manualDie2 = TextEditingController();
  final _manualDamage = TextEditingController();

  late final Random _random = widget.random ?? Random();

  /// Copia local de las ranuras por nivel: se descuenta acá al gastar
  /// para que el chip y el aviso se actualicen al instante.
  late final Map<int, int> _slotRemaining = {
    for (final option in widget.action.slotOptions)
      option.level: option.current,
  };

  late final List<RollSlotOption> _eligibleOptions = _computeEligible();
  late int _selectedLevel = _initialLevel();

  late int _chargesRemaining = widget.action.charges?.current ?? 0;

  List<int> _dice = const [];
  int? _damageTotal;
  String? _damageBreakdown;
  bool _manualDamageConfirmed = false;
  bool _slotConsumed = false;
  bool _chargeConsumed = false;
  String? _manualError;

  RollAction get _action => widget.action;

  bool get _needsTwoDice => _advantage != AdvantageMode.normal;

  List<RollSlotOption> _computeEligible() {
    if (!_action.usesSpellSlot) return const [];
    final list = _action.isScalable
        ? _action.slotOptions.where((o) => o.level >= _action.baseLevel)
        : _action.slotOptions.where((o) => o.level == _action.baseLevel);
    return list.toList()..sort((a, b) => a.level.compareTo(b.level));
  }

  int _initialLevel() {
    if (!_action.usesSpellSlot) return _action.baseLevel;
    final available = _eligibleOptions.where((o) => o.current > 0);
    if (available.isNotEmpty) return available.first.level;
    if (_eligibleOptions.isNotEmpty) return _eligibleOptions.first.level;
    return _action.baseLevel;
  }

  int get _slotLeft => _slotRemaining[_selectedLevel] ?? 0;

  bool get _hasChargesLeft => !_action.hasCharges || _chargesRemaining > 0;

  bool get _canRoll {
    if (!_hasChargesLeft) return false;
    if (_action.usesSpellSlot) return _slotLeft > 0;
    return true;
  }

  @override
  void dispose() {
    _manualDie1.dispose();
    _manualDie2.dispose();
    _manualDamage.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Recursos.
  // -------------------------------------------------------------------

  /// La ranura se gasta una sola vez por hoja, al lanzar (o al declarar
  /// la salvación), acierte o no: el conjuro ya se usó.
  void _consumeSlotIfNeeded() {
    if (!_action.usesSpellSlot || _slotConsumed) return;
    final left = _slotRemaining[_selectedLevel] ?? 0;
    if (left > 0) {
      _slotRemaining[_selectedLevel] = left - 1;
      _action.onConsumeSlot?.call(_selectedLevel);
    }
    _slotConsumed = true;
  }

  void _consumeChargeIfNeeded() {
    if (!_action.hasCharges || _chargeConsumed) return;
    if (_chargesRemaining > 0) {
      _chargesRemaining -= 1;
      _action.onConsumeCharge?.call();
    }
    _chargeConsumed = true;
  }

  // -------------------------------------------------------------------
  // Tiradas.
  // -------------------------------------------------------------------

  int get _keptDie => D20RollResult(_dice, _advantage).kept;

  void _rollDigital() {
    if (!_canRoll) return;
    final result = rollD20(mode: _advantage, random: _random);
    _consumeSlotIfNeeded();
    _consumeChargeIfNeeded();
    setState(() {
      _dice = result.dice;
      _phase = _Phase.attack;
    });
  }

  void _confirmManual() {
    if (!_canRoll) return;

    final first = int.tryParse(_manualDie1.text.trim());
    final second = _needsTwoDice ? int.tryParse(_manualDie2.text.trim()) : null;

    if (first == null || first < 1 || first > 20) {
      setState(() => _manualError = 'Escribí un resultado de 1 a 20.');
      return;
    }
    if (_needsTwoDice && (second == null || second < 1 || second > 20)) {
      setState(() => _manualError = 'Completá los dos dados (1 a 20).');
      return;
    }

    _consumeSlotIfNeeded();
    _consumeChargeIfNeeded();
    setState(() {
      _manualError = null;
      _dice = [first, if (second != null) second];
      _phase = _Phase.attack;
    });
  }

  void _computeDamage() {
    final result = resolveDamageRoll(
      baseDice: _action.damageDice,
      isScalable: _action.isScalable,
      baseLevel: _action.baseLevel,
      scalingFormula: _action.scalingFormula,
      selectedLevel: _selectedLevel,
      random: _random,
    );
    _damageTotal = result?.total;
    _damageBreakdown = result?.breakdown;
  }

  void _onFail() => Navigator.of(context).pop();

  void _onImpact() {
    if (!_action.hasDamage) {
      Navigator.of(context).pop();
      return;
    }
    if (_mode == _RollMode.digital) _computeDamage();
    setState(() => _phase = _Phase.damage);
  }

  void _onSaveFailed() {
    _consumeSlotIfNeeded();
    _consumeChargeIfNeeded();
    if (!_action.hasDamage) {
      Navigator.of(context).pop();
      return;
    }
    if (_mode == _RollMode.digital) _computeDamage();
    setState(() => _phase = _Phase.damage);
  }

  void _onSavePassed() {
    _consumeSlotIfNeeded();
    _consumeChargeIfNeeded();
    Navigator.of(context).pop();
  }

  void _onUse() {
    _consumeSlotIfNeeded();
    _consumeChargeIfNeeded();
    Navigator.of(context).pop();
  }

  void _onOmitDamage() => Navigator.of(context).pop();

  void _onConfirmDamage() {
    if (_mode == _RollMode.manual && !_manualDamageConfirmed) {
      final value = int.tryParse(_manualDamage.text.trim());
      if (value == null || value < 0) {
        setState(() => _manualError = 'Escribí el daño total (0 o más).');
        return;
      }
      setState(() {
        _manualError = null;
        _damageTotal = value;
        _damageBreakdown = null;
        _manualDamageConfirmed = true;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  /// Fórmula de daño a nivel elegido, para el recordatorio de mesa en
  /// modo manual: "2d6", "8d6 + 2 × 1d6" o "1d8 + 4" (escalado plano).
  String? get _damageExpression {
    final base = _action.damageDice;
    if (base == null) return null;
    if (!_action.isScalable || _action.scalingFormula == null) return base;

    final extra = _selectedLevel - _action.baseLevel;
    if (extra <= 0) return base;

    final scale = DiceFormula.tryParse(_action.scalingFormula!);
    if (scale == null) return base;
    if (scale.isFlat) {
      final flat = scale.bonus * extra;
      if (flat == 0) return base;
      return '$base ${flat > 0 ? '+' : ''}$flat';
    }
    return '$base + ${scale.count * extra}d${scale.sides}';
  }

  // -------------------------------------------------------------------
  // Build.
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    final Widget content = switch (_phase) {
      _Phase.setup => _buildSetup(),
      _Phase.attack => _buildAttackResult(),
      _Phase.damage => _buildDamage(),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetup() {
    final theme = Theme.of(context);
    final action = _action;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(action: action),
        if (action.isSavingThrow) ...[
          const SizedBox(height: 16),
          _Banner(
            icon: Icons.shield_rounded,
            text: 'CD de Salvación: ${action.saveDc ?? '—'}',
            highlight: true,
          ),
        ],
        if (_action.hasCharges) ...[
          const SizedBox(height: 10),
          Text(
            'Usos: $_chargesRemaining/${action.charges!.max}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: _chargesRemaining > 0
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
        ],
        if (_hasText(action.loreDescription)) ...[
          const SizedBox(height: 12),
          Text(
            action.loreDescription!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_hasText(action.tacticalSummary)) ...[
          const SizedBox(height: 12),
          _Banner(
            icon: Icons.lightbulb_outline_rounded,
            text: action.tacticalSummary!,
          ),
        ],
        if (action.usesSpellSlot) ...[
          const SizedBox(height: 20),
          _sectionLabel('Nivel de lanzamiento'),
          const SizedBox(height: 8),
          if (_eligibleOptions.isEmpty)
            Text(
              'La ficha no tiene ranuras de nivel ${action.baseLevel}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else if (action.isScalable)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _eligibleOptions)
                  ChoiceChip(
                    label: Text(
                      'Nv. ${option.level} · '
                      '${_slotRemaining[option.level] ?? 0}/${option.max}',
                    ),
                    selected: _selectedLevel == option.level,
                    onSelected: (_slotRemaining[option.level] ?? 0) > 0
                        ? (_) => setState(() => _selectedLevel = option.level)
                        : null,
                  ),
              ],
            )
          else
            _FixedSlotIndicator(
              level: action.baseLevel,
              current: _slotLeft,
              max: _eligibleOptions.first.max,
            ),
        ],
        if (!_canRoll) ...[
          const SizedBox(height: 16),
          _Banner(
            icon: Icons.error_outline_rounded,
            text: !_hasChargesLeft
                ? 'Sin usos disponibles: recuperalos con un descanso.'
                : 'No te quedan ranuras de este nivel.',
            error: true,
          ),
        ],
        if (_canRoll) ...[
          if (!action.isPlainUse && !action.isSavingThrow) ...[
            const SizedBox(height: 20),
            _sectionLabel('Tirada'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Normal'),
                  selected: _advantage == AdvantageMode.normal,
                  onSelected: (_) =>
                      setState(() => _advantage = AdvantageMode.normal),
                ),
                ChoiceChip(
                  label: const Text('Ventaja'),
                  selected: _advantage == AdvantageMode.advantage,
                  onSelected: (_) =>
                      setState(() => _advantage = AdvantageMode.advantage),
                ),
                ChoiceChip(
                  label: const Text('Desventaja'),
                  selected: _advantage == AdvantageMode.disadvantage,
                  onSelected: (_) =>
                      setState(() => _advantage = AdvantageMode.disadvantage),
                ),
              ],
            ),
          ],
          if ((!_action.isPlainUse && _action.hasDamage) ||
              _action.isSavingThrow) ...[
            const SizedBox(height: 20),
            _sectionLabel('Método de daño'),
            const SizedBox(height: 8),
            SegmentedButton<_RollMode>(
              segments: const [
                ButtonSegment(
                  value: _RollMode.digital,
                  label: Text('Digital'),
                  icon: Icon(Icons.casino_rounded, size: 18),
                ),
                ButtonSegment(
                  value: _RollMode.manual,
                  label: Text('Manual'),
                  icon: Icon(Icons.pin_rounded, size: 18),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
            ),
          ],
          const SizedBox(height: 20),
          if (_action.isPlainUse)
            FilledButton.icon(
              onPressed: _onUse,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Usar'),
            )
          else if (_action.isSavingThrow)
            _buildSavingThrowOutcome()
          else if (_mode == _RollMode.digital)
            FilledButton.icon(
              onPressed: _rollDigital,
              icon: const Icon(Icons.casino_rounded),
              label: Text(_needsTwoDice ? 'Tirar 2d20' : 'Tirar d20'),
            )
          else
            _buildManualD20(),
        ],
      ],
    );
  }

  Widget _buildSavingThrowOutcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _onSaveFailed,
          icon: const Icon(Icons.close_rounded),
          label: Text(
            _action.hasDamage
                ? 'El objetivo falla · tirar daño'
                : 'El objetivo falla',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _onSavePassed,
          icon: const Icon(Icons.check_rounded),
          label: const Text('El objetivo supera'),
        ),
      ],
    );
  }

  Widget _buildManualD20() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_damageExpression != null) ...[
          Text(
            'En mesa: tirá ${_needsTwoDice ? '2d20 (usá el ${_advantage == AdvantageMode.advantage ? 'mayor' : 'menor'})' : '1d20'} '
            'y sumá ${_modLabel(_action.modifier)}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _manualDie1,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: _needsTwoDice ? 'Dado 1' : 'Dado',
                  errorText: _manualError,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (_needsTwoDice) ...[
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _manualDie2,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Dado 2',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _confirmManual,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Confirmar tirada'),
        ),
      ],
    );
  }

  Widget _buildAttackResult() {
    final theme = Theme.of(context);
    final natural = _keptDie;
    final total = natural + _action.modifier;
    final isCrit = natural == 20;
    final isFumble = natural == 1;
    final highlight = isCrit
        ? theme.colorScheme.tertiary
        : isFumble
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(action: _action),
        if (_action.usesSpellSlot) ...[
          const SizedBox(height: 2),
          Text(
            'Lanzado a nivel $_selectedLevel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          _dice.length > 1
              ? 'Dados: ${_dice.join(' y ')} → se usa $natural '
                    '(${_advantage == AdvantageMode.advantage ? 'ventaja' : 'desventaja'})'
              : 'Dado natural: $natural',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              color: highlight.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$total',
              style: theme.textTheme.displaySmall?.copyWith(
                color: highlight,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$natural natural ${_modLabel(_action.modifier)} mod',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (isCrit)
          _Verdict(
            label: '¡Éxito crítico!',
            description: _action.successDescription,
            color: theme.colorScheme.tertiary,
          )
        else if (isFumble)
          _Verdict(
            label: '¡Pifia!',
            description: _action.failureDescription,
            color: theme.colorScheme.error,
          )
        else
          _Descriptions(action: _action),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _onFail,
                child: const Text('Fallo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _onImpact,
                child: const Text('Impacto'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDamage() {
    final theme = Theme.of(context);
    final showManualInput =
        _mode == _RollMode.manual && !_manualDamageConfirmed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(action: _action),
        const SizedBox(height: 16),
        _sectionLabel('Daño / efecto'),
        const SizedBox(height: 8),
        if (showManualInput)
          TextField(
            controller: _manualDamage,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Daño total',
              helperText: _damageExpression == null
                  ? null
                  : 'En mesa: tirá $_damageExpression',
              errorText: _manualError,
              border: const OutlineInputBorder(),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _action.damageType ?? 'Daño',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_damageTotal ?? 0}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_damageBreakdown != null)
                      Text(
                        _damageBreakdown!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _onOmitDamage,
                child: const Text('Omitir'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _onConfirmDamage,
                child: Text(showManualInput ? 'Ver daño' : 'Cerrar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  static String _modLabel(int mod) => mod >= 0 ? '+$mod' : '$mod';

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}

// ---------------------------------------------------------------------
// Piezas privadas de la hoja.
// ---------------------------------------------------------------------

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.action});

  final RollAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = [
      action.kindLabel,
      if (action.damageDice != null && action.damageDice!.trim().isNotEmpty)
        action.damageDice!.trim(),
      if (action.damageType != null && action.damageType!.trim().isNotEmpty)
        action.damageType!.trim(),
    ].join(' · ');

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(action.icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    this.highlight = false,
    this.error = false,
  });

  final IconData icon;
  final String text;
  final bool highlight;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = error
        ? theme.colorScheme.error
        : highlight
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedSlotIndicator extends StatelessWidget {
  const _FixedSlotIndicator({
    required this.level,
    required this.current,
    required this.max,
  });

  final int level;
  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Ranura de nivel $level',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$current/$max disponibles',
            style: theme.textTheme.bodySmall?.copyWith(
              color: current > 0
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.label,
    required this.description,
    required this.color,
  });

  final String label;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Descriptions extends StatelessWidget {
  const _Descriptions({required this.action});

  final RollAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = action.successDescription.trim();
    final failure = action.failureDescription.trim();
    if (success.isEmpty && failure.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (success.isNotEmpty) ...[
          Text(
            'Si tiene éxito',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.tertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(success, style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
        ],
        if (failure.isNotEmpty) ...[
          Text(
            'Si falla',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(failure, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
