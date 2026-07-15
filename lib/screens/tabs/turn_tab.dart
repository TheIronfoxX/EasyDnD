// lib/screens/tabs/turn_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ability_model.dart';
import '../../models/character_model.dart';
import '../../models/stats_model.dart';
import '../../models/weapon_model.dart';
import '../../providers/character_provider.dart';
import '../../theme/theme_notifier.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/themed_card.dart';
import '../../widgets/resolution_modal.dart';

/// Representa una entrada del despliegue táctico: puede venir de un arma
/// (ataque) o de una habilidad/conjuro. Es una clase de solo-UI, se
/// construye de nuevo en cada build a partir de los modelos reales.
/// Desde la Fase 5, las entradas "tappable" (todo menos las pasivas)
/// llevan además lo necesario para abrir el Protocolo de Dados. Desde la
/// Fase 6, las que son conjuros escalables llevan también los datos de
/// escalado — el resto de entradas (armas, rasgos, conjuros no escalables)
/// simplemente los dejan en sus valores por defecto.
class _TacticalEntry {
  final String name;
  final String subtitle;
  final IconData icon;
  final bool tappable;
  final int modifier;
  final String successDescription;
  final String failureDescription;
  final bool isScalable;
  final int baseLevel;
  final String? scalingFormula;
  final String? damageDice;
  final String? loreDescription;
  final String? tacticalSummary;
  // Fase 12 — Clasificación Táctica: solo lo llevan las pasivas, para que
  // el HUD las agrupe por rol ("Ofensivo", "Defensivo", "Utilidad"...).
  final String? tacticalRole;
  // Fase 8: solo relevante para habilidades con Ability.magicCharges
  // (has_charges == true). Las armas todavía no pintan su contador aquí
  // — igual que antes de la Fase 8, esa vista vive solo en InventoryTab —
  // así que hasCharges siempre llega en false para _weaponToEntry.
  final bool hasCharges;
  final int currentCharges;
  final int maxCharges;
  // Refactor "Caos Visual": naturaleza explícita de la entrada, para poder
  // agrupar Rasgos vs Conjuros en la sección táctica sin tener que parsear
  // el texto de subtitle (que es solo para mostrar, no para lógica).
  // Armas y pasivas quedan en false por defecto — nunca son conjuros.
  final bool isSpell;
  // Aviso "CD de Salvación": true si esta entrada viene de una Ability con
  // attackType == 'save' (Ability.isSavingThrowType). Armas y pasivas
  // quedan en false por defecto — las armas no tienen attackType propio y
  // las pasivas nunca abren el modal.
  final bool isSavingThrow;

  const _TacticalEntry({
    required this.name,
    required this.subtitle,
    required this.icon,
    this.tappable = false,
    this.modifier = 0,
    this.successDescription = '',
    this.failureDescription = '',
    this.isScalable = false,
    this.baseLevel = 0,
    this.scalingFormula,
    this.damageDice,
    this.loreDescription,
    this.tacticalSummary,
    this.tacticalRole,
    this.hasCharges = false,
    this.currentCharges = 0,
    this.maxCharges = 0,
    this.isSpell = false,
    this.isSavingThrow = false,
  });

  /// Fase 3 (Pasivas): si hay lore o resumen táctico que mostrar, la
  /// tarjeta se renderiza como ExpansionTile en vez de estática.
  bool get hasExpandableInfo =>
      (loreDescription != null && loreDescription!.trim().isNotEmpty) ||
      (tacticalSummary != null && tacticalSummary!.trim().isNotEmpty);
}

/// Traduce la clave de una stat ('str', 'dex'...) al modificador real del
/// personaje. Si una Ability trae una clave vacía o desconocida, el
/// modificador aplicado es 0 en vez de reventar.
int _modForStatKey(StatsBlock stats, String key) {
  switch (key) {
    case 'str':
      return stats.str.mod;
    case 'dex':
      return stats.dex.mod;
    case 'con':
      return stats.con.mod;
    case 'int':
      return stats.intelligence.mod;
    case 'wis':
      return stats.wis.mod;
    case 'cha':
      return stats.cha.mod;
    default:
      return 0;
  }
}

