import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import 'combat_hud_body.dart';

/// Pantalla independiente del HUD de combate.
///
/// Fase 6: toda la lógica real (grid asimétrico, drag & drop, modo
/// edición) vive ahora en [CombatHudBody]. Esta pantalla solo aporta
/// el Scaffold/AppBar para los casos en que se navegue a ella fuera
/// del sistema de tabs de MainHudScreen (ej. un acceso directo desde
/// otro punto de la app). Dentro de MainHudScreen se usa en cambio
/// `tabs/combat_hud_tab.dart`, que reutiliza el mismo CombatHudBody
/// sin Scaffold propio.
class CombatHudScreen extends StatelessWidget {
  const CombatHudScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: context.appColors.background,
        foregroundColor: context.appColors.textPrimary,
        elevation: 0,
        title: const Text('HUD de Combate'),
      ),
      body: const CombatHudBody(),
    );
  }
}
