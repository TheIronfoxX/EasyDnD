// Paleta semántica de EasyDnD (Etapa 6; dirección "pergamino" en 8b).
//
// Los nombres describen ROLES, no colores: background, surface,
// textPrimary... Así un skin futuro puede cambiar los valores sin que
// ningún widget se entere.
//
// La identidad es "pergamino oscuro": superficies cálidas (marrón/oliva
// apagado, no azul-grisáceo), tinta crema y bordes gastados, con el oro
// sepia del acento como firma. El modo claro es la cara de papel: crema
// envejecida y tinta marrón.
//
// danger y success se mantienen reconocibles en ambos modos (terracota y
// musgo), pero templados para no romper la calidez del conjunto.

import 'package:flutter/material.dart';

@immutable
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.danger,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color danger;
  final Color success;

  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? danger,
    Color? success,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceElevated: surfaceElevated ?? this.surfaceElevated,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    danger: danger ?? this.danger,
    success: success ?? this.success,
  );

  /// Grimorio (oscuro por defecto): obsidiana profunda y bronce oscuro.
  static const AppPalette dark = AppPalette(
    background: Color(0xFF0F0D0A),
    surface: Color(0xFF19150F),
    surfaceElevated: Color(0xFF272016),
    border: Color(0xFF403524),
    textPrimary: Color(0xFFEFE5D2),
    textSecondary: Color(0xFFA99879),
    danger: Color(0xFFD2594A),
    success: Color(0xFF86B56B),
  );

  /// Pergamino (claro por defecto): papel cálido y tinta sepia.
  static const AppPalette light = AppPalette(
    background: Color(0xFFF3E9D5),
    surface: Color(0xFFFBF6EA),
    surfaceElevated: Color(0xFFEDE0C7),
    border: Color(0xFFD3BF99),
    textPrimary: Color(0xFF2A2216),
    textSecondary: Color(0xFF6A5A42),
    danger: Color(0xFFA93A2B),
    success: Color(0xFF4A7434),
  );

  /// Forja Arcana: azul pizarra abisal y acero frío.
  static const AppPalette forge = AppPalette(
    background: Color(0xFF0A0F16),
    surface: Color(0xFF111923),
    surfaceElevated: Color(0xFF1B2633),
    border: Color(0xFF2D3D50),
    textPrimary: Color(0xFFE3ECF5),
    textSecondary: Color(0xFF8FA3BA),
    danger: Color(0xFFE56E62),
    success: Color(0xFF6FC89C),
  );

  /// Sangre y Hierro: carbón volcánico y hierro templado.
  static const AppPalette blood = AppPalette(
    background: Color(0xFF160708),
    surface: Color(0xFF240C0E),
    surfaceElevated: Color(0xFF361416),
    border: Color(0xFF5E2A2C),
    textPrimary: Color(0xFFF6E4E0),
    textSecondary: Color(0xFFB8908C),
    danger: Color(0xFFFF6A55),
    success: Color(0xFF93B56B),
  );

  /// Senda Silvestre: bosque nocturno y corteza oscura.
  static const AppPalette wild = AppPalette(
    background: Color(0xFF0A100C),
    surface: Color(0xFF121A14),
    surfaceElevated: Color(0xFF1C281E),
    border: Color(0xFF304233),
    textPrimary: Color(0xFFE5EEDE),
    textSecondary: Color(0xFF95A78F),
    danger: Color(0xFFE2705A),
    success: Color(0xFF7CD69B),
  );

  /// Velo Astral: violeta noche / índigo profundo, texto lavanda suave.
  static const AppPalette astral = AppPalette(
    background: Color(0xFF0C0919),
    surface: Color(0xFF151030),
    surfaceElevated: Color(0xFF211A48),
    border: Color(0xFF3B3274),
    textPrimary: Color(0xFFE9E3FA),
    textSecondary: Color(0xFFA99FD0),
    danger: Color(0xFFFF6F8F),
    success: Color(0xFF72E3AE),
  );

  /// Escarcha: azul pizarra helado y blanco hielo.
  static const AppPalette frost = AppPalette(
    background: Color(0xFF0E1C2A),
    surface: Color(0xFF16293C),
    surfaceElevated: Color(0xFF20384F),
    border: Color(0xFF3A6385),
    textPrimary: Color(0xFFE8F6FF),
    textSecondary: Color(0xFF9CC0DA),
    danger: Color(0xFFF07A7A),
    success: Color(0xFF78D4B0),
  );

  /// Necrópolis: cripta casi negra con verde enfermizo y tinta de hueso.
  static const AppPalette crypt = AppPalette(
    background: Color(0xFF0E0D12),
    surface: Color(0xFF18161F),
    surfaceElevated: Color(0xFF241F2D),
    border: Color(0xFF3B3548),
    textPrimary: Color(0xFFE9E4F0),
    textSecondary: Color(0xFFA69DB8),
    danger: Color(0xFFE0605A),
    success: Color(0xFF9BD65A),
  );

  /// Dragón Dorado: ceniza cálida y brasa.
  static const AppPalette dragon = AppPalette(
    background: Color(0xFF1C1206),
    surface: Color(0xFF2B1B0A),
    surfaceElevated: Color(0xFF3C2810),
    border: Color(0xFF6B4A1E),
    textPrimary: Color(0xFFF8E9CC),
    textSecondary: Color(0xFFC2A27A),
    danger: Color(0xFFFF6B4A),
    success: Color(0xFF9CBF5E),
  );

  /// Mar Profundo: azul abisal y turquesa.
  static const AppPalette abyss = AppPalette(
    background: Color(0xFF021A1C),
    surface: Color(0xFF06292C),
    surfaceElevated: Color(0xFF0B3A3E),
    border: Color(0xFF14565A),
    textPrimary: Color(0xFFDDF7F3),
    textSecondary: Color(0xFF7FBDB8),
    danger: Color(0xFFF2767A),
    success: Color(0xFF5ED6A6),
  );

  /// Mazmorra: piedra gris y musgo.
  static const AppPalette dungeon = AppPalette(
    background: Color(0xFF101112),
    surface: Color(0xFF1A1C1E),
    surfaceElevated: Color(0xFF26292C),
    border: Color(0xFF44494E),
    textPrimary: Color(0xFFE6E8EA),
    textSecondary: Color(0xFF9AA1A8),
    danger: Color(0xFFD9604F),
    success: Color(0xFF8DBB5A),
  );

  /// Marfil y Azur (claro): marfil frío y tinta azul petróleo.
  static const AppPalette ivory = AppPalette(
    background: Color(0xFFEEF2F1),
    surface: Color(0xFFF8FAF9),
    surfaceElevated: Color(0xFFE3EAEA),
    border: Color(0xFFBCCACB),
    textPrimary: Color(0xFF17262B),
    textSecondary: Color(0xFF4B6168),
    danger: Color(0xFFB3362E),
    success: Color(0xFF2F7A4E),
  );

  /// Ruido Perdido (oscuro): negro asfalto neutro, texto casi blanco y
  /// rojo de neón como único acento caliente.
  static const AppPalette noise = AppPalette(
    background: Color(0xFF0B0B0D),
    surface: Color(0xFF141416),
    surfaceElevated: Color(0xFF1F1F23),
    border: Color(0xFF3A3A40),
    textPrimary: Color(0xFFEDEDED),
    textSecondary: Color(0xFF9A9AA2),
    danger: Color(0xFFFF3B3B),
    success: Color(0xFF5BD68A),
  );

  /// Zoo Pastel (claro): crema rosada, ciruela suave y pasteles de mascota.
  static const AppPalette zoo = AppPalette(
    background: Color(0xFFFFF6F0),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFDE8EE),
    border: Color(0xFFF2C7D3),
    textPrimary: Color(0xFF3A2A3D),
    textSecondary: Color(0xFF7F6482),
    danger: Color(0xFFD9435B),
    success: Color(0xFF3FA57F),
  );

  /// Borahae (oscuro): ciruela y orquídea, más magenta que el índigo de
  /// Velo Astral.
  static const AppPalette borahae = AppPalette(
    background: Color(0xFF1C0B26),
    surface: Color(0xFF2A1239),
    surfaceElevated: Color(0xFF3C1B54),
    border: Color(0xFF6A3A8C),
    textPrimary: Color(0xFFF6ECFF),
    textSecondary: Color(0xFFBBA3DB),
    danger: Color(0xFFFF6B8A),
    success: Color(0xFF7BE0B0),
  );

  /// Minsung (oscuro): bosque verde oscuro con naranja encendido y verde
  /// hoja claro.
  static const AppPalette citrus = AppPalette(
    background: Color(0xFF14200F),
    surface: Color(0xFF1F2D17),
    surfaceElevated: Color(0xFF2C3F20),
    border: Color(0xFF4E6B34),
    textPrimary: Color(0xFFF1F5E6),
    textSecondary: Color(0xFFB5C69A),
    danger: Color(0xFFFF6B5A),
    success: Color(0xFF8FE388),
  );

  /// Fuego Kitsune (oscuro): tinta cálida, laca de obsidiana y marfil.
  static const AppPalette kitsune = AppPalette(
    background: Color(0xFF0E0B0C),
    surface: Color(0xFF171214),
    surfaceElevated: Color(0xFF231B1E),
    border: Color(0xFF3D262A),
    textPrimary: Color(0xFFF5EFEA),
    textSecondary: Color(0xFFA89A9E),
    danger: Color(0xFFE53935),
    success: Color(0xFF2E9E6B),
  );

  /// Seda Carmesí (claro): papel de arroz, seda y tinta laca.
  static const AppPalette silk = AppPalette(
    background: Color(0xFFDCD0BE),
    surface: Color(0xFFE8DECF),
    surfaceElevated: Color(0xFFD3C6B2),
    border: Color(0xFF2E2526),
    textPrimary: Color(0xFF181314),
    textSecondary: Color(0xFF5E5052),
    danger: Color(0xFFC62828),
    success: Color(0xFF1E8E5A),
  );

  /// Panda Blindado (oscuro): tinta de pelaje, acero pavonado y marfil.
  static const AppPalette pandaArmor = AppPalette(
    background: Color(0xFF0A0D0E),
    surface: Color(0xFF12171D),
    surfaceElevated: Color(0xFF1B3350),
    border: Color(0xFF566066),
    textPrimary: Color(0xFFF6F7F5),
    textSecondary: Color(0xFFA2AEB8),
    danger: Color(0xFFD93B3B),
    success: Color(0xFF38B874),
  );

  /// Eclipse Sombrío (oscuro): negro abisal con subtono azul noche.
  static const AppPalette eclipse = AppPalette(
    background: Color(0xFF04050B),
    surface: Color(0xFF0A0B16),
    surfaceElevated: Color(0xFF140F24),
    border: Color(0xFF2E1F45),
    textPrimary: Color(0xFFEFE8F7),
    textSecondary: Color(0xFF8A7FA8),
    danger: Color(0xFFC62A5E),
    success: Color(0xFF00BFA5),
  );

  /// Maldición Nacida (oscuro): negro con violeta profundo y gris ceniza.
  static const AppPalette crimsonRite = AppPalette(
    background: Color(0xFF09070D),
    surface: Color(0xFF130F1A),
    surfaceElevated: Color(0xFF1D1727),
    border: Color(0xFF392F4A),
    textPrimary: Color(0xFFE9E5EF),
    textSecondary: Color(0xFF9A90AD),
    danger: Color(0xFFD9534F),
    success: Color(0xFF4E9A7C),
  );

  /// Cresta de Forja (oscuro): basalto, hierro forjado y bronce envejecido.
  static const AppPalette forgeCrest = AppPalette(
    background: Color(0xFF0B0D0F),
    surface: Color(0xFF15181C),
    surfaceElevated: Color(0xFF20252B),
    border: Color(0xFF4D3D33),
    textPrimary: Color(0xFFF2EFE9),
    textSecondary: Color(0xFF9AA1A8),
    danger: Color(0xFFD93829),
    success: Color(0xFF3A9964),
  );

  /// Filigrana Maldita (oscuro): índigo abisal con matiz violeta, túnica de
  /// medianoche, esmeralda de ojos y carmesí infernal.
  static const AppPalette damonNight = AppPalette(
    background: Color(0xFF0D0820),
    surface: Color(0xFF181234),
    surfaceElevated: Color(0xFF1F1838),
    border: Color(0xFF3B2F66),
    textPrimary: Color(0xFFF1F0FA),
    textSecondary: Color(0xFF9C98C4),
    danger: Color(0xFFD9383A),
    success: Color(0xFF24A866),
  );

  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
