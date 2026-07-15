// lib/widgets/ai_prompt_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/character_provider.dart';
import '../theme/app_colors.dart';

// ============================================================================
// Integración Nivel20 — Diálogo compartido para guardar el enlace de la
// ficha en Nivel20 y generar (con copia al portapapeles) el prompt listo
// para pegar en cualquier IA de texto. Actúa sobre el personaje activo del
// roster, así que se usa tanto desde el HUD como desde la pantalla de
// selección de personaje.
// ============================================================================

/// Abre el diálogo de importación/actualización con IA vía Nivel20 para el
/// personaje activo del [CharacterProvider].
void showAIPromptDialog(BuildContext context, {required Color accent}) {
  final provider = context.read<CharacterProvider>();
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: AIPromptDialogContent(
        accent: accent,
        provider: provider,
        messenger: messenger,
      ),
    ),
  );
}

class AIPromptDialogContent extends StatefulWidget {
  final Color accent;
  final CharacterProvider provider;
  final ScaffoldMessengerState messenger;

  const AIPromptDialogContent({
    super.key,
    required this.accent,
    required this.provider,
    required this.messenger,
  });

  @override
  State<AIPromptDialogContent> createState() => _AIPromptDialogContentState();
}

class _AIPromptDialogContentState extends State<AIPromptDialogContent> {
  late final TextEditingController _linkController;
  late String _prompt;

  @override
  void initState() {
    super.initState();
    _linkController = TextEditingController(
      text: widget.provider.activeCharacter.basicInfo.nivel20Link ?? '',
    );
    _prompt = widget.provider.generateAIPrompt();
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  void _saveLinkAndRegenerate() {
    widget.provider.updateNivel20Link(_linkController.text.trim());
    setState(() => _prompt = widget.provider.generateAIPrompt());
  }

  Future<void> _copyPrompt() async {
    // Nos aseguramos de que el prompt refleja el último enlace guardado
    // antes de copiarlo, por si el jugador editó el campo y pulsó
    // "Copiar" directamente sin perder el foco antes.
    _saveLinkAndRegenerate();
    await Clipboard.setData(ClipboardData(text: _prompt));
    if (!mounted) return;
    widget.messenger.showSnackBar(
      const SnackBar(content: Text('Prompt copiado al portapapeles.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return Container(
      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withOpacity(0.05), AppColors.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.18), blurRadius: 26, spreadRadius: -6),
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'IMPORTAR DESDE NIVEL20 CON IA',
                  style: GoogleFonts.inter(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Enlace de Nivel20',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _linkController,
            autocorrect: false,
            keyboardType: TextInputType.url,
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'https://nivel20.com/characters/...',
              hintStyle: GoogleFonts.inter(color: AppColors.textSecondary.withOpacity(0.6)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accent),
              ),
            ),
            onChanged: (_) => _saveLinkAndRegenerate(),
          ),
          const SizedBox(height: 18),
          Text(
            'Prompt generado',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _prompt,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _copyPrompt,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('COPIAR PROMPT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.withOpacity(0.9),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}