// Sección "Compañeros" del editor: mascotas, invocaciones y aliados
// que viajan con el personaje.
//
// `hasHp` distingue entidades vulnerables (con barra de vida que el HUD
// gestiona en combate) de apoyos narrativos invulnerables (un familiar
// que no recibe daño). Cuando está apagado, los PG siguen viajando en
// el modelo pero la UI los ignora.
//
// Como el resto de las listas del editor: tap abre el diálogo, basura
// borra directo y el FAB agrega. El tope de PG mantiene la coherencia
// de siempre (si estaba lleno sigue lleno; bajar recorta; subir no
// regala).

import 'package:flutter/material.dart';

import '../../domain/models/character.dart';
import 'editor_fields.dart';
import '../../core/theme/design_tokens.dart';

/// Diálogo de alta/edición de un compañero. Retorna el Companion listo
/// para insertar o null al cancelar.
class CompanionDialog extends StatefulWidget {
  const CompanionDialog({super.key, this.initial});

  /// Null = alta nueva.
  final Companion? initial;

  @override
  State<CompanionDialog> createState() => _CompanionDialogState();
}

class _CompanionDialogState extends State<CompanionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name = widget.initial?.name ?? '';
  late String _type = widget.initial?.type ?? '';
  late bool _hasHp = widget.initial?.hasHp ?? true;
  late int _maxHp = widget.initial?.maxHp ?? 1;
  late int _currentHp = widget.initial?.currentHp ?? 1;
  late int _ac = widget.initial?.ac ?? 10;

  /// El tope puede arrastrar/recortar el current: el campo visible va
  /// con controller porque initialValue no se refresca solo.
  late final TextEditingController _currentHpController;

  @override
  void initState() {
    super.initState();
    _currentHpController = TextEditingController(text: _currentHp.toString());
  }

  @override
  void dispose() {
    _currentHpController.dispose();
    super.dispose();
  }

  void _setMaxHp(int value) {
    setState(() {
      // Misma semántica que setHpMax: si estaba lleno sigue lleno; si
      // estaba herido se respeta — salvo que quede por encima del tope
      // nuevo.
      final wasFull = _currentHp >= _maxHp;
      _maxHp = value;
      if (wasFull || _currentHp > value) {
        _currentHp = value;
        _currentHpController.text = '$value';
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Companion(
        name: _name.trim(),
        type: _type.trim(),
        hasHp: _hasHp,
        currentHp: _currentHp,
        maxHp: _maxHp,
        ac: _ac,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Nuevo compañero' : 'Editar compañero',
      ),
      content: Form(
        key: _formKey,
        // El diálogo es alto (nombre, tipo, switch, PG y CA): en
        // pantallas bajas/teclado abierto el contenido tiene que
        // scrollear en vez de desbordar.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _name = value,
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Poné un nombre.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                initialValue: _type,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tipo (opcional)',
                  hintText: 'bestia, familiar, invocación...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _type = value,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tiene PG'),
                subtitle: const Text(
                  'Destildado = apoyo narrativo invulnerable',
                ),
                value: _hasHp,
                onChanged: (value) => setState(() => _hasHp = value),
              ),
              if (_hasHp) ...[
                EditorIntField(
                  label: 'PG máximos',
                  value: _maxHp,
                  onChanged: (value) {
                    if (value != null) _setMaxHp(value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                EditorIntField(
                  label: 'PG actuales',
                  value: _currentHp,
                  controller: _currentHpController,
                  hint: 'estado de combate',
                  validator: (text) {
                    final parsed = int.tryParse(text ?? '');
                    if (parsed != null && parsed > _maxHp) {
                      return 'No puede superar los PG máximos ($_maxHp).';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value != null) _currentHp = value;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              EditorIntField(
                label: 'CA',
                value: _ac,
                onChanged: (value) {
                  if (value != null) _ac = value;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
