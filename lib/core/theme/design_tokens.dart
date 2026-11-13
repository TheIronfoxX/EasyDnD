// Tokens de diseño de EasyDnD (Etapa 6).
//
// Una sola escala para espaciado, radios y duraciones. La regla es la
// misma que con los colores: ningún widget inventa valores sueltos; si
// un número se repite en más de una pantalla, vive acá.
//
// Son constantes puras (sin Flutter) para poder usarlas tanto en el
// tema como en widgets y tests sin arrastrar dependencias.

/// Escala de espaciado, en píxeles lógicos. De menor a mayor.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Radios de esquina. [pill] es el comodín para chips y etiquetas.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Duraciones de animación. [fast] para toques y estados, [normal] para
/// transiciones de pantalla o cambios de tema.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
}
