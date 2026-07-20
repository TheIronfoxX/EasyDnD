import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';
import '../models/character_model.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_extension.dart';
import '../widgets/journal_number_text.dart';
import '../widgets/hsv_color_picker.dart';
import 'character_selection_screen.dart';
import 'codex_screen.dart';
import 'tabs/stats_tab.dart';
import 'tabs/turn_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/lore_tab.dart';
import 'tabs/allies_tab.dart';

class MainHudScreen extends StatefulWidget {
  const MainHudScreen({super.key});

  @override
  State<MainHudScreen> createState() => _MainHudScreenState();
}

class _MainHudScreenState extends State<MainHudScreen> {
  int _selectedIndex = 0;

  List<Widget> _buildTabs() {
    return const [
      StatsTab(),
      TurnTab(),
      InventoryTab(),
      LoreTab(),
      AlliesTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final character = provider.character;
    final info = character.basicInfo;
    final hasDisadvantage = provider.hasDisadvantage;

    // El acento del HUD es siempre el que el jugador eligió manualmente
    // en el selector HSV — ya no varía según la clase del personaje ni
    // según el HP actual.
    final baseAccent = context.watch<ThemeNotifier>().accentColor;
    final accent = baseAccent;

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: context.appColors.background,
        elevation: 0,
        title: Text(
          'EasyDnD',
          style: GoogleFonts.inter(
          color: context.appColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          _CodexButton(accent: accent),
          _RosterButton(accent: accent),
          _RestButton(accent: accent),
          _ColorPickerButton(baseAccent: baseAccent),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea( // <-- ESTE ES EL ESCUDO TÁCTICO
        child: Column(
          children: [
            if (hasDisadvantage) const _DisadvantageBanner(),
            _HudCards(
              accent: accent,
              name: info.name,
              race: info.race,
              characterClass: info.characterClass,
              hp: info.currentHp,
              hpMax: info.hpMax,
              ac: info.ac,
              initiative: character.stats.dex.mod,
              avatarPath: character.avatarPath,
              // La vida (HP/CA) solo se muestra en Stats y Mi Turno; en
              // Inventario, Lore y Aliados no aporta nada y solo resta espacio.
              showVitals: _selectedIndex == 0 || _selectedIndex == 1,
            ),
            Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06), height: 1),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _buildTabs(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: context.appColors.background,
          indicatorColor: accent.withOpacity(0.16),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? accent : context.appColors.textSecondary,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(color: selected ? accent : context.appColors.textSecondary);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.menu_book), label: 'Stats'),
            NavigationDestination(icon: Icon(Icons.auto_stories), label: 'Mi Turno'),
            NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Inventario'),
            NavigationDestination(icon: Icon(Icons.history_edu), label: 'Lore'),
            NavigationDestination(icon: Icon(Icons.group_work), label: 'Aliados'),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Estados Alterados — Alerta Táctica de Desventaja
// ============================================================================
class _DisadvantageBanner extends StatelessWidget {
  const _DisadvantageBanner();

  static const _dangerRed = Color(0xFFFF5252);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _dangerRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dangerRed.withOpacity(0.45), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _dangerRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ATENCIÓN: Sistemas comprometidos. Tiras con Desventaja',
              style: GoogleFonts.inter(
                color: _dangerRed,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexButton extends StatelessWidget {
  final Color accent;

  const _CodexButton({required this.accent});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.menu_book_outlined, color: accent),
      tooltip: 'Códice de Aventura',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CodexScreen()),
        );
      },
    );
  }
}

class _RosterButton extends StatelessWidget {
  final Color accent;

  const _RosterButton({required this.accent});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.groups_outlined, color: accent),
      tooltip: 'Cambiar de personaje',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CharacterSelectionScreen()),
        );
      },
    );
  }
}

// ============================================================================
// HUD — Tarjetas flotantes agrupadas: IDENTIDAD, VITAL, ESTADOS.
// ============================================================================
class _HudCards extends StatelessWidget {
  final Color accent;
  final String name;
  final String race;
  final String characterClass;
  final int hp;
  final int hpMax;
  final int ac;
  final int initiative;
  final String? avatarPath;
  final bool showVitals;

