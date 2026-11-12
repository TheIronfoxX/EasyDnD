// Test de humo del arranque (Etapa 5): la app pasa por el estado de
// carga del store y, con el roster vacío, cae en la bienvenida. El HUD
// con fichas se prueba en hud_shell_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/state/character_store.dart';

void main() {
  testWidgets('mientras el store carga muestra el splash, después la '
      'bienvenida', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));

    await tester.pumpWidget(EasyDnDApp(store: store));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Importar ficha con IA'), findsNothing);

    await store.init();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('EasyDnD'), findsOneWidget);
    expect(find.text('Importar ficha con IA'), findsOneWidget);
    expect(find.text('Crear ficha a mano'), findsOneWidget);
  });
}
