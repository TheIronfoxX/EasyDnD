// lib/utils/nivel20_extractor.dart
//
// Puente Nivel20 -> Prompt de IA.
//
// Ya NO construye un CharacterModel a partir del JSON de Nivel20. Su único
// trabajo ahora es: resolver el link que pega el jugador (largo o corto),
// descargar el JSON crudo de la ficha, quitarle el HTML de las
// descripciones (Nivel20 mete <p>, <br>, entidades... en casi todos los
// campos de texto) y devolverlo como texto legible para incrustarlo dentro
// del prompt que el jugador copia a su IA de confianza. Es la IA quien se
// encarga de traducirlo al JSON que espera la app — este extractor solo
// evita que el jugador tenga que copiar/pegar la ficha a mano.

import 'dart:convert';

import 'package:http/http.dart' as http;

class Nivel20Extractor {
  Nivel20Extractor._(); // clase estática, no se instancia.

  // ---------------------------------------------------------------------
  // PUNTO DE ENTRADA
  // ---------------------------------------------------------------------

  /// Recibe el link que pegó el jugador (largo o corto de "Compartir"),
  /// descarga la ficha de Nivel20 y devuelve su JSON ya limpio de HTML,
  /// formateado con indentación para que sea legible dentro del prompt.
  ///
  /// Lanza [Exception] con un mensaje en español listo para mostrar en la
  /// UI si el link no es válido, la ficha no es pública, o la respuesta no
  /// es JSON reconocible.
  static Future<String> extractInfoText(String rawLink) async {
    final jsonUrl = await _resolveJsonUrl(rawLink);
    final uri = Uri.parse(jsonUrl);

    final response = await http
        .get(uri, headers: _browserHeaders)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Nivel20 respondió con un error (${response.statusCode}). '
        'Comprueba que la ficha sea pública y que el enlace sea correcto.',
      );
    }

    final body = response.body.trim();
    final looksLikeJson = body.startsWith('{') || body.startsWith('[');
    if (!looksLikeJson) {
      final looksLikeHtml = body.toLowerCase().contains('<html') ||
          body.toLowerCase().contains('<!doctype');
      final preview = body.length > 140 ? '${body.substring(0, 140)}…' : body;
      throw Exception(
        looksLikeHtml
            ? 'Nivel20 ha devuelto una página web en vez del JSON. Suele '
                'pasar cuando la ficha no está realmente marcada como '
                'pública. Abre ese mismo enlace con ".json" al final en el '
                'navegador: si no ves el JSON ahí tampoco, la ficha no es '
                'pública todavía.'
            : 'Nivel20 no ha devuelto un JSON reconocible. Contenido '
                'recibido: "$preview"',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'El enlace no ha devuelto un JSON válido. Revisa que acabe en '
        '".json" y que la ficha esté marcada como pública en Nivel20.',
      );
    }

    final unwrapped = _unwrapPrintableHash(decoded);
    final cleaned = _cleanJsonTree(unwrapped);

    return const JsonEncoder.withIndent('  ').convert(cleaned);
  }

  /// Variante de conveniencia si en algún punto ya se tiene el JSON crudo
  /// como String (p.ej. pegado directamente desde la web) y no hace falta
  /// resolver ningún link.
  static String cleanRawJsonString(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final unwrapped = _unwrapPrintableHash(decoded);
    final cleaned = _cleanJsonTree(unwrapped);
    return const JsonEncoder.withIndent('  ').convert(cleaned);
  }

  // ---------------------------------------------------------------------
  // RESOLUCIÓN DE LINKS
  // ---------------------------------------------------------------------

  static final RegExp _shortLinkRegex = RegExp(r'nivel20\.com/s/([A-Za-z0-9]+)');
  static final RegExp _longLinkRegex =
      RegExp(r'nivel20\.com/games/[^/]+/characters/\d+');

  /// Encuentra un enlace largo de ficha (`/games/.../characters/<id>...`)
  /// embebido dentro de una página HTML — típicamente en un
  /// `<link rel="canonical">` o una meta `og:url`, que las páginas de
  /// "Compartir" suelen incluir para las vistas previas de redes sociales.
  static final RegExp _longLinkPathRegex =
      RegExp(r'/games/[^"\s]+/characters/\d+[^"\s]*');

  /// Muchos sitios (Nivel20 incluido, a través de su CDN) devuelven una
  /// página HTML en vez del recurso pedido cuando detectan que la petición
  /// no viene de un navegador real. Estas cabeceras hacen que la petición
  /// se parezca a la de un navegador normal y piden explícitamente JSON.
  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  };

  /// Nivel20 tiene dos formatos de enlace para una misma ficha:
  ///
  /// - El largo, tipo `.../games/<partida>/characters/<id>-<slug>` — es el
  ///   que da el JSON en crudo simplemente añadiéndole ".json" al final.
  /// - El corto, tipo `.../s/<hash>` — el que genera el botón "Compartir"
  ///   de Nivel20. Añadirle ".json" a este NO funciona; hay que resolverlo
  ///   primero hasta el enlace largo de la ficha.
  ///
  /// Esta función acepta cualquiera de los dos.
  static Future<String> _resolveJsonUrl(String rawInput) async {
    var url = rawInput.trim();
    if (url.isEmpty) {
      throw Exception('Pega primero el enlace de tu ficha de Nivel20.');
    }

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.toLowerCase().endsWith('.json')) {
      url = url.substring(0, url.length - 5);
    }

    if (Uri.tryParse(url)?.hasScheme != true) {
      throw Exception(
        'Ese enlace no parece válido. Cópialo tal cual desde la barra del navegador.',
      );
    }

    // Caso 1: ya es el enlace largo de ficha.
    if (_longLinkRegex.hasMatch(url)) {
      return '$url.json';
    }

    // Caso 2: enlace corto de "Compartir". Hay que seguirlo hasta la ficha
    // larga primero.
    if (_shortLinkRegex.hasMatch(url)) {
      final shortResponse = await http
          .get(Uri.parse(url), headers: _browserHeaders)
          .timeout(const Duration(seconds: 15));

      final match = _longLinkPathRegex.firstMatch(shortResponse.body);
      if (match != null) {
        return 'https://nivel20.com${match.group(0)}.json';
      }

      throw Exception(
        'No he podido encontrar la ficha completa a partir de ese enlace '
        'corto. Abre el enlace en el navegador, entra en la ficha y copia '
        'la URL larga de la página (la que tiene "/characters/" en medio) '
        'en vez del enlace corto de "Compartir".',
      );
    }

    // Formato no reconocido: lo intentamos tal cual, por si acaso.
    return '$url.json';
  }

  // ---------------------------------------------------------------------
  // DESENVOLTORIO
  // ---------------------------------------------------------------------

  /// Algunos exports de Nivel20 envuelven la ficha entera dentro de una
  /// única clave "printable_hash" en vez de traer "info" directamente en
  /// la raíz. Si detectamos ese envoltorio, lo desenvolvemos aquí.
  static Map<String, dynamic> _unwrapPrintableHash(Map<String, dynamic> n) {
    if (n.containsKey('info')) return n;
    final wrapped = n['printable_hash'];
    if (wrapped is Map) return Map<String, dynamic>.from(wrapped);
    return n;
  }

  // ---------------------------------------------------------------------
  // LIMPIEZA DE HTML (recursiva sobre todo el árbol del JSON)
  // ---------------------------------------------------------------------

  static final RegExp _tagRegex = RegExp(r'<[^>]*>');
  static final RegExp _multiSpaceRegex = RegExp(r'[ \t]{2,}');
  static final RegExp _multiNewlineRegex = RegExp(r'\n{3,}');

  static const _entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&aacute;': 'á',
    '&eacute;': 'é',
    '&iacute;': 'í',
    '&oacute;': 'ó',
    '&uacute;': 'ú',
    '&ntilde;': 'ñ',
  };

  /// Purga etiquetas HTML (<p>, <br>, <strong>...) y entidades comunes de
  /// un String, dejando texto plano legible.
  static String _clean(String raw) {
    var text = raw;

    // <br> y </p><p> se convierten en saltos de línea reales antes de
    // borrar el resto de etiquetas, para no dejar todo el texto pegado.
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(
        RegExp(r'</p>\s*<p[^>]*>', caseSensitive: false), '\n\n');

    text = text.replaceAll(_tagRegex, '');

    _entities.forEach((key, value) => text = text.replaceAll(key, value));

    text = text.replaceAll(_multiSpaceRegex, ' ');
    text = text.replaceAll(_multiNewlineRegex, '\n\n');
    text = text.replaceAll('\r\n', '\n');

    return text.trim();
  }

  /// Recorre recursivamente Maps/Lists del JSON decodificado y aplica
  /// [_clean] a cada valor String hoja, dejando números/bools/null tal
  /// cual. Así no hay que conocer de antemano qué claves concretas traen
  /// HTML (Nivel20 lo mete en descripciones, notas, historia...).
  static dynamic _cleanJsonTree(dynamic value) {
    if (value is String) return _clean(value);
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), _cleanJsonTree(v)));
    }
    if (value is List) {
      return value.map(_cleanJsonTree).toList();
    }
    return value;
  }
}