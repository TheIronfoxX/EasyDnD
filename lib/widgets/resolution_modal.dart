import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum _RollMode { digital, manual }

enum _AdvantageMode { normal, advantage, disadvantage }

/// Hotfix (Objetivo 3): el modal ahora es una máquina de tres fases en vez
/// de un simple booleano "¿ya hay resultado?". Antes de este hotfix se
/// tiraba el d20 y el daño en el mismo gesto, lo cual era ineficiente en
/// mesa: el jugador tiraba daño incluso cuando el ataque fallaba. Ahora:
///   setup   -> elegir nivel/método/ventaja y tirar el d20.
///   attack  -> se ve el resultado del d20; el jugador decide FALLO/IMPACTO.
///   damage  -> (solo si IMPACTO y la acción inflige daño) se resuelve el
///              daño, digital o manual, y se cierra con APLICAR DAÑO.
enum _Phase { setup, attack, damage }

/// Representa, para el selector de nivel de la Fase 6, cuánto le queda al
/// personaje de un nivel de ranura concreto. El modal es agnóstico del
/// modelo real (SpellSlot vive en character_model.dart) para no acoplarse
/// a él — quien llama a showResolutionModal hace la traducción.
class SpellSlotOption {
  final int level;
  final int current;
  final int max;

  const SpellSlotOption({required this.level, required this.current, required this.max});
}

class _ParsedDice {
  final int count;
  final int sides;
  final int flatBonus;

  const _ParsedDice(this.count, this.sides, this.flatBonus);
}

/// Parsea notación de dados tipo "8d6", "1d6+2" o "2d4-1". Devuelve null si
/// el formato no es reconocible, para que el resto del código pueda
/// simplemente ocultar la sección de daño en vez de reventar.
///
/// Hotfix (Objetivo 2): esta misma función es la que permite que el daño
/// de armas como "2d6+8" (bonificador ya embebido en la notación) se lea
/// exactamente igual que el damageDice de un hechizo — el modal no
/// necesita saber si el origen es un Weapon o una Ability, solo recibir
/// la cadena correcta (ver turn_tab.dart, _weaponToEntry).
///
/// Hotfix (Blindaje del Escalado): además de "NdM(+/-K)", ahora también
/// reconoce una notación puramente plana ("+3", "-1", "4") sin dado, para
/// habilidades que escalan con un número fijo por nivel en vez de tirar
/// dados extra. Antes, un scalingFormula así de simple no parseaba y el
/// escalado se quedaba mudo sin que nadie se enterara. El patrón debe
/// mantenerse en sincronía con _looksLikeValidDiceOrFlat en
/// ability_model.dart, que valida el mismo formato al importar la ficha.
_ParsedDice? _parseDice(String formula) {
  final trimmed = formula.trim();

  final diceMatch = RegExp(r'^(\d+)d(\d+)\s*([+-]\s*\d+)?$').firstMatch(trimmed);
  if (diceMatch != null) {
    final count = int.parse(diceMatch.group(1)!);
    final sides = int.parse(diceMatch.group(2)!);
    final bonusRaw = diceMatch.group(3)?.replaceAll(' ', '');
    final bonus = bonusRaw != null ? int.parse(bonusRaw) : 0;
    return _ParsedDice(count, sides, bonus);
  }

  final flatMatch = RegExp(r'^([+-]?\s*\d+)$').firstMatch(trimmed);
  if (flatMatch != null) {
    final bonus = int.parse(flatMatch.group(1)!.replaceAll(' ', ''));
    return _ParsedDice(0, 0, bonus);
  }

  return null;
}

int _rollDiceSum(int count, int sides, Random random) {
  var total = 0;
  for (var i = 0; i < count; i++) {
    total += random.nextInt(sides) + 1;
  }
  return total;
}

/// Resultado puro de "cuánto daño hace esta tirada", ya con el desglose
/// listo para pintar.
class SpellDamageResult {
  final int total;
  final String breakdown;

  const SpellDamageResult({required this.total, required this.breakdown});
}

/// Hotfix (Blindaje del Escalado): la cuenta de "daño base + N niveles ×
/// fórmula de escalado" vivía como un método privado de
/// _ResolutionModalContentState. Eso obligaba a montar un Dialog completo
/// para comprobar con un test que Bola de Fuego a nivel 5 escala como toca.
/// Sacarla aquí, a una clase sin Flutter ni State de por medio, la hace
/// testeable con cuatro líneas y reutilizable fuera del modal si algún día
/// hace falta (p.ej. mostrar daño medio esperado en la lista de conjuros).
class SpellDamageResolver {
  /// Límite de niveles extra puramente defensivo: _selectedLevel ya viene
  /// acotado por las ranuras de conjuro reales del personaje (normalmente
  /// hasta nivel 9), así que en la práctica nunca se llega ni de lejos a
  /// este tope. Está aquí para que un valor corrupto o un test mal escrito
  /// no dispare una tirada de miles de dados en vez de fallar rápido.
  static const int defaultMaxScalingLevels = 20;

