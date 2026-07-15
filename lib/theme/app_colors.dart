import 'package:flutter/material.dart';

// Paleta "Diario de Aventuras" v2 — Fase 4b: dejamos el café/negro plano
// y pasamos a un tono azul-grisáceo profundo tipo "panel táctico". El
// acento ya NO vive aquí como preset fijo — desde la Fase 2 es libre
// (elegido por el usuario vía HsvColorPickerDialog), así que esta clase
// solo guarda lo que de verdad es estático.
//
// Fase 5: se añade la paleta clara (light*) como contrapartida exacta de
// cada color oscuro. NINGÚN valor oscuro se toca — siguen siendo los
// mismos de siempre. ThemeNotifier decide cuál de los dos juegos usar
// según el modo activo.
class AppColors {
  // ---- Modo oscuro (sin cambios) ----
  static const Color background = Color(0xFF0A0E17); // azul-gris muy oscuro, fijo
  static const Color surface = Color(0xFF171E28); // "panel" ligeramente más claro
  static const Color surfaceLight = Color(0xFF1F2733); // superficies elevadas (avatar, CA)
  static const Color border = Color(0xFF2A3441); // borde sutil de respaldo, casi no se usa ya
  static const Color textPrimary = Color(0xFFEDEFF3); // texto claro, ligeramente frío
  static const Color textSecondary = Color(0xFF8C96A6); // texto secundario, gris azulado
  static const Color danger = Color(0xFFD9534F); // rojo de daño
  static const Color success = Color(0xFF5CB88A); // verde de curación

  // ---- Modo claro (nuevo) ----
  static const Color lightBackground = Color(0xFFF7F8FA); // blanco casi puro, evita el blanco puro plano
  static const Color lightSurface = Color(0xFFFFFFFF); // panel blanco limpio
  static const Color lightSurfaceLight = Color(0xFFEFF1F4); // superficies elevadas en claro
  static const Color lightBorder = Color(0xFFD9DEE5); // borde sutil sobre blanco
  static const Color lightTextPrimary = Color(0xFF1A1D23); // texto casi negro, buen contraste
  static const Color lightTextSecondary = Color(0xFF5B6472); // texto secundario gris oscuro
  // danger/success se mantienen iguales en ambos modos: ya tienen contraste
  // suficiente sobre fondo blanco y sobre fondo oscuro.

  // Color de acento de fábrica, solo para el primer arranque antes de que
  // SharedPreferences devuelva nada (o si el usuario nunca ha elegido uno).
  static const Color defaultAccent = Color(0xFFC9A227); // sepia
}
