import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/design_tokens.dart';

/// Utilidad para seleccionar una foto y codificarla como Data URI Base64.
/// Cero dependencias de dart:io: compatible al 100% con Android, iOS y Web.
abstract final class AvatarPickerHelper {
  static Future<String?> pickAvatar({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (_) {
      return null;
    }
  }

  /// Muestra un modal para elegir entre Galería, Cámara o Eliminar foto.
  static Future<void> showAvatarOptions(
    BuildContext context, {
    required String? currentPath,
    required ValueChanged<String?> onSelected,
  }) async {
    final theme = Theme.of(context);
    final hasPhoto = currentPath != null && currentPath.trim().isNotEmpty;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(sheetContext).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Tomar foto con la cámara'),
              onTap: () => Navigator.of(sheetContext).pop('camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Quitar foto',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () => Navigator.of(sheetContext).pop('remove'),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (action == 'remove') {
      onSelected(null);
      return;
    }

    final source = action == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    final dataUri = await pickAvatar(source: source);
    if (dataUri != null) {
      onSelected(dataUri);
    }
  }
}

/// Avatar circular que soporta imágenes en Base64 (Data URI), URLs y
/// fallback automático a las iniciales del personaje con estética pergamino.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.avatarPath,
    required this.name,
    this.size = 40,
    this.onTap,
  });

  final String? avatarPath;
  final String name;
  final double size;
  final VoidCallback? onTap;

  static String initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words.first.substring(0, 1) + words.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final path = avatarPath?.trim();
    final hasImage = path != null && path.isNotEmpty;

    Widget content;
    if (hasImage) {
      if (path.startsWith('data:image')) {
        try {
          final comma = path.indexOf(',');
          final base64Data = comma >= 0 ? path.substring(comma + 1) : path;
          final bytes = base64Decode(base64Data);
          content = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialsWidget(theme, scheme),
          );
        } catch (_) {
          content = _initialsWidget(theme, scheme);
        }
      } else if (path.startsWith('http://') || path.startsWith('https://')) {
        content = Image.network(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsWidget(theme, scheme),
        );
      } else {
        content = _initialsWidget(theme, scheme);
      }
    } else {
      content = _initialsWidget(theme, scheme);
    }

    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withValues(alpha: 0.16),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (onTap == null) return avatar;

    return GestureDetector(onTap: onTap, child: avatar);
  }

  Widget _initialsWidget(ThemeData theme, ColorScheme scheme) {
    return Center(
      child: Text(
        initials(name),
        style: TextStyle(
          color: scheme.primary,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