  /// Devuelve null si la acción no tiene daño resoluble (damageDice es null
  /// o no parsea) — mismo criterio que usa _hasDamage para decidir si hay
  /// Fase de Daño o no.
  ///
  /// [onUnparseableScaling] se invoca (en vez de fallar en silencio) cuando
  /// isScalable es true, scalingFormula no es null, pero el formato no
  /// parsea — esto no debería pasar nunca si el JSON pasó la validación de
  /// Ability.fromJson, pero una ficha vieja cacheada antes del hotfix podría
  /// colarse igualmente.
  static SpellDamageResult? resolve({
    required String? baseDiceFormula,
    required bool isScalable,
    required int baseLevel,
    required String? scalingFormula,
    required int selectedLevel,
    required Random random,
    int maxScalingLevels = defaultMaxScalingLevels,
    void Function(String message)? onUnparseableScaling,
  }) {
    if (baseDiceFormula == null) return null;
    final base = _parseDice(baseDiceFormula);
    if (base == null) return null;

    final baseRoll = _rollDiceSum(base.count, base.sides, random) + base.flatBonus;

    var extraRoll = 0;
    var extraLevels = 0;
    if (isScalable && scalingFormula != null) {
      extraLevels = (selectedLevel - baseLevel).clamp(0, maxScalingLevels);
      if (extraLevels > 0) {
        final scale = _parseDice(scalingFormula);
        if (scale != null) {
          extraRoll = _rollDiceSum(scale.count * extraLevels, scale.sides, random) +
              scale.flatBonus * extraLevels;
        } else {
          onUnparseableScaling?.call(
            'scalingFormula "$scalingFormula" no parsea (ni dado ni plano). '
            'Escalado ignorado para esta tirada.',
          );
        }
      }
    }

    return SpellDamageResult(
      total: baseRoll + extraRoll,
      breakdown: extraLevels > 0 ? '$baseDiceFormula + $extraLevels × $scalingFormula' : baseDiceFormula,
    );
  }
}

/// Punto de entrada público: abre el modal de resolución de dados para
/// cualquier acción tirable (ataque de arma, conjuro o rasgo activo).
/// El modal solo recibe valores ya resueltos (modificador, dados de daño,
/// opciones de ranura) — no conoce Ability ni Weapon, así que sirve por
/// igual para cualquier origen.
Future<void> showResolutionModal({
  required BuildContext context,
  required Color accent,
  required String name,
  required int modifier,
  required String successDescription,
  required String failureDescription,
  bool isScalable = false,
  int baseLevel = 0,
  String? scalingFormula,
  String? damageDice,
  List<SpellSlotOption> spellSlotOptions = const [],
  ValueChanged<int>? onSlotConsumed,
  String? loreDescription,
  String? tacticalSummary,
  // Aviso "CD de Salvación": true si esta habilidad/hechizo es de tipo
  // 'save' (ability.isSavingThrowType) — quien llama hace la traducción,
  // igual que con isScalable/damageDice, para que el modal siga sin
  // conocer Ability ni Weapon directamente.
  bool isSavingThrow = false,
  // CD ya resuelta a mostrar cuando isSavingThrow es true (viene de
  // CharacterModel.basicInfo.spellSaveDc, ya calculada en la ficha/JSON:
  // 8 + competencia + mod. de la característica de lanzamiento). El modal
  // ya NO recalcula la CD a partir de `modifier` — ese cálculo asumía que
  // la característica de lanzamiento es siempre la misma que el
  // modificador de ataque/tirada de la habilidad, lo cual no es cierto en
  // general (multiclase, rasgos homebrew). Si viene null (ficha antigua
  // sin este campo, o personaje sin conjuros), se cae a "—" en vez de
  // inventar un número.
  int? saveDc,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: _ResolutionModalContent(
        accent: accent,
        name: name,
        modifier: modifier,
        successDescription: successDescription,
        failureDescription: failureDescription,
        isScalable: isScalable,
        baseLevel: baseLevel,
        scalingFormula: scalingFormula,
        damageDice: damageDice,
        spellSlotOptions: spellSlotOptions,
        onSlotConsumed: onSlotConsumed,
        loreDescription: loreDescription,
        tacticalSummary: tacticalSummary,
        isSavingThrow: isSavingThrow,
        saveDc: saveDc,
      ),
    ),
  );
}

