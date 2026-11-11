// Tests del extractor de Nivel20.
//
// El HTTP va por MockClient (cero red): los tests cubren la resolución
// de enlaces (largo/corto/normalización), los mensajes de error
// amigables para el jugador, el desenvolvimiento de "printable_hash" y
// la limpieza recursiva de HTML sobre todo el árbol del JSON.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:easydnd/data/nivel20_extractor.dart';

void main() {
  group('cleanRawJsonString', () {
    test('desenvuelve printable_hash y limpia HTML en strings hoja', () {
      final raw = jsonEncode({
        'printable_hash': {
          'info': {
            'name': 'Kaelen',
            'bio': '<p>Hola<br/>mundo</p>',
            'nested': ['<strong>x</strong>', 42, true, null],
          },
        },
      });

      final cleaned = Nivel20Extractor.cleanRawJsonString(raw);
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;

      // Desenvuelto: la raíz es la ficha, no el envoltorio.
      expect(decoded.containsKey('info'), isTrue);
      final info = decoded['info'] as Map<String, dynamic>;
      expect(info['name'], 'Kaelen');
      // <br> → salto, </p><p> → salto doble, tags fuera.
      expect(info['bio'], 'Hola\nmundo');
      // Números/bools/null intactos; limpieza solo en strings.
      expect(info['nested'], ['x', 42, true, null]);
    });

    test('con "info" en la raíz no desenvuelve nada', () {
      final raw = jsonEncode({
        'info': {'name': 'Directo'},
      });
      final decoded =
          jsonDecode(Nivel20Extractor.cleanRawJsonString(raw)) as Map;
      expect(decoded['info'], isNotNull);
      expect(decoded.containsKey('printable_hash'), isFalse);
    });

    test('entidades HTML se traducen', () {
      final raw = jsonEncode({'a': 'ca&ntilde;a &amp; &lt;b&gt;'});
      final decoded =
          jsonDecode(Nivel20Extractor.cleanRawJsonString(raw)) as Map;
      expect(decoded['a'], 'caña & <b>');
    });

    test('json no-objeto revienta con FormatException', () {
      expect(
        () => Nivel20Extractor.cleanRawJsonString('[1,2]'),
        throwsFormatException,
      );
    });
  });

  group('extractInfoText', () {
    test('link largo: descarga el .json, lo limpia y lo indenta', () async {
      final body = jsonEncode({
        'info': {
          'name': 'Kaelen',
          'bio': '<p>Uno</p><p>Dos</p>',
        },
      });

      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://nivel20.com/games/abc/characters/12-k.json',
        );
        return http.Response(body, 200);
      });

      final text = await Nivel20Extractor.extractInfoText(
        'https://nivel20.com/games/abc/characters/12-k',
        client: client,
      );

      final decoded = jsonDecode(text) as Map<String, dynamic>;
      expect((decoded['info'] as Map)['name'], 'Kaelen');
      expect((decoded['info'] as Map)['bio'], 'Uno\n\nDos');
      // Indentado legible para el prompt.
      expect(text, contains('\n  '));
    });

    test('link corto: resuelve el largo desde el HTML y baja el json', () async {
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url == 'https://nivel20.com/s/abc123') {
          return http.Response(
            '<html><head><link rel="canonical" '
            'href="https://nivel20.com/games/g/characters/7-x"></head></html>',
            200,
          );
        }
        if (url == 'https://nivel20.com/games/g/characters/7-x.json') {
          return http.Response(jsonEncode({'info': {'name': 'Ok'}}), 200);
        }
        fail('URL inesperada: $url');
      });

      final text = await Nivel20Extractor.extractInfoText(
        'https://nivel20.com/s/abc123',
        client: client,
      );
      expect((jsonDecode(text) as Map)['info']['name'], 'Ok');
    });

    test('normaliza barra final y sufijo .json de sobra', () async {
      late String requested;
      final client = MockClient((request) async {
        requested = request.url.toString();
        return http.Response(jsonEncode({'info': {}}), 200);
      });

      await Nivel20Extractor.extractInfoText(
        'https://nivel20.com/games/g/characters/7-x.json/',
        client: client,
      );

      expect(requested, 'https://nivel20.com/games/g/characters/7-x.json');
    });

    test('respuesta HTML: error que explica la ficha no pública', () async {
      final client = MockClient(
        (request) async => http.Response('<html><body>login</body></html>', 200),
      );

      await expectLater(
        Nivel20Extractor.extractInfoText(
          'https://nivel20.com/games/g/characters/7-x',
          client: client,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          allOf(contains('página web'), contains('pública')),
        )),
      );
    });

    test('status de error: lo reporta con el código', () async {
      final client = MockClient(
        (request) async => http.Response('nope', 403),
      );

      await expectLater(
        Nivel20Extractor.extractInfoText(
          'https://nivel20.com/games/g/characters/7-x',
          client: client,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('(403)'),
        )),
      );
    });

    test('json roto: error que sugiere revisar el .json', () async {
      final client = MockClient(
        (request) async => http.Response('{esto no es json', 200),
      );

      await expectLater(
        Nivel20Extractor.extractInfoText(
          'https://nivel20.com/games/g/characters/7-x',
          client: client,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('.json'),
        )),
      );
    });

    test('link corto sin ficha atrás: error que pide la URL larga', () async {
      final client = MockClient(
        (request) async => http.Response('<html>nada</html>', 200),
      );

      await expectLater(
        Nivel20Extractor.extractInfoText(
          'https://nivel20.com/s/abc123',
          client: client,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          allOf(contains('enlace corto'), contains('"/characters/"')),
        )),
      );
    });

    test('input vacío: falla antes de cualquier request', () async {
      final client = MockClient(
        (request) async => fail('no debería haber pedido nada'),
      );

      await expectLater(
        Nivel20Extractor.extractInfoText('', client: client),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('Pega primero el enlace'),
        )),
      );
    });

    test('link sin esquema: error amigable de copia desde el navegador', () async {
      final client = MockClient(
        (request) async => fail('no debería haber pedido nada'),
      );

      await expectLater(
        Nivel20Extractor.extractInfoText('nivel20.com/s/abc123', client: client),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('no parece válido'),
        )),
      );
    });
  });
}
