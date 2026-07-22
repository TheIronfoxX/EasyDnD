import 'package:flutter/material.dart';

import '../combat_hud_body.dart';

/// Envoltorio delgado para incrustar el HUD de combate como un tab
/// más dentro de `MainHudScreen`.
///
/// Toda la lógica real (cuadrícula escalonada, drag & drop, modo
/// edición, theming dinámico) vive en [CombatHudBody]. Este archivo
/// solo existe para que la lista de tabs de MainHudScreen sea
/// simétrica con el resto (stats_tab.dart, turn_tab.dart, etc.) y
/// para dejar un lugar natural donde, en el futuro, inyectar por
/// ejemplo el personaje activo si el HUD llega a necesitarlo.
class HudTab extends StatelessWidget {
  const HudTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CombatHudBody();
  }
}