class _ResolutionModalContent extends StatefulWidget {
  final Color accent;
  final String name;
  final int modifier;
  final String successDescription;
  final String failureDescription;
  final bool isScalable;
  final int baseLevel;
  final String? scalingFormula;
  final String? damageDice;
  final List<SpellSlotOption> spellSlotOptions;
  final ValueChanged<int>? onSlotConsumed;
  final String? loreDescription;
  final String? tacticalSummary;
  final bool isSavingThrow;
  final int? saveDc;

  const _ResolutionModalContent({
    required this.accent,
    required this.name,
    required this.modifier,
    required this.successDescription,
    required this.failureDescription,
    required this.isScalable,
    required this.baseLevel,
    required this.scalingFormula,
    required this.damageDice,
    required this.spellSlotOptions,
    required this.onSlotConsumed,
    required this.loreDescription,
    required this.tacticalSummary,
    required this.isSavingThrow,
    required this.saveDc,
  });

  @override
  State<_ResolutionModalContent> createState() => _ResolutionModalContentState();
}

class _ResolutionModalContentState extends State<_ResolutionModalContent> {
  _RollMode _mode = _RollMode.digital;
  _AdvantageMode _advantage = _AdvantageMode.normal;

  final TextEditingController _manualDie1 = TextEditingController();
  final TextEditingController _manualDie2 = TextEditingController();
  // Objetivo 3 — Fase de daño manual: el jugador introduce aquí el total
  // que ha sacado en la mesa con sus propios dados de daño físicos.
  final TextEditingController _manualDamage = TextEditingController();
  // Hotfix (Daño Manual Invisible): antes _onAplicarDano() cerraba el modal
  // en la misma pulsación en la que se leía _manualDamage.text — el
  // jugador escribía el número y el modal desaparecía sin mostrárselo, a
  // diferencia del modo digital que sí lo enseña en _damageBlock antes de
  // cerrar. Esta bandera separa "confirmar el número escrito" (primera
  // pulsación) de "cerrar ya viendo el resultado" (segunda pulsación).
  bool _manualDamageConfirmed = false;
  final Random _random = Random();

  late int _selectedLevel;

  // Objetivo 3: sustituye al antiguo booleano _showResult por una máquina
  // de tres estados (ver enum _Phase más arriba).
  _Phase _phase = _Phase.setup;

  int? _naturalDie;
  int? _rawDie1;
  int? _rawDie2;
  int? _damageTotal;
  String? _damageBreakdown;
  // Evita que reabrir la fase de ataque (si en el futuro se añadiera esa
  // opción) consuma una segunda ranura de conjuro para el mismo
  // lanzamiento: la ranura se gasta una única vez por sesión del modal.
  bool _slotConsumed = false;

  @override
  void initState() {
    super.initState();
    if (_usesSpellSlot && _eligibleOptions.isNotEmpty) {
      final firstAvailable = _eligibleOptions.where((o) => o.current > 0);
      _selectedLevel = firstAvailable.isNotEmpty ? firstAvailable.first.level : _eligibleOptions.first.level;
    } else {
      _selectedLevel = widget.baseLevel;
    }
  }

  @override
  void dispose() {
    _manualDie1.dispose();
    _manualDie2.dispose();
    _manualDamage.dispose();
    super.dispose();
  }

  bool get _needsTwoDice => _advantage != _AdvantageMode.normal;

  /// CD de Salvación: se muestra tal cual viene de la ficha
  /// (CharacterModel.basicInfo.spellSaveDc vía widget.saveDc), en vez de
  /// recalcularla como 8 + widget.modifier. Ese cálculo antiguo asumía que
  /// la característica de lanzamiento de conjuros era siempre la misma
  /// que la del modificador de la habilidad concreta que abrió el modal —
  /// rompía con multiclase o rasgos homebrew con característica distinta.
  /// Null (ficha sin este campo) se resuelve como '—' en _saveDcLabel.
  int? get _saveDC => widget.saveDc;

  String get _saveDcLabel => _saveDC != null ? '$_saveDC' : '—';

  /// Hotfix (Ranuras Fantasma): "¿este conjuro gasta una ranura al
  /// lanzarse?" NO es lo mismo que "¿se puede subir de nivel?"
  /// (widget.isScalable). Un truco (baseLevel 0) nunca gasta ranura,
  /// aunque sea escalable por nivel de personaje (ej. Rayo de Escarcha).
  /// Un conjuro de nivel 1+ SIEMPRE gasta ranura al lanzarse, aunque el
  /// homebrew le prohíba subirse de nivel (ej. Onda Atronadora en la
  /// ficha de Jiseol: "no se puede lanzar a nivel superior, pero sí
  /// consume 1 de los 4 usos"). isScalable solo decide si el jugador
  /// puede ELEGIR a qué nivel gastar esa ranura, o si va fija a baseLevel.
  bool get _usesSpellSlot => widget.baseLevel >= 1;

