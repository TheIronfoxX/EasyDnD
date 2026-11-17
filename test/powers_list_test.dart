// Tests de la lista sencilla de poderes (combat/powers.dart): grupos por
// categoría, pasivas plegadas y pantalla de detalle con Usar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/core/theme/app_theme.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/domain/models/ability.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/features/hud/combat/powers.dart';
import 'package:easydnd/features/hud/hud_resolution_sheet.dart';
import 'package:easydnd/state/character_store.dart';

import 'fakes/test_fichas.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<CharacterStore> bootWith(CharacterModel c) async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    store.addCharacter(c);
    return store;
  }

  Future<void> pumpList(
    WidgetTester tester,
    CharacterStore store, {
    required bool spells,
  }) async {
    await tester.binding.setSurfaceSize(const Size(500, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider<CharacterStore>.value(
        value: store,
        child: MaterialApp(
          theme: AppTheme.clean(brightness: Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final c = store.activeCharacter!;
                return ListView(
                  children: groupedPowerList(
                    context,
                    c,
                    powerEntries(c, spells: spells),
                    passivesFolded: !spells,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  CharacterModel mixed() {
    final c = buildCharacter(id: 'char_mix', name: 'Rook');
    c.abilitiesByAction.reaction.add(
      Ability.fromJson({
        'id': 'a_parry',
        'name': 'Parada',
        'attack_type': 'none',
        'power_role': 'Defensa',
        'plain_summary': 'Reduces el daño de un golpe.',
      }),
    );
    c.abilitiesByAction.passive.add(
      Ability.fromJson({
        'id': 'a_dark',
        'name': 'Visión en la oscuridad',
        'tactical_role': 'Utilidad',
      }),
    );
    c.abilitiesByAction.action.addAll([
      Ability.fromJson({
        'id': 'sp_bless',
        'name': 'Bendición',
        'type': 'spell',
        'base_level': 1,
        'attack_type': 'none',
        'concentration': true,
        'success_description': 'Hasta tres aliados suman 1d4.',
        'when_to_use': 'Antes de que tu grupo ataque.',
      }),
      Ability.fromJson({
        'id': 'sp_fire',
        'name': 'Rayo de Fuego',
        'type': 'spell',
        'base_level': 0,
        'damage_dice': '1d10',
        'plain_summary': 'Lanzas fuego a un enemigo.',
      }),
    ]);
    return c;
  }

  testWidgets('ataques: grupos por categoría y pasivas plegadas', (
    tester,
  ) async {
    final store = await bootWith(mixed());
    await pumpList(tester, store, spells: false);

    expect(find.text('Daño'), findsOneWidget);
    expect(find.text('Espada Larga'), findsOneWidget);
    expect(find.text('Defensa'), findsOneWidget);
    expect(find.text('Reduces el daño de un golpe.'), findsOneWidget);
    // Los conjuros no salen en esta lista.
    expect(find.text('Rayo de Fuego'), findsNothing);
    // Pasivas plegadas.
    expect(find.text('Siempre activos (1)'), findsOneWidget);
    expect(find.text('Visión en la oscuridad'), findsNothing);
    await tester.tap(find.text('Siempre activos (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Visión en la oscuridad'), findsOneWidget);
  });

  testWidgets('conjuros: Daño y Apoyo deducidos, etiqueta de nivel', (
    tester,
  ) async {
    final store = await bootWith(mixed());
    await pumpList(tester, store, spells: true);

    expect(find.text('Daño'), findsOneWidget);
    expect(find.text('Apoyo'), findsOneWidget);
    expect(find.text('truco'), findsOneWidget);
    expect(find.text('nv 1'), findsOneWidget);
    expect(find.text('Lanzas fuego a un enemigo.'), findsOneWidget);
    expect(find.textContaining('Concentración'), findsOneWidget);
    expect(find.text('Espada Larga'), findsNothing);
  });

  testWidgets('el detalle explica el poder y Usar abre la tirada', (
    tester,
  ) async {
    final store = await bootWith(mixed());
    await pumpList(tester, store, spells: true);

    await tester.tap(find.text('Bendición'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle'), findsOneWidget);
    expect(find.text('Conjuro de nivel 1: gasta una ranura'), findsOneWidget);
    expect(
      find.text('Cuándo usarlo: Antes de que tu grupo ataque.'),
      findsOneWidget,
    );
    expect(
      find.text('Dura mientras no pierdas la concentración'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('power-use')));
    await tester.pumpAndSettle();
    expect(find.byType(ResolutionSheet), findsOneWidget);
  });
}
