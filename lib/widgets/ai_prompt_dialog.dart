// lib/widgets/ai_prompt_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/character_provider.dart';
import '../theme/app_colors.dart';
import '../utils/nivel20_extractor.dart';

// ============================================================================
// Integración Nivel20 — Diálogo compartido para generar (con copia al
// portapapeles) el prompt listo para pegar en cualquier IA de texto.
//
// El jugador pega aquí el JSON crudo exportado de Nivel20 (o de donde sea);
// se limpia con Nivel20Extractor.cleanRawJsonString() y ese texto ya
// limpio se incrusta en el prompt. La IA nunca visita ningún enlace: todo
// lo que necesita ya va incluido como texto.
//
// Actúa sobre el personaje activo del roster, así que se usa tanto desde el
// HUD como desde la pantalla de selección de personaje.
// ============================================================================

/// Abre el diálogo de generación de prompt con IA para el personaje activo
/// del [CharacterProvider]. El jugador pega el JSON crudo dentro del propio
/// diálogo; no hay campo de enlace ni visita de la IA a ninguna URL.
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
  final TextEditingController _jsonController = TextEditingController();

  /// Prompt ya generado a partir del JSON pegado. Null hasta que el
  /// jugador pulsa "Generar prompt" con éxito.
  String? _prompt;
  String? _error;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  /// Limpia el JSON pegado y genera el prompt a partir de él. Cualquier
  /// edición posterior del campo invalida el prompt ya generado, para no
  /// copiar por error un prompt que no corresponde al texto visible.
  void _generatePrompt() {
    final raw = _jsonController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _error = 'Pega primero el JSON exportado de tu ficha.';
        _prompt = null;
      });
      return;
    }

    try {
      final cleaned = Nivel20Extractor.cleanRawJsonString(raw);
      final prompt = widget.provider.generateAIPrompt(rawSourceText: cleaned);
      setState(() {
        _prompt = prompt;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _prompt = null;
        _error = 'JSON inválido — revisa que lo hayas copiado completo.';
      });
    }
  }

  Future<void> _copyPrompt() async {
    if (_prompt == null) {
      _generatePrompt();
      if (_prompt == null) return;
    }
    await Clipboard.setData(ClipboardData(text: _prompt!));
    if (!mounted) return;
    widget.messenger.showSnackBar(
      const SnackBar(content: Text('Prompt copiado al portapapeles.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return Container(
      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
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
            'JSON exportado de tu ficha',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _error != null
                    ? AppColors.danger.withOpacity(0.6)
                    : Colors.white.withOpacity(0.06),
              ),
            ),
            child: TextField(
              controller: _jsonController,
              maxLines: 6,
              minLines: 4,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontFamily: 'monospace',
              ),
              cursorColor: accent,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(12),
                border: InputBorder.none,
                hintText: '{ "basic_info": { ... }, ... }',
                hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.25)),
              ),
              // Cualquier edición del JSON invalida el prompt ya generado,
              // para no dejar copiar un prompt desactualizado respecto al
              // texto visible en el campo.
              onChanged: (_) => setState(() {
                _prompt = null;
                _error = null;
              }),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.inter(color: AppColors.danger, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _generatePrompt,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: _prompt != null
                      ? Colors.greenAccent.withOpacity(0.5)
                      : Colors.white.withOpacity(0.15),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _prompt != null ? Icons.check_rounded : Icons.auto_fix_high_rounded,
                color: _prompt != null ? Colors.greenAccent : Colors.white70,
                size: 18,
              ),
              label: Text(
                _prompt != null ? 'Prompt generado' : 'Generar prompt',
                style: GoogleFonts.inter(
                  color: _prompt != null ? Colors.greenAccent : Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          if (_prompt != null) ...[
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
                    _prompt!,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary.withOpacity(0.85),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],

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