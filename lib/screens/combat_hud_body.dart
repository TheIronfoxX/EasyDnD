import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/hud_layout_repository.dart';
import '../models/hud_module.dart';
import '../providers/character_provider.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_theme_extension.dart';

/// Cuerpo reutilizable del HUD de combate: cuadrícula escalonada +
/// modo edición con drag & drop.
///
/// Vive separado de [CombatHudScreen] a propósito, para poder
/// incrustarse tal cual dentro de un tab de `MainHudScreen`
/// (ver `tabs/combat_hud_tab.dart`) sin arrastrar un Scaffold/AppBar
/// propio ni duplicar la lógica de estado.
///
/// Fase 6: ya no hay colores hardcodeados. Superficie/borde/texto
/// salen de `context.appColors` (respetan claro/oscuro automáticamente)
/// y todo lo que antes era ámbar fijo (borde de edición, resaltado de
/// drag target) ahora usa el `accentColor` libre de [ThemeNotifier].
class CombatHudBody extends StatefulWidget {
  const CombatHudBody({super.key});

  @override
  State<CombatHudBody> createState() => _CombatHudBodyState();
}

class _CombatHudBodyState extends State<CombatHudBody> {
  bool isEditMode = false;
  bool _isLoadingLayout = true;

  final HudLayoutRepository _layoutRepository = HudLayoutRepository();

  /// Módulos "de fábrica": por ahora dummies de prueba, más adelante
  /// vendrán de los spells/stats reales del personaje. Es la fuente
  /// de verdad para title/emoji/type/targetReferenceId; el ORDEN y
  /// TAMAÑO reales que ve el jugador pueden venir sobreescritos por
  /// lo que haya guardado en `HudLayoutRepository`.
  static const List<HudModule> _defaultModules = [
    HudModule(
      id: 'mod_1',
      title: 'Bola de Fuego',
      emojiIcon: '🔥',
      type: 'attack',
      targetReferenceId: 'spell_fireball_001',
      crossAxisCellCount: 1,
      mainAxisCellCount: 1,
    ),
    HudModule(
      id: 'mod_2',
      title: 'Puntos de Vida',
      emojiIcon: '❤️',
      type: 'resource',
      targetReferenceId: 'stat_hp_current',
      crossAxisCellCount: 2,
      mainAxisCellCount: 1,
    ),
    HudModule(
      id: 'mod_3',
      title: 'Escudo Arcano',
      emojiIcon: '🛡️',
      type: 'spell',
      targetReferenceId: 'spell_arcane_shield_014',
      crossAxisCellCount: 2,
      mainAxisCellCount: 2,
    ),
    HudModule(
      id: 'mod_4',
      title: 'Rastreador de Turnos',
      emojiIcon: '⏳',
      type: 'counter',
      targetReferenceId: 'counter_turn_tracker',
      crossAxisCellCount: 4,
      mainAxisCellCount: 1,
    ),
  ];

  /// Lista real que se pinta en pantalla, ya fusionada con el layout
  /// guardado (orden y tamaño) DEL PERSONAJE ACTIVO. Empieza vacía
  /// mientras carga.
  List<HudModule> _modules = [];

  /// id del personaje cuyo layout está actualmente cargado en
  /// `_modules`. Null mientras no se ha cargado nada todavía.
  String? _loadedForCharacterId;

  /// id del personaje cuya carga ya se disparó pero aún no termina,
  /// para no lanzar la misma carga dos veces si el widget se
  /// reconstruye mientras tanto.
  String? _pendingLoadCharacterId;

  Future<void> _loadLayoutForCharacter(String characterId) async {
    setState(() => _isLoadingLayout = true);
    final loaded = await _layoutRepository.load(
      characterId: characterId,
      defaultModules: _defaultModules,
    );
    if (!mounted) return;
    setState(() {
      _modules = loaded;
      _isLoadingLayout = false;
      _loadedForCharacterId = characterId;
      _pendingLoadCharacterId = null;
    });
  }

  /// Persiste el orden/tamaño actual del personaje [characterId]. Se
  /// llama después de cada reordenamiento; si falla (ej. sin espacio,
  /// error de IO), no rompe la UI — el HUD sigue funcionando en
  /// memoria para esta sesión, solo no queda guardado para la
  /// próxima.
  void _persistLayout(String characterId) {
    _layoutRepository
        .save(characterId: characterId, modules: _modules)
        .catchError((e) {
      debugPrint('No se pudo guardar el layout del HUD: $e');
    });
  }

  /// Borra el layout guardado de [characterId] y vuelve a los módulos
  /// de fábrica.
  Future<void> _resetLayout(String characterId) async {
    await _layoutRepository.reset(characterId: characterId);
    if (!mounted) return;
    setState(() => _modules = List.of(_defaultModules));
  }

  void _toggleEditMode() {
    setState(() => isEditMode = !isEditMode);
  }

  /// Acción "real" del módulo cuando el HUD está bloqueado. En
  /// producción esto dispararía el hechizo / abriría el contador real
  /// usando [HudModule.targetReferenceId].
  void _triggerModuleAction(HudModule module) {
    print(
      'Acción disparada -> type: ${module.type}, '
      'targetReferenceId: ${module.targetReferenceId}',
    );
  }