class TurnTab extends StatelessWidget {
  const TurnTab({super.key});

  @override
  Widget build(BuildContext context) {
    final character = context.watch<CharacterProvider>().character;
    final accent = context.watch<ThemeNotifier>().accentColor;
    final stats = character.stats;

    final abilities = character.abilitiesByAction;
    final weapons = character.inventory.weapons;

    // Fase 9: separamos armas y habilidades/conjuros en listas propias
    // (antes iban todas mezcladas en actionEntries) para poder pintar las
    // subcategorías "ARMAS" / "CONJUROS Y RASGOS" dentro de cada sección.
    final actionWeaponEntries = weapons.map((w) => _weaponToEntry(w)).toList();
    final actionAbilityEntries = abilities.action.map((a) => _abilityToEntry(a, stats)).toList();

    final bonusEntries = abilities.bonusAction.map((a) => _abilityToEntry(a, stats)).toList();
    final reactionEntries = abilities.reaction.map((a) => _abilityToEntry(a, stats)).toList();
    // Las pasivas nunca se tiran: no llevan modificador ni descripciones de
    // resultado, y sus tarjetas no son tappable. Al ser homogéneas (todo
    // Rasgos, nunca armas), no necesitan la subcategorización.
    final passiveEntries = abilities.passive.map(_passiveToEntry).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'DESPLIEGUE TÁCTICO',
          style: TextStyle(color: accent, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'serif'),
        ),
        const SizedBox(height: 4),
        Text(
          'Todo lo que puedes hacer con tu turno, de un vistazo.',
          style: TextStyle(color: context.appColors.textSecondary, fontSize: 12, fontFamily: 'serif'),
        ),
        const SizedBox(height: 16),
        // Action Economy Tracker: los tres recursos de acción del turno
        // en curso, arriba del todo — es lo primero que hace falta
        // consultar/marcar al empezar a resolver un turno.
        _TurnStatusSection(status: character.turnStatus, accent: accent),
        _SpellSlotsBar(slots: character.spellSlots.slots, accent: accent),
        // Paso 3 (Vertical Slice) — Sistema Genérico de Recursos: Puntos
        // de Ki, Hechicería, Furia por día, etc. Se pinta justo debajo de
        // las ranuras de magia, con el mismo lenguaje visual de sección.
        // No renderiza nada si el personaje no trae recursos definidos.
        _ResourcesSection(resources: character.resources, accent: accent),
        _TacticalSection(
          title: 'Acción Principal',
          weaponEntries: actionWeaponEntries,
          abilityEntries: actionAbilityEntries,
          accent: accent,
        ),
        _TacticalSection(title: 'Acción Adicional', abilityEntries: bonusEntries, accent: accent),
        _TacticalSection(title: 'Reacción', abilityEntries: reactionEntries, accent: accent),
        _PassivesSection(entries: passiveEntries, accent: accent),
        const SizedBox(height: 8),
        _EndTurnButton(accent: accent),
      ],
    );
  }

  _TacticalEntry _weaponToEntry(Weapon w) {
    return _TacticalEntry(
      name: w.name,
      subtitle: 'Arma · ${w.damage.baseDice} ${w.damage.baseType} · +${w.attackBonus} al ataque',
      icon: Icons.bolt,
      tappable: true,
      modifier: w.attackBonus,
      successDescription: w.successDescription,
      failureDescription: w.failureDescription,
      // Hotfix (Objetivo 2 — "bug del Mordisco"): antes esta entrada no
      // llevaba damageDice, así que el modal nunca veía el dado de daño
      // de las armas (solo el de los hechizos, que sí lo pasaban por
      // _abilityToEntry). w.damage.baseDice ya trae sus bonificadores
      // embebidos en la propia notación (ej. "2d6+8"), así que basta con
      // reenviarlo tal cual — _parseDice() en resolution_modal.dart ya
      // sabe leer ese "+8".
      damageDice: w.damage.baseDice,
    );
  }

  _TacticalEntry _abilityToEntry(Ability a, StatsBlock stats) {
    final origin = a.type == 'spell' ? 'Conjuro' : 'Rasgo';
    final icon = a.type == 'spell' ? Icons.auto_fix_high : Icons.shield_moon;
    final mod = _modForStatKey(stats, a.relatedStat);
    final scaleTag = a.isScalable ? ' · Escalable desde Nv.${a.baseLevel}' : '';
    return _TacticalEntry(
      name: a.name,
      subtitle: '$origin · ${mod >= 0 ? '+' : ''}$mod$scaleTag',
      icon: icon,
      tappable: true,
      modifier: mod,
      successDescription: a.successDescription,
      failureDescription: a.failureDescription,
      isScalable: a.isScalable,
      baseLevel: a.baseLevel,
      scalingFormula: a.scalingFormula,
      damageDice: a.damageDice,
      loreDescription: a.loreDescription,
      tacticalSummary: a.tacticalSummary,
      hasCharges: a.magicCharges.hasCharges,
      currentCharges: a.magicCharges.current,
      maxCharges: a.magicCharges.max,
      isSpell: a.type == 'spell',
      isSavingThrow: a.isSavingThrowType,
    );
  }

  /// Fase 3: las pasivas ahora también arrastran su lore/resumen táctico
  /// desde el modelo — antes se descartaban aquí y por eso la UI solo
  /// mostraba el nombre, aunque el JSON y el modelo ya traían los datos.
  _TacticalEntry _passiveToEntry(Ability a) {
    return _TacticalEntry(
      name: a.name,
      subtitle: 'Rasgo pasivo',
      icon: Icons.shield_moon,
      loreDescription: a.loreDescription,
      tacticalSummary: a.tacticalSummary,
      tacticalRole: a.tacticalRole,
    );
  }
}