  List<SpellSlotOption> get _eligibleOptions {
    if (!_usesSpellSlot) return const [];
    final list = widget.isScalable
        // Escalable: cualquier ranura de baseLevel para arriba sirve.
        ? widget.spellSlotOptions.where((o) => o.level >= widget.baseLevel).toList()
        // No escalable: SOLO la ranura de su propio nivel fijo — no puede
        // gastar una de nivel superior aunque le sobren.
        : widget.spellSlotOptions.where((o) => o.level == widget.baseLevel).toList();
    list.sort((a, b) => a.level.compareTo(b.level));
    return list;
  }

  bool get _hasAnyAvailableSlot => _eligibleOptions.any((o) => o.current > 0);

  bool get _canRoll => !_usesSpellSlot || _hasAnyAvailableSlot;

  /// Objetivo 3: si la acción no tiene un damageDice parseable (p.ej.
  /// "Escudo", que es puro efecto sin dado de daño), el botón IMPACTO no
  /// tiene una Fase 2 a la que ir — simplemente confirma y cierra.
  bool get _hasDamage {
    final baseDice = widget.damageDice;
    if (baseDice == null) return false;
    return _parseDice(baseDice) != null;
  }

  void _computeDamage() {
    final result = SpellDamageResolver.resolve(
      baseDiceFormula: widget.damageDice,
      isScalable: widget.isScalable,
      baseLevel: widget.baseLevel,
      scalingFormula: widget.scalingFormula,
      selectedLevel: _selectedLevel,
      random: _random,
      // Blindaje: si esto se dispara, es que un JSON con scaling_formula
      // roto se coló pasando la validación de Ability.fromJson (o venía de
      // una ficha cacheada de antes del hotfix). Mejor un aviso feo en
      // consola que un hechizo que sube de nivel y no hace ni un punto de
      // daño extra sin que nadie se entere.
      onUnparseableScaling: (message) => debugPrint('[ResolutionModal] "${widget.name}": $message'),
    );

    _damageTotal = result?.total;
    _damageBreakdown = result?.breakdown;
  }

  /// El gasto de la ranura de conjuro ocurre al tirar (Fase de Ataque), no
  /// al resolver el daño: el recurso se consume al lanzar el hechizo,
  /// acierte o no.
  void _consumeSlotIfNeeded() {
    if (_usesSpellSlot && !_slotConsumed && widget.onSlotConsumed != null) {
      widget.onSlotConsumed!(_selectedLevel);
      _slotConsumed = true;
    }
  }

  // ---------------------------------------------------------------------
  // FASE 1 — ATAQUE: solo gestiona y muestra la tirada del D20.
  // ---------------------------------------------------------------------

  void _rollDigital() {
    if (!_canRoll) return;

    int naturalDie;
    int? d1;
    int? d2;

    if (!_needsTwoDice) {
      naturalDie = _random.nextInt(20) + 1;
      d1 = naturalDie;
    } else {
      final a = _random.nextInt(20) + 1;
      final b = _random.nextInt(20) + 1;
      naturalDie = _advantage == _AdvantageMode.advantage ? max(a, b) : min(a, b);
      d1 = a;
      d2 = b;
    }

    setState(() {
      _rawDie1 = d1;
      _rawDie2 = d2;
      _naturalDie = naturalDie;
      _consumeSlotIfNeeded();
      _phase = _Phase.attack;
    });
  }

  void _confirmManualAttack() {
    if (!_canRoll) return;

    final d1 = int.tryParse(_manualDie1.text);
    if (d1 == null || d1 < 1 || d1 > 20) return;

    if (!_needsTwoDice) {
      setState(() {
        _rawDie1 = d1;
        _rawDie2 = null;
        _naturalDie = d1;
        _consumeSlotIfNeeded();
        _phase = _Phase.attack;
      });
      return;
    }

    final d2 = int.tryParse(_manualDie2.text);
    if (d2 == null || d2 < 1 || d2 > 20) return;

    final chosen = _advantage == _AdvantageMode.advantage ? max(d1, d2) : min(d1, d2);
    setState(() {
      _rawDie1 = d1;
      _rawDie2 = d2;
      _naturalDie = chosen;
      _consumeSlotIfNeeded();
      _phase = _Phase.attack;
    });
  }

  // ---------------------------------------------------------------------
  // Transición FASE 1 -> FASE 2 / cierre
  // ---------------------------------------------------------------------

  /// [ FALLO ]: el ataque no impacta, no hay nada más que resolver.
  void _onFallo() {
    Navigator.of(context).pop();
  }

