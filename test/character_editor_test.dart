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
}
