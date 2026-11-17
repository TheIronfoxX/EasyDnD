// Familias tipográficas empaquetadas (Etapa 8a).
//
// La app es offline: no descarga fuentes en runtime. Estas tres familias
// viven en `assets/fonts` y son las únicas que existen tanto en Android
// como en la web. En la web Flutter usa CanvasKit, que NO resuelve las
// familias genéricas ('serif'/'monospace'); por eso nunca se usan y todo
// el texto sale de acá.
//
// Los nombres deben coincidir con las `family:` declaradas en
// pubspec.yaml. El nombre interno de cada .ttf es indistinto para Flutter.

/// Familias disponibles. Cada una se declara en pubspec con sus pesos.
abstract final class AppFonts {
  /// Títulos. Serif clásica, con aire de inscripción grabada.
  static const String cinzel = 'Cinzel';

  /// Cuerpo. Sans humanista, muy legible en pantalla.
  static const String inter = 'Inter';

  /// Números y bloques crudos (JSON, notaciones, prompts).
  static const String jetBrainsMono = 'JetBrainsMono';

  /// Títulos en uncial: letras de manuscrito medieval.
  static const String uncialAntiqua = 'UncialAntiqua';

  /// Cuerpo serif de lectura larga, estilo libro.
  static const String crimsonText = 'CrimsonText';

  /// Fantasía de cuento: serif caligráfica para títulos y cuerpo.
  static const String almendra = 'Almendra';
}