/// Paso 3 (Vertical Slice) — Sistema Genérico de Recursos.
///
/// Sección de la pestaña de Turno para cualquier "pool" de puntos que no
/// sea una ranura de conjuro (Puntos de Ki, Puntos de Hechicería, Furia
/// por día, Inspiración Bárdica...). Mismo lenguaje visual de cabecera
/// que "RANURAS DE MAGIA" para que se lea como parte del mismo bloque de
/// recursos del turno. Si el personaje no trae recursos definidos, no
/// pinta nada (ni siquiera la cabecera).
class _ResourcesSection extends StatelessWidget {
  final List<ResourcePoint> resources;
  final Color accent;

  const _ResourcesSection({required this.resources, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            child: Text(
              'RECURSOS ACTIVOS',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                fontFamily: 'serif',
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...resources.map(
            (resource) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ResourceCard(resource: resource, accent: accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de un recurso individual: nombre, barra de progreso
/// current/max y botones +/- limpios para gastarlo o recuperarlo. Mismo
/// tratamiento visual de panel (ThemedCard) que el resto de la pestaña.
class _ResourceCard extends StatelessWidget {
  final ResourcePoint resource;
  final Color accent;

  const _ResourceCard({required this.resource, required this.accent});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CharacterProvider>();
    final depleted = resource.current <= 0;
    final full = resource.max > 0 && resource.current >= resource.max;
    final progress = resource.max > 0 ? resource.current / resource.max : 0.0;

    return ThemedCard(
      accentColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.hexagon_outlined, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        resource.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'serif',
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${resource.current}/${resource.max}',
                      style: TextStyle(
                        color: depleted ? context.appColors.textSecondary : accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      depleted ? context.appColors.textSecondary.withOpacity(0.4) : accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ResourceStepButton(
            icon: Icons.remove_rounded,
            enabled: !depleted,
            accent: accent,
            onPressed: () => provider.decrementResource(resource.name),
          ),
          const SizedBox(width: 6),
          _ResourceStepButton(
            icon: Icons.add_rounded,
            enabled: !full,
            accent: accent,
            onPressed: () => provider.incrementResource(resource.name),
          ),
        ],
      ),
    );
  }
}

/// Botón circular compacto para +/- de un recurso. Se atenúa (sin
/// interacción) cuando la acción no tiene efecto — gastar a 0 o recargar
/// a tope — para que el estado límite se lea de un vistazo.
class _ResourceStepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color accent;
  final VoidCallback onPressed;

  const _ResourceStepButton({
    required this.icon,
    required this.enabled,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? accent : context.appColors.textSecondary.withOpacity(0.3);
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

/// Action Economy Tracker.
///
/// Cabecera con los tres recursos de acción del turno en curso (Acción,
/// Adicional, Reacción) como selectores táctiles: tocar un chip invierte
/// su estado usado/disponible. Mismo lenguaje visual de sección que
/// "RANURAS DE MAGIA" / "RECURSOS ACTIVOS" para leerse como parte del
/// mismo bloque.
class _TurnStatusSection extends StatelessWidget {
  final TurnStatus status;
  final Color accent;

  const _TurnStatusSection({required this.status, required this.accent});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CharacterProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            child: Text(
              'ECONOMÍA DE TURNO',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                fontFamily: 'serif',
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionToggleTile(
                  label: 'ACCIÓN',
                  icon: Icons.flash_on,
                  used: status.actionUsed,
                  accent: accent,
                  onTap: () => provider.toggleAction('action'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionToggleTile(
                  label: 'ADICIONAL',
                  icon: Icons.bolt,
                  used: status.bonusActionUsed,
                  accent: accent,
                  onTap: () => provider.toggleAction('bonus'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionToggleTile(
                  label: 'REACCIÓN',
                  icon: Icons.shield,
                  used: status.reactionUsed,
                  accent: accent,
                  onTap: () => provider.toggleAction('reaction'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Selector táctil de un único recurso de turno. Estado "disponible": el
/// icono y el borde se pintan con el color de acento, a tope de opacidad
/// (igual que un pip de ranura de conjuro lleno). Estado "usado": todo se
/// atenúa a gris y el icono cambia a un check, para que el vistazo rápido
/// del jugador distinga disponible/gastado sin tener que leer el texto.
class _ActionToggleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool used;
  final Color accent;
  final VoidCallback onTap;

  const _ActionToggleTile({
    required this.label,
    required this.icon,
    required this.used,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = used ? context.appColors.textSecondary : accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ThemedCard(
          accentColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                used ? Icons.check_circle_outline : icon,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 3),
              Text(
                used ? 'Gastada' : 'Libre',
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'serif',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón "Fin de Turno": llama a resetTurn() para liberar los tres
/// recursos de acción de golpe. Vive al final del despliegue táctico,
/// separado del resto por su propio espaciado, para que no se confunda
/// con una tarjeta de acción más.
class _EndTurnButton extends StatelessWidget {
  final Color accent;

  const _EndTurnButton({required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.read<CharacterProvider>().resetTurn(),
        icon: const Icon(Icons.replay_rounded, size: 18),
        label: const Text(
          'FIN DE TURNO',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontFamily: 'serif'),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: accent.withOpacity(0.18),
          foregroundColor: accent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: accent.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }
}

class _TacticalSection extends StatelessWidget {
  final String title;
  final List<_TacticalEntry> weaponEntries;
  final List<_TacticalEntry> abilityEntries;
  final Color accent;
  // Fase 9: si es false (caso de las Pasivas), se renderiza como lista
  // plana sin subtítulos "ARMAS" / "CONJUROS Y RASGOS".
  final bool useSubcategories;

  const _TacticalSection({
    required this.title,
    this.weaponEntries = const [],
    this.abilityEntries = const [],
    required this.accent,
    this.useSubcategories = true,
  });

  @override
  Widget build(BuildContext context) {
    if (weaponEntries.isEmpty && abilityEntries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera llamativa con el color de acento, como el encabezado
          // de una sección en un mapa de batalla.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                fontFamily: 'serif',
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (useSubcategories) ...[
            if (weaponEntries.isNotEmpty) ..._buildGroup(context, 'ARMAS', weaponEntries),
            // Refactor "Caos Visual": en vez de un único bloque plano
            // 'CONJUROS Y RASGOS', separamos por naturaleza (Rasgo vs
            // Conjuro) y, dentro de los conjuros, por baseLevel (Trucos,
            // Nivel 1, Nivel 2...). Cada subgrupo se pinta solo si tiene
            // elementos — las categorías vacías no dejan ni rastro (ni
            // siquiera su cabecera).
            if (abilityEntries.isNotEmpty) ..._buildAbilityGroups(context, abilityEntries),
          ] else
            ...[...weaponEntries, ...abilityEntries].map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TacticalCard(entry: entry, accent: accent),
              ),
            ),
        ],
      ),
    );
  }

  /// Separa las entradas de habilidad en Rasgos y Conjuros, y agrupa
  /// estos últimos por su baseLevel (0 = Trucos, 1 = Nivel 1, ...).
  /// Devuelve los grupos ya renderizados, en orden: Trucos, Nivel 1,
  /// Nivel 2, ... y por último Rasgos y Habilidades. Cualquier grupo sin
  /// elementos simplemente no aparece en la lista resultante.
  List<Widget> _buildAbilityGroups(BuildContext context, List<_TacticalEntry> entries) {
    final spellsByLevel = <int, List<_TacticalEntry>>{};
    final traits = <_TacticalEntry>[];

    for (final entry in entries) {
      if (entry.isSpell) {
        spellsByLevel.putIfAbsent(entry.baseLevel, () => []).add(entry);
      } else {
        traits.add(entry);
      }
    }

    final sortedLevels = spellsByLevel.keys.toList()..sort();
    final widgets = <Widget>[];

    for (final level in sortedLevels) {
      final label = level == 0 ? 'Trucos' : 'Conjuros Nivel $level';
      widgets.addAll(_buildGroup(context, label, spellsByLevel[level]!));
    }

    if (traits.isNotEmpty) {
      widgets.addAll(_buildGroup(context, 'Rasgos y Habilidades', traits));
    }

    return widgets;
  }

  /// Subtítulo tipo etiqueta ("ARMAS" / "Trucos" / "Rasgos y
  /// Habilidades"...) + sus tarjetas. El diseño de _TacticalCard queda
  /// intacto; solo se añade esta cabecera secundaria más discreta que la
  /// de la sección, ahora derivada de Theme.of(context) en vez de un
  /// TextStyle suelto.
  List<Widget> _buildGroup(BuildContext context, String label, List<_TacticalEntry> entries) {
    final baseStyle = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    final headerStyle = baseStyle.copyWith(
      color: accent.withOpacity(0.7),
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
      fontFamily: 'serif',
      fontSize: 11,
    );

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(label.toUpperCase(), style: headerStyle),
      ),
      ...entries.map(
        (entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TacticalCard(entry: entry, accent: accent),
        ),
      ),
      const SizedBox(height: 6),
    ];
  }
}

/// Fase 12 — Clasificación Táctica de Pasivas: en vez de una lista plana,
/// agrupa las tarjetas de pasivas por su Ability.tacticalRole (Ofensivo,
/// Defensivo, Utilidad...). Mismo lenguaje visual que _TacticalSection:
/// cabecera de sección grande con el color de acento, y sub-cabeceras de
/// grupo derivadas de Theme.of(context).textTheme.labelLarge (mismo
/// patrón que _TacticalSection._buildGroup). El diseño interno de cada
/// tarjeta (_TacticalCard) no se toca.
///
/// Categorías conocidas primero, en orden fijo; cualquier otro valor que
/// traiga el JSON aparece después, en el orden en que se encuentra; las
/// pasivas sin tacticalRole (fichas antiguas u homebrew sin clasificar)
/// caen en "Otros" al final. Un grupo sin elementos no pinta ni su
/// cabecera — y si no hay pasivas en absoluto, la sección entera
/// desaparece, igual que el resto de secciones de esta pantalla.
class _PassivesSection extends StatelessWidget {
  final List<_TacticalEntry> entries;
  final Color accent;

  const _PassivesSection({required this.entries, required this.accent});

  static const List<String> _knownRoleOrder = ['Ofensivo', 'Defensivo', 'Utilidad'];
  static const String _fallbackRoleLabel = 'Otros';

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final grouped = <String, List<_TacticalEntry>>{};
    for (final entry in entries) {
      final role = (entry.tacticalRole == null || entry.tacticalRole!.trim().isEmpty)
          ? _fallbackRoleLabel
          : entry.tacticalRole!;
      grouped.putIfAbsent(role, () => []).add(entry);
    }

    // Orden: categorías conocidas (si están presentes) -> cualquier otra
    // categoría no reconocida, en el orden en que apareció -> "Otros" al
    // final, si hay alguna pasiva sin clasificar.
    final orderedLabels = <String>[
      ..._knownRoleOrder.where(grouped.containsKey),
      ...grouped.keys.where((k) => !_knownRoleOrder.contains(k) && k != _fallbackRoleLabel),
      if (grouped.containsKey(_fallbackRoleLabel)) _fallbackRoleLabel,
    ];

    final baseStyle = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    final groupHeaderStyle = baseStyle.copyWith(
      color: accent.withOpacity(0.7),
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
      fontFamily: 'serif',
      fontSize: 11,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            child: Text(
              'PASIVAS (SIEMPRE ACTIVAS)',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                fontFamily: 'serif',
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final label in orderedLabels) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2),
              child: Text(label.toUpperCase(), style: groupHeaderStyle),
            ),
            ...grouped[label]!.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TacticalCard(entry: entry, accent: accent),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _TacticalCard extends StatelessWidget {
  final _TacticalEntry entry;
  final Color accent;

  const _TacticalCard({required this.entry, required this.accent});

  Widget _buildHeaderRow(BuildContext context) {
    return Row(
      children: [
        Icon(entry.icon, color: accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                style: TextStyle(
                  color: context.appColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'serif',
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.subtitle,
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'serif',
                ),
              ),
            ],
          ),
        ),
        if (entry.hasCharges) ...[
          _ChargeBadge(current: entry.currentCharges, max: entry.maxCharges, accent: accent),
          const SizedBox(width: 8),
        ],
        if (entry.tappable)
          Icon(Icons.casino_outlined, color: accent.withOpacity(0.6), size: 18),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fase 3 — Pasivas con descripción: en vez de una tarjeta estática con
    // solo el nombre, si hay lore_description y/o tactical_summary se
    // despliega un ExpansionTile al tocar. Solo aplica a entradas NO
    // tappable (las pasivas nunca abren el Protocolo de Dados).
    if (!entry.tappable && entry.hasExpandableInfo) {
      return ThemedCard(
        accentColor: accent,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: accent,
                ),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            iconColor: accent,
            collapsedIconColor: accent.withOpacity(0.6),
            title: Row(
              children: [
                Icon(entry.icon, color: accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: TextStyle(
                          color: context.appColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'serif',
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.subtitle,
                        style: TextStyle(
                          color: context.appColors.textSecondary,
                          fontSize: 12,
                          fontFamily: 'serif',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: [
              if (entry.loreDescription != null && entry.loreDescription!.trim().isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    entry.loreDescription!,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'serif',
                    ),
                  ),
                ),
              ],
              if (entry.tacticalSummary != null && entry.tacticalSummary!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    entry.tacticalSummary!,
                    style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontSize: 12.5,
                      fontFamily: 'serif',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final content = _buildHeaderRow(context);

    if (!entry.tappable) {
      return ThemedCard(
        accentColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: content,
      );
    }

    // Envolvemos el contenido en Material+InkWell para que el ripple del
    // tap respete el mismo radio de esquina que ThemedCard (12), sin tener
    // que tocar ThemedCard en sí.
    return ThemedCard(
      accentColor: accent,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final provider = context.read<CharacterProvider>();
            // Hotfix (Ranuras Fantasma): antes esto miraba entry.isScalable
            // para decidir si había que rastrear/consumir una ranura de
            // conjuro. isScalable solo dice "¿se puede lanzar a un nivel
            // superior?" — un conjuro homebrew con base_level >= 1 e
            // is_scalable=false (ej. Onda Atronadora, Estallar, Escudo en
            // la ficha de Jiseol: "no se puede lanzar a nivel superior,
            // pero sí consume 1 de los 4 usos") caía por la rendija: nunca
            // se le pasaban spellSlotOptions ni onSlotConsumed, así que se
            // lanzaba gratis. Lo correcto es: cualquier conjuro con
            // base_level >= 1 (no es un truco) gasta ranura, sea o no
            // escalable; isScalable solo decide si el jugador puede ELEGIR
            // a qué nivel gastarla.
            final usesSpellSlot = entry.baseLevel >= 1;
            final spellSlotOptions = usesSpellSlot
                ? provider.character.spellSlots.slots
                    .map((s) => SpellSlotOption(level: s.level, current: s.current, max: s.max))
                    .toList()
                : const <SpellSlotOption>[];

            showResolutionModal(
              context: context,
              accent: accent,
              name: entry.name,
              modifier: entry.modifier,
              successDescription: entry.successDescription,
              failureDescription: entry.failureDescription,
              isScalable: entry.isScalable,
              baseLevel: entry.baseLevel,
              scalingFormula: entry.scalingFormula,
              damageDice: entry.damageDice,
              spellSlotOptions: spellSlotOptions,
              onSlotConsumed: usesSpellSlot ? (level) => provider.consumeSpellSlot(level) : null,
              loreDescription: entry.loreDescription,
              tacticalSummary: entry.tacticalSummary,
              isSavingThrow: entry.isSavingThrow,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Fase 8: contador compacto "[actual/máximo]" para habilidades con
/// cargas propias (ej. un conjuro de objeto mágico con 3 usos al día).
/// Mismo lenguaje visual que el badge de bonificador de ataque en
/// InventoryTab (fondo al 15% del acento, texto en negrita), pero en
/// formato corchete para diferenciarlo de un modificador.
class _ChargeBadge extends StatelessWidget {
  final int current;
  final int max;
  final Color accent;

  const _ChargeBadge({required this.current, required this.max, required this.accent});

  @override
  Widget build(BuildContext context) {
    final depleted = current <= 0;
    final color = depleted ? context.appColors.textSecondary : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '[$current/$max]',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// Fase 11 — Ranuras de Magia: barra horizontal scrollable, una tarjeta
/// por nivel de conjuro que el personaje tiene. Cada tarjeta dibuja sus
/// ranuras como "pips" circulares — llenos y con glow si están
/// disponibles, apagados si ya se gastaron. Tocar un pip lleno gasta esa
/// ranura (spendSpellSlot); los agotados no son tappable.
class _SpellSlotsBar extends StatelessWidget {
  final List<SpellSlot> slots;
  final Color accent;

  const _SpellSlotsBar({required this.slots, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox.shrink();
    final sorted = [...slots]..sort((a, b) => a.level.compareTo(b.level));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            child: Text(
              'RANURAS DE MAGIA',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                fontFamily: 'serif',
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Hotfix (Objetivo 1): el SizedBox(height: 88) fijo + scroll
          // horizontal podía desbordar verticalmente si un nivel tenía
          // muchas ranuras y su Wrap interno de pips saltaba a 3+ filas.
          // Un único Wrap para las tarjetas de nivel, sin alto fijo, se
          // adapta solo (fila nueva si no caben) y no puede desbordar.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: sorted.map((slot) => _SpellSlotLevelCard(slot: slot, accent: accent)).toList(),
          ),
        ],
      ),
    );
  }
}

class _SpellSlotLevelCard extends StatelessWidget {
  final SpellSlot slot;
  final Color accent;

  const _SpellSlotLevelCard({required this.slot, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: ThemedCard(
        accentColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nv. ${slot.level}',
              style: TextStyle(color: context.appColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'serif'),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: List.generate(slot.max, (i) {
                final filled = i < slot.current;
                return _SlotPip(
                  filled: filled,
                  accent: accent,
                  onTap: filled ? () => context.read<CharacterProvider>().spendSpellSlot(slot.level) : null,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotPip extends StatelessWidget {
  final bool filled;
  final Color accent;
  final VoidCallback? onTap;

  const _SlotPip({required this.filled, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? accent.withOpacity(0.85) : Colors.white.withOpacity(0.06),
            border: Border.all(color: filled ? accent : context.appColors.border, width: 1),
            boxShadow: filled
                ? [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 8, spreadRadius: -1)]
                : null,
          ),
        ),
      ),
    );
  }
}