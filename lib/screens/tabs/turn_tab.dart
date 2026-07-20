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
  // Borrado de habilidades: id estable de la Ability de origen (Ability.id).
  // Las entradas que vienen de un arma (_weaponToEntry) lo dejan en null a
  // propósito — borrar armas no entra en el alcance de esta función, y un
  // id null es justo la señal que usa _TacticalCard para no pintar el
  // icono de papelera en esas tarjetas.
  final String? id;
  // Edición: la Ability original completa y la categoría a la que
  // pertenece ('action'/'bonusAction'/'reaction'/'passive'). Solo se
  // rellenan en entradas que vienen de una Ability (no de un arma) — es
  // lo que necesita el formulario de edición para precargar todos sus
  // campos sin tener que reconstruirlos a mano desde _TacticalEntry.
  final Ability? sourceAbility;
  final String? categoryKey;

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
    this.id,
    this.sourceAbility,
    this.categoryKey,
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
/// Réplica local de la validación de scaling_formula que ya hace
/// Ability.fromJson() (_looksLikeValidDiceOrFlat en ability_model.dart).
/// No se puede importar de allí porque es privada a ese archivo (el guion
/// bajo la limita a su propia librería), así que se duplica aquí a
/// propósito — igual que el propio ability_model.dart ya avisa que hace
/// con resolution_modal.dart. Debe mantenerse en sincronía con las tres
/// copias si el formato de escalado cambia algún día.
///
/// Acepta dado con o sin bono plano ("1d6", "2d4+3", "8d6-2") o un plano
/// puro sin dado ("+3", "-1", "4").
bool _looksLikeValidScalingFormula(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  final diceMatch = RegExp(r'^\d+d\d+\s*([+-]\s*\d+)?$').hasMatch(trimmed);
  final flatMatch = RegExp(r'^[+-]?\s*\d+$').hasMatch(trimmed);
  return diceMatch || flatMatch;
}

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
    final actionAbilityEntries = abilities.action.map((a) => _abilityToEntry(a, stats, 'action')).toList();

    final bonusEntries = abilities.bonusAction.map((a) => _abilityToEntry(a, stats, 'bonusAction')).toList();
    final reactionEntries = abilities.reaction.map((a) => _abilityToEntry(a, stats, 'reaction')).toList();
    // Las pasivas nunca se tiran: no llevan modificador ni descripciones de
    // resultado, y sus tarjetas no son tappable. Al ser homogéneas (todo
    // Rasgos, nunca armas), no necesitan la subcategorización.
    final passiveEntries = abilities.passive.map(_passiveToEntry).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                ],
              ),
            ),
            // Alta de habilidades: abre un formulario simple (nombre +
            // descripción + categoría) en un modal. El alta en sí vive en
            // CharacterProvider.addAbility(), aquí solo se recogen los datos.
            _AddAbilityButton(accent: accent),
          ],
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

  _TacticalEntry _abilityToEntry(Ability a, StatsBlock stats, String categoryKey) {
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
      id: a.id,
      sourceAbility: a,
      categoryKey: categoryKey,
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
      id: a.id,
      sourceAbility: a,
      categoryKey: 'passive',
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
        if (entry.sourceAbility != null && entry.categoryKey != null) ...[
          _AbilityOptionsMenu(ability: entry.sourceAbility!, categoryKey: entry.categoryKey!),
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
                if (entry.sourceAbility != null && entry.categoryKey != null)
                  _AbilityOptionsMenu(ability: entry.sourceAbility!, categoryKey: entry.categoryKey!),
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

/// Botón compacto de la cabecera que abre el formulario de alta de
/// habilidades en un modal inferior. Vive junto al título "DESPLIEGUE
/// TÁCTICO" para que el alta esté a mano sin añadir una pantalla nueva.
class _AddAbilityButton extends StatelessWidget {
  final Color accent;

  const _AddAbilityButton({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddAbilitySheet(),
        ),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.15),
            border: Border.all(color: accent.withOpacity(0.5), width: 1),
          ),
          child: Icon(Icons.add, color: accent, size: 18),
        ),
      ),
    );
  }
}

