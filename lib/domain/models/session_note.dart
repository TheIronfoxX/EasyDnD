// Nota de sesión: una entrada fechada del diario de una ficha.
// Pura (sin Flutter). Todos los campos tienen fallback al leer JSON.

import 'dart:math';

class SessionNote {
  final String id;

  /// Momento de creación (ISO 8601 en JSON). Ordena la lista.
  final DateTime createdAt;

  String title;
  String body;

  SessionNote({
    String? id,
    DateTime? createdAt,
    this.title = '',
    this.body = '',
  }) : createdAt = createdAt ?? DateTime.now(),
       id = id ?? _generateId();

  static String _generateId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    return 'note_${t}_${Random().nextInt(0x7FFFFFFF)}';
  }

  factory SessionNote.fromJson(Map<String, dynamic> json) {
    return SessionNote(
      id: json['id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'title': title,
    'body': body,
  };
}
