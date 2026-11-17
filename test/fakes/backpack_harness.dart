// Arnés de la Mochila para tests: en la app cada sección (Armas, Objetos,
// Dinero) es una pantalla propia de la pestaña Mochila; aquí se montan
// juntas, con un botón "Dinero" que cambia a la bolsa, para probar las
// secciones sin la navegación del HUD.

import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/features/hud/hud_inventory_tab.dart';
import 'package:flutter/material.dart';

class BackpackHarness extends StatefulWidget {
  const BackpackHarness({super.key, required this.character});

  final CharacterModel character;

  @override
  State<BackpackHarness> createState() => _BackpackHarnessState();
}

class _BackpackHarnessState extends State<BackpackHarness> {
  bool _money = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    return ListView(
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _money = false),
              child: const Text('Equipo'),
            ),
            TextButton(
              onPressed: () => setState(() => _money = true),
              child: const Text('Dinero'),
            ),
          ],
        ),
        if (_money)
          HudPurseSection(character: c)
        else ...[
          HudWeaponsSection(character: c),
          HudItemsSection(character: c),
        ],
      ],
    );
  }
}
