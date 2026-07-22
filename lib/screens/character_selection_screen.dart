// lib/screens/character_selection_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/character_provider.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_colors.dart';
import 'prompt_screen.dart';

/// Fase 12 — Pantalla de selección de personaje. Estética "Nothing OS":
/// fondo negro puro, tipografía Inter en blanco para lo neutro y en el
/// acento dinámico del jugador (ThemeNotifier) para lo interactivo, mucho
/// aire entre elementos y bordes finos en vez de sombras pesadas. El rojo
/// de sistema (AppColors.danger) queda reservado para lo destructivo:
/// purgar un personaje.
class CharacterSelectionScreen extends StatelessWidget {
  const CharacterSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final accent = context.watch<ThemeNotifier>().accentColor;
    final roster = provider.roster;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'PERSONAJES',
          style: GoogleFonts.inter(
            color: Colors.white,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: roster.isEmpty
          ? Center(
              child: Text(
                'Sin personajes todavía.',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: roster.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final char = roster[index];
                final isActive = index == provider.activeIndex;

                return _CharacterTile(
                  name: char.basicInfo.name,
                  subtitle: [char.basicInfo.race, char.basicInfo.characterClass]
                      .where((s) => s.trim().isNotEmpty)
                      .join(' · '),
                  avatarPath: char.avatarPath,
                  isActive: isActive,
                  accent: accent,
                  onTap: () {
                    provider.switchCharacter(index);
                    Navigator.of(context).pop();
                  },
                  onDelete: () => _showDeleteConfirmationDialog(
                    context,
                    provider,
                    index,
                    char.basicInfo.name,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.file_upload_outlined),
        label: Text(
          'IMPORTAR FICHA',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        onPressed: () => _showImportOptions(context, provider, accent),
      ),
    );
  }

  /// Diálogo de confirmación de "Autodestrucción" antes de borrar un
  /// personaje del roster. Estética oscura con borde rojo de sistema,
  /// coherente con el resto de diálogos de la app.
  void _showDeleteConfirmationDialog(
    BuildContext context,
    CharacterProvider provider,
    int index,
    String name,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.danger.withOpacity(0.5), width: 1.2),
          ),
          title: Text(
            'AUTODESTRUCCIÓN',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          content: Text(
            '¿Vas a purgar a "$name" del roster? Esta acción no se puede deshacer.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancelar', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                context.read<CharacterProvider>().deleteCharacter(index);
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Purgar',
                style: GoogleFonts.inter(color: AppColors.danger, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Fase 12 (ampliación): además de elegir un .json del dispositivo, el
  /// jugador puede pegar el JSON directamente (útil cuando lo copió de un
  /// chat o de una web y no lo tiene guardado como archivo). Un bottom
  /// sheet simple con las dos opciones, misma estética Nothing OS.
  void _showImportOptions(
    BuildContext context,
    CharacterProvider provider,
    Color accent,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _importFromFile(context, provider);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: accent.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.folder_open, color: accent, size: 20),
                            const SizedBox(width: 14),
                            Text(
                              'Seleccionar archivo .json',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showPasteJsonDialog(context, provider, accent);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: accent.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.content_paste, color: accent, size: 20),
                            const SizedBox(width: 14),
                            Text(
                              'Pegar JSON directamente',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Tercera vía: la misma PromptScreen a la que se llega tras
                // la welcome screen — extrae el JSON de la ficha de Nivel20
                // directo de la web y genera el prompt para refinarlo con
                // una IA. Navegación directa, sin enlace pre-rellenado
                // (el jugador lo pega ya en la propia PromptScreen).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PromptScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: accent.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome, color: accent, size: 20),
                            const SizedBox(width: 14),
                            Text(
                              'Extraer de Nivel20',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
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
        );
      },
    );
  }

  /// Abre el selector de archivos del sistema restringido a `.json` y
  /// delega el parseo/validación en `CharacterProvider.importCharacterFromJsonString`,
  /// la misma ruta que ya usan el diálogo de "pegar JSON" y prompt_screen.
  /// El `messenger` se captura antes del `await` porque, si el usuario
  /// cierra la pantalla mientras el picker está abierto, `context` podría
  /// dejar de ser válido al volver.
  Future<void> _importFromFile(
    BuildContext context,
    CharacterProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // allowedExtensions SIN el punto inicial ('json', no '.json'):
      // file_picker las compara literalmente contra la extensión del
      // archivo y con el punto delante nunca matchea nada.
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );

      // El usuario cerró el selector sin elegir nada: no es un error,
      // simplemente no hay nada que importar.
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) {
        throw const FormatException('No se pudo acceder a la ruta del archivo seleccionado.');
      }

      final file = File(path);
      final bytes = await file.readAsBytes();

      // Leemos como bytes en vez de file.readAsString() directamente
      // porque algunos editores (típicamente el Bloc de notas de Windows)
      // guardan el .json con un BOM (marca de orden de bytes) UTF-8 al
      // principio: un carácter invisible que rompe jsonDecode aunque el
      // archivo sea perfectamente válido a la vista. allowMalformed evita
      // que un encoding raro tumbe la lectura entera con una excepción
      // distinta a "JSON inválido".
      var raw = utf8.decode(bytes, allowMalformed: true);
      if (raw.isNotEmpty && raw.codeUnitAt(0) == 0xFEFF) {
        raw = raw.substring(1);
      }
      raw = raw.trim();

      // La validación real de que "raw" es un JSON de ficha válido vive
      // dentro del provider (misma lógica que usa el diálogo de pegado
      // y prompt_screen), así evitamos dos criterios distintos de qué
      // cuenta como ficha válida.
      await provider.importCharacterFromJsonString(raw);

      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Ficha importada desde archivo.', style: GoogleFonts.inter())),
      );
    } catch (e) {
      // Cualquier fallo (archivo corrupto, JSON inválido, permisos,
      // cancelación rara del picker, etc.) se notifica sin tumbar la app.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo importar el archivo: JSON inválido o corrupto.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Diálogo con un campo de texto multilínea para pegar el JSON de la
  /// ficha a mano. Si el texto no parsea, muestra el error en el propio
  /// diálogo en vez de cerrarlo, para que el jugador pueda corregir el
  /// pegado sin tener que reabrir todo el flujo.
  void _showPasteJsonDialog(
    BuildContext context,
    CharacterProvider provider,
    Color accent,
  ) {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: accent.withOpacity(0.35)),
              ),
              title: Text(
                'Pegar ficha JSON',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: 420,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 10,
                  minLines: 6,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: '{ "basic_info": { ... }, ... }',
                    hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                    errorText: errorText,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancelar', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await provider.importCharacterFromJsonString(controller.text);
                      Navigator.of(dialogContext).pop();
                      messenger.showSnackBar(
                        SnackBar(content: Text('Ficha importada al roster.', style: GoogleFonts.inter())),
                      );
                    } catch (_) {
                      setState(() => errorText = 'JSON inválido — revisa el formato.');
                    }
                  },
                  child: Text(
                    'Importar',
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

}

class _CharacterTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? avatarPath;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CharacterTile({
    required this.name,
    required this.subtitle,
    required this.avatarPath,
    required this.isActive,
    required this.accent,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? accent.withOpacity(0.7) : Colors.white.withOpacity(0.08),
              width: isActive ? 1.4 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.18),
                      blurRadius: 18,
                      spreadRadius: -6,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.06),
                backgroundImage:
                    avatarPath != null ? FileImage(File(avatarPath!)) : null,
                child: avatarPath == null
                    ? const Icon(Icons.person, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accent.withOpacity(0.5)),
                  ),
                  child: Text(
                    'ACTIVO',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                tooltip: 'Purgar personaje',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}