  const _HudCards({
    required this.accent,
    required this.name,
    required this.race,
    required this.characterClass,
    required this.hp,
    required this.hpMax,
    required this.ac,
    required this.initiative,
    required this.avatarPath,
    this.showVitals = true,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String get _subtitle {
    final segments = [race, characterClass].where((s) => s.trim().isNotEmpty);
    return segments.join(' · ');
  }

  String get _initiativeDisplay => initiative >= 0 ? '+$initiative' : '$initiative';

  Future<void> _showAdjustHpDialog(BuildContext context, {required bool isDamage}) async {
    final controller = TextEditingController();
    final provider = context.read<CharacterProvider>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.appColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accent.withOpacity(0.35)),
          ),
          title: Text(
            isDamage ? 'Aplicar daño' : 'Aplicar curación',
            style: GoogleFonts.inter(color: context.appColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: GoogleFonts.inter(color: context.appColors.textPrimary, fontSize: 20),
            decoration: InputDecoration(
              hintText: 'Cantidad',
              hintStyle: GoogleFonts.inter(color: context.appColors.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent.withOpacity(0.4))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancelar', style: GoogleFonts.inter(color: context.appColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final amount = int.tryParse(controller.text) ?? 0;
                if (amount > 0) {
                  if (isDamage) {
                    provider.applyDamage(amount);
                  } else {
                    provider.applyHealing(amount);
                  }
                }
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Confirmar',
                style: GoogleFonts.inter(
                  color: isDamage ? AppColors.danger : AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _floatingCard(BuildContext context, {required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withOpacity(0.06), context.appColors.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06), width: 1),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.16), blurRadius: 20, spreadRadius: -6),
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Tarjeta fusionada: IDENTIDAD + VITAL, más compacta -------------
          _floatingCard(
            context,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Fila superior: avatar + nombre completo + estado ---------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => context.read<CharacterProvider>().pickAvatarForActiveCharacter(),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Color.alphaBlend(accent.withOpacity(0.1), context.appColors.surfaceLight),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06), width: 1),
                              image: avatarPath != null
                                  ? DecorationImage(image: FileImage(File(avatarPath!)), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: avatarPath == null
                                ? Center(
                                    child: Text(
                                      _initials,
                                      style: GoogleFonts.inter(
                                        color: accent,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: context.appColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: accent.withOpacity(0.6), width: 1),
                              ),
                              child: Icon(Icons.photo_camera, size: 11, color: accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Nombre completo, sin recortar
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    color: context.appColors.textPrimary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusBadge(accent: accent),
                            ],
                          ),
                          if (_subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _subtitle.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                if (showVitals) ...[
                  const SizedBox(height: 16),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06), height: 1),
                  const SizedBox(height: 14),

                  // --- Vida, a todo lo ancho y bien grande -----------------------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HP',
                              style: GoogleFonts.inter(
                                color: context.appColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _HpActionButton(
                                  icon: Icons.remove_rounded,
                                  color: AppColors.danger,
                                  tooltip: 'Aplicar daño',
                                  size: 38,
                                  onPressed: () => _showAdjustHpDialog(context, isDamage: true),
                                ),
                                const SizedBox(width: 14),
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      JournalNumberText(text: '$hp', color: accent, fontSize: 38),
                                      Text(
                                        ' / $hpMax',
                                        style: GoogleFonts.inter(
                                          color: context.appColors.textSecondary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                _HpActionButton(
                                  icon: Icons.add_rounded,
                                  color: accent,
                                  tooltip: 'Aplicar curación',
                                  size: 38,
                                  onPressed: () => _showAdjustHpDialog(context, isDamage: false),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // CA + Iniciativa, apiladas una sobre otra
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MiniStatBox(label: 'CA', value: '$ac', accent: accent),
                          const SizedBox(height: 8),
                          _MiniStatBox(label: 'INI', value: _initiativeDisplay, accent: accent),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _dangerRed = Color(0xFFFF5252);

void _showConditionDetail(BuildContext context, String conditionName) {
  final detail = conditionDetails[conditionName];
  final provider = context.read<CharacterProvider>();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.bolt, color: _dangerRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conditionName.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: context.appColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              detail?.description ?? 'Sin descripción registrada.',
              style: GoogleFonts.inter(
                color: context.appColors.textSecondary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            if (detail?.causesDisadvantage == true) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _dangerRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _dangerRed.withOpacity(0.35)),
                ),
                child: Text(
                  'Impone Desventaja',
                  style: GoogleFonts.inter(
                    color: _dangerRed,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
            if (conditionName == 'Envenenado') ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final damage = Random().nextInt(4) + 1; // 1d4
                    provider.applyPoisonDamage(damage);
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Daño por veneno: -$damage HP')),
                    );
                  },
                  icon: const Icon(Icons.dangerous_outlined, size: 18),
                  label: const Text('Recibir Daño por Veneno (1d4)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dangerRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      );
    },
  );
}

// ============================================================================
// Cuadradito de ESTADO junto al nombre — reemplaza la antigua tarjeta ESTADOS.
// Muestra "SIN ESTADO" por defecto; al pulsarlo abre el desplegable donde se
// elige la condición activa.
// ============================================================================
class _StatusBadge extends StatelessWidget {
  final Color accent;

  const _StatusBadge({required this.accent});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final activeConditions = provider.character.activeConditions;
    final hasCondition = activeConditions.isNotEmpty;

    final label = !hasCondition
        ? 'SIN ESTADO'
        : activeConditions.length == 1
            ? activeConditions.first.toUpperCase()
            : '${activeConditions.first.toUpperCase()} +${activeConditions.length - 1}';

    final badgeColor = hasCondition ? _dangerRed : context.appColors.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _ConditionSelectorSheet(accent: accent),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: hasCondition ? _dangerRed.withOpacity(0.12) : Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasCondition ? _dangerRed.withOpacity(0.4) : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasCondition ? Icons.bolt : Icons.check_circle_outline,
              size: 11,
              color: badgeColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: badgeColor,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionSelectorSheet extends StatelessWidget {
  final Color accent;

  const _ConditionSelectorSheet({required this.accent});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final activeConditions = provider.character.activeConditions;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (sheetContext, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'ESTADOS DISPONIBLES',
                style: GoogleFonts.inter(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Toca para activar o desactivar. Mantén pulsado para ver el detalle.',
                style: GoogleFonts.inter(color: context.appColors.textSecondary, fontSize: 11.5),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: conditionDetails.isEmpty
                    ? Center(
                        child: Text(
                          'Sin condiciones definidas.',
                          style: GoogleFonts.inter(color: context.appColors.textSecondary, fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: conditionDetails.length,
                        separatorBuilder: (_, __) => Divider(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                          height: 1,
                        ),
                        itemBuilder: (itemContext, index) {
                          final conditionName = conditionDetails.keys.elementAt(index);
                          final isActive = activeConditions.contains(conditionName);
                          return GestureDetector(
                            onLongPress: () => _showConditionDetail(context, conditionName),
                            child: CheckboxListTile(
                              value: isActive,
                              onChanged: (_) => provider.toggleCondition(conditionName),
                              activeColor: _dangerRed,
                              checkColor: Colors.white,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                conditionName,
                                style: GoogleFonts.inter(
                                  color: context.appColors.textPrimary,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HpActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  const _HpActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.16),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: size * 0.56),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Casilla compacta reutilizable para estadísticas pequeñas (CA, Iniciativa...)
// ============================================================================
class _MiniStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 46,
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withOpacity(0.1), context.appColors.surfaceLight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: context.appColors.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          JournalNumberText(text: value, color: accent, fontSize: 17),
        ],
      ),
    );
  }
}

class _ColorPickerButton extends StatelessWidget {
  final Color baseAccent;

  const _ColorPickerButton({required this.baseAccent});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.palette_outlined, color: baseAccent),
      tooltip: 'Elegir color de acento',
      onPressed: () async {
        final themeNotifier = context.read<ThemeNotifier>();
        final picked = await showDialog<Color>(
          context: context,
          builder: (_) => HsvColorPickerDialog(initialColor: baseAccent),
        );
        if (picked != null) {
          themeNotifier.setAccentColor(picked);
        }
      },
    );
  }
}

// ============================================================================
// Fase 7 — Protocolo de Descanso
// ============================================================================

class _RestButton extends StatelessWidget {
  final Color accent;

  const _RestButton({required this.accent});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.local_fire_department, color: accent),
      tooltip: 'Protocolo de Descanso',
      onPressed: () {
        final provider = context.read<CharacterProvider>();
        final messenger = ScaffoldMessenger.of(context);

        showDialog<void>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.65),
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: _RestDialogContent(accent: accent, provider: provider, messenger: messenger),
          ),
        );
      },
    );
  }
}

enum _RestView { choices, custom }

class _RestDialogContent extends StatefulWidget {
  final Color accent;
  final CharacterProvider provider;
  final ScaffoldMessengerState messenger;

