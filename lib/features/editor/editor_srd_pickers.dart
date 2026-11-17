// Selectores de armas y armaduras del catálogo SRD para el taller.

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../data/equipment_catalog.dart';
import '../../domain/models/srd_spell.dart' show normalizeSpellName;

Future<SrdWeapon?> showSrdWeaponPicker(BuildContext context) {
  return showModalBottomSheet<SrdWeapon>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _SrdPicker<SrdWeapon>(
      title: 'Arma SRD',
      load: () => EquipmentCatalog.loadWeapons(),
      name: (w) => w.name,
      subtitle: (w) =>
          '${w.damageDice ?? '—'} ${w.damageType ?? ''} · ${w.category} · ${w.properties.join(', ')}',
      keyFor: (w) => 'srd-weapon-${w.id}',
    ),
  );
}

Future<SrdArmor?> showSrdArmorPicker(BuildContext context) {
  return showModalBottomSheet<SrdArmor>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _SrdPicker<SrdArmor>(
      title: 'Armadura / Escudo SRD',
      load: () => EquipmentCatalog.loadArmors(),
      name: (a) => a.name,
      subtitle: (a) =>
          'CA ${a.category == 'escudo' ? '+' : ''}${a.baseAc} · ${a.category}',
      keyFor: (a) => 'srd-armor-${a.id}',
    ),
  );
}

class _SrdPicker<T> extends StatefulWidget {
  const _SrdPicker({
    required this.title,
    required this.load,
    required this.name,
    required this.subtitle,
    required this.keyFor,
  });

  final String title;
  final Future<List<T>> Function() load;
  final String Function(T) name;
  final String Function(T) subtitle;
  final String Function(T) keyFor;

  @override
  State<_SrdPicker<T>> createState() => _SrdPickerState<T>();
}

class _SrdPickerState<T> extends State<_SrdPicker<T>> {
  List<T> _all = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.load().then((items) {
      if (mounted) {
        setState(() {
          _all = items;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = normalizeSpellName(_query);
    final shown = _all
        .where(
          (e) => q.isEmpty || normalizeSpellName(widget.name(e)).contains(q),
        )
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar en ${widget.title}',
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      for (final e in shown)
                        ListTile(
                          key: Key(widget.keyFor(e)),
                          title: Text(widget.name(e)),
                          subtitle: Text(widget.subtitle(e)),
                          onTap: () => Navigator.of(context).pop(e),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
