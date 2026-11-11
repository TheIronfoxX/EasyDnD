// Saneado de JSON pegado desde una IA.
//
// ChatGPT/Claude casi nunca devuelven JSON "puro": suele venir envuelto
// en un bloque de código Markdown (```json ... ```) y/o con texto de
// cortesía antes o después ("¡Aquí tienes tu personaje!", "Espero que
// lo disfrutes"...). jsonDecode() no tolera nada de eso y revienta con
// un FormatException genérico — este helper se queda solo con el objeto
// JSON real antes de intentar decodificarlo, para que el "texto extra"
// deje de ser un problema para el jugador.

/// Devuelve el substring que contiene (con suerte) el objeto JSON real.
/// Pasos:
///  1. Quita vallas de código Markdown si las hay (```json ... ```).
///  2. Se queda con lo que hay entre la primera '{' y la última '}',
///     por si aún queda texto de cortesía alrededor.
String sanitizeJsonText(String raw) {
  var text = raw.trim();

  final fenceMatch =
      RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false)
          .firstMatch(text);
  if (fenceMatch != null) {
    text = fenceMatch.group(1)!.trim();
  }

  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end != -1 && end > start) {
    text = text.substring(start, end + 1);
  }

  return text;
}
