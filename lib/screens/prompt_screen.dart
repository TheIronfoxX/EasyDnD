import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/character_provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_notifier.dart';
import '../utils/nivel20_extractor.dart';
import 'main_hud_screen.dart';

class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key, this.initialNivel20Link});

  /// Si se pasa un enlace (típicamente desde el atajo de WelcomeScreen),
  /// se pre-rellena el campo de link y se lanza la extracción
  /// automáticamente en cuanto la pantalla se monta, para que el jugador
  /// no tenga que pegarlo dos veces.
  final String? initialNivel20Link;

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  final TextEditingController _jsonController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  bool _copied = false;
  bool _isImporting = false;
  String? _errorText;

  // El texto del prompt ya no vive aquí: se carga en tiempo de ejecución
  // desde el asset `assets/promt.txt` (ver initState y _loadPromptTemplate).
  String _promptTemplate = '';
  bool _isLoadingTemplate = true;
  String? _loadError;

  // Datos de la ficha de Nivel20 ya descargados y limpios de HTML (ver
  // _fetchNivel20Info). Se incrustan en el prompt en vez de solo el link,
  // para no depender de que la IA pueda navegar por su cuenta.
  bool _isFetchingInfo = false;
  String? _fetchedInfoText;
  String? _linkError;

  /// Prompt final a copiar. Si el jugador ya extrajo los datos de su ficha
  /// de Nivel20 (botón "Extraer datos"), se incrustan como un bloque de
  /// texto justo al principio, para que la IA los use como fuente directa
  /// en vez de tener que ir a buscarlos ella misma.
  String get _fullPrompt {
    final info = _fetchedInfoText;
    if (info == null || info.isEmpty) return _promptTemplate.trim();

    return 'Aquí tienes los datos de mi ficha, extraídos automáticamente '
        'de Nivel20 (JSON, ya limpio de HTML):\n\n$info\n\n'
        '${_promptTemplate.trim()}';
  }

  Future<void> _fetchNivel20Info() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) {
      setState(() => _linkError = 'Pega primero el enlace de tu ficha de Nivel20.');
      return;
    }

    setState(() {
      _isFetchingInfo = true;
      _linkError = null;
    });

    try {
      final infoText = await Nivel20Extractor.extractInfoText(link);
      if (!mounted) return;
      setState(() {
        _fetchedInfoText = infoText;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchedInfoText = null;
        _linkError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isFetchingInfo = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _loadPromptTemplate();

    // Atajo desde WelcomeScreen: si ya venimos con un enlace de Nivel20
    // (el jugador lo pegó en la pantalla anterior), lo pre-rellenamos y
    // lanzamos la extracción solos — así no tiene que pegarlo dos veces,
    // pero el flujo de "copiar prompt / pegar JSON / importar archivo"
    // sigue siendo exactamente el mismo, sin saltarse ningún paso.
    final initialLink = widget.initialNivel20Link?.trim();
    if (initialLink != null && initialLink.isNotEmpty) {
      _linkController.text = initialLink;
      _fetchNivel20Info();
    }
  }

  /// Lee el texto del prompt desde el archivo `assets/promt.txt`.
  /// Recuerda declarar ese asset en pubspec.yaml (ver instrucciones).
  Future<void> _loadPromptTemplate() async {
    try {
      final text = await rootBundle.loadString('assets/promt.txt');
      if (!mounted) return;
      setState(() {
        _promptTemplate = text;
        _isLoadingTemplate = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'No se pudo cargar promt.txt: $e';
        _isLoadingTemplate = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _jsonController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: _fullPrompt));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _importJson() async {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'Pega primero el JSON que te devolvió la IA. (En verdad lo que te ha pasao Pedro)');
      return;
    }

    setState(() {
      _isImporting = true;
      _errorText = null;
    });

    try {
      final provider = context.read<CharacterProvider>();
      await provider.importCharacterFromJsonString(text);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainHudScreen()),
        (route) => false,
      );
    } catch (_) {
      setState(() {
        _errorText = 'JSON inválido — revisa que lo hayas copiado completo, '
            'sin texto extra antes o después.';
      });
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Alternativa a pegar el JSON a mano: deja elegir directamente un
  /// archivo `.json` del dispositivo. Reutiliza el mismo
  /// `_isImporting`/`_errorText` que `_importJson` para que ambos botones
  /// no puedan lanzarse a la vez y compartan el mismo feedback visual.
  Future<void> _importFromFile() async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isImporting = true;
      _errorText = null;
    });

    try {
      // allowedExtensions sin el punto inicial ('json', no '.json').
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );

      // Selector cerrado sin elegir archivo: no es un error, solo se
      // cancela silenciosamente.
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) {
        throw const FormatException('No se pudo acceder a la ruta del archivo seleccionado.');
      }

      final raw = await File(path).readAsString();

      final provider = context.read<CharacterProvider>();
      await provider.importCharacterFromJsonString(raw);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainHudScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      // Mismo mensaje de error visible en la caja de texto de pegado,
      // más un snackbar porque aquí no hay campo de texto asociado
      // donde el jugador esté mirando en el momento del fallo.
      setState(() {
        _errorText = 'El archivo no es un JSON válido de ficha, o está corrupto.';
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo importar el archivo seleccionado.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ThemeNotifier>().accentColor;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: accent.withOpacity(0.25), width: 1),
                            ),
                            child: Icon(Icons.auto_awesome_rounded, color: accent, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Paso 1: Genera tu ficha",
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        "Copia este prompt y pégalo en tu IA de confianza (ChatGPT, Claude, etc). Rellena tus datos al final antes de enviarlo. Te devolverá el JSON listo para importar.",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Enlace opcional a la ficha (Nivel20 u otra plataforma).
                    // Si se rellena, se incrusta automáticamente al
                    // principio del prompt de abajo para que la IA lo
                    // visite y extraiga los datos de ahí.
                    Text(
                      "¿Tienes tu ficha en Nivel20? Pega el enlace y extrae los datos (opcional):",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _linkError != null
                              ? AppColors.danger.withOpacity(0.6)
                              : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: TextField(
                        controller: _linkController,
                        enabled: !_isFetchingInfo,
                        autocorrect: false,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        cursorColor: accent,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                          hintText: 'https://nivel20.com/characters/...',
                          hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.25)),
                          prefixIcon: Icon(Icons.link_rounded, color: accent, size: 20),
                        ),
                        // Cualquier edición del link invalida los datos ya
                        // extraídos, para no incrustar en el prompt una
                        // ficha desactualizada respecto al link visible.
                        onChanged: (_) => setState(() {
                          _fetchedInfoText = null;
                          _linkError = null;
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isFetchingInfo ? null : _fetchNivel20Info,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: _fetchedInfoText != null
                                ? Colors.greenAccent.withOpacity(0.5)
                                : Colors.white.withOpacity(0.15),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isFetchingInfo
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              )
                            : Icon(
                                _fetchedInfoText != null
                                    ? Icons.check_rounded
                                    : Icons.download_rounded,
                                color: _fetchedInfoText != null
                                    ? Colors.greenAccent
                                    : Colors.white70,
                                size: 18,
                              ),
                        label: Text(
                          _isFetchingInfo
                              ? 'Extrayendo...'
                              : (_fetchedInfoText != null
                                  ? 'Datos extraídos — incluidos en el prompt'
                                  : 'Extraer datos de Nivel20'),
                          style: GoogleFonts.inter(
                            color: _fetchedInfoText != null
                                ? Colors.greenAccent
                                : Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    if (_linkError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _linkError!,
                        style: GoogleFonts.inter(color: AppColors.danger, fontSize: 12.5),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Caja del prompt
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 260),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: _isLoadingTemplate
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              ),
                            )
                          : _loadError != null
                              ? Text(
                                  _loadError!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.5,
                                    color: AppColors.danger,
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: SelectableText(
                                    _fullPrompt,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.5,
                                      color: Colors.white.withOpacity(0.75),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                    ),
                    const SizedBox(height: 14),

                    // Botón copiar
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (_isLoadingTemplate || _loadError != null)
                            ? null
                            : _copyPrompt,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: _copied
                                ? Colors.greenAccent.withOpacity(0.5)
                                : Colors.white.withOpacity(0.15),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          color: _copied ? Colors.greenAccent : Colors.white70,
                          size: 18,
                        ),
                        label: Text(
                          _copied ? "¡Copiado!" : "Copiar prompt",
                          style: GoogleFonts.inter(
                            color: _copied ? Colors.greenAccent : Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "PASO 2",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.35),
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      "Cuando la IA te devuelva el JSON, pégalo aquí para crear tu personaje.",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo para pegar el JSON
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _errorText != null
                              ? AppColors.danger.withOpacity(0.6)
                              : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: TextField(
                        controller: _jsonController,
                        maxLines: 8,
                        minLines: 5,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                        cursorColor: accent,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.all(16),
                          border: InputBorder.none,
                          hintText: '{ "basic_info": { ... }, ... }',
                          hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.25)),
                        ),
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorText!,
                        style: GoogleFonts.inter(color: AppColors.danger, fontSize: 12.5),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Botón real de importar JSON — mismo lenguaje visual
                    // que el CTA de welcome_screen: el acento vive en el
                    // borde y el icono, no en un relleno sólido.
                    SizedBox(
                      width: double.infinity,
                      child: Container(
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
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _isImporting ? null : _importJson,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 17),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isImporting)
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: accent,
                                      ),
                                    )
                                  else
                                    Icon(Icons.add_circle_outline, color: accent, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isImporting ? "Importando..." : "Importar personaje (JSON)",
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
                    const SizedBox(height: 12),

                    // Vía alternativa: si el jugador ya tiene el JSON
                    // guardado como archivo (en vez de tenerlo copiado en
                    // el portapapeles), se salta el campo de texto entero.
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isImporting ? null : _importFromFile,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.folder_open, color: Colors.white70, size: 18),
                        label: Text(
                          'IMPORTAR ARCHIVO DIRECTAMENTE',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}