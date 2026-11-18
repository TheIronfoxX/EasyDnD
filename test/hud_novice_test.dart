// Tests de la interfaz para novatos (rework): bienvenida, shell de tres
// pestañas, vida en la píldora, recursos en Combate, lista de poderes por
// categoría, estados, ajustes (borrar ficha), buscador y persistencia.
//
// De punta a punta contra el store real (prefs mockeadas): se toca lo
// que tocaría el jugador y se comprueba el efecto en la ficha.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/domain/models/ability.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/features/editor/character_editor_screen.dart';
import 'package:easydnd/features/hud/hud_resolution_sheet.dart';
import 'package:easydnd/features/import/import_wizard_screen.dart';
import 'package:easydnd/state/character_store.dart';
import 'package:easydnd/state/skin_controller.dart';

import 'fakes/test_fichas.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Llamarlo de nuevo dentro de un test simula reiniciar la app.
  Future<CharacterStore> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    return store;
  }

  /// Pantalla alta: Combate ahora tiene más tarjetas y las listas se
  /// construyen en diferido.
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpApp(WidgetTester tester, CharacterStore store) async {
    final prefs = await SharedPreferences.getInstance();
    final skin = SkinController(prefs);
    await skin.init();
    await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    // Las listas se construyen en diferido: si aún no existe, desplaza
    // la última lista visible hasta encontrarlo.
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> pickMenu(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> applyDamageFromPill(WidgetTester tester, int amount) async {
    await tapKey(tester, 'hp-pill');
    await tester.tap(find.text('Daño'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '$amount');
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar daño'));
    await tester.pumpAndSettle();
    // Cierra la hoja de Vida.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  }

  Future<void> openSettingsDelete(WidgetTester tester) async {
    await pickMenu(tester, 'Ajustes');
    await tapKey(tester, 'settings-delete');
  }

  group('datos', () {
    testWidgets('Copiar ficha deja el JSON en el portapapeles', (tester) async {
      tallView(tester);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await pickMenu(tester, 'Ajustes');
      await tapKey(tester, 'settings-copy');

      expect(copied, isNotNull);
      expect(copied, contains('Rook'));
      expect(find.text('Ficha copiada al portapapeles.'), findsOneWidget);
    });

    testWidgets('Exportar a archivo y Respaldar son filas aparte', (
      tester,
    ) async {
      tallView(tester);
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await pickMenu(tester, 'Ajustes');
      for (final key in [
        'settings-export',
        'settings-copy',
        'settings-backup',
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey(key)),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
    });
  });

  group('bienvenida', () {
    testWidgets('las dos vías de alta abren sus pantallas', (tester) async {
      final store = await boot();
      await pumpApp(tester, store);

      expect(find.text('EasyDnD'), findsOneWidget);
      expect(find.text('Importar archivo JSON'), findsOneWidget);
      await tester.tap(find.text('Ficha en blanco'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva ficha'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Importar desde Nivel20'));
      await tester.pumpAndSettle();
      expect(find.text('Importar ficha'), findsOneWidget);
    });
  });

  group('shell', () {
    testWidgets('Combate abre con armadura, iniciativa y movimiento', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      for (final key in ['vital-ac', 'vital-init', 'vital-speed']) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      final info = store.activeCharacter!.basicInfo;
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('vital-ac')),
          matching: find.text('${info.ac}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tres pestañas que son índices de tarjetas', (tester) async {
      tester.view.physicalSize = const Size(412, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.text('Rook'), findsOneWidget);
      // Combate: recursos y tarjetas; la vida solo en la píldora.
      expect(find.byKey(const ValueKey('slots-schema')), findsOneWidget);
      expect(find.byKey(const ValueKey('resources-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-attacks')), findsOneWidget);
      expect(find.text('20/20'), findsOneWidget);
      expect(find.text('Daño'), findsNothing);
      // Sin control de turno.
      expect(find.text('Terminar turno'), findsNothing);
      expect(find.text('Reacción'), findsNothing);

      await tester.tap(find.text('Ficha'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-attributes')), findsOneWidget);

      await tester.tap(find.text('Mochila'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-weapons')), findsOneWidget);
    });

    testWidgets('el ⋮ tiene solo Recargar todo, Editar ficha y Ajustes', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      expect(find.text('Recargar todo'), findsOneWidget);
      expect(find.text('Editar ficha'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Descanso largo'), findsNothing);
      expect(find.text('Descanso corto'), findsNothing);

      await tester.tap(find.text('Editar ficha'));
      await tester.pumpAndSettle();
      expect(find.byType(CharacterEditorScreen), findsOneWidget);
    });

    testWidgets('Recargar todo deja vida y ranuras al máximo', (tester) async {
      final store = await boot();
      store.addCharacter(
        buildCharacter(
          id: 'char_rook',
          name: 'Rook',
          hpCurrent: 4,
          slotCurrent: 0,
        ),
      );
      await pumpApp(tester, store);

      await pickMenu(tester, 'Recargar todo');
      final c = store.activeCharacter!;
      expect(c.basicInfo.currentHp, 20);
      expect(c.spellSlots.slots.single.current, 4);
      expect(find.textContaining('Todo recargado'), findsOneWidget);
    });

    testWidgets('el nombre abre el selector y cambia de personaje', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      store.addCharacter(buildCharacter(id: 'char_mira', name: 'Mira'));
      await pumpApp(tester, store);
      expect(store.activeIndex, 1);

      await tapKey(tester, 'roster-switch');
      await tapKey(tester, 'roster-0');

      expect(store.activeIndex, 0);
      expect(find.text('Rook'), findsOneWidget);
      expect(store.roster, hasLength(2));
    });

    testWidgets('Ajustes abre la corrección con IA', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await pickMenu(tester, 'Ajustes');
      await tapKey(tester, 'settings-ai-fix');
      expect(find.byType(ImportWizardScreen), findsOneWidget);
    });

    testWidgets('>= 600 px: riel lateral en vez de barra inferior', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('cabecera hero y vida directa', () {
    testWidgets('-1 y +1 cambian la vida sin abrir la hoja', (tester) async {
      tallView(tester);
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await tapKey(tester, 'hp-minus');
      expect(store.activeCharacter!.basicInfo.currentHp, 19);
      expect(find.text('19/20'), findsOneWidget);
      await tapKey(tester, 'hp-plus');
      expect(store.activeCharacter!.basicInfo.currentHp, 20);
    });

    testWidgets('emblema y lema se eligen y se guardan en la ficha', (
      tester,
    ) async {
      tallView(tester);
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await tapKey(tester, 'hero-header');
      await tapKey(tester, 'emblem-fire');
      await tester.enterText(
        find.byKey(const ValueKey('motto-field')),
        'La llama',
      );
      await tapKey(tester, 'hero-save');
      final c = store.activeCharacter!;
      expect(c.emblem, 'fire');
      expect(c.motto, 'La llama');
      expect(find.text('La llama'), findsOneWidget);
      // Round-trip JSON: una ficha vieja sin los campos sigue cargando.
      final json = c.toJson()
        ..remove('emblem')
        ..remove('motto');
      expect(CharacterModel.fromJson(json).motto, '');
    });
  });

  group('vida', () {
    testWidgets('la píldora abre la hoja de Vida: daño y curación', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await tapKey(tester, 'hp-pill');
      expect(find.text('de 20'), findsOneWidget);
      expect(find.text('Defensa'), findsOneWidget);

      await tester.tap(find.text('Daño'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '7');
      await tester.tap(find.widgetWithText(FilledButton, 'Aplicar daño'));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.basicInfo.currentHp, 13);
      // La vida se ve en la tarjeta de Combate (y en la hoja de Vida).
      expect(find.text('13'), findsWidgets);

      await tester.tap(find.text('Curación'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.tap(find.widgetWithText(FilledButton, 'Curar'));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.basicInfo.currentHp, 15);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('15/20'), findsOneWidget);
    });

    testWidgets('vida temporal desde la hoja', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await tapKey(tester, 'hp-pill');
      await tapKey(tester, 'temp-hp-button');
      await tester.enterText(find.byType(TextFormField), '6');
      await tester.tap(find.widgetWithText(FilledButton, 'Fijar'));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.basicInfo.tempHp, 6);
      expect(find.text('+6 de escudo'), findsOneWidget);
    });

    testWidgets('a 0 PG Combate muestra las salvaciones de muerte', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);
      expect(find.byKey(const ValueKey('down-card')), findsNothing);

      store.applyDamage(20);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('down-card')), findsOneWidget);
      expect(find.textContaining('Inconsciente.'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tapKey(tester, 'death-success');
      }
      expect(store.activeCharacter!.basicInfo.deathSaveSuccesses, 3);
      expect(find.textContaining('Estable'), findsOneWidget);
    });
  });

  group('recursos en Combate', () {
    testWidgets('se gastan y recuperan tocando los puntos', (tester) async {
      tallView(tester);
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await tester.tap(find.byTooltip('Gastar un punto de Furia'));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.resources.single.current, 1);
      await tester.tap(find.byTooltip('Recuperar un punto de Furia'));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.resources.single.current, 2);

      // Las ranuras se gastan en la pantalla de Conjuros.
      await tapKey(tester, 'nav-spells');
      await tester.tap(find.byTooltip('Gastar ranura de nivel 1'));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.spellSlots.slots.single.current, 3);

      await tapKey(tester, 'refill-slots');
      expect(store.activeCharacter!.spellSlots.slots.single.current, 4);
      expect(store.activeCharacter!.resources.single.current, 2);
    });
  });

  group('favoritas', () {
    testWidgets('la estrella lleva un poder a Favoritas y persiste', (
      tester,
    ) async {
      tallView(tester);
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      expect(find.byKey(const ValueKey('favorites-empty')), findsOneWidget);

      final weapon = store.activeCharacter!.inventory.weapons.first;
      await tapKey(tester, 'nav-attacks');
      await tapKey(tester, 'fav-${weapon.id}');
      expect(store.activeCharacter!.favoritePowers, [weapon.id]);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('favorites-empty')), findsNothing);
      expect(find.text(weapon.name), findsOneWidget);

      // Sobrevive a reiniciar.
      final again = await boot();
      expect(again.activeCharacter!.favoritePowers, [weapon.id]);
    });
  });

  group('poderes por categoría', () {
    testWidgets('Ataques y habilidades agrupa en Daño y abre el detalle', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await tapKey(tester, 'nav-attacks');
      expect(find.text('Daño'), findsWidgets);
      expect(find.text('Espada Larga'), findsOneWidget);

      await tester.tap(find.text('Espada Larga'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle'), findsOneWidget);
      await tapKey(tester, 'power-use');
      expect(find.byType(ResolutionSheet), findsOneWidget);
    });

    testWidgets('Conjuros usa la frase en llano y la categoría de la IA', (
      tester,
    ) async {
      final store = await boot();
      final character = buildCharacter(id: 'char_rook', name: 'Rook');
      character.abilitiesByAction.action.add(
        Ability.fromJson({
          'id': 'sp_escudo',
          'name': 'Escudo arcano',
          'type': 'spell',
          'base_level': 1,
          'attack_type': 'none',
          'power_role': 'Defensa',
          'plain_summary': 'Te proteges cuando te atacan.',
        }),
      );
      store.addCharacter(character);
      await pumpApp(tester, store);

      await tapKey(tester, 'nav-spells');
      expect(find.text('Defensa'), findsOneWidget);
      expect(find.text('Te proteges cuando te atacan.'), findsOneWidget);
      expect(find.text('nv 1'), findsOneWidget);
    });
  });

  group('estados', () {
    testWidgets('se añaden desde su pantalla y se ven en la tarjeta', (
      tester,
    ) async {
      tallView(tester);
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);
      expect(find.text('Ninguno: estás bien'), findsOneWidget);

      await tapKey(tester, 'nav-conditions');
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envenenado'));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.activeConditions, ['Envenenado']);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Envenenado'), findsOneWidget);
    });
  });

  group('borrar ficha desde Ajustes', () {
    testWidgets('cancelar deja el roster intacto', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await openSettingsDelete(tester);
      expect(find.textContaining('"Rook"'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(store.roster, hasLength(1));
    });

    testWidgets('confirmar borra la activa y cae en la anterior', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      store.addCharacter(buildCharacter(id: 'char_mira', name: 'Mira'));
      await pumpApp(tester, store);

      await openSettingsDelete(tester);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(store.roster, hasLength(1));
      expect(store.activeCharacter!.basicInfo.name, 'Rook');
      expect(find.text('Rook'), findsOneWidget);
      expect(find.text('Ficha de Mira eliminada.'), findsOneWidget);
    });

    testWidgets('borrar la última vuelve a la bienvenida', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await openSettingsDelete(tester);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(store.roster, isEmpty);
      expect(find.text('Importar desde Nivel20'), findsOneWidget);
    });
  });

  group('buscador de reglas', () {
    testWidgets('encuentra un estado y lo explica', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpApp(tester, store);

      await tapKey(tester, 'rules-search');
      await tester.enterText(
        find.byKey(const ValueKey('rules-search-field')),
        'envene',
      );
      await tester.pumpAndSettle();
      expect(find.text('Envenenado'), findsOneWidget);
      expect(find.text('Cegado'), findsNothing);
    });
  });

  group('persistencia', () {
    testWidgets('daño e inventario sobreviven a reiniciar', (tester) async {
      final first = await boot();
      first.addCharacter(
        buildCharacter(id: 'char_rook', name: 'Rook', hpCurrent: 20),
      );
      await pumpApp(tester, first);

      await applyDamageFromPill(tester, 5);

      await tester.tap(find.text('Mochila'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'nav-weapons');
      await tester.tap(find.text('Espada Larga'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sumar una copia de Espada Larga'));
      await tester.pumpAndSettle();

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );

      final second = await boot();
      expect(second.activeCharacter!.basicInfo.currentHp, 15);
      expect(second.activeCharacter!.inventory.weapons.single.quantity, 2);
    });
  });
}
