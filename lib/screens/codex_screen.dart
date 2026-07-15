import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_theme_extension.dart';

/// Paso 2 (Vertical Slice) — Códice / Diario.
///
/// Pantalla completa (no tab) dedicada a las notas del personaje activo:
///   - Consejos de IA: solo lectura, generados fuera de esta pantalla.
///   - Tácticas del jugador: notas libres sobre cómo jugar la ficha.
///   - Diario de aventura: texto largo de formato libre.
///
/// Se accede desde main_hud_screen.dart (botón de libro en la AppBar). Los
/// controladores se inicializan una sola vez con el estado del personaje
/// activo en el momento de abrir la pantalla; cada cambio se persiste al
/// vuelo a través del provider (debounce ligero para no escribir en disco
/// en cada pulsación).
class CodexScreen extends StatefulWidget {
  const CodexScreen({super.key});

  @override
  State<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends State<CodexScreen> {
  late final TextEditingController _tacticsController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final character = context.read<CharacterProvider>().character;
    _tacticsController = TextEditingController(text: character.userTactics);
    _notesController = TextEditingController(text: character.adventureNotes);
  }

  @override
  void dispose() {
    // Por si el usuario cierra la pantalla (gesto de back del sistema,
    // etc.) sin que el último onChanged haya llegado a persistir todavía.
    _flushToProvider();
    _tacticsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _flushToProvider() {
    final provider = context.read<CharacterProvider>();
    provider.updateUserTactics(_tacticsController.text);
    provider.updateAdventureNotes(_notesController.text);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ThemeNotifier>().accentColor;
    final character = context.watch<CharacterProvider>().character;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _flushToProvider();
      },
      child: Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          backgroundColor: context.appColors.background,
          elevation: 0,
          title: Text(
            'Códice de Aventura',
            style: GoogleFonts.inter(
              color: context.appColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AiTipsCard(accent: accent, text: character.aiTips),
                const SizedBox(height: 20),
                _CodexSection(
                  accent: accent,
                  icon: Icons.psychology_alt_outlined,
                  title: 'TÁCTICAS DEL JUGADOR',
                  hint: '¿Como te han dicho los mayores que se usa tu personaje?',
                  controller: _tacticsController,
                  minLines: 6,
                  onChanged: (text) =>
                      context.read<CharacterProvider>().updateUserTactics(text),
                ),
                const SizedBox(height: 20),
                _CodexSection(
                  accent: accent,
                  icon: Icons.auto_stories_outlined,
                  title: 'DIARIO DE AVENTURA',
                  hint: 'Sesión 1: llegamos a la posada del Grifo Dorado...',
                  controller: _notesController,
                  minLines: 12,
                  onChanged: (text) => context
                      .read<CharacterProvider>()
                      .updateAdventureNotes(text),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de solo lectura para los consejos generados por IA. Sin campo
/// editable a propósito: si en el futuro se regeneran desde una llamada de
/// IA, el provider ya expone setAiTips() para ese flujo.
class _AiTipsCard extends StatelessWidget {
  final Color accent;
  final String text;

  const _AiTipsCard({required this.accent, required this.text});

  @override
  Widget build(BuildContext context) {
    final hasText = text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withOpacity(0.08), context.appColors.surfaceLight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.18), blurRadius: 18, spreadRadius: -4),
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'CONSEJOS DE IA',
                style: GoogleFonts.inter(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Icon(Icons.lock_outline, color: context.appColors.textSecondary.withOpacity(0.6), size: 14),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasText
                ? text
                : 'Todavía no hay consejos generados para este personaje.',
            style: GoogleFonts.inter(
              color: hasText ? context.appColors.textPrimary : context.appColors.textSecondary,
              fontSize: 14,
              height: 1.5,
              fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección editable genérica (tácticas / diario): cabecera con icono +
/// título, y un área de texto cómoda de fondo oscuro que crece con el
/// contenido en vez de recortarlo.
class _CodexSection extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String title;
  final String hint;
  final TextEditingController controller;
  final int minLines;
  final ValueChanged<String> onChanged;

  const _CodexSection({
    required this.accent,
    required this.icon,
    required this.title,
    required this.hint,
    required this.controller,
    required this.minLines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: minLines,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.inter(
              color: context.appColors.textPrimary,
              fontSize: 14.5,
              height: 1.5,
            ),
            cursorColor: accent,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: context.appColors.textSecondary.withOpacity(0.6),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ],
    );
  }
}