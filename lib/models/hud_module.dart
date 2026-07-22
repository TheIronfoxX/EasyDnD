/// Representa un bloque visual dentro del HUD de combate.
///
/// Este modelo es puramente de datos: no sabe nada sobre cómo se
/// renderiza en pantalla (eso lo resolverá el grid asimétrico en la
/// Fase 2). Solo describe QUÉ es el bloque y QUÉ TAMAÑO ocupa.
class HudModule {
  /// ID único del bloque visual (no confundir con [targetReferenceId]).
  final String id;

  /// Título legible del módulo, ej: "Bola de Fuego", "Puntos de Vida".
  final String title;

  /// Emoji representativo del módulo, ej: "🔥", "❤️".
  final String emojiIcon;

  /// Tipo de módulo: permite diferenciar comportamiento/estilo futuro
  /// (ej: "attack", "counter", "spell", "resource").
  final String type;

  /// ID del objeto real en la base de datos del usuario al que este
  /// botón apunta (el hechizo, el stat, el contador, etc.).
  final String targetReferenceId;

  /// Columnas que ocupa en un grid base de 4 columnas. Máximo 4.
  final int crossAxisCellCount;

  /// Filas que ocupa el módulo.
  final int mainAxisCellCount;

  const HudModule({
    required this.id,
    required this.title,
    required this.emojiIcon,
    required this.type,
    required this.targetReferenceId,
    required this.crossAxisCellCount,
    required this.mainAxisCellCount,
  }) : assert(
          crossAxisCellCount > 0 && crossAxisCellCount <= 4,
          'crossAxisCellCount debe estar entre 1 y 4',
        ),
        assert(
          mainAxisCellCount > 0,
          'mainAxisCellCount debe ser mayor que 0',
        );

  /// Reconstruye un [HudModule] a partir del JSON guardado en disco
  /// (ver `HudLayoutRepository`).
  factory HudModule.fromJson(Map<String, dynamic> json) {
    return HudModule(
      id: json['id'] as String,
      title: json['title'] as String,
      emojiIcon: json['emojiIcon'] as String,
      type: json['type'] as String,
      targetReferenceId: json['targetReferenceId'] as String,
      crossAxisCellCount: json['crossAxisCellCount'] as int,
      mainAxisCellCount: json['mainAxisCellCount'] as int,
    );
  }

  /// Serializa el módulo para poder guardarlo con `HudLayoutRepository`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'emojiIcon': emojiIcon,
      'type': type,
      'targetReferenceId': targetReferenceId,
      'crossAxisCellCount': crossAxisCellCount,
      'mainAxisCellCount': mainAxisCellCount,
    };
  }

  /// Copia el módulo permitiendo sobreescribir campos puntuales.
  /// Útil en Fase 2 cuando el usuario reordene o redimensione bloques.
  HudModule copyWith({
    String? id,
    String? title,
    String? emojiIcon,
    String? type,
    String? targetReferenceId,
    int? crossAxisCellCount,
    int? mainAxisCellCount,
  }) {
    return HudModule(
      id: id ?? this.id,
      title: title ?? this.title,
      emojiIcon: emojiIcon ?? this.emojiIcon,
      type: type ?? this.type,
      targetReferenceId: targetReferenceId ?? this.targetReferenceId,
      crossAxisCellCount: crossAxisCellCount ?? this.crossAxisCellCount,
      mainAxisCellCount: mainAxisCellCount ?? this.mainAxisCellCount,
    );
  }

  @override
  String toString() =>
      'HudModule(id: $id, title: $title, size: ${crossAxisCellCount}x$mainAxisCellCount)';
}