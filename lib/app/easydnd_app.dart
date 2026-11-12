import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/hud/startup_gate.dart';
import '../state/character_store.dart';

/// Raíz del árbol de widgets de EasyDnD.
///
/// El CharacterStore vive acá (por encima del MaterialApp, así también
/// lo ven las pantallas que se apilen encima) y se inyecta por valor con
/// un ChangeNotifierProvider: lo construye y lo inicializa main() una
/// sola vez, antes de pintar, y así las pantallas que lo miran con
/// context.watch se re-renderizan cuando el roster cambia.
///
/// Desde la Etapa 5 el home es la StartupGate: decide entre bienvenida
/// (roster vacío) y HUD de combate (con fichas), y el estado "cargando"
/// para cuando el store todavía no terminó init().
///
/// La Etapa 6 agrega acá el SkinController y el sistema de tokens de
/// diseño.
class EasyDnDApp extends StatelessWidget {
  const EasyDnDApp({super.key, required this.store});

  final CharacterStore store;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CharacterStore>.value(
      value: store,
      child: MaterialApp(
        title: 'EasyDnD',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // La app siempre arrancó en oscuro: lo dejamos explícito hasta que
        // exista la preferencia persistida de tema (Etapa 6).
        themeMode: ThemeMode.dark,
        home: const StartupGate(),
      ),
    );
  }
}
