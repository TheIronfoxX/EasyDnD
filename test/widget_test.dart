// Test de humo de las etapas 1-3: verifica que el árbol de la app
// (MaterialApp + tema + Provider del store + pantalla provisoria) se
// construye sin explotar, con un store real sobre prefs mockeadas.
// En la Etapa 7 se reemplaza por la batería real de tests de widgets.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/state/character_store.dart';

void main() {
  testWidgets('la app arranca y muestra la pantalla provisoria', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();

    await tester.pumpWidget(EasyDnDApp(store: store));

    expect(find.text('EasyDnD'), findsOneWidget);
    expect(find.textContaining('Etapa 3/7'), findsOneWidget);
    // El roster arranca vacío: sin ficha activa, sin botón de corrección.
    expect(find.textContaining('Ficha activa'), findsNothing);
    expect(find.text('Importar ficha con IA'), findsOneWidget);
  });
}
