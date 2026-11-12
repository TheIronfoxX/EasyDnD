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
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Velocidad (metros por turno)'),
        '12',
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
      expect(guardada.basicInfo.speed, 12);
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
}
