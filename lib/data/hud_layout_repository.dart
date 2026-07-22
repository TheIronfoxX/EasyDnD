import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hud_module.dart';

/// Persiste el layout del HUD de combate (orden y tamaño de cada
/// módulo) en `SharedPreferences`, namespaceado por personaje: cada
/// entrada del roster tiene su propio layout guardado, indexado por
/// `CharacterModel.id`.
///
/// Importante: solo se guarda POSICIÓN y TAMAÑO, no el contenido "de
/// verdad" del módulo (title, emojiIcon, type, targetReferenceId).
/// Esos siguen viniendo siempre de la fuente de datos real (por ahora
/// la lista dummy de `CombatHudBody`; más adelante los spells/stats
/// reales de CADA personaje). Así, si el nombre o el ícono de un
/// módulo cambia en el futuro, el layout guardado no se queda con
/// datos viejos — solo recuerda "dónde" iba y "qué tan grande" era.
class HudLayoutRepository {
  static const _layoutPrefsKeyPrefix = 'hud_layout_v1';

  String _keyFor(String characterId) => '${_layoutPrefsKeyPrefix}_$characterId';

  /// Carga el layout guardado del personaje [characterId] y lo
  /// fusiona con [defaultModules]:
  /// - Un módulo guardado que ya no existe en los defaults (porque se
  ///   eliminó ese tipo de módulo del juego) se descarta.
  /// - Un módulo nuevo en los defaults que no estaba guardado (porque
  ///   se añadió después de la última vez que el jugador guardó su
  ///   layout) se agrega al final, en su orden original.
  /// - De los módulos que sí coinciden por `id`, el orden y el tamaño
  ///   (`crossAxisCellCount` / `mainAxisCellCount`) salen del guardado;
  ///   el resto de los campos (title, emojiIcon, etc.) salen siempre
  ///   del default actual, nunca del guardado.
  Future<List<HudModule>> load({
    required String characterId,
    required List<HudModule> defaultModules,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(characterId));
    if (raw == null) return List.of(defaultModules);

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final saved = decoded
          .map((e) => HudModule.fromJson(e as Map<String, dynamic>))
          .toList();

      final pendingDefaults = {for (final m in defaultModules) m.id: m};
      final merged = <HudModule>[];

      for (final savedModule in saved) {
        final currentDefault = pendingDefaults.remove(savedModule.id);
        if (currentDefault == null) continue; // el módulo ya no existe
        merged.add(currentDefault.copyWith(
          crossAxisCellCount: savedModule.crossAxisCellCount,
          mainAxisCellCount: savedModule.mainAxisCellCount,
        ));
      }

      // Módulos nuevos que no estaban en el guardado: al final,
      // respetando el orden de defaultModules.
      for (final m in defaultModules) {
        if (pendingDefaults.containsKey(m.id)) merged.add(m);
      }

      return merged;
    } catch (_) {
      // Layout corrupto o de un formato antiguo: no rompemos el HUD,
      // simplemente volvemos a los valores por defecto.
      return List.of(defaultModules);
    }
  }

  /// Guarda el orden y tamaño actual de [modules] para el personaje
  /// [characterId].
  Future<void> save({
    required String characterId,
    required List<HudModule> modules,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(modules.map((m) => m.toJson()).toList());
    await prefs.setString(_keyFor(characterId), encoded);
  }

  /// Borra el layout guardado de [characterId], para volver a los
  /// valores por defecto.
  Future<void> reset({required String characterId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(characterId));
  }
}