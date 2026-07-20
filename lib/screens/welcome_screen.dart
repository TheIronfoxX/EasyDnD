import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/theme_notifier.dart';
import 'prompt_screen.dart';

/// Nothing OS / Industrial Stark.
///
/// Sin ficha activa todavía no hay clase ni HP que leer, así que el color
/// dinámico aquí se reduce a su señal más simple: la preferencia manual del
/// jugador guardada en [ThemeNotifier] (persiste entre sesiones, incluida
/// la elegida en una partida anterior). Si por lo que sea el provider no
/// estuviera montado en este punto del árbol, se cae a un rojo Nothing por
/// defecto para que la pantalla nunca se quede sin acento.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const Color _fallbackAccent = Color(0xFFE63946);

  late final AnimationController _controller;

  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;

  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;

  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _logoFade = _fadeAnim(0.0, 0.5);
    _logoSlide = _slideAnim(0.0, 0.5);

    _titleFade = _fadeAnim(0.15, 0.65);
    _titleSlide = _slideAnim(0.15, 0.65);

    _cardFade = _fadeAnim(0.3, 0.8);
    _cardSlide = _slideAnim(0.3, 0.8);

    _buttonFade = _fadeAnim(0.5, 1.0);
    _buttonSlide = _slideAnim(0.5, 1.0);

    _controller.forward();
  }

  Animation<double> _fadeAnim(double start, double end) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  Animation<Offset> _slideAnim(double start, double end) {
    return Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Widget _animated({
    required Animation<double> fade,
    required Animation<Offset> slide,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  /// Lee el acento dinámico sin reventar si `ThemeNotifier` no está
  /// disponible todavía en este punto del árbol de widgets.
  Color _readAccent(BuildContext context) {
    try {
      return context.watch<ThemeNotifier>().accentColor;
    } catch (_) {
      return _fallbackAccent;
    }
  }

  /// Único punto de navegación hacia `PromptScreen`, tanto para el atajo
  /// "Iniciar Extracción" (con el enlace de Nivel20 ya pegado) como para
  /// "Ensamblaje Manual" (sin enlace). Toda la lógica de verdad — resolver
  /// el enlace, descargar y limpiar la ficha, generar el prompt, copiarlo,
  /// y luego pegar/importar el JSON que devuelva la IA — vive en
  /// `PromptScreen`/`Nivel20Extractor`/`CharacterProvider`; aquí no se
  /// duplica nada de eso, así que no hay ningún punto en el que el
  /// personaje se importe "directo" sin pasar por copiar o continuar.
  void _goToPromptScreen({String? nivel20Link}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) => PromptScreen(
          initialNivel20Link: nivel20Link,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _handleExtractionShortcut() {
    final link = _urlController.text.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pega primero el enlace de tu ficha de Nivel20.'),
        ),
      );
      return;
    }
    _goToPromptScreen(nivel20Link: link);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _readAccent(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo de la app
                _animated(
                  fade: _logoFade,
                  slide: _logoSlide,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.25),
                          blurRadius: 26,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon/icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                // Título + subtítulo
                _animated(
                  fade: _titleFade,
                  slide: _titleSlide,
                  child: Column(
                    children: [
                      Text(
                        'EasyD&D',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'TU MESA, SIN FRICCIÓN',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 44),

                // Tarjeta destacada: importación desde Nivel20 — panel
                // plano, borde fino, sin sombras pesadas, en línea con la
                // estética "industrial stark" del resto de la pantalla.
                _animated(
                  fade: _cardFade,
                  slide: _cardSlide,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withOpacity(0.28), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: accent.withOpacity(0.25), width: 1),
                              ),
                              child: Icon(Icons.bolt_rounded, color: accent, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Importar desde Nivel20 (Recomendado)',
                                style: GoogleFonts.inter(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.92),
                          ),
                          cursorColor: accent,
                          decoration: InputDecoration(
                            hintText: 'Pega aquí la URL de tu ficha de Nivel20',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13.5,
                              color: Colors.white.withOpacity(0.32),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.03),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.link_rounded,
                              size: 19,
                              color: Colors.white.withOpacity(0.35),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accent.withOpacity(0.7), width: 1.3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: Colors.white.withOpacity(0.38),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nota: Vale tanto el enlace de tu ficha como el enlace corto '
                                'de "Compartir" — la app detecta cuál es y resuelve el resto. '
                                'Te llevará al prompt ya con tu ficha incrustada: cópialo, '
                                'pégalo en tu IA de confianza, y luego pega aquí el JSON (o '
                                'importa el archivo) que te devuelva.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  height: 1.35,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _handleExtractionShortcut,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 17),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: accent.withOpacity(0.06),
                                  border: Border.all(color: accent, width: 1.4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withOpacity(0.22),
                                      blurRadius: 20,
                                      spreadRadius: -6,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download_rounded, color: accent, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Iniciar Extracción',
                                      style: GoogleFonts.inter(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: accent,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // Opción secundaria: el método manual de siempre, discreto
                // y sin competir visualmente con la tarjeta principal.
                _animated(
                  fade: _buttonFade,
                  slide: _buttonSlide,
                  child: TextButton(
                    onPressed: _goToPromptScreen,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.45),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    child: Text(
                      'Ensamblaje Manual (Método antiguo)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}