// Tests del asistente guiado de creación (5 pasos): flujo completo hasta
// el store, navegación Atrás/Adelante sin perder selecciones, estadísticas
// en vivo y acceso a "Ficha en blanco".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/features/creation/character_creation_wizard_screen.dart';
import 'package:easydnd/features/hud/welcome_screen.dart';
import 'package:easydnd/state/character_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<CharacterStore> boot() async {
    final store = CharacterStore(RosterRepository(await SharedPreferences.getInstance()));
    await store.init();
    return store;
  }

  Future<void> pumpApp(WidgetTester tester, CharacterStore store, Widget home) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<CharacterStore>.value(
        value: store,
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openWizard(WidgetTester tester, CharacterStore store) async {
    await pumpApp(
      tester,
      store,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CharacterCreationWizardScreen()),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  /// Las listas son perezosas: baja hasta que el widget exista.
  Future<void> ensureBuilt(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      return;
    }
    final list = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    ).first;
    await tester.scrollUntilVisible(finder, 300, scrollable: list);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await ensureBuilt(tester, finder);
    await tester.tap(finder.hitTestable());
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) => tapKey(tester, 'creation-next');

  Future<void> fillStep1(WidgetTester tester, {String name = 'Elminster'}) async {
    await tester.enterText(find.byKey(const Key('creation-name')), name);
    await tester.pump();
    await tapKey(tester, 'class-mago');
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('flujo completo: Paso 1 → 5 y alta en el CharacterStore', (tester) async {
    final store = await boot();
    await openWizard(tester, store);

    // Paso 1: sin nombre ni clase no se puede continuar.
    expect(find.text('Escribe el nombre del personaje.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('creation-next'))).onPressed, isNull);
    await fillStep1(tester);
    expect(find.byKey(const Key('class-card')), findsOneWidget);
    expect(find.text('Dado de golpe: d6'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('creation-race')), 'Elfo');
    await next(tester);

    // Paso 2: compra de puntos, INT a 15 (9 puntos) y bono racial +2.
    await tapKey(tester, 'method-pointBuy');
    expect(text(tester, 'points-remaining'), 'Puntos restantes: 27 / 27');
    for (var i = 0; i < 7; i++) {
      await tapKey(tester, 'base-int-inc');
    }
    expect(text(tester, 'base-int-value'), '15');
    expect(text(tester, 'points-remaining'), 'Puntos restantes: 18 / 27');
    await tapKey(tester, 'racial-int-inc');
    await tapKey(tester, 'racial-int-inc');
    expect(text(tester, 'total-int'), '17 (+3)');
    await next(tester);

    // Paso 3: exactamente 2 habilidades.
    expect(find.text('Elige 2 habilidades más.'), findsOneWidget);
    await tapKey(tester, 'skill-Arcanos');
    await tapKey(tester, 'skill-Historia');
    await next(tester);

    // Paso 4: Bastón y Proyectil mágico.
    await tapKey(tester, 'weapon-baston');
    await tapKey(tester, 'spell-Magic Missile');
    await next(tester);

    // Paso 5: revisión y alta.
    expect(find.text('Revisá antes de confirmar'), findsOneWidget);
    expect(find.text('Elminster'), findsOneWidget);
    expect(store.roster, isEmpty);
    await tapKey(tester, 'creation-confirm');

    expect(store.roster, hasLength(1));
    final c = store.activeCharacter!;
    expect(c.basicInfo.name, 'Elminster');
    expect(c.basicInfo.race, 'Elfo');
    expect(c.basicInfo.characterClass, 'Mago');
    expect(c.stats.intelligence.value, 17);
    expect(c.basicInfo.spellSaveDc, 8 + 2 + 3);
    expect(c.inventory.weapons.single.name, 'Bastón');
    expect(c.abilitiesByAction.all.any((a) => a.name == 'Proyectil mágico'), isTrue);
    // El wizard se cerró.
    expect(find.byType(CharacterCreationWizardScreen), findsNothing);
  });

  testWidgets('Atrás/Adelante conserva textos, atributos, habilidades y equipo', (tester) async {
    final store = await boot();
    await openWizard(tester, store);
    await fillStep1(tester, name: 'Gandalf');
    await tester.enterText(find.byKey(const Key('creation-background')), 'Sabio');
    await tapKey(tester, 'level-inc');
    await next(tester);

    await tapKey(tester, 'method-manual');
    await tapKey(tester, 'base-str-inc');
    await tapKey(tester, 'base-str-inc');
    await next(tester);

    await tapKey(tester, 'skill-Medicina');
    await tapKey(tester, 'skill-Religión');
    await next(tester);
    await tapKey(tester, 'armor-escudo');

    // Atrás ×3 hasta el Paso 1.
    for (var i = 0; i < 3; i++) {
      await tapKey(tester, 'creation-back');
    }
    expect(tester.widget<TextField>(find.byKey(const Key('creation-name'))).controller!.text, 'Gandalf');
    expect(tester.widget<TextField>(find.byKey(const Key('creation-background'))).controller!.text, 'Sabio');
    expect(text(tester, 'level-value'), '2');
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('class-mago'))).selected, isTrue);

    await next(tester);
    expect(text(tester, 'base-str-value'), '12');
    await next(tester);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('skill-Medicina'))).value, isTrue);
    await next(tester);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('armor-escudo'))).value, isTrue);
  });

  testWidgets('estadísticas en vivo: PG, CA, iniciativa, percepción y salvaciones', (tester) async {
    final store = await boot();
    await openWizard(tester, store);
    await tester.enterText(find.byKey(const Key('creation-name')), 'Tharn');
    await tester.pump();
    await tapKey(tester, 'class-guerrero');
    await next(tester);

    // Manual: CON 12 → +1 (FUE/DES/CON suben de 10 a 12).
    await tapKey(tester, 'method-manual');
    for (final k in ['con', 'dex']) {
      await tapKey(tester, 'base-$k-inc');
      await tapKey(tester, 'base-$k-inc');
    }
    await next(tester);

    await tapKey(tester, 'skill-Percepción');
    await tapKey(tester, 'skill-Atletismo');
    // d10 + 1 (CON 12), CA 10 + 1, iniciativa +1, percepción 10 + 0 (SAB) + 2.
    expect(text(tester, 'stat-hp'), '11');
    expect(text(tester, 'stat-ac'), '11');
    expect(text(tester, 'stat-init'), '+1');
    expect(text(tester, 'stat-perception'), '12');
    // Guerrero: salvaciones de FUE y CON con competencia (+2).
    expect(find.text('FUE +2'), findsOneWidget);
    expect(find.text('CON +3'), findsOneWidget);
    expect(find.text('DES +1'), findsOneWidget);

    // PG personalizados.
    await tapKey(tester, 'hp-custom');
    await tester.enterText(find.byKey(const Key('hp-custom-field')), '14');
    await tester.pump();
    expect(text(tester, 'stat-hp'), '14');

    // Con armadura equipada (Paso 4) la CA cambia en vivo.
    await next(tester);
    await tapKey(tester, 'armor-cota_de_mallas');
    await tapKey(tester, 'armor-escudo');
    await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    expect(text(tester, 'stat-ac'), '18');
  });

  testWidgets('el grimorio solo ofrece conjuros hasta el nivel de ranura', (tester) async {
    final store = await boot();
    await openWizard(tester, store);
    await fillStep1(tester);
    await next(tester);
    await next(tester);
    await tapKey(tester, 'skill-Arcanos');
    await tapKey(tester, 'skill-Historia');
    await next(tester);

    // Nivel 1: ranuras de nivel 1 → hay Proyectil mágico, no Bola de fuego (3).
    await ensureBuilt(tester, find.byKey(const Key('spell-Magic Missile')));
    expect(find.byKey(const Key('spell-Magic Missile')), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('spell-Fireball')), findsNothing);
    expect(find.byKey(const Key('spell-Wish')), findsNothing);
  });

  testWidgets('bienvenida: asistente guiado y "Ficha en blanco (editor manual)"', (tester) async {
    final store = await boot();
    await pumpApp(tester, store, const WelcomeScreen());

    expect(find.text('Crear personaje guiado'), findsOneWidget);
    await tester.tap(find.text('Crear personaje guiado'));
    await tester.pumpAndSettle();
    expect(find.text('Crear personaje'), findsOneWidget);
    expect(find.text('Identidad y clase'), findsOneWidget);
    Navigator.of(tester.element(find.text('Identidad y clase'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ficha en blanco (editor manual)'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva ficha'), findsOneWidget);
  });
}
