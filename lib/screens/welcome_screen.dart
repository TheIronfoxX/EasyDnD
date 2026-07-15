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

                // Tarjeta con los pain points — panel plano, borde fino,
                // sin sombras pesadas: estética "industrial stark".
                _animated(
                  fade: _cardFade,
                  slide: _cardSlide,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          children: [
                            _PainPoint(
                              accent: accent,
                              icon: Icons.flash_on_rounded,
                              text: '¿Cansado de perderte en mitad del combate?',
                            ),
                            const _Divider(),
                            _PainPoint(
                              accent: accent,
                              icon: Icons.security_rounded,
                              text: '¿Harto de buscar dónde está tu clase de armadura?',
                            ),
                            const _Divider(),
                            _PainPoint(
                              accent: accent,
                              icon: Icons.auto_fix_high_rounded,
                              text: '¿Se te hace bola tu lista infinita de conjuros?',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'EasyD&D lo resuelve.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          color: Colors.white.withOpacity(0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 44),

                // Botón principal — minimalista, borde fino que reacciona
                // al color dinámico. Sin relleno degradado: el acento vive
                // en el borde, el icono y el texto, no en un bloque sólido.
                _animated(
                  fade: _buttonFade,
                  slide: _buttonSlide,
                  child: SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              transitionDuration: const Duration(milliseconds: 500),
                              pageBuilder: (_, animation, __) => const PromptScreen(),
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
                        },
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
                              Icon(Icons.arrow_forward_rounded, color: accent, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Continuar',
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PainPoint extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String text;

  const _PainPoint({required this.accent, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withOpacity(0.25), width: 1),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                height: 1.3,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(color: Colors.white.withOpacity(0.06), height: 1);
  }
}