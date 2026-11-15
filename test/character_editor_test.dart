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
    // Pantalla alta: las pestañas son ListView perezosos y así casi todo
    // queda construido sin tener que scrollear en cada test.
    tester.view.physicalSize = const Size(800, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

  /// Cambia de pestaña del taller.
  Future<void> goTab(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(Tab, name));
    await tester.pumpAndSettle();
  }

  /// Campo de un diálogo abierto (los diálogos no ocultan la pestaña de
  /// abajo, así que buscar solo por label daría coincidencias dobles).
  Finder dialogField(String label) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextFormField, label),
      );

  /// Campo de texto dentro de un widget con key (ej. 'summary-a1').
  Finder fieldIn(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextFormField),
      );

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester, CharacterStore store) async {
    await pumpHome(tester, store, edit: store.activeCharacter);
    await tester.tap(find.text('editar-ficha'));
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


  group('estructura del taller', () {
    testWidgets('4 pestañas y el menú de secciones ya no existe', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);

      for (final name in ['Núcleo', 'Arsenal', 'Grimorio', 'Mochila']) {
        expect(find.widgetWithText(Tab, name), findsOneWidget);
      }
      expect(find.text('Datos básicos'), findsNothing);
      expect(find.text('Objetos y monedas'), findsNothing);
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

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Rook');
      await tester.pump();
      await tester.tap(find.text('Crear ficha'));
      await tester.pumpAndSettle();

      // La ficha recién creada avisa que no trae habilidades: no
      // bloquea, pero se confirma explícitamente.
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
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), '');
      await tester.pump();
      await tester.tap(find.text('Crear ficha'));
      await tester.pumpAndSettle();

      expect(find.text('La ficha no se puede guardar'), findsOneWidget);
      expect(find.textContaining('El personaje no tiene nombre'), findsOneWidget);
      expect(find.byType(CharacterEditorScreen), findsOneWidget);
      expect(store.roster, isEmpty);
    });
  });

  group('edición', () {
    testWidgets('guardar reemplaza sin duplicar y conserva id y PG actuales',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      final idOriginal = store.activeCharacter!.id;
      store.activeCharacter!.basicInfo.currentHp = 10;

      await openEditor(tester, store);
      expect(find.text('Editar a Rook'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Clase'), 'Clérigo 4');
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Velocidad (pies por turno)'),
        '40',
      );
      await tester.pump();

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Hay 1 avisos'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      expect(find.byType(CharacterEditorScreen), findsNothing);
      expect(store.roster, hasLength(1), reason: 'no debe duplicar');
      final guardada = store.activeCharacter!;
      expect(guardada.id, idOriginal);
      expect(guardada.basicInfo.characterClass, 'Clérigo 4');
      expect(guardada.basicInfo.speed, 40);
      expect(guardada.basicInfo.currentHp, 10);
    });

    testWidgets('salir con cambios sin guardar pide confirmación',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);

      // Sin cambios: el atrás sale directo, sin diálogo.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CharacterEditorScreen), findsNothing);

      await tester.tap(find.text('editar-ficha'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Rook Renombrado',
      );
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.byType(CharacterEditorScreen), findsNothing);
      expect(store.activeCharacter!.basicInfo.name, 'Rook');
    });

    testWidgets('cambiar de pestaña conserva lo tipeado', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);

      await tester.enterText(find.widgetWithText(TextFormField, 'Raza'), 'Mediano');
      await tester.pump();
      await goTab(tester, 'Mochila');
      await goTab(tester, 'Núcleo');

      expect(find.text('Mediano'), findsOneWidget);
    });
  });

  group('pestaña Núcleo', () {
    testWidgets('steppers de vitales, alineamiento e indicadores en vivo',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      final original = store.activeCharacter!.basicInfo;
      final hp0 = original.hpMax, ac0 = original.ac, speed0 = original.speed;
      await openEditor(tester, store);

      await tapKey(tester, 'hp-inc');
      await tapKey(tester, 'ac-inc');
      await tapKey(tester, 'ac-inc');
      await tapKey(tester, 'speed-dec');
      await tapKey(tester, 'dc-inc'); // CD vacía: parte de 10
      await tester.enterText(find.widgetWithText(TextFormField, 'Alineamiento'), 'Legal bueno');
      await tester.pump();

      // Iniciativa = mod. de Destreza; percepción pasiva sin competencia
      // = 10 + mod. de Sabiduría.
      expect(tester.widget<Text>(find.byKey(const Key('readout-initiative'))).data, '+1');
      expect(tester.widget<Text>(find.byKey(const Key('readout-passive-perception'))).data, '10');

      // Con una competencia "Percepción +7" el indicador la usa.
      await tester.tap(find.text('Competencias'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'add-skill');
      await tester.enterText(dialogField('Nombre'), 'Percepción');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sabiduría').last);
      await tester.pumpAndSettle();
      await tester.enterText(dialogField('Modificador'), '7');
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('readout-passive-perception'))).data, '17');

      // Con la CD cargada la ficha ya no tiene avisos: guarda directo.
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Hay 1 avisos'), findsNothing);

      final b = store.activeCharacter!.basicInfo;
      expect(b.hpMax, hp0 + 1);
      expect(b.ac, ac0 + 2);
      expect(b.speed, speed0 - 1);
      expect(b.spellSaveDc, 11);
      expect(b.alignment, 'Legal bueno');
      expect(store.activeCharacter!.skills.single.name, 'Percepción');
    });

    testWidgets('atributos: stepper, "usar estándar" y nota de salvación',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);

      await tester.enterText(find.byKey(const ValueKey('value-str')), '17');
      await tester.pump();
      await tapKey(tester, 'value-str-inc'); // 18
      // El mod sigue en +3: el botón ofrece el +4 estándar del 18.
      await tester.tap(find.byKey(const ValueKey('standard-str')));
      await tester.pump();

      final modField = tester.widget<TextFormField>(find.byKey(const ValueKey('mod-str')));
      expect(modField.controller?.text, '4');
      expect(tester.widget<Text>(find.byKey(const Key('mod-live-str'))).data, '+4');

      await tester.enterText(fieldIn('note-str'), 'Salvación +6 (competente)');
      await tester.pump();

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      final stats = store.activeCharacter!.stats;
      expect(stats.str.value, 18);
      expect(stats.str.mod, 4);
      expect(stats.str.description, 'Salvación +6 (competente)');
    });

    testWidgets('competencias: alta con diálogo y persistencia', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);

      expect(find.text('sin competencias'), findsOneWidget);
      await tester.tap(find.text('Competencias'));
      await tester.pumpAndSettle();
      expect(find.text('Todavía no hay competencias en la ficha.'), findsOneWidget);

      await tapKey(tester, 'add-skill');
      await tester.enterText(dialogField('Nombre'), 'Arcanos');
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sabiduría').last);
      await tester.pumpAndSettle();
      await tester.enterText(dialogField('Modificador'), '7');
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Arcanos'), findsOneWidget);
      expect(find.text('Sabiduría · +7'), findsOneWidget);
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
      await openEditor(tester, store);
      await tester.tap(find.text('Competencias'));
      await tester.pumpAndSettle();

      await tapKey(tester, 'add-skill');
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(find.text('Poné un nombre.'), findsOneWidget);
      expect(find.text('Nueva competencia'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.skills, isEmpty);
    });
  });

  group('pestaña Arsenal', () {
    testWidgets('reclasificación en 1 toque conserva la identidad (id)',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Arsenal');

      expect(find.text('Acción · 1'), findsOneWidget);
      expect(find.text('Reacción · 0'), findsOneWidget);

      await tapKey(tester, 'cat-a1-reaction');
      expect(find.text('Acción · 0'), findsOneWidget);
      expect(find.text('Reacción · 1'), findsOneWidget);

      // Y a pasiva: el rol táctico queda definido (exclusión mutua).
      await tapKey(tester, 'cat-a1-passive');

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Hay 1 avisos'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      final abilities = store.activeCharacter!.abilitiesByAction;
      expect(abilities.action, isEmpty);
      expect(abilities.passive, hasLength(1));
      expect(abilities.passive.single.id, 'a1');
      expect(abilities.passive.single.name, 'Golpe Devastador');
      expect(abilities.passive.single.tacticalRole, 'Utilidad');
    });

    testWidgets('el filtro por categoría oculta las demás', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Arsenal');

      await tapKey(tester, 'filter-reaction');
      expect(find.text('Golpe Devastador'), findsNothing);
      await tapKey(tester, 'filter-all');
      expect(find.text('Golpe Devastador'), findsOneWidget);
    });

    testWidgets('resumen táctico editable en línea', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Arsenal');

      await tester.enterText(fieldIn('summary-a1'), 'Gasta la acción, +2d6 al impactar');
      await tester.pump();

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      expect(
        store.activeCharacter!.abilitiesByAction.action.single.tacticalSummary,
        'Gasta la acción, +2d6 al impactar',
      );
    });

    testWidgets('alta de habilidad completa y persistencia', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Arsenal');

      await tapKey(tester, 'add-trait');
      expect(find.text('Nueva habilidad'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Bola de Fuego');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ability-attack-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvación — el objetivo tira contra tu CD'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Dados de daño'), '8d6');
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Usos limitados por descanso'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usos limitados por descanso'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextFormField, 'Tope de usos'), '3');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Acción · 2'), findsOneWidget);
      expect(find.text('Bola de Fuego'), findsOneWidget);

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

    testWidgets('borrar la única habilidad avisa al guardar (2 avisos)',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Arsenal');

      await tester.tap(find.byTooltip('Borrar habilidad'));
      await tester.pumpAndSettle();
      expect(find.text('Golpe Devastador'), findsNothing);
      expect(find.text('No hay rasgos todavía.'), findsOneWidget);

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Hay 2 avisos'), findsOneWidget);
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      expect(store.activeCharacter!.abilitiesByAction.all, isEmpty);
    });

    testWidgets('notación de dados inválida avisada en vivo', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Arsenal');

      await tester.tap(find.text('Golpe Devastador'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Dados de daño'), 'banana');
      await tester.pump();

      expect(find.textContaining('Notación de dado inválida'), findsOneWidget);
    });

    testWidgets('armas: editar bono, daño condicional y arma única', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Arsenal');

      expect(find.text('Ataque +5 · 1d8+3 cortante'), findsOneWidget);
      await tester.tap(find.text('Espada Larga'));
      await tester.pumpAndSettle();
      expect(find.text('Editar arma'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Bono de ataque'), '7');
      await tester.pump();
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
      await tester.enterText(find.widgetWithText(TextFormField, 'Dados'), '1d6');
      await tester.enterText(find.widgetWithText(TextFormField, 'Tipo'), 'fuego');
      await tester.pump();
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
      expect(find.text('Ataque +7 · 1d8+3 cortante'), findsOneWidget);
      // El daño condicional ya aparece inline en la tarjeta.
      expect(find.text('Si el objetivo está quemado'), findsOneWidget);

      await saveWithWarning(tester);
      final weapon = store.activeCharacter!.inventory.weapons.single;
      expect(weapon.attackBonus, 7);
      expect(weapon.conditionalDamage, hasLength(1));
      expect(weapon.conditionalDamage.single.trigger, 'Si el objetivo está quemado');
      expect(weapon.conditionalDamage.single.dice, '1d6');
      expect(weapon.conditionalDamage.single.type, 'fuego');
      expect(weapon.isUnique, isTrue);
      expect(weapon.quantity, 1);
    });

    testWidgets('daño condicional y resumen táctico en línea en la tarjeta',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Arsenal');

      await tester.tap(find.text('Daño condicional'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Condición'), 'Contra no muertos');
      await tester.enterText(find.widgetWithText(TextFormField, 'Dados'), '2d8');
      await tester.enterText(find.widgetWithText(TextFormField, 'Tipo'), 'radiante');
      await tester.pump();

      await saveWithWarning(tester);
      final c = store.activeCharacter!.inventory.weapons.single.conditionalDamage.single;
      expect((c.trigger, c.dice, c.type), ('Contra no muertos', '2d8', 'radiante'));
    });

    testWidgets('armas: alta casera con cantidad y cargas', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Arsenal');

      await tapKey(tester, 'add-homebrew-weapon');
      expect(find.text('Nueva arma'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Hacha de Guerra');
      await tester.enterText(find.widgetWithText(TextFormField, 'Dados de daño base'), '1d12');
      await tester.enterText(find.widgetWithText(TextFormField, 'Tipo de daño base'), 'cortante');
      await tester.enterText(find.widgetWithText(TextFormField, 'Cantidad'), '2');
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Usos limitados por descanso'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usos limitados por descanso'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextFormField, 'Tope de usos'), '2');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Hacha de Guerra'), findsOneWidget);

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
      expect(hacha.id, startsWith('weapon_'));
    });

    testWidgets('+ Arma SRD calcula bonos con los atributos del borrador',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Arsenal');

      await tapKey(tester, 'add-srd-weapon');
      await tester.tap(find.byKey(const Key('srd-weapon-estoque')));
      await tester.pumpAndSettle();
      expect(find.text('Estoque'), findsOneWidget);

      await saveWithWarning(tester);
      final weapons = store.activeCharacter!.inventory.weapons;
      expect(weapons, hasLength(2));
      final estoque = weapons.firstWhere((w) => w.name == 'Estoque');
      // Sutil: usa FUE +3 (mayor que DES +1) y no pierde el dado.
      expect(estoque.damage.baseDice, '1d8+3');
      expect(estoque.damage.baseType, 'perforante');
      expect(estoque.properties, contains('Sutil'));
      expect(estoque.id, startsWith('weapon_'));
    });

    testWidgets('borrar un arma y descartar el editor no toca la ficha',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Arsenal');

      await tester.tap(find.byTooltip('Borrar arma'));
      await tester.pumpAndSettle();
      expect(find.text('La ficha no trae armas todavía.'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(CharacterEditorScreen), findsNothing);
      expect(store.activeCharacter!.inventory.weapons, hasLength(1));
      expect(store.activeCharacter!.inventory.weapons.single.name, 'Espada Larga');
    });
  });

  group('pestaña Grimorio', () {
    testWidgets('ranuras: stepper alta, baja y respeta current <= max',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook', slotCurrent: 2));
      await openEditor(tester, store);
      await goTab(tester, 'Grimorio');

      expect(find.text('2 de 4 disponibles'), findsOneWidget);
      // Gastada (2/4): subir el tope no regala ranuras.
      await tapKey(tester, 'slot-1-inc');
      expect(find.text('2 de 5 disponibles'), findsOneWidget);
      // Bajar por debajo de lo disponible las recorta.
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('list-grimorio')),
          matching: find.widgetWithText(TextFormField, 'Nivel 1'),
        ),
        '1',
      );
      await tester.pump();
      expect(find.text('1 de 1 disponibles'), findsOneWidget);

      // Nivel nuevo: arranca lleno.
      await tapKey(tester, 'slot-2-inc');
      await tapKey(tester, 'slot-2-inc');
      expect(find.text('2 de 2 disponibles'), findsOneWidget);
      // Llevar el nivel 1 a 0 lo quita de la ficha.
      await tapKey(tester, 'slot-1-dec');

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      final slots = store.activeCharacter!.spellSlots.slots;
      expect(slots, hasLength(1));
      expect((slots.single.level, slots.single.max, slots.single.current), (2, 2, 2));
    });

    testWidgets('la cuadrícula ofrece los 9 niveles', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Grimorio');

      for (var level = 1; level <= 9; level++) {
        expect(find.byKey(Key('slot-$level-inc')), findsOneWidget, reason: 'nivel $level');
      }
    });

    testWidgets('+ Conjuro casero: alta con nivel, dados y resumen',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Grimorio');

      expect(find.text('La ficha no trae conjuros todavía.'), findsOneWidget);
      await tapKey(tester, 'add-homebrew-spell');
      expect(find.text('Nuevo conjuro casero'), findsOneWidget);

      // Sin nombre no pasa.
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      expect(find.text('Poné un nombre.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('homebrew-spell-name')), 'Rayo de la Tormenta');
      await tester.tap(find.byKey(const Key('homebrew-level-inc')));
      await tester.pump();
      await tester.enterText(dialogField('Dados de daño'), '3d8');
      await tester.enterText(dialogField('Resumen táctico'), 'Cadena de 3 objetivos');
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Rayo de la Tormenta'), findsOneWidget);
      // Una vez en la tarjeta del conjuro y otra en la etiqueta de la cuadrícula.
      expect(find.text('Nivel 2'), findsNWidgets(2));

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();

      final spell = store.activeCharacter!.abilitiesByAction.all
          .firstWhere((a) => a.name == 'Rayo de la Tormenta');
      expect(spell.type, 'spell');
      expect(spell.isSpell, isTrue);
      expect(spell.baseLevel, 2);
      expect(spell.damageDice, '3d8');
      expect(spell.tacticalSummary, 'Cadena de 3 objetivos');
      expect(spell.id, startsWith('spell_'));
    });

    testWidgets('+ Conjuro SRD agrega el conjuro del catálogo y se edita en línea',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Grimorio');

      await tapKey(tester, 'add-srd-spell');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proyectil mágico').first);
      await tester.pumpAndSettle();
      expect(find.text('Proyectil mágico'), findsOneWidget);

      final spell = store.activeCharacter!.abilitiesByAction.all.where((a) => a.isSpell);
      expect(spell, isEmpty, reason: 'todavía es solo el borrador');

      await saveWithWarning(tester);
      final saved = store.activeCharacter!.abilitiesByAction.all.where((a) => a.isSpell);
      expect(saved.single.name, 'Proyectil mágico');
    });

    testWidgets('recursos: steppers, recarga y alta', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Grimorio');

      // Furia 2/3 (gastado): subir el tope no regala usos.
      await tapKey(tester, 'res-0-max-inc');
      expect(
        tester
            .widget<TextFormField>(find.descendant(
              of: find.byKey(const Key('list-grimorio')),
              matching: find.widgetWithText(TextFormField, 'Usos restantes'),
            ))
            .controller
            ?.text,
        '2',
      );
      // Bajar el tope por debajo de los usos restantes los recorta.
      await tapKey(tester, 'res-0-max-dec');
      await tapKey(tester, 'res-0-max-dec');
      await tapKey(tester, 'res-0-max-dec');

      await tester.tap(find.byKey(const Key('res-0-recovery')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descanso corto').last);
      await tester.pumpAndSettle();

      await tapKey(tester, 'add-resource');
      await tester.enterText(fieldIn('res-1-name'), 'Ki');
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tapKey(tester, 'res-1-max-inc');
      }

      await saveWithWarning(tester);
      final resources = store.activeCharacter!.resources;
      expect(resources, hasLength(2));
      expect((resources[0].name, resources[0].current, resources[0].max), ('Furia', 1, 1));
      expect(resources[0].recovery, 'short_rest');
      expect((resources[1].name, resources[1].current, resources[1].max), ('Ki', 4, 4));
      expect(resources[1].recovery, 'manual');
    });
  });

  group('pestaña Mochila', () {
    testWidgets('monedero con steppers y objetos', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Mochila');

      await tester.enterText(find.widgetWithText(TextFormField, 'Oro (po)'), '99');
      await tester.pump();
      expect(find.text('Equivalente total: 99.52 po'), findsOneWidget);
      await tapKey(tester, 'coin-pp-inc'); // 1 de platino = 10 po
      await tapKey(tester, 'coin-pe-inc'); // 1 de electro = 0.5 po
      expect(find.text('Equivalente total: 110.02 po'), findsOneWidget);

      await tapKey(tester, 'add-item');
      await tester.enterText(dialogField('Nombre'), 'Poción de curación');
      await tester.enterText(dialogField('Descripción (opcional)'), 'Cura 2d4+2');
      await tester.enterText(dialogField('Cantidad'), '3');
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Poción de curación'), findsOneWidget);
      expect(find.text('Cura 2d4+2 · ×3'), findsOneWidget);

      await saveWithWarning(tester);
      final ficha = store.activeCharacter!;
      expect(ficha.purse.gold, 99);
      expect(ficha.purse.platinum, 1);
      expect(ficha.purse.electrum, 1);
      expect(ficha.inventory.mundaneItems, hasLength(2));
      final pocion = ficha.inventory.mundaneItems.firstWhere((i) => i.name == 'Poción de curación');
      expect((pocion.description, pocion.quantity), ('Cura 2d4+2', 3));
    });

    testWidgets('+ Armadura / Escudo SRD agrega el objeto con su CA', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Mochila');

      await tapKey(tester, 'add-srd-armor');
      await tester.tap(find.byKey(const Key('srd-armor-escudo')));
      await tester.pumpAndSettle();
      expect(find.text('CA +2 · escudo · ×1'), findsOneWidget);

      await saveWithWarning(tester);
      expect(
        store.activeCharacter!.inventory.mundaneItems.map((i) => i.name),
        containsAll(['Cuerda', 'Escudo']),
      );
    });

    testWidgets('historia: el desplegable edita un campo y persiste', (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Mochila');

      expect(find.text('1 de 5 campos'), findsOneWidget);
      await tester.tap(find.text('Historia y personalidad'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Defectos'),
        'Se distrae con cualquier cosa brillante.',
      );
      await tester.pump();
      expect(find.text('2 de 5 campos'), findsOneWidget);

      await saveWithWarning(tester);
      final lore = store.activeCharacter!.loreInfo;
      expect(lore.backstory, 'Historia');
      expect(lore.flaws, 'Se distrae con cualquier cosa brillante.');
    });

    testWidgets('compañeros: PG coherentes al cambiar el tope y CA',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Mochila');

      expect(find.text('bestia · 5/10 PG · CA 12'), findsOneWidget);
      await tester.tap(find.text('Lobo'));
      await tester.pumpAndSettle();
      expect(find.text('Editar compañero'), findsOneWidget);

      TextFormField field(String label) => tester.widget<TextFormField>(dialogField(label));
      await tester.enterText(dialogField('PG máximos'), '3');
      await tester.pump();
      expect(field('PG actuales').controller?.text, '3');
      await tester.enterText(dialogField('PG máximos'), '20');
      await tester.pump();
      expect(field('PG actuales').controller?.text, '20');
      await tester.enterText(dialogField('CA'), '13');
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('bestia · 20/20 PG · CA 13'), findsOneWidget);

      await saveWithWarning(tester);
      final companion = store.activeCharacter!.companions.single;
      expect((companion.name, companion.currentHp, companion.maxHp, companion.ac),
          ('Lobo', 20, 20, 13));
      expect(companion.hasHp, isTrue);
    });

    testWidgets('compañero sin PG: apoyo invulnerable que persiste',
        (tester) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
      await openEditor(tester, store);
      await goTab(tester, 'Mochila');

      await tapKey(tester, 'add-companion');
      await tester.enterText(dialogField('Nombre'), 'Cuervo');
      await tester.enterText(dialogField('Tipo (opcional)'), 'familiar');
      await tester.tap(find.text('Tiene PG'));
      await tester.pumpAndSettle();
      expect(dialogField('PG máximos'), findsNothing);
      expect(dialogField('CA'), findsOneWidget);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('familiar · invulnerable · CA 10'), findsOneWidget);

      await saveWithWarning(tester);
      final cuervo = store.activeCharacter!.companions.firstWhere((c) => c.name == 'Cuervo');
      expect(cuervo.type, 'familiar');
      expect(cuervo.hasHp, isFalse);
    });
  });

  group('cierre del editor — estado de combate', () {
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
      ficha.resources.single.current = 2;
      ficha.companions.single.currentHp = 5;
      ficha.turnStatus.movementRemaining = 4;
      ficha.activeConditions.add('Envenenado');
      store.addCharacter(ficha);
      await openEditor(tester, store);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Rook el Intacto');
      await tester.pump();
      await saveWithWarning(tester);

      final guardada = store.activeCharacter!;
      expect(guardada.id, 'char_rook');
      expect(guardada.basicInfo.name, 'Rook el Intacto');
      expect(guardada.basicInfo.currentHp, 7);
      expect(guardada.inventory.weapons.single.magicCharges.current, 1);
      expect(guardada.abilitiesByAction.action.single.magicCharges.current, 1);
      expect(guardada.resources.single.current, 2);
      expect(guardada.resources.single.max, 3);
      expect(guardada.companions.single.currentHp, 5);
      expect(guardada.companions.single.maxHp, 10);
      expect(guardada.turnStatus.movementRemaining, 4);
      expect(guardada.activeConditions, ['Envenenado']);
    });
  });
}