/// Formulario de alta de habilidades: nombre, descripción y categoría
/// siempre visibles; el resto de campos de Ability (stat asociada, tipo
/// de tirada, dado de daño, escalado, cargas, rol táctico) viven dentro
/// de un ExpansionTile "Avanzado" colapsado por defecto, para que el
/// alta rápida siga siendo rápida y el detalle mecánico esté ahí solo
/// para quien lo necesite. Al confirmar llama a
/// CharacterProvider.addAbility() — la lista reactiva
/// (abilitiesByAction) se repinta sola gracias a notifyListeners().
class _AddAbilitySheet extends StatefulWidget {
  final Ability? existingAbility;
  final String? existingCategory;

  const _AddAbilitySheet({this.existingAbility, this.existingCategory});

  @override
  State<_AddAbilitySheet> createState() => _AddAbilitySheetState();
}

class _AddAbilitySheetState extends State<_AddAbilitySheet> {
  static const List<(String key, String label)> _categories = [
    ('action', 'Acción'),
    ('bonusAction', 'Acción Adicional'),
    ('reaction', 'Reacción'),
    ('passive', 'Pasiva'),
  ];

  static const List<(String key, String label)> _types = [
    ('trait', 'Rasgo'),
    ('spell', 'Conjuro'),
  ];

  static const List<(String key, String label)> _relatedStats = [
    ('', 'Ninguna'),
    ('str', 'Fuerza'),
    ('dex', 'Destreza'),
    ('con', 'Constitución'),
    ('int', 'Inteligencia'),
    ('wis', 'Sabiduría'),
    ('cha', 'Carisma'),
  ];

  static const List<(String key, String label)> _attackTypes = [
    ('attack', 'Ataque (tira para impactar)'),
    ('save', 'Salvación (el objetivo tira CD)'),
    ('none', 'Ninguna (sin tirada enfrentada)'),
  ];

  static const List<(String key, String label)> _tacticalRoles = [
    ('', 'Sin clasificar'),
    ('Ofensivo', 'Ofensivo'),
    ('Defensivo', 'Defensivo'),
    ('Utilidad', 'Utilidad'),
  ];

  // -- Básico --
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = _categories.first.$1;

  // -- Avanzado --
  String _selectedType = _types.first.$1; // 'trait' | 'spell'
  String _selectedRelatedStat = ''; // '' | 'str' | 'dex' | ...
  String _selectedAttackType = _attackTypes.first.$1; // 'attack' | 'save' | 'none'
  final _damageDiceController = TextEditingController();
  final _tacticalSummaryController = TextEditingController();
  String _selectedTacticalRole = '';
  bool _isScalable = false;
  final _baseLevelController = TextEditingController(text: '0');
  final _scalingFormulaController = TextEditingController();
  bool _hasCharges = false;
  final _maxChargesController = TextEditingController(text: '1');
  // Controlado a mano (en vez de ExpansionTile.initiallyExpanded, que solo
  // se lee una vez) para poder forzar la apertura del bloque si el envío
  // falla por un error de validación ahí dentro (ej. fórmula de escalado
  // mal escrita) mientras el usuario lo tenía colapsado.
  bool _advancedExpanded = false;

  bool get _isPassive => _selectedCategory == 'passive';
  bool get _isEditing => widget.existingAbility != null;

  @override
  void initState() {
    super.initState();
    final ability = widget.existingAbility;
    if (ability == null) return;

    // Modo edición: precargamos todo desde la Ability existente. Los
    // campos que el formulario no expone en modo alta (successDescription/
    // failureDescription) no se tocan aquí — updateAbility() los conserva
    // tal cual estaban.
    _nameController.text = ability.name;
    _descriptionController.text = ability.loreDescription ?? '';
    _selectedCategory = widget.existingCategory ?? 'action';
    _selectedType = ability.type == 'spell' ? 'spell' : 'trait';
    _selectedRelatedStat = ability.relatedStat;
    _selectedAttackType = ability.attackType;
    _damageDiceController.text = ability.damageDice ?? '';
    _tacticalSummaryController.text = ability.tacticalSummary ?? '';
    _selectedTacticalRole = ability.tacticalRole ?? '';
    _isScalable = ability.isScalable;
    _baseLevelController.text = ability.baseLevel.toString();
    _scalingFormulaController.text = ability.scalingFormula ?? '';
    _hasCharges = ability.magicCharges.hasCharges;
    _maxChargesController.text =
        ability.magicCharges.hasCharges ? ability.magicCharges.max.toString() : '1';
    // Si hay algún dato avanzado relevante ya cargado, abrimos el bloque
    // directamente para que se vea de un vistazo qué se está editando, en
    // vez de que parezca que se ha perdido información.
    _advancedExpanded = _selectedType == 'spell' ||
        _selectedRelatedStat.isNotEmpty ||
        _selectedAttackType != 'attack' ||
        (ability.damageDice != null && ability.damageDice!.trim().isNotEmpty) ||
        _isScalable ||
        _hasCharges ||
        (ability.tacticalSummary != null && ability.tacticalSummary!.trim().isNotEmpty) ||
        _selectedTacticalRole.isNotEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _damageDiceController.dispose();
    _tacticalSummaryController.dispose();
    _baseLevelController.dispose();
    _scalingFormulaController.dispose();
    _maxChargesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      // Si el error viene de dentro del bloque avanzado (ej. fórmula de
      // escalado inválida) y el usuario lo tenía colapsado, lo abrimos
      // para que vea qué falló en vez de que el botón simplemente no
      // reaccione sin explicación.
      if (!_advancedExpanded) setState(() => _advancedExpanded = true);
      return;
    }

