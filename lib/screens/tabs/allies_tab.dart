import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/character_provider.dart';
import '../../models/character_model.dart';
import '../../theme/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme_extension.dart';

class AlliesTab extends StatelessWidget {
  const AlliesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final companions = provider.character.companions;
    final accent = context.watch<ThemeNotifier>().accentColor;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FUERZAS DE APOYO',
                style: GoogleFonts.inter(
                  color: context.appColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showAddCompanionDialog(context, accent),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'AÑADIR',
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: companions.isEmpty
                ? Center(
                    child: Text(
                      'Sin aliados tácticos en el perímetro.',
                      style: GoogleFonts.inter(color: context.appColors.textSecondary, fontSize: 13),
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // Dos columnas para optimizar el espacio
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1, 
                    ),
                    itemCount: companions.length,
                    itemBuilder: (context, index) {
                      return _CompanionCard(
                        companion: companions[index],
                        index: index,
                        accent: accent,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LÓGICA DE APOYO (Trasladada desde el HUD principal)
// ============================================================================

Future<void> _showAddCompanionDialog(BuildContext context, Color accent) async {
  final nameController = TextEditingController();
  final typeController = TextEditingController();
  final maxHpController = TextEditingController();
  final acController = TextEditingController(text: '10');
  final provider = context.read<CharacterProvider>();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      bool hasHp = true;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: context.appColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: accent.withOpacity(0.35)),
            ),
            title: Text(
              'Nuevo Aliado Táctico',
              style: GoogleFonts.inter(color: context.appColors.textPrimary, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CompanionTextField(controller: nameController, hint: 'Nombre', accent: accent, autofocus: true),
                  const SizedBox(height: 12),
                  _CompanionTextField(controller: typeController, hint: 'Tipo (Bestia, Familiar...)', accent: accent),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '¿Entidad con puntos de vida?',
                          style: GoogleFonts.inter(color: context.appColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      Switch(
                        value: hasHp,
                        onChanged: (v) => setState(() => hasHp = v),
                        activeColor: accent,
                      ),
                    ],
                  ),
                  if (hasHp) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _CompanionTextField(
                            controller: maxHpController,
                            hint: 'Vida Máxima',
                            accent: accent,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CompanionTextField(
                            controller: acController,
                            hint: 'CA',
                            accent: accent,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Cancelar', style: GoogleFonts.inter(color: context.appColors.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final maxHp = hasHp ? (int.tryParse(maxHpController.text) ?? 0) : 0;
                  final ac = int.tryParse(acController.text) ?? 10;
                  provider.addCompanion(
                    Companion(
                      name: name,
                      type: typeController.text.trim(),
                      hasHp: hasHp,
                      maxHp: maxHp,
                      currentHp: maxHp,
                      ac: ac,
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: Text(
                  'Añadir',
                  style: GoogleFonts.inter(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _CompanionTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color accent;
  final TextInputType? keyboardType;
  final bool autofocus;

  const _CompanionTextField({
    required this.controller,
    required this.hint,
    required this.accent,
    this.keyboardType,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: context.appColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: context.appColors.textSecondary, fontSize: 13),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent.withOpacity(0.4))),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
      ),
    );
  }
}

class _CompanionCard extends StatelessWidget {
  final Companion companion;
  final int index;
  final Color accent;

  const _CompanionCard({
    required this.companion,
    required this.index,
    required this.accent,
  });

  Future<void> _confirmRemove(BuildContext context) async {
    final provider = context.read<CharacterProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: context.appColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accent.withOpacity(0.35)),
          ),
          title: Text(
            'Retirar aliado',
            style: GoogleFonts.inter(color: context.appColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          content: Text(
            '¿Retirar a "${companion.name}" del campo de batalla?',
            style: GoogleFonts.inter(color: context.appColors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancelar', style: GoogleFonts.inter(color: context.appColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Retirar', style: GoogleFonts.inter(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      provider.removeCompanion(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CharacterProvider>();

    return GestureDetector(
      onLongPress: () => _confirmRemove(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(accent.withOpacity(0.04), context.appColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companion.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: context.appColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                if (companion.type.isNotEmpty)
                  Text(
                    companion.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: context.appColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
            if (companion.hasHp) ...[
              Center(
                child: Text(
                  '${companion.currentHp}/${companion.maxHp}',
                  style: GoogleFonts.inter(color: accent, fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CompanionHpButton(
                    icon: Icons.remove,
                    color: AppColors.danger,
                    onPressed: () => provider.updateCompanionHp(index, -1),
                  ),
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: context.appColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${companion.ac}', style: GoogleFonts.inter(color: context.appColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  _CompanionHpButton(
                    icon: Icons.add,
                    color: accent,
                    onPressed: () => provider.updateCompanionHp(index, 1),
                  ),
                ],
              ),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    Icon(Icons.shield_moon, size: 28, color: accent.withOpacity(0.8)),
                    const SizedBox(height: 4),
                    Text(
                      'Apoyo / Invulnerable',
                      style: GoogleFonts.inter(
                        color: context.appColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompanionHpButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CompanionHpButton({required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}