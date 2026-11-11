// Test de humo de la Etapa 1: verifica que el árbol mínimo de la app
// (MaterialApp + tema + pantalla provisoria) se construye sin explotar.
// En la Etapa 7 se reemplaza por la batería real de tests de widgets.

import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/app/easydnd_app.dart';

void main() {
  testWidgets('la app arranca y muestra la pantalla provisoria', (
    tester,
  ) async {
    await tester.pumpWidget(const EasyDnDApp());

    expect(find.text('EasyDnD'), findsOneWidget);
    expect(find.textContaining('Etapa 1/7'), findsOneWidget);
  });
}
