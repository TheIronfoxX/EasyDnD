// Cabecera "hero" de Combate: emblema elegido por el jugador, clase y
// nivel, y un lema corto opcional. Toca para cambiar el emblema o el lema.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/clean_shape.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../domain/models/character.dart';
import '../../../state/character_store.dart';

/// Emblemas disponibles: id guardado en la ficha → icono y nombre.
const Map<String, ({IconData icon, String label})> kHeroEmblems = {
  'fire': (icon: Icons.local_fire_department_rounded, label: 'Fuego'),
  'rune': (icon: Icons.blur_circular_rounded, label: 'Runa'),
  'sword': (icon: Icons.sports_martial_arts_rounded, label: 'Espada'),
  'shield': (icon: Icons.shield_rounded, label: 'Escudo'),
  'leaf': (icon: Icons.eco_rounded, label: 'Hoja'),
  'star': (icon: Icons.star_rounded, label: 'Estrella'),
  'skull': (icon: Icons.sentiment_very_dissatisfied_rounded, label: 'Calavera'),
  'book': (icon: Icons.auto_stories_rounded, label: 'Libro'),
};

IconData heroEmblemIcon(String? id) =>
    (kHeroEmblems[id] ?? kHeroEmblems['star']!).icon;

class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.character});

  final CharacterModel character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = character.basicInfo;
    final cls = info.characterClass.split('(').first.trim();
    final subtitle = [
      if (cls.isNotEmpty) cls,
      if (cls.isEmpty || !RegExp(r'\d').hasMatch(cls)) 'Nv. ${info.level}',
    ].join(' · ');
    final motto = character.motto.trim();
    // Fila plana: vive dentro del panel de estado de Combate, que pone
    // la superficie. Tocarla abre el editor de emblema y lema.
    return InkWell(
      key: const ValueKey('hero-header'),
      borderRadius: context.cleanShape.radius(12),
      onTap: () => showHeroEditor(context, character),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.16),
                borderRadius: context.cleanShape.radius(14),
              ),
              child: Icon(
                heroEmblemIcon(character.emblem),
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  // El lema solo sale si lo escribiste: sin texto de relleno.
                  if (motto.isNotEmpty)
                    Text(
                      motto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 18,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja para elegir emblema y escribir el lema.
Future<void> showHeroEditor(BuildContext context, CharacterModel character) {
  final store = context.read<CharacterStore>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _HeroEditor(store: store, character: character),
  );
}

class _HeroEditor extends StatefulWidget {
  const _HeroEditor({required this.store, required this.character});

  final CharacterStore store;
  final CharacterModel character;

  @override
  State<_HeroEditor> createState() => _HeroEditorState();
}

class _HeroEditorState extends State<_HeroEditor> {
  late String? _emblem = widget.character.emblem;
  late final _motto = TextEditingController(text: widget.character.motto);

  @override
  void dispose() {
    _motto.dispose();
    super.dispose();
  }

  void _save() {
    widget.store.setHeroIdentity(emblem: _emblem, motto: _motto.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Emblema y lema', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final e in kHeroEmblems.entries)
                  ChoiceChip(
                    key: ValueKey('emblem-${e.key}'),
                    avatar: Icon(e.value.icon, size: 18),
                    label: Text(e.value.label),
                    selected: _emblem == e.key,
                    onSelected: (_) => setState(() => _emblem = e.key),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey('motto-field'),
              controller: _motto,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: 'Lema o título (opcional)',
                hintText: 'Ej. «La llama que no se apaga»',
                helperText: 'Sale bajo tu clase y nivel.',
                helperStyle: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('hero-save'),
              onPressed: _save,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
