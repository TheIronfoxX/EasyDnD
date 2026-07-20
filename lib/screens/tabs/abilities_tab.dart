// lib/screens/abilities_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/character_provider.dart';
import '../models/ability_model.dart';

/// Pestaña de Habilidades del personaje activo.
///
/// Muestra las cuatro categorías de la economía de acciones (Acción,
/// Acción Adicional, Reacción, Pasiva) tal y como las guarda
/// CharacterModel.abilitiesByAction. Permite:
///   - Añadir una habilidad nueva mediante un formulario simple (nombre +
///     descripción + categoría) abierto en un modal.
///   - Eliminar una habilidad existente mediante un icono de papelera que
///     SIEMPRE pide confirmación antes de borrar.
///
/// No requiere parámetros: lee el personaje activo directamente de
/// CharacterProvider a través de Consumer, así que se puede colocar como
/// una pestaña más dentro del HUD principal (main_hud_screen.dart) sin
/// pasarle nada.
class AbilitiesTab extends StatelessWidget {
  const AbilitiesTab({super.key});

  // Las cuatro categorías, con la clave interna que usa el provider
  // (actionType) y la etiqueta legible para la UI.
  static const List<_ActionCategory> _categories = [
    _ActionCategory(key: 'action', label: 'Acción', icon: Icons.bolt),
    _ActionCategory(
      key: 'bonusAction',
      label: 'Acción Adicional',
      icon: Icons.flash_on,
    ),
    _ActionCategory(key: 'reaction', label: 'Reacción', icon: Icons.shield),
    _ActionCategory(
      key: 'passive',
      label: 'Pasiva',
      icon: Icons.self_improvement,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Habilidades')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddAbilityModal(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Habilidad'),
      ),
      body: Consumer<CharacterProvider>(
        builder: (context, provider, _) {
          final abilities = provider.activeCharacter.abilitiesByAction;

          final sections = <_ActionCategory, List<Ability>>{
            _categories[0]: abilities.action,
            _categories[1]: abilities.bonusAction,
            _categories[2]: abilities.reaction,
            _categories[3]: abilities.passive,
          };

          final totalAbilities = sections.values
              .fold<int>(0, (sum, list) => sum + list.length);

          if (totalAbilities == 0) {
            return _EmptyState(
              onAddPressed: () => _openAddAbilityModal(context),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              for (final entry in sections.entries)
                if (entry.value.isNotEmpty)
                  _AbilitySection(
                    category: entry.key,
                    abilities: entry.value,
                    onDeleteRequested: (ability) =>
                        _confirmAndDelete(context, provider, ability),
                  ),
            ],
          );
        },
      ),
    );
  }

  /// Abre el modal de confirmación antes de borrar. El borrado en sí se
  /// delega siempre a CharacterProvider.removeAbility, nunca se toca la
  /// lista directamente desde la UI.
  Future<void> _confirmAndDelete(
    BuildContext context,
    CharacterProvider provider,
    Ability ability,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Eliminar habilidad?'),
          content: Text(
            'Vas a eliminar "${ability.name}" de la ficha. '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      provider.removeAbility(ability.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${ability.name}" eliminada')),
        );
      }
    }
  }

  Future<void> _openAddAbilityModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => const _AddAbilitySheet(),
    );
  }
}

/// Categoría de la economía de acciones, junto con la clave que el
/// provider espera recibir en addAbility(actionType: ...).
class _ActionCategory {
  final String key;
  final String label;
  final IconData icon;

  const _ActionCategory({
    required this.key,
    required this.label,
    required this.icon,
  });
}

class _AbilitySection extends StatelessWidget {
  final _ActionCategory category;
  final List<Ability> abilities;
  final ValueChanged<Ability> onDeleteRequested;

  const _AbilitySection({
    required this.category,
    required this.abilities,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            children: [
              Icon(category.icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                category.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        for (final ability in abilities)
          _AbilityCard(
            ability: ability,
            onDelete: () => onDeleteRequested(ability),
          ),
      ],
    );
  }
}

class _AbilityCard extends StatelessWidget {
  final Ability ability;
  final VoidCallback onDelete;

  const _AbilityCard({required this.ability, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final description = ability.loreDescription?.trim();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          ability.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: (description == null || description.isEmpty)
            ? null
            : Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Eliminar habilidad',
          color: Theme.of(context).colorScheme.error,
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddPressed;

  const _EmptyState({required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Este personaje todavía no tiene habilidades registradas.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('Añadir habilidad'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario de alta rápida: nombre, descripción y categoría de la
/// economía de acciones. Al confirmar, llama a
/// CharacterProvider.addAbility() y cierra el modal.
class _AddAbilitySheet extends StatefulWidget {
  const _AddAbilitySheet();

  @override
  State<_AddAbilitySheet> createState() => _AddAbilitySheetState();
}

class _AddAbilitySheetState extends State<_AddAbilitySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = AbilitiesTab._categories.first.key;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    context.read<CharacterProvider>().addAbility(
          actionType: _selectedCategory,
          name: _nameController.text,
          description: _descriptionController.text,
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Padding que respeta el teclado para que el formulario no quede
    // tapado al escribir.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nueva Habilidad',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Golpe Aturdidor',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Qué hace esta habilidad...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 5,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de acción',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final category in AbilitiesTab._categories)
                      DropdownMenuItem(
                        value: category.key,
                        child: Text(category.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedCategory = value);
                  },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  label: const Text('Guardar Habilidad'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}