  void _reorderModules(HudModule moved, HudModule target, String characterId) {
    if (moved.id == target.id) return;
    setState(() {
      final fromIndex = _modules.indexWhere((m) => m.id == moved.id);
      final toIndex = _modules.indexWhere((m) => m.id == target.id);
      if (fromIndex == -1 || toIndex == -1) return;
      final item = _modules.removeAt(fromIndex);
      _modules.insert(toIndex, item);
    });
    _persistLayout(characterId);
  }

  @override
  Widget build(BuildContext context) {
    // accentColor es el color libre elegido por el jugador vía el
    // HsvColorPickerDialog (ThemeNotifier), no un preset fijo.
    final accent = context.watch<ThemeNotifier>().accentColor;

    // El HUD escucha al personaje ACTIVO del roster. Si cambia (el
    // jugador cambió de ficha desde CharacterSelectionScreen), el id
    // ya no coincide con `_loadedForCharacterId` y disparamos la
    // carga del layout de ese otro personaje.
    final characterId = context.watch<CharacterProvider>().character.id;

    if (characterId != _loadedForCharacterId &&
        characterId != _pendingLoadCharacterId) {
      _pendingLoadCharacterId = characterId;
      // No se puede llamar setState en medio de un build: se agenda
      // la carga real para justo después de este frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLayoutForCharacter(characterId);
      });
    }

    return Column(
      children: [
        _buildHeader(context, accent, characterId),
        Expanded(
          child: _isLoadingLayout
              ? Center(child: CircularProgressIndicator(color: accent))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: StaggeredGrid.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: _modules.map((module) {
                      return StaggeredGridTile.count(
                        key: ValueKey(module.id),
                        crossAxisCellCount: module.crossAxisCellCount,
                        mainAxisCellCount: module.mainAxisCellCount,
                        child: _buildModuleTile(context, module, accent, characterId),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  /// Cabecera compacta propia del HUD (título + candado + reset). No
  /// es un AppBar real: vive dentro del cuerpo para poder incrustarse
  /// en cualquier contenedor (tab o pantalla independiente) sin
  /// pelearse por quién controla la AppBar de verdad de la app.
  Widget _buildHeader(BuildContext context, Color accent, String characterId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Text(
            'HUD DE COMBATE',
            style: GoogleFonts.inter(
              color: context.appColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          if (isEditMode)
            IconButton(
              icon: Icon(Icons.restart_alt, color: context.appColors.textSecondary),
              tooltip: 'Restablecer layout',
              onPressed: () => _resetLayout(characterId),
            ),
          IconButton(
            icon: Icon(
              isEditMode ? Icons.lock_open : Icons.lock,
              color: isEditMode ? accent : context.appColors.textSecondary,
            ),
            tooltip: isEditMode ? 'Salir de edición' : 'Editar HUD',
            onPressed: _toggleEditMode,
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTile(
    BuildContext context,
    HudModule module,
    Color accent,
    String characterId,
  ) {
    final tile = _ModuleContainer(module: module, isEditMode: isEditMode, accent: accent);

    if (!isEditMode) {
      // Bloqueado: el tap dispara la acción real del botón.
      return GestureDetector(
        onTap: () => _triggerModuleAction(module),
        child: tile,
      );
    }

    // Modo edición: el bloque se puede arrastrar y también actúa como
    // destino para recibir a otros bloques arrastrados.
    return DragTarget<HudModule>(
      onWillAcceptWithDetails: (details) => details.data.id != module.id,
      onAcceptWithDetails: (details) => _reorderModules(details.data, module, characterId),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return LongPressDraggable<HudModule>(
          data: module,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: SizedBox(
                width: 90.0 * module.crossAxisCellCount,
                height: 90.0 * module.mainAxisCellCount,
                child: tile,
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: tile),
          child: isHovering ? _HighlightWrapper(accent: accent, child: tile) : tile,
        );
      },
    );
  }
}

/// Resalta el bloque que está a punto de recibir un módulo arrastrado
/// encima. Usa el accentColor dinámico en vez de un ámbar fijo.
class _HighlightWrapper extends StatelessWidget {
  final Widget child;
  final Color accent;

  const _HighlightWrapper({required this.child, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent, width: 2),
      ),
      child: child,
    );
  }
}

/// Diseño visual "industrial" de cada módulo, ahora sobre el sistema
/// de colores dinámicos: superficie/borde salen de `context.appColors`
/// (respetan claro/oscuro automáticamente) y el resaltado de edición
/// usa el accent libre del jugador en vez de un color fijo.
class _ModuleContainer extends StatelessWidget {
  final HudModule module;
  final bool isEditMode;
  final Color accent;

  const _ModuleContainer({
    required this.module,
    required this.isEditMode,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEditMode ? accent.withOpacity(0.7) : context.appColors.border,
          width: isEditMode ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(module.emojiIcon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                module.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: context.appColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${module.crossAxisCellCount}x${module.mainAxisCellCount}',
                style: GoogleFonts.inter(
                  color: context.appColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          if (isEditMode)
            Positioned(
              top: 0,
              right: 0,
              child: Icon(
                Icons.drag_indicator,
                size: 16,
                color: context.appColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}