  const _RestDialogContent({required this.accent, required this.provider, required this.messenger});

  @override
  State<_RestDialogContent> createState() => _RestDialogContentState();
}

class _RestDialogContentState extends State<_RestDialogContent> {
  _RestView _view = _RestView.choices;

  bool _healMax = true;
  bool _restoreSpells = true;
  bool _restoreCharges = true;

  void _confirmLongRest() {
    widget.provider.longRest();
    Navigator.of(context).pop();
    widget.messenger.showSnackBar(
      const SnackBar(content: Text('Descanso largo completado. Vida, conjuros y cargas restaurados.')),
    );
  }

  void _confirmShortRest() {
    Navigator.of(context).pop();
    widget.messenger.showSnackBar(
      const SnackBar(content: Text('Reserva de Dados de Golpe en desarrollo.')),
    );
  }

  void _confirmCustomRest() {
    widget.provider.customRest(
      healMax: _healMax,
      restoreSpells: _restoreSpells,
      restoreCharges: _restoreCharges,
    );
    Navigator.of(context).pop();
    widget.messenger.showSnackBar(
      const SnackBar(content: Text('Descanso personalizado aplicado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withOpacity(0.05), context.appColors.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05), width: 1),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.18), blurRadius: 26, spreadRadius: -6),
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: _view == _RestView.choices ? _buildChoices(context, accent) : _buildCustom(context, accent),
    );
  }

  Widget _buildChoices(BuildContext context, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_fire_department, color: accent, size: 20),
            const SizedBox(width: 8),
            Text(
              'PROTOCOLO DE DESCANSO',
              style: GoogleFonts.inter(color: accent, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.6),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _RestOptionTile(
          icon: Icons.bedtime,
          title: 'Descanso Largo',
          subtitle: 'Vida, conjuros y cargas al máximo.',
          accent: accent,
          onTap: _confirmLongRest,
        ),
        const SizedBox(height: 10),
        _RestOptionTile(
          icon: Icons.timer_outlined,
          title: 'Descanso Corto',
          subtitle: 'Reserva de Dados de Golpe.',
          accent: accent,
          onTap: _confirmShortRest,
        ),
        const SizedBox(height: 10),
        _RestOptionTile(
          icon: Icons.tune,
          title: 'Descanso Personalizado',
          subtitle: 'Elige exactamente qué recuperar.',
          accent: accent,
          onTap: () => setState(() => _view = _RestView.custom),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar', style: GoogleFonts.inter(color: context.appColors.textSecondary)),
          ),
        ),
      ],
    );
  }