  /// [ IMPACTO ]: si hay daño que tirar, pasa a la Fase 2. Si la acción no
  /// inflige daño (p.ej. un hechizo de utilidad pura), simplemente
  /// confirma y cierra.
  void _onImpacto() {
    if (!_hasDamage) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      if (_mode == _RollMode.digital) {
        _computeDamage();
      }
      _phase = _Phase.damage;
    });
  }

  /// [ APLICAR DAÑO ]: en modo manual, vuelca lo que el jugador ha escrito
  /// a _damageTotal antes de cerrar (solo informativo, la aplicación real
  /// de daño a la vida del objetivo la hace el jugador/DM en mesa). En
  /// digital el daño ya se calculó al entrar a la Fase 2.
  /// [ OMITIR ]: válvula de escape de la Fase 2 — cierra el modal sin
  /// validar ni exigir ningún campo (ni el daño digital ya calculado ni
  /// el manual). Útil cuando el jugador solo quería confirmar el impacto
  /// y va a resolver el daño de otra forma (o directamente no aplica).
  void _onOmitirDano() {
    Navigator.of(context).pop();
  }

  void _onAplicarDano() {
    if (_mode == _RollMode.manual && !_manualDamageConfirmed) {
      final value = int.tryParse(_manualDamage.text);
      if (value == null) return;
      // Primera pulsación en manual: solo confirma y enseña el número —
      // NO cierra el modal todavía. El jugador necesita ver "esto es lo
      // que le hago" antes de que la ventana desaparezca.
      setState(() {
        _damageTotal = value;
        _damageBreakdown = null;
        _manualDamageConfirmed = true;
      });
      return;
    }
    // Digital (el número ya se veía desde que se entró a esta fase) o
    // segunda pulsación en manual (ya confirmado, ahora sí se cierra).
    Navigator.of(context).pop();
  }

  /// [ OBJETIVO FALLA ]: equivalente a IMPACTO pero sin tirada de d20 — el
  /// objetivo falló su salvación contra tu CD fija. Si el hechizo tiene
  /// daño, pasa a la Fase de Daño; si no, confirma y cierra. La ranura de
  /// conjuro se consume aquí (al lanzar), igual que al tirar un ataque.
  void _onObjetivoFalla() {
    _consumeSlotIfNeeded();
    _onImpacto();
  }

  /// [ OBJETIVO SUPERA ]: el objetivo superó su salvación. No hay daño que
  /// resolver — se confirma y cierra. La ranura se consume igual: el
  /// hechizo se lanzó, superara o no la salvación el objetivo.
  void _onObjetivoSupera() {
    _consumeSlotIfNeeded();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    Widget content;
    switch (_phase) {
      case _Phase.setup:
        content = _buildSetup(accent);
        break;
      case _Phase.attack:
        content = _buildAttackResult(accent);
        break;
      case _Phase.damage:
        content = _buildDamagePhase(accent);
        break;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withOpacity(0.06), AppColors.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.22), blurRadius: 30, spreadRadius: -4),
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      // Hotfix (Objetivo 1): el AlertDialog original sufría un Bottom
      // Overflow en pantallas pequeñas porque el contenido (sobre todo con
      // niveles de ranura, sabor y resumen táctico a la vez) podía superar
      // el alto disponible. Envolver el contenido en un
      // SingleChildScrollView permite que el usuario baje con el dedo en
      // vez de que el layout reviente.
      child: SingleChildScrollView(
        child: content,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // FASE DE CONFIGURACIÓN: nivel (si escala) + método + ventaja/desventaja
  // ---------------------------------------------------------------------
  Widget _buildSetup(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.name.toUpperCase(),
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.8,
            fontFamily: 'serif',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Modificador: ${widget.modifier >= 0 ? '+' : ''}${widget.modifier}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'serif'),
        ),
        if (widget.isSavingThrow) ...[
          const SizedBox(height: 10),
          _savingThrowBanner(accent),
        ],
        const SizedBox(height: 14),
        if (widget.loreDescription != null && widget.loreDescription!.isNotEmpty) ...[
          Text(
            widget.loreDescription!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              fontFamily: 'serif',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.tacticalSummary != null && widget.tacticalSummary!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withOpacity(0.4)),
            ),
            child: Text(
              widget.tacticalSummary!,
              style: TextStyle(
                color: accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'serif',
                height: 1.3,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (widget.isScalable && _usesSpellSlot) ...[
          _sectionLabel('NIVEL DE LANZAMIENTO'),
          const SizedBox(height: 8),
          if (_eligibleOptions.isEmpty || !_hasAnyAvailableSlot)
            _noSlotsWarning(accent)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _eligibleOptions.map((o) {
                return _LevelChip(
                  option: o,
                  selected: _selectedLevel == o.level,
                  accent: accent,
                  onTap: o.current > 0 ? () => setState(() => _selectedLevel = o.level) : null,
                );
              }).toList(),
            ),
          const SizedBox(height: 18),
        ] else if (_usesSpellSlot) ...[
          // Conjuro de nivel fijo (no escalable) que aun así gasta una
          // ranura propia — ej. Onda Atronadora, Estallar, Escudo en la
          // ficha homebrew de Jiseol. No hay nada que elegir (siempre es
          // baseLevel), pero sí hay que avisar si no queda ranura, porque
          // antes de este hotfix esta rama no existía y el conjuro se
          // lanzaba gratis y en silencio.
          _sectionLabel('RANURA DE CONJURO'),
          const SizedBox(height: 8),
          if (!_hasAnyAvailableSlot)
            _noSlotsWarning(accent)
          else
            _fixedSlotIndicator(accent),
          const SizedBox(height: 18),
        ],
        if (_canRoll) ...[
          if (widget.isSavingThrow) ...[
            _sectionLabel('MÉTODO (para el daño)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ToggleButton(
                    label: 'DIGITAL',
                    icon: Icons.casino,
                    selected: _mode == _RollMode.digital,
                    accent: accent,
                    onTap: () => setState(() => _mode = _RollMode.digital),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ToggleButton(
                    label: 'MANUAL',
                    icon: Icons.pin,
                    selected: _mode == _RollMode.manual,
                    accent: accent,
                    onTap: () => setState(() => _mode = _RollMode.manual),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildSavingThrowButtons(accent),
          ] else ...[
            _sectionLabel('MÉTODO'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ToggleButton(
                    label: 'DIGITAL',
                    icon: Icons.casino,
                    selected: _mode == _RollMode.digital,
                    accent: accent,
                    onTap: () => setState(() => _mode = _RollMode.digital),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ToggleButton(
                    label: 'MANUAL',
                    icon: Icons.pin,
                    selected: _mode == _RollMode.manual,
                    accent: accent,
                    onTap: () => setState(() => _mode = _RollMode.manual),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionLabel('TIRADA'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ToggleButton(
                    label: 'VENTAJA',
                    icon: Icons.arrow_upward,
                    selected: _advantage == _AdvantageMode.advantage,
                    accent: AppColors.success,
                    onTap: () => setState(() => _advantage = _AdvantageMode.advantage),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ToggleButton(
                    label: 'NORMAL',
                    icon: Icons.remove,
                    selected: _advantage == _AdvantageMode.normal,
                    accent: accent,
                    onTap: () => setState(() => _advantage = _AdvantageMode.normal),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ToggleButton(
                    label: 'DESVENT.',
                    icon: Icons.arrow_downward,
                    selected: _advantage == _AdvantageMode.disadvantage,
                    accent: AppColors.danger,
                    onTap: () => setState(() => _advantage = _AdvantageMode.disadvantage),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (_mode == _RollMode.digital) _buildDigitalAction(accent) else _buildManualAction(accent),
          ],
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }

  /// Banner de CD de Salvación: bien visible, pensado para leerse de un
  /// vistazo en mesa mientras se juega. Calcula CD = 8 + modificador (regla
  /// estándar de D&D 5e) a partir de widget.modifier, siempre que la
  /// habilidad/hechizo sea de tipo salvación (widget.isSavingThrow).
  Widget _savingThrowBanner(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.6), width: 1.2),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.35), blurRadius: 18, spreadRadius: -3),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield, color: accent, size: 20),
          const SizedBox(width: 10),
          Text(
            'CD de Salvación: $_saveDcLabel',
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              fontFamily: 'serif',
            ),
          ),
        ],
      ),
    );
  }

  /// Sustituye por completo al flujo de d20 (MÉTODO/TIRADA/RODAR DADO)
  /// cuando el hechizo es de salvación: aquí no tiras tú, tira el
  /// objetivo contra _saveDC (el spellSaveDc de la ficha) — así que el
  /// modal solo necesita preguntar el resultado narrado en mesa, no
  /// simular ninguna tirada.
  Widget _buildSavingThrowButtons(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('RESULTADO DE LA SALVACIÓN'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onObjetivoFalla,
                  icon: const Icon(Icons.close),
                  label: const Text('OBJETIVO FALLA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger.withOpacity(0.85),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4, fontSize: 12.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onObjetivoSupera,
                  icon: const Icon(Icons.check),
                  label: const Text('OBJETIVO SUPERA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success.withOpacity(0.85),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.4, fontSize: 12.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _noSlotsWarning(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withOpacity(0.35)),
      ),
      child: const Text(
        'No te quedan espacios de conjuro disponibles a ningún nivel válido.',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontFamily: 'serif'),
      ),
    );
  }

  /// Conjuro de nivel fijo (no escalable, widget.baseLevel siempre) que
  /// gasta una ranura propia. Aquí no hay nada que elegir — solo
  /// confirmar cuántas quedan de esa ranura exacta, para que quede claro
  /// que lanzarlo sí va a descontar una.
  Widget _fixedSlotIndicator(Color accent) {
    final option = _eligibleOptions.firstWhere(
      (o) => o.level == widget.baseLevel,
      orElse: () => SpellSlotOption(level: widget.baseLevel, current: 0, max: 0),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Ranura de Nivel ${widget.baseLevel}',
            style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'serif'),
          ),
          Text(
            '${option.current} / ${option.max} disponibles',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontFamily: 'serif'),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalAction(Color accent) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _rollDigital,
        icon: const Icon(Icons.casino),
        label: const Text('RODAR DADO'),
        style: ElevatedButton.styleFrom(
          backgroundColor: accent.withOpacity(0.85),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.6),
        ),
      ),
    );
  }

  /// Texto de la tirada de d20 en la mesa: "Tira 1d20" o "Tira 2d20" según
  /// ventaja/desventaja, con el modificador que hay que sumar al resultado
  /// final (no al dado en sí, para que quede claro que se suma después).
  String _physicalD20Hint() {
    final modText = '${widget.modifier >= 0 ? '+' : ''}${widget.modifier}';
    if (!_needsTwoDice) return 'Tira 1d20 · suma $modText al resultado';
    final pick = _advantage == _AdvantageMode.advantage ? 'usa el MAYOR' : 'usa el MENOR';
    return 'Tira 2d20 ($pick) · suma $modText al resultado';
  }

  /// Texto del dado de daño/efecto en la mesa, resuelto al nivel
  /// seleccionado. Null si la habilidad no tiene damageDice (p.ej. Escudo).
  String? _physicalDamageHint() {
    final baseDice = widget.damageDice;
    if (baseDice == null) return null;
    final base = _parseDice(baseDice);
    if (base == null) return null;

    var expression = baseDice;
    if (widget.isScalable && widget.scalingFormula != null) {
      final extraLevels = (_selectedLevel - widget.baseLevel).clamp(0, 999);
      if (extraLevels > 0) {
        final scale = _parseDice(widget.scalingFormula!);
        if (scale != null) {
          expression = '$expression + ${scale.count * extraLevels}d${scale.sides}';
        }
      }
    }
    return 'Daño: tira $expression';
  }

  Widget _physicalDiceHintBanner(Color accent) {
    final damageHint = _physicalDamageHint();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.3), blurRadius: 16, spreadRadius: -4),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.casino, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _physicalD20Hint(),
                  style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                if (damageHint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    damageHint,
                    style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualAction(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicador de Dados Físicos: solo existe dentro de esta rama
        // (modo MANUAL), así que en DIGITAL nunca se construye ni se
        // muestra. Ahora solo anuncia el d20 de la Fase 1 — el de daño se
        // muestra en su propio banner al entrar a la Fase 2.
        _physicalDiceHintBanner(accent),
        Row(
          children: [
            Expanded(
              child: _DieInput(
                controller: _manualDie1,
                label: _needsTwoDice ? 'Dado 1' : 'Dado',
                accent: accent,
              ),
            ),
            if (_needsTwoDice) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _DieInput(controller: _manualDie2, label: 'Dado 2', accent: accent),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirmManualAttack,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent.withOpacity(0.85),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.6),
            ),
            child: const Text('CONFIRMAR'),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // FASE 1 — RESULTADO DEL ATAQUE (solo D20; el daño vive en la Fase 2)
  // ---------------------------------------------------------------------
  Widget _buildAttackResult(Color accent) {
    final natural = _naturalDie!;
    final total = natural + widget.modifier;
    final isCrit = natural == 20;
    final isFumble = natural == 1;

    final Color highlightColor = isCrit
        ? const Color(0xFFE8C55A) // dorado
        : isFumble
            ? AppColors.danger
            : accent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.name.toUpperCase(),
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.8,
            fontFamily: 'serif',
          ),
        ),
        if (widget.isScalable) ...[
          const SizedBox(height: 2),
          Text(
            'Lanzado a nivel $_selectedLevel',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontFamily: 'serif'),
          ),
        ],
        const SizedBox(height: 6),
        if (_rawDie2 != null)
          Text(
            'Dados: $_rawDie1 y $_rawDie2 → se usa $natural (${_advantage == _AdvantageMode.advantage ? 'ventaja' : 'desventaja'})',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontFamily: 'serif'),
          )
        else
          Text(
            'Dado natural: $natural',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontFamily: 'serif'),
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          decoration: BoxDecoration(
            color: highlightColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: highlightColor.withOpacity(0.45), blurRadius: 28, spreadRadius: -2),
            ],
          ),
          child: Text(
            '$total',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 46,
              fontWeight: FontWeight.w700,
              color: highlightColor,
              letterSpacing: 2,
              shadows: [
                Shadow(color: highlightColor.withOpacity(0.7), blurRadius: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$natural natural ${widget.modifier >= 0 ? '+' : ''}${widget.modifier} mod',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontFamily: 'serif'),
        ),
        const SizedBox(height: 18),
        if (isCrit)
          _verdictBanner(
            label: '¡ÉXITO CRÍTICO!',
            color: highlightColor,
            description: widget.successDescription,
          )
        else if (isFumble)
          _verdictBanner(
            label: '¡PIFIA!',
            color: highlightColor,
            description: widget.failureDescription,
          )
        else
          _neutralDescriptions(accent),
        const SizedBox(height: 18),
        // Objetivo 3: en lugar del antiguo "Confirmar", el jugador declara
        // aquí si el ataque impacta o falla.
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _onFallo,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
                child: const Text('FALLO'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _onImpacto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent.withOpacity(0.85),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
                child: const Text('IMPACTO'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // FASE 2 — DAÑO: el D20 desaparece, solo queda resolver el daño/efecto.
  // ---------------------------------------------------------------------
  Widget _buildDamagePhase(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.name.toUpperCase(),
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.8,
            fontFamily: 'serif',
          ),
        ),
        if (widget.isScalable) ...[
          const SizedBox(height: 2),
          Text(
            'Lanzado a nivel $_selectedLevel',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontFamily: 'serif'),
          ),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: _sectionLabel('DAÑO / EFECTO'),
        ),
        const SizedBox(height: 8),
        if (_mode == _RollMode.digital || _manualDamageConfirmed)
          _damageBlock(accent)
        else
          _manualDamageInput(accent),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _onOmitirDano,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
                child: const Text('OMITIR'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _onAplicarDano,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent.withOpacity(0.85),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
                child: Text(
                  _mode == _RollMode.manual && !_manualDamageConfirmed ? 'VER DAÑO' : 'CERRAR',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Fase 2 en modo MANUAL: el jugador introduce el total de daño que ha
  /// sacado físicamente en la mesa (en vez de que la app lo calcule).
  Widget _manualDamageInput(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _physicalManualDamageHintBanner(accent),
        _DieInput(controller: _manualDamage, label: 'Daño total', accent: accent),
      ],
    );
  }

  /// Recordatorio de qué dados tirar en mesa para el daño, resuelto al
  /// nivel seleccionado. Solo se muestra en la Fase 2 manual.
  Widget _physicalManualDamageHintBanner(Color accent) {
    final damageHint = _physicalDamageHint() ?? 'Introduce el total de daño';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.3), blurRadius: 16, spreadRadius: -4),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.casino, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              damageHint,
              style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _damageBlock(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('DAÑO / EFECTO', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_damageTotal',
                style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              if (_damageBreakdown != null)
                Text(
                  _damageBreakdown!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontFamily: 'serif'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verdictBanner({required String label, required Color color, required String description}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.35), blurRadius: 24, spreadRadius: -4),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 1,
              fontFamily: 'serif',
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'serif', height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _neutralDescriptions(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.successDescription.isNotEmpty) ...[
          Text('SI TIENE ÉXITO', style: TextStyle(color: AppColors.success, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
          const SizedBox(height: 3),
          Text(
            widget.successDescription,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontFamily: 'serif', height: 1.3),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.failureDescription.isNotEmpty) ...[
          const Text('SI FALLA', style: TextStyle(color: AppColors.danger, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
          const SizedBox(height: 3),
          Text(
            widget.failureDescription,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontFamily: 'serif', height: 1.3),
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 1),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final SpellSlotOption option;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  const _LevelChip({required this.option, required this.selected, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final color = disabled ? AppColors.textSecondary : accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.18) : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? color.withOpacity(0.6) : Colors.white.withOpacity(0.06)),
              boxShadow: selected
                  ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: -3)]
                  : null,
            ),
            child: Text(
              'Nv.${option.level} (${option.current}/${option.max})',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.18) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? accent.withOpacity(0.6) : Colors.white.withOpacity(0.06)),
            boxShadow: selected
                ? [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 14, spreadRadius: -3)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? accent : AppColors.textSecondary),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: selected ? accent : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DieInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color accent;

  const _DieInput({required this.controller, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent),
        ),
      ),
    );
  }
}