// Tests del editor manual de fichas (Etapa 4): alta desde cero,
// edición sin duplicar, validación al guardar y descarte con
// confirmación. El estado de combate debe sobrevivir a la edición.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/domain/character_validator.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/features/editor/character_editor_screen.dart';
import 'package:easydnd/state/character_store.dart';

import 'fakes/test_fichas.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<CharacterStore> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    return store;
  }

  /// Home con botones al editor, imitando el PlaceholderHome real
  /// (mismo mecanismo de navegación, sin depender de la pantalla
  /// provisoria).
  Future<void> pumpHome(
    WidgetTester tester,
    CharacterStore store, {
    CharacterModel? edit,
  }) {
    return tester.pumpWidget(
      ChangeNotifierProvider<CharacterStore>.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CharacterEditorScreen(),
                      ),
                    ),
                    child: const Text('crear-ficha'),
                  ),
                  if (edit != null)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CharacterEditorScreen(character: edit),
                        ),
                      ),
                      child: const Text('editar-ficha'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Guarda el borrador confirmando el aviso persistente de la ficha
  /// fixture (ranuras sin CD). Todos los tests de 4d parten de esa
  /// ficha, así que el aviso es siempre 1.
  Future<void> saveWithWarning(WidgetTester tester) async {
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Hay 1 avisos'), findsOneWidget);
    await tester.tap(find.text('Guardar igual'));
    await tester.pumpAndSettle();
  }

  /// Toca un tile del shell del editor. Las últimas secciones quedan
  /// debajo del pliegue: el ListView es lazy y hay que scrollearlo.
  Future<void> openSection(WidgetTester tester, String title) async {
    await tester.scrollUntilVisible(
      find.text(title),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  group('modelo — piezas del editor', () {
    test('blank() valida sin errores; su único aviso es que no trae '
        'habilidades (correcto: recién creada)', () {
      final result = CharacterValidator.validateMap(
        CharacterModel.blank().toJson(),
      );

      expect(result.isOk, isTrue, reason: 'errores: ${result.errors}');
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.field, 'abilities_by_action');
    });

    test('copy() es profunda e independiente, y conserva el id', () {
      final original = buildCharacter(
        id: 'char_x',
        name: 'Original',
        hpCurrent: 7,
      );
      final copia = original.copy();

      // Mutaciones anidadas de la copia no tocan el original.
      copia.basicInfo.name = 'Cambiado';
      copia.inventory.weapons.add(
        original.inventory.weapons.single
          ..name = 'pisa-el-original',
      );
      copia.basicInfo.setHpMax(1);

      expect(copia.id, original.id);
      expect(original.basicInfo.name, 'Original');
      expect(original.basicInfo.hpMax, 20);
      expect(original.basicInfo.currentHp, 7);
      expect(original.inventory.weapons, hasLength(1));
    });

    test('setHpMax/setLevel/setSpeed mantienen coherencia sin regalar', () {
      final ficha = buildCharacter(hpCurrent: 20, hitDiceCurrent: 5);

      // Bajar el tope recorta la vida actual; subirlo no "cura".
      ficha.basicInfo.setHpMax(10);
      expect(ficha.basicInfo.currentHp, 10);
      ficha.basicInfo.setHpMax(30);
      expect(ficha.basicInfo.currentHp, 10);

      // Subir nivel arrastra los dados de golpe (uno por nivel: 5→6).
      ficha.basicInfo.setLevel(6);
      expect(ficha.basicInfo.hitDiceMax, 6);
      expect(ficha.basicInfo.hitDiceCurrent, 5);

      // Bajar la velocidad recorta el movimiento del turno; subirla
      // no regala movimiento.
      ficha.setSpeed(4);
      expect(ficha.turnStatus.movementRemaining, 4);
      ficha.setSpeed(12);
      expect(ficha.turnStatus.movementRemaining, 4);
    });
  });

  group('alta manual', () {
    testWidgets('ficha en blanco → llenar nombre → crear entra al roster',
        (tester) async {
      final store = await boot();
      await pumpHome(tester, store);

      await tester.tap(find.text('crear-ficha'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva ficha'), findsOneWidget);

      // Los campos viven en la página de la sección, no en el shell.
      await tester.tap(find.text('Datos básicos'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Rook',
      );
      await tester.pump();

      // El "Crear ficha" es del shell: volver de la sección primero.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear ficha'));
      await tester.pumpAndSettle();

      // La ficha recién creada avisa que no trae habilidades: no
      // bloquea, pero se confirma explícitamente (mismo criterio que
      // el wizard de importación).
      expect(find.text('Hay 1 avisos'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      expect(find.byType(CharacterEditorScreen), findsNothing);
      expect(store.roster, hasLength(1));
      expect(store.activeCharacter!.basicInfo.name, 'Rook');
      expect(store.activeIndex, 0);
    });

    testWidgets('nombre vacío bloquea el guardado', (tester) async {
      final store = await boot();
      await pumpHome(tester, store);

      await tester.tap(find.text('crear-ficha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Datos básicos'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        '',
      );
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear ficha'));
      await tester.pumpAndSettle();

      // El diálogo lista el error bloqueante y no sale del editor.
      expect(find.text('La ficha no se puede guardar'), findsOneWidget);
      expect(find.textContaining('El personaje no tiene nombre'),
          findsOneWidget);
      expect(find.byType(CharacterEditorScreen), findsOneWidget);
      expect(store.roster, isEmpty);
    });
  });

  group('edición', () {
    testWidgets('guardar reemplaza sin duplicar y conserva id y PG actuales',
        (tester) async {
      final store = await boot();
      final ficha = buildCharacter(id: 'char_rook', name: 'Rook');
      store.addCharacter(ficha);
      final idOriginal = store.activeCharacter!.id;

      // Combate en curso: media vida, para verificar que la edición no
      // la toca.
      store.activeCharacter!.basicInfo.currentHp = 10;

      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      expect(find.text('Editar a Rook'), findsOneWidget);

      await tester.tap(find.text('Datos básicos'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Clase'),
        'Clérigo 4',
      );
      await tester.pump();
      // El avatar (8b) empuja este campo debajo del pliegue: el
      // ListView de la sección es lazy, hay que scrollearlo.
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Velocidad (pies por turno)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Velocidad (pies por turno)'),
        '40',
      );
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      // La ficha fixture tiene ranuras sin spell_save_dc: el aviso
      // persistente vuelve a mostrarse en cada guardado (informativo,
      // no bloquea).
      expect(find.text('Hay 1 avisos'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      expect(find.byType(CharacterEditorScreen), findsNothing);
      expect(store.roster, hasLength(1), reason: 'no debe duplicar');
      final guardada = store.activeCharacter!;
      expect(guardada.id, idOriginal);
      expect(guardada.basicInfo.characterClass, 'Clérigo 4');
      expect(guardada.basicInfo.speed, 40);
      // El estado de combate sobrevive a la edición.
      expect(guardada.basicInfo.currentHp, 10);
    });

    testWidgets('salir con cambios sin guardar pide confirmación',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));

      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      // Sin cambios: el atrás sale directo, sin diálogo.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CharacterEditorScreen), findsNothing);

      // Con cambios: aparece el diálogo y Descartar pierde los edits.
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Datos básicos'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Rook Renombrado',
      );
      await tester.pump();

      // Volver de la sección (sin confirmar: las secciones no preguntan)
      // y recién ahí salir del editor.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.byType(CharacterEditorScreen), findsNothing);
      expect(store.activeCharacter!.basicInfo.name, 'Rook');
    });
  });

  group('secciones 4b — atributos, competencias, ranuras', () {
    testWidgets('atributos: "usar estándar" recalcula el modificador',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      // El tile del shell resume los seis valores.
      expect(
        find.text('STR 16 · DEX 12 · CON 14 · INT 10 · WIS 10 · CHA 10'),
        findsOneWidget,
      );

      await tester.tap(find.text('Atributos'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('value-str')), '18');
      await tester.pump();

      // El mod sigue en +3: el botón ofrece el +4 estándar del 18.
      await tester.tap(find.byKey(const ValueKey('standard-str')));
      await tester.pump();

      // La sobreescritura también se ve en el campo, no solo en el
      // borrador (los mods van con controllers a propósito).
      final modField = tester.widget<TextFormField>(
        find.byKey(const ValueKey('mod-str')),
      );
      expect(modField.controller?.text, '4');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Hay 1 avisos'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      final stats = store.activeCharacter!.stats;
      expect(stats.str.value, 18);
      expect(stats.str.mod, 4);
    });

    testWidgets('competencias: alta con diálogo y persistencia',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      expect(find.text('sin competencias'), findsOneWidget);

      await tester.tap(find.text('Competencias'));
      await tester.pumpAndSettle();

      expect(find.text('Todavía no hay competencias en la ficha.'),
          findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Arcanos',
      );
      await tester.pump();

      // Dropdown del atributo relacionado (se tipea el campo, no el
      // hint: el hint es decorativo y no recibe eventos).
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sabiduría').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Modificador'),
        '7',
      );
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Arcanos'), findsOneWidget);
      expect(find.text('Sabiduría · +7'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('1 competencia'), findsOneWidget);

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Hay 1 avisos'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      final skills = store.activeCharacter!.skills;
      expect(skills, hasLength(1));
      expect(skills.single.name, 'Arcanos');
      expect(skills.single.relatedStat, 'wis');
      expect(skills.single.modifier, 7);
    });

    testWidgets('competencias: el nombre vacío no pasa del diálogo',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Competencias'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(find.text('Poné un nombre.'), findsOneWidget);
      // El diálogo sigue abierto y la lista sigue vacía.
      expect(find.text('Nueva competencia'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.skills, isEmpty);
    });

    testWidgets(
        'ranuras: agregar un nivel nuevo, borrar otro y persistir '
        'ordenado', (tester) async {
      final store = await boot();
      store.addCharacter(
        buildCharacter(id: 'char_rook', name: 'Rook', slotCurrent: 2),
      );
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      expect(find.text('4 de nivel 1'), findsOneWidget);

      await tester.tap(find.text('Ranuras de conjuro'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 4 disponibles'), findsOneWidget);

      // El alta arranca en el primer nivel libre (la ficha tiene el 1).
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Nivel 2'), findsWidgets);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ranuras totales'),
        '2',
      );
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Disponibles ahora'),
        '2',
      );
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Nivel 1'), findsOneWidget);
      expect(find.text('Nivel 2'), findsOneWidget);
      expect(find.text('2 de 2 disponibles'), findsOneWidget);

      // Borrado directo del nivel 1 (el borrador cubre el arrepentimiento).
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Nivel 1'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Hay 1 avisos'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      final slots = store.activeCharacter!.spellSlots.slots;
      expect(slots, hasLength(1));
      expect(slots.single.level, 2);
      expect(slots.single.max, 2);
      expect(slots.single.current, 2);
    });

    testWidgets('ranuras: disponibles no puede superar las totales',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ranuras de conjuro'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Disponibles ahora'),
        '5',
      );
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(find.text('No puede superar las totales (1).'), findsOneWidget);
      expect(find.text('Nuevo nivel de ranura'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.spellSlots.slots, hasLength(1));
    });

    testWidgets('ranuras: con los 9 niveles el alta avisa en vez de romper',
        (tester) async {
      final store = await boot();
      final ficha = buildCharacter(id: 'char_rook', name: 'Rook');
      ficha.spellSlots.slots
        ..clear()
        ..addAll([
          for (var level = 1; level <= 9; level++)
            SpellSlot(level: level, max: 2, current: 2),
        ]);
      store.addCharacter(ficha);

      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ranuras de conjuro'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('La ficha ya tiene ranuras de los 9 niveles.'),
          findsOneWidget);
      // Sin diálogo abierto: no hay niveles para elegir.
      expect(find.text('Nuevo nivel de ranura'), findsNothing);
    });
  });

  group('secciones 4c — habilidades', () {
    testWidgets('alta completa desde el FAB y persistencia',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      expect(find.text('1 acción'), findsOneWidget);

      await tester.tap(find.text('Habilidades'));
      await tester.pumpAndSettle();

      expect(find.text('ACCIÓN · 1'), findsOneWidget);
      expect(find.text('Golpe Devastador'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Nueva habilidad'), findsOneWidget);
      expect(find.text('Habilidad sin nombre'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Bola de Fuego',
      );
      await tester.pump();

      // Tipo de tirada: salvación.
      await tester.tap(find.byKey(const ValueKey('ability-attack-type')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.text('Salvación — el objetivo tira contra tu CD'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dados de daño'),
        '8d6',
      );
      await tester.pump();

      // El switch de cargas vive abajo de la página: el ListView es
      // lazy, hay que scrollear hasta él. Ojo: cada TextField tiene su
      // propio Scrollable interno — el primero del árbol es el ListView.
      await tester.scrollUntilVisible(
        find.text('Usos limitados por descanso'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Usos limitados por descanso'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tope de usos'),
        '3',
      );
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('ACCIÓN · 2'), findsOneWidget);
      expect(find.text('Bola de Fuego'), findsOneWidget);
      expect(find.text('Salvación · 8d6 · 3/3 usos'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('2 acciones'), findsOneWidget);

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Hay 1 avisos'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      final bola = store.activeCharacter!.abilitiesByAction.action
          .firstWhere((a) => a.name == 'Bola de Fuego');
      expect(bola.attackType, 'save');
      expect(bola.damageDice, '8d6');
      expect(bola.magicCharges.hasCharges, isTrue);
      expect(bola.magicCharges.max, 3);
      expect(bola.magicCharges.current, 3);
    });

    testWidgets('mover de categoría conserva la identidad (id)',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Habilidades'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Golpe Devastador'));
      await tester.pumpAndSettle();
      expect(find.text('Editar habilidad'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ability-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reacción'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('ACCIÓN · 1'), findsNothing);
      expect(find.text('REACCIÓN · 1'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('1 reacción'), findsOneWidget);

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Hay 1 avisos'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      final abilities = store.activeCharacter!.abilitiesByAction;
      expect(abilities.action, isEmpty);
      expect(abilities.reaction, hasLength(1));
      // La identidad no cambia al mover: el HUD cuelga las cargas
      // de este id.
      expect(abilities.reaction.single.id, 'a1');
      expect(abilities.reaction.single.name, 'Golpe Devastador');
    });

    testWidgets('borrar la única habilidad avisa al guardar (2 avisos)',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Habilidades'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Golpe Devastador'), findsNothing);
      expect(find.text('La ficha no trae habilidades todavía.'),
          findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('sin habilidades'), findsOneWidget);

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      // El aviso de "no trae habilidades" se SUMA al de ranuras sin CD.
      expect(find.text('Hay 2 avisos'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.abilitiesByAction.all, isEmpty);
    });

    testWidgets('notación de dados inválida avisada en vivo',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Habilidades'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Golpe Devastador'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dados de daño'),
        'banana',
      );
      await tester.pump();

      expect(find.textContaining('Notación de dado inválida'),
          findsOneWidget);
    });
  });
  group('secciones 4d — recursos, armas, objetos, lore y compañeros', () {
    testWidgets('recursos: coherencia del tope y alta desde el FAB', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      expect(find.text('Furia 2/3'), findsOneWidget);

      await openSection(tester, 'Recursos');
      expect(find.text('2 de 3 usos'), findsOneWidget);

      // El recurso está gastado (2 de 3): subir el tope no regala usos.
      await tester.tap(find.text('Furia'));
      await tester.pumpAndSettle();
      expect(find.text('Editar recurso'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tope de usos'),
        '5',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Usos restantes'),
            )
            .controller
            ?.text,
        '2',
      );

      // Bajar el tope por debajo de los usos restantes los recorta.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tope de usos'),
        '1',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Usos restantes'),
            )
            .controller
            ?.text,
        '1',
      );

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('1 de 1 usos'), findsOneWidget);

      // Alta nueva: recién creado arranca lleno (1/1) y el tope lo
      // acompaña.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Ki',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tope de usos'),
        '4',
      );
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Ki'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Furia 1/1 · Ki 4/4'), findsOneWidget);

      await saveWithWarning(tester);

      final resources = store.activeCharacter!.resources;
      expect(resources, hasLength(2));
      expect(resources[0].name, 'Furia');
      expect(resources[0].current, 1);
      expect(resources[0].max, 1);
      expect(resources[1].name, 'Ki');
      expect(resources[1].current, 4);
      expect(resources[1].max, 4);
    });

    testWidgets('armas: editar bono, daño condicional inline y arma única', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      expect(find.text('1 arma'), findsOneWidget);

      await openSection(tester, 'Armas');
      expect(
        find.text('Ataque +5 · 1d8+3 cortante · 3/3 cargas'),
        findsOneWidget,
      );

      await tester.tap(find.text('Espada Larga'));
      await tester.pumpAndSettle();
      expect(find.text('Editar arma'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bono de ataque'),
        '7',
      );
      await tester.pump();

      // El daño condicional vive abajo: se agrega inline y se completa
      // en la misma tarjeta (no hay diálogo anidado).
      await tester.scrollUntilVisible(
        find.text('Agregar daño condicional'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar daño condicional'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Disparador'),
        'Si el objetivo está quemado',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dados'),
        '1d6',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tipo'),
        'fuego',
      );
      await tester.pump();

      // Volver arriba: marcar única fuerza la cantidad a 1 y oculta el
      // campo.
      await tester.scrollUntilVisible(
        find.text('Arma única'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Cantidad'), findsOneWidget);
      await tester.tap(find.text('Arma única'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Cantidad'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('Ataque +7 · 1d8+3 cortante · 3/3 cargas'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await saveWithWarning(tester);

      final weapon = store.activeCharacter!.inventory.weapons.single;
      expect(weapon.attackBonus, 7);
      expect(weapon.conditionalDamage, hasLength(1));
      expect(
        weapon.conditionalDamage.single.trigger,
        'Si el objetivo está quemado',
      );
      expect(weapon.conditionalDamage.single.dice, '1d6');
      expect(weapon.conditionalDamage.single.type, 'fuego');
      expect(weapon.isUnique, isTrue);
      expect(weapon.quantity, 1);
    });

    testWidgets('armas: alta desde el FAB con cantidad y cargas', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();
      await openSection(tester, 'Armas');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Nueva arma'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Hacha de Guerra',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dados de daño base'),
        '1d12',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tipo de daño base'),
        'cortante',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cantidad'),
        '2',
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Usos limitados por descanso'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usos limitados por descanso'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tope de usos'),
        '2',
      );
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Hacha de Guerra'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await saveWithWarning(tester);

      final weapons = store.activeCharacter!.inventory.weapons;
      expect(weapons, hasLength(2));
      final hacha = weapons.firstWhere((w) => w.name == 'Hacha de Guerra');
      expect(hacha.damage.baseDice, '1d12');
      expect(hacha.damage.baseType, 'cortante');
      expect(hacha.quantity, 2);
      expect(hacha.isUnique, isFalse);
      expect(hacha.magicCharges.hasCharges, isTrue);
      expect(hacha.magicCharges.max, 2);
      expect(hacha.magicCharges.current, 2);
      // El id nuevo no se recalcula del nombre.
      expect(hacha.id, startsWith('weapon_'));
    });

    testWidgets('objetos y monedas: editar la bolsa y agregar un objeto', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      // El tile vive debajo del pliegue: scrollear antes de leerlo.
      await tester.scrollUntilVisible(
        find.text('Objetos y monedas'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1 objeto · 10 po · 5 pp · 2 pc'), findsOneWidget);

      await tester.tap(find.text('Objetos y monedas'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Oro (po)'),
        '99',
      );
      await tester.pump();
      expect(find.text('Equivalente total: 99.52 po'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Poción de curación',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción (opcional)'),
        'Cura 2d4+2',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cantidad'),
        '3',
      );
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Poción de curación'), findsOneWidget);
      expect(find.text('Cura 2d4+2 · ×3'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('2 objetos · 99 po · 5 pp · 2 pc'), findsOneWidget);

      await saveWithWarning(tester);

      final ficha = store.activeCharacter!;
      expect(ficha.purse.gold, 99);
      expect(ficha.inventory.mundaneItems, hasLength(2));
      final pocion = ficha.inventory.mundaneItems.firstWhere(
        (item) => item.name == 'Poción de curación',
      );
      expect(pocion.description, 'Cura 2d4+2');
      expect(pocion.quantity, 3);
    });

    testWidgets('lore: editar un campo actualiza el resumen y persiste', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      // La fixture ya trae el trasfondo: 1 de 5. El tile vive debajo
      // del pliegue.
      await tester.scrollUntilVisible(
        find.text('Historia y personalidad'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1 de 5 campos'), findsOneWidget);

      await tester.tap(find.text('Historia y personalidad'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Defectos'),
        'Se distrae con cualquier cosa brillante.',
      );
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('2 de 5 campos'), findsOneWidget);

      await saveWithWarning(tester);

      final lore = store.activeCharacter!.loreInfo;
      expect(lore.backstory, 'Historia');
      expect(lore.flaws, 'Se distrae con cualquier cosa brillante.');
    });

    testWidgets('compañeros: PG coherentes al cambiar el tope y CA', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      // El tile vive debajo del pliegue: scrollear antes de leerlo.
      await tester.scrollUntilVisible(
        find.text('Compañeros'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1 compañero'), findsOneWidget);

      await tester.tap(find.text('Compañeros'));
      await tester.pumpAndSettle();
      expect(find.text('bestia · 5/10 PG · CA 12'), findsOneWidget);

      await tester.tap(find.text('Lobo'));
      await tester.pumpAndSettle();
      expect(find.text('Editar compañero'), findsOneWidget);

      // Estaba herido (5/10): bajar el tope recorta los PG actuales...
      await tester.enterText(
        find.widgetWithText(TextFormField, 'PG máximos'),
        '3',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'PG actuales'),
            )
            .controller
            ?.text,
        '3',
      );

      // ...y volver a subirlo, con la barra llena, la arrastra.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'PG máximos'),
        '20',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'PG actuales'),
            )
            .controller
            ?.text,
        '20',
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'CA'), '13');
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('bestia · 20/20 PG · CA 13'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await saveWithWarning(tester);

      final companion = store.activeCharacter!.companions.single;
      expect(companion.name, 'Lobo');
      expect(companion.currentHp, 20);
      expect(companion.maxHp, 20);
      expect(companion.ac, 13);
      expect(companion.hasHp, isTrue);
    });
  });

  group('cierre del editor — estado de combate y descarte', () {
    testWidgets('una edición cosmética conserva TODO el estado de combate',
        (tester) async {
      final store = await boot();
      final ficha = buildCharacter(
        id: 'char_rook',
        name: 'Rook',
        hpCurrent: 7,
        weaponChargesCurrent: 1,
        abilityChargesCurrent: 1,
      );
      // Combate en curso: recurso gastado, compañero herido, movimiento
      // consumido y una condición activa.
      ficha.resources.single.current = 2;
      ficha.companions.single.currentHp = 5;
      ficha.turnStatus.movementRemaining = 4;
      ficha.activeConditions.add('Envenenado');
      store.addCharacter(ficha);

      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      // El único cambio es el nombre: nada de combate debería moverse.
      await tester.tap(find.text('Datos básicos'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Rook el Intacto',
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await saveWithWarning(tester);

      final guardada = store.activeCharacter!;
      expect(guardada.id, 'char_rook');
      expect(guardada.basicInfo.name, 'Rook el Intacto');
      expect(guardada.basicInfo.currentHp, 7);
      expect(guardada.inventory.weapons.single.magicCharges.current, 1);
      expect(
        guardada.abilitiesByAction.action.single.magicCharges.current,
        1,
      );
      expect(guardada.resources.single.current, 2);
      expect(guardada.resources.single.max, 3);
      expect(guardada.companions.single.currentHp, 5);
      expect(guardada.companions.single.maxHp, 10);
      expect(guardada.turnStatus.movementRemaining, 4);
      expect(guardada.activeConditions, ['Envenenado']);
    });

    testWidgets('compañero sin PG: apoyo invulnerable que persiste',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Compañeros'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Compañeros'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Cuervo',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tipo (opcional)'),
        'familiar',
      );
      await tester.tap(find.text('Tiene PG'));
      await tester.pumpAndSettle();

      // Sin PG los campos de vida desaparecen, pero la CA sigue.
      expect(find.widgetWithText(TextFormField, 'PG máximos'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'CA'), findsOneWidget);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('familiar · invulnerable · CA 10'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await saveWithWarning(tester);

      final cuervo = store.activeCharacter!.companions
          .firstWhere((companion) => companion.name == 'Cuervo');
      expect(cuervo.type, 'familiar');
      expect(cuervo.hasHp, isFalse);
    });

    testWidgets('borrar un arma y descartar el editor no toca la ficha',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await pumpHome(tester, store, edit: store.activeCharacter);
      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Armas'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // El tile queda justo sobre el borde del bottom bar (Guardar):
      // scrollear un poco más para que el tap no lo agarre el botón.
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Armas'));
      await tester.pumpAndSettle();

      // Borrado directo en el borrador: la lista queda vacía...
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('La ficha no trae armas todavía.'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('sin armas'), findsOneWidget);

      // ...pero salir del editor sin guardar descarta el borrador: el
      // roster sigue con el arma original.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.byType(CharacterEditorScreen), findsNothing);
      expect(store.activeCharacter!.inventory.weapons, hasLength(1));
      expect(
        store.activeCharacter!.inventory.weapons.single.name,
        'Espada Larga',
      );
    });
  });
}