  Widget _buildCustom(BuildContext context, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: context.appColors.textSecondary, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _view = _RestView.choices),
            ),
            const SizedBox(width: 6),
            Text(
              'DESCANSO PERSONALIZADO',
              style: GoogleFonts.inter(color: accent, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _RestSwitchRow(
          label: 'Curar vida al máximo',
          value: _healMax,
          accent: accent,
          onChanged: (v) => setState(() => _healMax = v),
        ),
        _RestSwitchRow(
          label: 'Recuperar todos los conjuros',
          value: _restoreSpells,
          accent: accent,
          onChanged: (v) => setState(() => _restoreSpells = v),
        ),
        _RestSwitchRow(
          label: 'Recuperar cargas mágicas',
          value: _restoreCharges,
          accent: accent,
          onChanged: (v) => setState(() => _restoreCharges = v),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_healMax || _restoreSpells || _restoreCharges) ? _confirmCustomRest : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent.withOpacity(0.9),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            child: const Text('CONFIRMAR'),
          ),
        ),
      ],
    );
  }
}

class _RestOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _RestOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(color: context.appColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(color: context.appColors.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: accent.withOpacity(0.6), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _RestSwitchRow({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(color: context.appColors.textPrimary, fontSize: 13),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accent,
          ),
        ],
      ),
    );
  }
}