import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'placeholder_home.dart';

/// Raíz del árbol de widgets de EasyDnD.
///
/// Etapa 1 (fundaciones): por ahora monta el MaterialApp con el tema base
/// y la pantalla provisoria. Las etapas siguientes agregan acá:
///   - Etapa 2: los stores (Provider) de roster y ficha activa.
///   - Etapa 3/5: la StartupGate que decide entre onboarding y HUD
///     según si el roster migrado tiene fichas.
///   - Etapa 6: el SkinController y el sistema de tokens de diseño.
class EasyDnDApp extends StatelessWidget {
  const EasyDnDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyDnD',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // La app siempre arrancó en oscuro: lo dejamos explícito hasta que
      // exista la preferencia persistida de tema (Etapa 6).
      themeMode: ThemeMode.dark,
      home: const PlaceholderHome(),
    );
  }
}
