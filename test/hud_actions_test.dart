// Tests de las tiradas (hoja de resolución) con el store real y un
// Random falso. Un arnés mínimo lista los poderes de la ficha y abre la
// hoja con los mismos constructores de RollAction que usa la app, así se
// verifica el efecto en la ficha (cargas, ranuras, recursos) sin depender
// de la navegación del HUD (cubierta en hud_novice_test.dart).

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/core/theme/app_theme.dart';
import 'package:easydnd/core/dice.dart';
import 'package:easydnd/domain/models/ability.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/features/hud/hud_resolution_sheet.dart';
import 'package:easydnd/features/hud/hud_roll_actions.dart';
import 'package:easydnd/state/character_store.dart';

import 'fakes/fake_random.dart';
import 'fakes/test_fichas.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<CharacterStore> bootWith(CharacterModel character) async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    store.addCharacter(character);
    return store;
  }

  /// Arnés de tiradas: una fila por poder de la ficha (armas, rasgos y
  /// conjuros) que abre la hoja de resolución con los mismos
  /// constructores que usa la app (`weaponRollAction`/`abilityRollAction`)
  /// y un Random inyectable. La pantalla es alta para que nada de la hoja
  /// quede fuera del viewport.
  Future<void> pumpActions(
    WidgetTester tester,
    CharacterStore store, {
    Random? random,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2200));
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
                  children: [
                    for (final w in c.inventory.weapons)
                      ListTile(
                        title: Text(w.name),
                        onTap: () => showResolutionSheet(
                          context,
                          weaponRollAction(context, w, store),
                          random: random,
                        ),
                      ),
                    for (final a in c.abilitiesByAction.all.where(
                      (a) => !c.abilitiesByAction.passive.contains(a),
                    ))
                      ListTile(
                        title: Text(a.name),
                        onTap: () => showResolutionSheet(
                          context,
                          abilityRollAction(context, c, a, store),
                          random: random,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    expect(finder, findsWidgets, reason: 'No se encontró "$text"');
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  group('armas', () {
    testWidgets('tirada digital consume una carga al atacar', (tester) async {
      final store = await bootWith(
        buildCharacter(id: 'char_weapon', name: 'Rook'),
      );
      // 9 % 20 + 1 = 10 natural.
      await pumpActions(tester, store, random: FakeRandom([9]));

      await tapText(tester, 'Espada Larga');
      expect(find.text('Usos: 3/3'), findsOneWidget);
      expect(find.text('Tirar d20'), findsOneWidget);

      await tapText(tester, 'Tirar d20');

      expect(find.text('Dado natural: 10'), findsOneWidget);
      expect(find.text('Fallo'), findsOneWidget);
      expect(find.text('Impacto'), findsOneWidget);
      expect(
        store.activeCharacter!.inventory.weapons.single.magicCharges.current,
        2,
      );

      await tapText(tester, 'Fallo');
      expect(find.text('Tirar d20'), findsNothing);
    });

    testWidgets('ventaja tira dos dados y detecta el crítico', (tester) async {
      final store = await bootWith(
        buildCharacter(id: 'char_crit', name: 'Rook'),
      );
      // 19 % 20 + 1 = 20 y 2 % 20 + 1 = 3: se queda el 20.
      await pumpActions(tester, store, random: FakeRandom([19, 2, 0]));

      await tapText(tester, 'Espada Larga');
      await tapText(tester, 'Ventaja');
      expect(find.text('Tirar 2d20'), findsOneWidget);

      await tapText(tester, 'Tirar 2d20');

      expect(find.text('Dados: 20 y 3 → se usa 20 (ventaja)'), findsOneWidget);
      expect(find.text('¡Éxito crítico!'), findsOneWidget);

      // El impacto pasa a la fase de daño con el siguiente valor del dado.
      await tapText(tester, 'Impacto');
      expect(find.text('Daño / efecto'), findsOneWidget);
      expect(find.text('1d8+3'), findsOneWidget); // desglose de la tirada

      await tapText(tester, 'Cerrar');
      expect(find.text('Daño / efecto'), findsNothing);
    });

    testWidgets('tirada manual acepta el d20 y el daño de mesa', (
      tester,
    ) async {
      final store = await bootWith(
        buildCharacter(id: 'char_manual', name: 'Rook'),
      );
      await pumpActions(tester, store);

      await tapText(tester, 'Espada Larga');
      await tapText(tester, 'Manual');
      expect(find.text('Dado'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '12');
      await tapText(tester, 'Confirmar tirada');

      expect(find.text('Dado natural: 12'), findsOneWidget);
      expect(find.text('17'), findsOneWidget); // 12 + 5
      expect(
        store.activeCharacter!.inventory.weapons.single.magicCharges.current,
        2,
      );

      await tapText(tester, 'Impacto');
      expect(find.text('Daño total'), findsOneWidget);
      expect(find.text('En mesa: tirá 1d8+3'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '9');
      await tapText(tester, 'Ver daño');

      expect(find.text('9'), findsOneWidget);

      await tapText(tester, 'Cerrar');
      expect(find.text('Daño total'), findsNothing);
    });

    testWidgets('sin cargas bloquea la tirada y avisa', (tester) async {
      final store = await bootWith(
        buildCharacter(id: 'char_empty', name: 'Rook', weaponChargesCurrent: 0),
      );
      await pumpActions(tester, store);

      await tapText(tester, 'Espada Larga');

      expect(find.text('Usos: 0/3'), findsOneWidget);
      expect(
        find.text('Sin usos disponibles: recuperalos con un descanso.'),
        findsOneWidget,
      );
      expect(find.text('Tirar d20'), findsNothing);
      expect(find.text('Manual'), findsNothing);
    });
  });

  group('habilidades', () {
    testWidgets('una habilidad con cargas las consume al atacar', (
      tester,
    ) async {
      final store = await bootWith(
        buildCharacter(
          id: 'char_ability',
          name: 'Rook',
          abilityChargesCurrent: 1,
        ),
      );
      await pumpActions(tester, store, random: FakeRandom([9]));

      await tapText(tester, 'Golpe Devastador');
      expect(find.text('Usos: 1/3'), findsOneWidget);

      await tapText(tester, 'Tirar d20');
      expect(find.text('Dado natural: 10'), findsOneWidget);
      expect(
        store
            .activeCharacter!
            .abilitiesByAction
            .action
            .single
            .magicCharges
            .current,
        0,
      );

      await tapText(tester, 'Fallo');
    });

    testWidgets('conjuro de salvación elige ranura y escala el daño', (
      tester,
    ) async {
      final character = buildCharacter(id: 'char_spell', name: 'Rook');
      character.basicInfo.spellSaveDc = 15;
      character.abilitiesByAction.action.add(
        Ability.fromJson({
          'id': 'a_fireball',
          'name': 'Bola de Fuego',
          'type': 'spell',
          'related_stat': 'int',
          'attack_type': 'save',
          'is_scalable': true,
          'base_level': 1,
          'scaling_formula': '1d6',
          'damage_dice': '2d6',
        }),
      );
      character.spellSlots.slots.add(SpellSlot(level: 2, max: 2, current: 2));

      final store = await bootWith(character);
      // 2d6 base + 1d6 de escalado, todos con el mínimo (1).
      await pumpActions(tester, store, random: FakeRandom([0]));

      await tapText(tester, 'Bola de Fuego');
      expect(find.text('CD de Salvación: 15'), findsOneWidget);
      expect(find.text('Nv. 1 · 4/4'), findsOneWidget);
      expect(find.text('Nv. 2 · 2/2'), findsOneWidget);

      // Sube a nivel 2 (un nivel por encima del base).
      await tapText(tester, 'Nv. 2 · 2/2');
      await tapText(tester, 'El objetivo falla · tirar daño');

      expect(find.text('Daño / efecto'), findsOneWidget);
      expect(find.text('2d6 + 1 × 1d6'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      final slots = store.activeCharacter!.spellSlots;
      expect(slots.forLevel(1)!.current, 4); // no gasta la ranura de nivel 1
      expect(slots.forLevel(2)!.current, 1);
    });

    testWidgets(
      'dado compuesto 2d8+4d6: tira todos los grupos y muestra el desglose',
      (tester) async {
        final character = buildCharacter(id: 'char_ice', name: 'Rook');
        character.abilitiesByAction.action.add(
          Ability.fromJson({
            'id': 'a_ice',
            'name': 'Tormenta de hielo',
            'type': 'spell',
            'related_stat': 'int',
            'attack_type': 'save',
            'base_level': 1,
            'damage_dice': '2d8+4d6',
          }),
        );
        final store = await bootWith(character);
        await pumpActions(tester, store, random: FakeRandom([0]));

        await tapText(tester, 'Tormenta de hielo');
        await tapText(tester, 'El objetivo falla · tirar daño');

        expect(find.text('Daño / efecto'), findsOneWidget);
        expect(find.text('2d8 [1, 1] = 2'), findsOneWidget);
        expect(find.text('4d6 [1, 1, 1, 1] = 4'), findsOneWidget);
        expect(find.text('6'), findsOneWidget); // 2 + 4
      },
    );

    testWidgets('"Usar" resuelve un efecto sin tirada y gasta la carga', (
      tester,
    ) async {
      final character = buildCharacter(id: 'char_use', name: 'Rook');
      character.abilitiesByAction.action.add(
        Ability.fromJson({
          'id': 'a_shield',
          'name': 'Escudo Arcano',
          'type': 'spell',
          'related_stat': 'int',
          'attack_type': 'none',
          'base_level': 0,
          'magic_charges': {'has_charges': true, 'max': 2, 'current': 2},
        }),
      );

      final store = await bootWith(character);
      await pumpActions(tester, store);

      await tapText(tester, 'Escudo Arcano');
      expect(find.text('Usos: 2/2'), findsOneWidget);
      expect(find.text('Usar'), findsOneWidget);
      // attack_type 'none' no muestra una tirada de ataque sin sentido.
      expect(find.text('Tirar d20'), findsNothing);

      await tapText(tester, 'Usar');
      expect(find.text('Usar'), findsNothing);

      final ability = store.activeCharacter!.abilitiesByAction.action
          .firstWhere((a) => a.id == 'a_shield');
      expect(ability.magicCharges.current, 1);
    });

    testWidgets('habilidad ligada a un recurso: muestra, gasta y cura', (
      tester,
    ) async {
      final character = buildCharacter(id: 'char_res', name: 'Rook');
      character.resources
        ..clear()
        ..add(ResourcePoint(name: 'Ki', current: 3, max: 4));
      character.abilitiesByAction.bonusAction.add(
        Ability.fromJson({
          'id': 'a_ki',
          'name': 'Ráfaga Vital',
          'attack_type': 'none',
          'resource_name': 'Ki',
          'resource_cost': 2,
          'heal_dice': '1d4',
        }),
      );

      final store = await bootWith(character);
      await pumpActions(tester, store, random: FakeRandom([0]));

      await tapText(tester, 'Ráfaga Vital');
      expect(find.text('Recurso: 3/4 · coste 2 (Ki)'), findsOneWidget);

      await tapText(tester, 'Usar');
      // Curación diferenciada del daño.
      expect(find.text('Curación'), findsOneWidget);
      expect(find.byKey(const ValueKey('heal_total')), findsOneWidget);
      expect(store.activeCharacter!.resources.single.current, 1);
    });

    testWidgets('sin puntos suficientes bloquea el uso', (tester) async {
      final character = buildCharacter(id: 'char_res2', name: 'Rook');
      character.resources
        ..clear()
        ..add(ResourcePoint(name: 'Ki', current: 1, max: 4));
      character.abilitiesByAction.action.add(
        Ability.fromJson({
          'id': 'a_ki',
          'name': 'Lluvia de Golpes',
          'attack_type': 'none',
          'resource_name': 'Ki',
          'resource_cost': 2,
        }),
      );

      final store = await bootWith(character);
      await pumpActions(tester, store);

      await tapText(tester, 'Lluvia de Golpes');
      expect(find.text('Usar'), findsNothing);
      expect(find.text('No te alcanzan los puntos de Ki.'), findsOneWidget);
      expect(store.activeCharacter!.resources.single.current, 1);
    });
  });

  group('estados y curación aplicada', () {
    testWidgets('un estado con desventaja la deja marcada al abrir', (
      tester,
    ) async {
      final character = buildCharacter(id: 'char_pois', name: 'Rook');
      character.activeConditions.add('Envenenado');
      final store = await bootWith(character);
      await pumpActions(tester, store, random: FakeRandom([9, 3]));

      await tapText(tester, 'Espada Larga');
      final selector = tester.widget<SegmentedButton<AdvantageMode>>(
        find.byKey(const ValueKey('advantage_selector')),
      );
      expect(selector.selected, {AdvantageMode.disadvantage});
      expect(find.byKey(const ValueKey('disadvantage_hint')), findsOneWidget);
      expect(find.text('Tirar 2d20'), findsOneWidget);
    });

    testWidgets('sin estados la tirada arranca en Normal', (tester) async {
      final store = await bootWith(buildCharacter(id: 'c', name: 'Rook'));
      await pumpActions(tester, store);
      await tapText(tester, 'Espada Larga');
      expect(find.byKey(const ValueKey('disadvantage_hint')), findsNothing);
      expect(find.text('Tirar d20'), findsOneWidget);
    });

    testWidgets('"Aplicar a mí" suma la curación a la vida', (tester) async {
      final character = buildCharacter(
        id: 'char_heal',
        name: 'Rook',
        hpCurrent: 10,
      );
      character.abilitiesByAction.bonusAction.add(
        Ability.fromJson({
          'id': 'a_heal',
          'name': 'Tomar Aliento',
          'attack_type': 'none',
          'heal_dice': '1d4+2',
        }),
      );
      final store = await bootWith(character);
      // 0 % 4 + 1 = 1 en el d4 → 1 + 2 = 3.
      await pumpActions(tester, store, random: FakeRandom([0]));

      await tapText(tester, 'Tomar Aliento');
      await tapText(tester, 'Usar');
      expect(find.text('Aplicar a mí (+3 PG)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('heal_apply')));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.basicInfo.currentHp, 13);
      expect(find.byType(ResolutionSheet), findsNothing);
    });
  });

  group('selector de ventaja y desventaja', () {
    Future<CharacterStore> openSword(
      WidgetTester tester,
      List<int> outcomes,
    ) async {
      final store = await bootWith(
        buildCharacter(id: 'char_adv', name: 'Rook'),
      );
      await pumpActions(tester, store, random: FakeRandom(outcomes));
      await tapText(tester, 'Espada Larga');
      return store;
    }

    SegmentedButton<AdvantageMode> selector(WidgetTester tester) =>
        tester.widget(find.byKey(const ValueKey('advantage_selector')));

    testWidgets(
      'muestra Ventaja | Normal | Desventaja, con Normal por defecto',
      (tester) async {
        await openSword(tester, [9]);

        expect(selector(tester).selected, {AdvantageMode.normal});
        final left = tester.getTopLeft(find.text('Ventaja')).dx;
        final middle = tester.getTopLeft(find.text('Normal')).dx;
        final right = tester.getTopLeft(find.text('Desventaja')).dx;
        expect(left, lessThan(middle));
        expect(middle, lessThan(right));
        expect(find.text('Tirar d20'), findsOneWidget);

        await tapText(tester, 'Desventaja');
        expect(selector(tester).selected, {AdvantageMode.disadvantage});
        expect(find.text('Tirar 2d20'), findsOneWidget);

        await tapText(tester, 'Normal');
        expect(selector(tester).selected, {AdvantageMode.normal});
        expect(find.text('Tirar d20'), findsOneWidget);
      },
    );

    testWidgets('ventaja: se queda con el mayor y muestra ambos dados', (
      tester,
    ) async {
      // 18 % 20 + 1 = 19 y 5 % 20 + 1 = 6.
      await openSword(tester, [18, 5]);

      await tapText(tester, 'Ventaja');
      await tapText(tester, 'Tirar 2d20');

      expect(find.text('Dados: 19 y 6 → se usa 19 (ventaja)'), findsOneWidget);
      expect(find.text('[19, 6]'), findsOneWidget);
      // 19 + 5 de bono de la espada.
      expect(find.text('24'), findsOneWidget);
      // 19 no es crítico.
      expect(find.text('¡Éxito crítico!'), findsNothing);
      expect(find.byKey(const ValueKey('natural_tag')), findsNothing);
    });

    testWidgets('desventaja: se queda con el menor y muestra ambos dados', (
      tester,
    ) async {
      await openSword(tester, [18, 5]);

      await tapText(tester, 'Desventaja');
      await tapText(tester, 'Tirar 2d20');

      expect(
        find.text('Dados: 19 y 6 → se usa 6 (desventaja)'),
        findsOneWidget,
      );
      expect(find.text('[19, 6]'), findsOneWidget);
      expect(find.text('11'), findsOneWidget); // 6 + 5
    });

    testWidgets('el crítico se evalúa sobre el dado elegido (ventaja)', (
      tester,
    ) async {
      // 20 y 3: con ventaja cuenta el 20.
      await openSword(tester, [19, 2]);

      await tapText(tester, 'Ventaja');
      await tapText(tester, 'Tirar 2d20');

      expect(find.text('[20, 3]'), findsOneWidget);
      expect(find.text('¡Éxito crítico!'), findsOneWidget);
      expect(find.text('Natural 20'), findsOneWidget);
      expect(find.text('¡Pifia!'), findsNothing);
    });

    testWidgets('un 20 descartado por la desventaja no es crítico', (
      tester,
    ) async {
      // 20 y 3: con desventaja cuenta el 3.
      await openSword(tester, [19, 2]);

      await tapText(tester, 'Desventaja');
      await tapText(tester, 'Tirar 2d20');

      expect(find.text('[20, 3]'), findsOneWidget);
      expect(find.text('¡Éxito crítico!'), findsNothing);
      expect(find.byKey(const ValueKey('natural_tag')), findsNothing);
    });

    testWidgets('la pifia se evalúa sobre el dado elegido (desventaja)', (
      tester,
    ) async {
      // 1 y 20: con desventaja cuenta el 1.
      await openSword(tester, [0, 19]);

      await tapText(tester, 'Desventaja');
      await tapText(tester, 'Tirar 2d20');

      expect(find.text('[1, 20]'), findsOneWidget);
      expect(find.text('¡Pifia!'), findsOneWidget);
      expect(find.text('Natural 1'), findsOneWidget);
      expect(find.text('¡Éxito crítico!'), findsNothing);
    });

    testWidgets('una tirada normal no muestra desglose de dos dados', (
      tester,
    ) async {
      await openSword(tester, [9]);

      await tapText(tester, 'Tirar d20');

      expect(find.text('Dado natural: 10'), findsOneWidget);
      expect(find.byKey(const ValueKey('dice_breakdown')), findsNothing);
    });

    testWidgets('una acción de salvación no ofrece el selector', (
      tester,
    ) async {
      final character = buildCharacter(id: 'char_save', name: 'Rook');
      character.abilitiesByAction.action.add(
        Ability.fromJson({
          'id': 'a_save',
          'name': 'Aliento Gélido',
          'attack_type': 'save',
          'damage_dice': '2d6',
        }),
      );
      final store = await bootWith(character);
      await pumpActions(tester, store);

      await tapText(tester, 'Aliento Gélido');
      expect(find.byKey(const ValueKey('advantage_selector')), findsNothing);
    });
  });
}
