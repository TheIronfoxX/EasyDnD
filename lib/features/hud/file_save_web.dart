// Descarga de un archivo de texto en la web: Blob + ancla `download`.
//
// Se hace a mano (en vez de FilePicker.saveFile) porque ese plugin abre
// el enlace en una pestaña nueva y revoca la URL del Blob al instante, y
// Chrome puede cancelar la descarga ("Error de red") o bloquear la
// ventana. Aquí el ancla va en el DOM, sin pestaña nueva, y la URL se
// revoca con calma.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> saveTextFile(String text, String fileName) async {
  final blob = web.Blob(
    [text.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  await Future<void>.delayed(const Duration(seconds: 4));
  web.URL.revokeObjectURL(url);
}