    final provider = context.read<CharacterProvider>();

    if (_isEditing) {
      provider.updateAbility(
        abilityId: widget.existingAbility!.id,
        actionType: _selectedCategory,
        name: _nameController.text,
        description: _descriptionController.text,
        type: _isPassive ? null : _selectedType,
        relatedStat: _isPassive ? '' : _selectedRelatedStat,
        attackType: _isPassive ? 'none' : _selectedAttackType,
        damageDice: _isPassive ? null : _damageDiceController.text,
        tacticalSummary: _tacticalSummaryController.text,
        tacticalRole: _isPassive ? _selectedTacticalRole : null,
        isScalable: !_isPassive && _isScalable,
        baseLevel: (!_isPassive && _isScalable) ? (int.tryParse(_baseLevelController.text) ?? 0) : 0,
        scalingFormula: (!_isPassive && _isScalable) ? _scalingFormulaController.text : null,
        hasCharges: _hasCharges,
        maxCharges: _hasCharges ? (int.tryParse(_maxChargesController.text) ?? 1) : 0,
      );
    } else {
      provider.addAbility(
        actionType: _selectedCategory,
        name: _nameController.text,
        description: _descriptionController.text,
        type: _isPassive ? null : _selectedType,
        relatedStat: _isPassive ? '' : _selectedRelatedStat,
        attackType: _isPassive ? 'none' : _selectedAttackType,
        damageDice: _isPassive ? null : _damageDiceController.text,
        tacticalSummary: _tacticalSummaryController.text,
        tacticalRole: _isPassive ? _selectedTacticalRole : null,
        isScalable: !_isPassive && _isScalable,
        baseLevel: (!_isPassive && _isScalable) ? (int.tryParse(_baseLevelController.text) ?? 0) : 0,
        scalingFormula: (!_isPassive && _isScalable) ? _scalingFormulaController.text : null,
        hasCharges: _hasCharges,
        maxCharges: _hasCharges ? (int.tryParse(_maxChargesController.text) ?? 1) : 0,
      );
    }

