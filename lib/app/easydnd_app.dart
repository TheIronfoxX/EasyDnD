import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/hud/startup_gate.dart';
import '../state/character_store.dart';
import '../state/skin_controller.dart';

/// Raíz del árbol de widgets de EasyDnD.
///
/// El CharacterStore y el SkinController viven acá (por encima del
/// MaterialApp, así también los ven las pantallas que se apilen encima)
/// y se inyectan por valor con ChangeNotifierProvider: main() los
/// construye e inicializa una sola vez, antes de pintar.
///
/// El SkinController se escucha para reconstruir MaterialApp cuando
/// cambia el acento o el modo. La Etapa 6 completa (picker de skin) usa
/// este mismo controlador.
class EasyDnDApp extends StatelessWidget {
  const EasyDnDApp({super.key, required this.store, required this.skin});

  final CharacterStore store;
  final SkinController skin;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CharacterStore>.value(value: store),
        ChangeNotifierProvider<SkinController>.value(value: skin),
      ],
      child: Consumer<SkinController>(
        builder: (context, skin, _) {
          return MaterialApp(
            title: 'EasyDnD',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(accent: skin.accentColor),
            darkTheme: AppTheme.dark(accent: skin.accentColor),
            themeMode: skin.themeMode,
            home: const StartupGate(),
          );
        },
      ),
    );
  }
}
