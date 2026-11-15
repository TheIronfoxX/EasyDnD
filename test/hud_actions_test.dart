// Tests de la sección de acciones del turno (Etapa 5c).
//
// Se pumpea HudActionsSection solo, con el store real y un Random falso:
// así se toca la misma UI que ve el jugador (tarjetas → hoja de
// resolución) y se verifica el efecto en la ficha, sin depender del
// resto del HUD. La hoja recibe los valores ya resueltos por la sección
// (modificador, CD, ranuras, cargas) y avisa al store por callback.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/core/theme/app_theme.dart';
import 'package:easydnd/core/ui/pip_shape.dart';
import 'package:easydnd/core/ui/tactical_card.dart';
import 'package:easydnd/domain/models/ability.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/features/hud/hud_actions_section.dart';
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

  /// Pumpea solo la sección de acciones en una pantalla alta, para que
  /// ninguna tarjeta ni botón de la hoja quede fuera del viewport.
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
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HudActionsSection(
                character: store.activeCharacter!,
                random: random,
              ),
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

  group('listado de acciones', () {
    testWidgets('muestra una tarjeta por economía de acción', (tester) async {
      final character = buildCharacter(id: 'char_actions', name: 'Rook');
      character.abilitiesByAction.bonusAction.add(
        Ability.fromJson({
          'id': 'a_bonus',
          'name': 'Empujón',
          'related_stat': 'str',
          'damage_dice': '1d4',
        }),
      );
      character.abilitiesByAction.reaction.add(
        Ability.fromJson({
          'id': 'a_reaction',
          'name': 'Contraataque',
          'related_stat': 'dex',
          'damage_dice': '1d8',
        }),
      );
      character.abilitiesByAction.passive.add(
        Ability.fromJson({
          'id': 'a_pass',
          'name': 'Paso Sombrío',
          'attack_type': 'none',
          'tactical_role': 'Utilidad',
        }),
      );

      final store = await bootWith(character);
      await pumpActions(tester, store);

      expect(find.text('Armas'), findsOneWidget);
      expect(find.text('Acción'), findsOneWidget);
      expect(find.text('Acción adicional'), findsOneWidget);
      expect(find.text('Reacción'), findsOneWidget);
      expect(find.text('Pasivas'), findsOneWidget);

      expect(find.text('Espada Larga'), findsOneWidget);
      expect(find.text('Golpe Devastador'), findsOneWidget);
      expect(find.text('Empujón'), findsOneWidget);
      expect(find.text('Contraataque'), findsOneWidget);
      expect(find.text('Paso Sombrío'), findsOneWidget);

      // La fila del arma resume ataque y daño; la del rasgo, su tipo.
      expect(find.text('Arma · Ataque +5 · 1d8+3 cortante'), findsOneWidget);
      expect(find.text('Habilidad · Ataque +6 · 2d6'), findsOneWidget);
    });

    testWidgets('las pasivas despliegan lore y resumen táctico', (
      tester,
    ) async {
      final character = buildCharacter(id: 'char_passive', name: 'Rook');
      character.abilitiesByAction.passive.add(
        Ability.fromJson({
          'id': 'a_pass',
          'name': 'Paso Sombrío',
          'attack_type': 'none',
          'tactical_role': 'Utilidad',
          'lore_description': 'Te moves sin dejar rastro.',
          'tactical_summary': 'No rompe la invisibilidad.',
        }),
      );

      final store = await bootWith(character);
      await pumpActions(tester, store);

      expect(find.text('Te moves sin dejar rastro.'), findsNothing);

      await tapText(tester, 'Paso Sombrío');

      expect(find.text('Te moves sin dejar rastro.'), findsOneWidget);
      expect(find.text('No rompe la invisibilidad.'), findsOneWidget);
      // Sigue siendo informativa: no abre la hoja de tiradas.
      expect(find.text('Tirar d20'), findsNothing);
    });
  });

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
      expect(find.text('DAÑO / EFECTO'), findsOneWidget);
      expect(find.text('1d8+3'), findsOneWidget); // desglose de la tirada

      await tapText(tester, 'Cerrar');
      expect(find.text('DAÑO / EFECTO'), findsNothing);
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

      expect(find.text('DAÑO / EFECTO'), findsOneWidget);
      expect(find.text('2d6 + 1 × 1d6'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      final slots = store.activeCharacter!.spellSlots;
      expect(slots.forLevel(1)!.current, 4); // no gasta la ranura de nivel 1
      expect(slots.forLevel(2)!.current, 1);
    });

    testWidgets('dado compuesto 2d8+4d6: tira todos los grupos y muestra el desglose', (
      tester,
    ) async {
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

      expect(find.text('DAÑO / EFECTO'), findsOneWidget);
      expect(find.text('2d8 [1, 1] = 2'), findsOneWidget);
      expect(find.text('4d6 [1, 1, 1, 1] = 4'), findsOneWidget);
      expect(find.text('6'), findsOneWidget); // 2 + 4
    });

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

      // Grupo propio con encabezado, insignia y chip de recurso.
      expect(find.text('HABILIDADES'), findsWidgets);
      expect(find.text('Ki 3/4'), findsOneWidget);
      expect(find.textContaining('Habilidad · Efecto'), findsOneWidget);

      await tapText(tester, 'Ráfaga Vital');
      expect(find.text('Recurso: 3/4 · coste 2 (Ki)'), findsOneWidget);

      await tapText(tester, 'Usar');
      // Curación diferenciada del daño.
      expect(find.text('Curación'.toUpperCase()), findsOneWidget);
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

  group('filtro rápido, insignias y lectura de reglas', () {
    /// Ficha con un arma, tres poderes de origen distinto, un conjuro con
    /// concentración y una habilidad sin tipo (fichas viejas).
    CharacterModel buildMixed() {
      final character = buildCharacter(id: 'char_mix', name: 'Rook');
      character.abilitiesByAction.bonusAction.addAll([
        Ability.fromJson({
          'id': 'a_furia',
          'name': 'Furia Primigenia',
          'type': 'class',
          'attack_type': 'none',
          'lore_description': 'Te llenas de una rabia ancestral.',
          'success_description': 'Resistes el daño físico.',
          'failure_description': 'La furia se agota.',
        }),
        Ability.fromJson({
          'id': 'a_racial',
          'name': 'Aliento de Dragón',
          'type': 'racial',
          'attack_type': 'save',
        }),
        Ability.fromJson({
          'id': 'a_dote',
          'name': 'Golpe Maestro',
          'type': 'feat',
          'attack_type': 'attack',
        }),
        Ability.fromJson({
          'id': 'a_item',
          'name': 'Rayo del Anillo',
          'type': 'item',
          'attack_type': 'none',
        }),
        Ability.fromJson({
          'id': 'a_viejo',
          'name': 'Habilidad Antigua',
          'attack_type': 'none',
        }),
      ]);
      character.abilitiesByAction.action.add(
        Ability.fromJson({
          'id': 'a_bendicion',
          'name': 'Bendición Lunar',
          'type': 'spell',
          'base_level': 1,
          'attack_type': 'none',
          'concentration': true,
          'lore_description': 'Una luz suave protege a tus aliados.',
        }),
      );
      return character;
    }

    testWidgets('el filtro rápido muestra solo la familia elegida', (
      tester,
    ) async {
      final store = await bootWith(buildMixed());
      await pumpActions(tester, store);

      Future<void> pick(String key) async {
        await tester.tap(find.byKey(Key('actions-filter-$key')));
        await tester.pumpAndSettle();
      }

      // Todo: de todo un poco.
      expect(find.text('Espada Larga'), findsOneWidget);
      expect(find.text('Furia Primigenia'), findsOneWidget);
      expect(find.text('Bendición Lunar'), findsOneWidget);

      await pick('weapons');
      expect(find.text('Espada Larga'), findsOneWidget);
      expect(find.text('Furia Primigenia'), findsNothing);
      expect(find.text('Bendición Lunar'), findsNothing);

      await pick('abilities');
      expect(find.text('Espada Larga'), findsNothing);
      expect(find.text('Furia Primigenia'), findsOneWidget);
      expect(find.text('Bendición Lunar'), findsNothing);

      await pick('spells');
      expect(find.text('Espada Larga'), findsNothing);
      expect(find.text('Furia Primigenia'), findsNothing);
      expect(find.text('Bendición Lunar'), findsOneWidget);

      await pick('all');
      expect(find.text('Espada Larga'), findsOneWidget);
      expect(find.text('Furia Primigenia'), findsOneWidget);
      expect(find.text('Bendición Lunar'), findsOneWidget);
    });

    testWidgets('las etiquetas del filtro llevan su conteo', (tester) async {
      final store = await bootWith(buildMixed());
      await pumpActions(tester, store);

      expect(find.textContaining('Todo · '), findsOneWidget);
      expect(find.text('Armas · 1'), findsOneWidget);
      expect(find.textContaining('Habilidades · '), findsOneWidget);
      expect(find.text('Conjuros · 1'), findsOneWidget);
    });

    testWidgets('un filtro sin resultados lo dice', (tester) async {
      final character = buildCharacter(id: 'char_nospell', name: 'Rook');
      final store = await bootWith(character);
      await pumpActions(tester, store);

      await tester.tap(find.byKey(const Key('actions-filter-spells')));
      await tester.pumpAndSettle();
      expect(
        find.text('No hay nada que mostrar con este filtro.'),
        findsOneWidget,
      );
    });

    testWidgets('insignias de origen según el type', (tester) async {
      final store = await bootWith(buildMixed());
      await pumpActions(tester, store);

      String badge(String id) => tester
          .widget<TonePill>(find.byKey(ValueKey('origin_badge_$id')))
          .label;

      expect(badge('a_furia'), 'Clase');
      expect(badge('a_racial'), 'Racial');
      expect(badge('a_dote'), 'Dote');
      expect(badge('a_item'), 'Objeto');
      // type == 'trait' (el valor por defecto de fichas viejas).
      expect(badge('a_viejo'), 'Habilidad');
      // Los conjuros no llevan insignia de origen.
      expect(find.byKey(const ValueKey('origin_badge_a_bendicion')), findsNothing);
    });

    testWidgets('la insignia de concentración solo sale cuando corresponde', (
      tester,
    ) async {
      final store = await bootWith(buildMixed());
      await pumpActions(tester, store);

      expect(
        find.byKey(const ValueKey('concentration_badge_a_bendicion')),
        findsOneWidget,
      );
      expect(find.text('Concentración'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('concentration_badge_a_furia')),
        findsNothing,
      );
    });

    testWidgets('el recurso vinculado muestra pips sin cambiar su texto', (
      tester,
    ) async {
      final character = buildCharacter(id: 'char_pips', name: 'Rook');
      character.resources
        ..clear()
        ..add(ResourcePoint(name: 'Ki', current: 3, max: 4));
      character.abilitiesByAction.bonusAction.add(
        Ability.fromJson({
          'id': 'a_ki',
          'name': 'Ráfaga Vital',
          'attack_type': 'none',
          'resource_name': 'Ki',
        }),
      );
      final store = await bootWith(character);
      await pumpActions(tester, store);

      final badge = find.ancestor(
        of: find.text('Ki 3/4'),
        matching: find.byType(Column),
      );
      expect(
        find.descendant(of: badge.first, matching: find.byType(PipGlyph)),
        findsNWidgets(4),
      );
    });

    testWidgets('el botón de info abre la lectura de reglas sin tirar dados', (
      tester,
    ) async {
      final store = await bootWith(buildMixed());
      await pumpActions(tester, store);

      await tester.ensureVisible(find.byKey(const ValueKey('info_a_furia')));
      await tester.tap(find.byKey(const ValueKey('info_a_furia')));
      await tester.pumpAndSettle();

      expect(find.text('Te llenas de una rabia ancestral.'), findsOneWidget);
      expect(find.text('Resistes el daño físico.'), findsOneWidget);
      expect(find.text('La furia se agota.'), findsOneWidget);
      expect(find.text('SI TIENE ÉXITO'), findsOneWidget);
      expect(find.text('SI FALLA'), findsOneWidget);
      // No es la hoja de resolución: no hay botón de tirar.
      expect(find.text('Tirar d20'), findsNothing);
      expect(find.text('Usar'), findsNothing);
    });

    testWidgets('lectura de una habilidad sin descripción lo avisa', (
      tester,
    ) async {
      final store = await bootWith(buildMixed());
      await pumpActions(tester, store);

      await tester.ensureVisible(find.byKey(const ValueKey('info_a_viejo')));
      await tester.tap(find.byKey(const ValueKey('info_a_viejo')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sin descripción todavía'), findsOneWidget);
    });

    testWidgets('el botón de info de un conjuro muestra concentración', (
      tester,
    ) async {
      final store = await bootWith(buildMixed());
      await pumpActions(tester, store);

      await tester.ensureVisible(find.byKey(const ValueKey('info_a_bendicion')));
      await tester.tap(find.byKey(const ValueKey('info_a_bendicion')));
      await tester.pumpAndSettle();

      expect(find.text('Una luz suave protege a tus aliados.'), findsOneWidget);
      // La píldora aparece en la tarjeta y en la hoja.
      expect(find.text('Concentración'), findsNWidgets(2));
      expect(find.text('Conjuro de nivel 1'), findsOneWidget);
    });
  });
}