    Navigator.of(context).pop();
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<(String key, String label)> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        for (final option in options) DropdownMenuItem(value: option.$1, child: Text(option.$2)),
      ],
      onChanged: (newValue) {
        if (newValue == null) return;
        onChanged(newValue);
      },
    );
  }

  /// Campos que solo tienen sentido para acción/adicional/reacción — una
  /// pasiva nunca se tira, así que stat/ataque/daño/escalado no aplican.
  List<Widget> _buildTappableAdvancedFields() {
    return [
      _buildDropdown(
        label: 'Tipo',
        value: _selectedType,
        options: _types,
        onChanged: (v) => setState(() => _selectedType = v),
      ),
      const SizedBox(height: 12),
      _buildDropdown(
        label: 'Stat asociada',
        value: _selectedRelatedStat,
        options: _relatedStats,
        onChanged: (v) => setState(() => _selectedRelatedStat = v),
      ),
      const SizedBox(height: 12),
      _buildDropdown(
        label: 'Tipo de tirada',
        value: _selectedAttackType,
        options: _attackTypes,
        onChanged: (v) => setState(() => _selectedAttackType = v),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _damageDiceController,
        decoration: const InputDecoration(
          labelText: 'Dado de daño (opcional)',
          hintText: 'Ej: 2d6+3',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Escalable con nivel de conjuro'),
        value: _isScalable,
        onChanged: (v) => setState(() => _isScalable = v),
      ),
      if (_isScalable) ...[
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _baseLevelController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nivel base',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _scalingFormulaController,
                decoration: const InputDecoration(
                  labelText: 'Fórmula de escalado',
                  hintText: 'Ej: 1d6',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (!_isScalable) return null;
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null; // opcional: escalable sin fórmula es válido, solo no se resuelve en combate
                  if (!_looksLikeValidScalingFormula(text)) {
                    return 'Formato inválido. Usa "1d6", "2d4+3" u "8" (plano)';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  /// Solo relevante en pasivas: el HUD las agrupa en el tab de Turno bajo
  /// esta etiqueta (ver _PassivesSection).
  List<Widget> _buildPassiveAdvancedFields() {
    return [
      _buildDropdown(
        label: 'Rol táctico',
        value: _selectedTacticalRole,
        options: _tacticalRoles,
        onChanged: (v) => setState(() => _selectedTacticalRole = v),
      ),
      const SizedBox(height: 12),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? 'Editar Habilidad' : 'Nueva Habilidad',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Golpe Aturdidor',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Qué hace esta habilidad...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 5,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Tipo de acción',
                  value: _selectedCategory,
                  options: _categories,
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
                const SizedBox(height: 8),
                // Bloque avanzado: colapsado por defecto. Usamos Offstage en
                // vez de ExpansionTile.children para que los TextFormField
                // de dentro sigan montados (y por tanto se validen) aunque
                // el usuario los tenga visualmente ocultos — así un error
                // como una fórmula de escalado mal escrita no se "pierde"
                // solo por estar el panel cerrado.
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _advancedExpanded = !_advancedExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            _advancedExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Text('Avanzado (opcional)'),
                        ],
                      ),
                    ),
                  ),
                ),
                Offstage(
                  offstage: !_advancedExpanded,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._isPassive ? _buildPassiveAdvancedFields() : _buildTappableAdvancedFields(),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Tiene cargas propias'),
                          subtitle: const Text('Ej: una vara mágica con 3 usos al día'),
                          value: _hasCharges,
                          onChanged: (v) => setState(() => _hasCharges = v),
                        ),
                        if (_hasCharges) ...[
                          TextFormField(
                            controller: _maxChargesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cargas máximas',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _tacticalSummaryController,
                          decoration: const InputDecoration(
                            labelText: 'Resumen táctico (opcional)',
                            hintText: 'Chuleta mecánica rápida...',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          minLines: 2,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  label: Text(_isEditing ? 'Guardar Cambios' : 'Guardar Habilidad'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Menú de opciones (⋮) que agrupa Editar y Eliminar en un único botón, en
/// vez de dos iconos sueltos pegados al icono de dados. Dos motivos:
///   1. Un solo objetivo de toque cerca de la zona "tocar para tirar" en
///      vez de dos, con el tamaño de toque estándar de Material (48dp,
///      sin forzar visualDensity compacto ni constraints a cero como
///      tenían los botones sueltos) — mucho más difícil rozarlo sin
///      querer al intentar tocar el resto de la tarjeta.
///   2. Borrar/editar pasan a requerir dos toques deliberados (abrir menú
///      → elegir opción) en vez de uno solo, lo que por sí mismo reduce
///      las pulsaciones accidentales incluso antes de llegar al diálogo
///      de confirmación de borrado.
class _AbilityOptionsMenu extends StatelessWidget {
  final Ability ability;
  final String categoryKey;

  const _AbilityOptionsMenu({required this.ability, required this.categoryKey});

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddAbilitySheet(existingAbility: ability, existingCategory: categoryKey),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Eliminar habilidad?'),
          content: Text(
            'Vas a eliminar "${ability.name}" de la ficha. Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      context.read<CharacterProvider>().removeAbility(ability.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${ability.name}" eliminada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopupMenuButton (como IconButton) resuelve el gesto sobre sí mismo
    // antes de que llegue al InkWell/ExpansionTile padre, así que no hace
    // falta ningún truco extra para que abrir el menú no dispare también
    // el Protocolo de Dados o el plegado de la tarjeta.
    return PopupMenuButton<String>(
      tooltip: 'Opciones de la habilidad',
      icon: Icon(Icons.more_vert, size: 20, color: context.appColors.textSecondary),
      onSelected: (value) {
        if (value == 'edit') {
          _openEditSheet(context);
        } else if (value == 'delete') {
          _confirmAndDelete(context);
        }
      },
      itemBuilder: (menuContext) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: Text('Eliminar', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ),
      ],
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