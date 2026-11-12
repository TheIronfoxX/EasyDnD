// Puerta de arranque del HUD (Etapa 5).
//
// Decide qué pantalla mostrar según el estado del store:
//   1. Store todavía cargando  → splash (solo pasa en tests o si un día
//      main() deja de esperar a init()).
//   2. Roster vacío            → bienvenida con las dos vías de alta.
//   3. Roster con fichas       → HUD de combate.
//
// Es un widget y no una decisión en main() a propósito: cuando el
// jugador borra la última ficha desde el HUD, el mismo árbol vuelve a
// la bienvenida sin reiniciar la app.
//
// En la app vieja el "no hay personajes" se disimulaba con una ficha
// mock siempre presente; acá el vacío es un estado real y explícito.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/character_store.dart';
import 'hud_screen.dart';
import 'welcome_screen.dart';

class StartupGate extends StatelessWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CharacterStore>();

    if (!store.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (store.roster.isEmpty) return const WelcomeScreen();

    return const HudScreen();
  }
}
