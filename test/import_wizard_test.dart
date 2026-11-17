// Tests del wizard de importación (flujo completo de 3 pasos).
//
// Cubren el circuito que en la app vieja quedaba roto o sin UI:
// - La validación con vista previa ANTES de tocar el roster.
// - La importación como alta y como reemplazo (sin duplicar fichas).
// - Los errores bloqueantes visibles en el paso 2, sin avanzar.
// - El banner del modo corrección y los modos de fuente del paso 1.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/features/editor/character_editor_screen.dart';
import 'package:easydnd/domain/character_validator.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/features/import/import_wizard_screen.dart';
import 'package:easydnd/features/import/wizard_step_preview.dart';
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

  /// Monta una home con botón que apila el wizard, para poder verificar
  /// que al confirmar la ficha el wizard vuelve (pop) y no explota el
  /// navigator.
  Future<void> pumpHome(
    WidgetTester tester,
    CharacterStore store, {
    int? replaceIndex,
  }) {
    return tester.pumpWidget(
      ChangeNotifierProvider<CharacterStore>.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ImportWizardScreen(replaceIndex: replaceIndex),
                  ),
                ),
                child: const Text('abrir-wizard'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openWizard(WidgetTester tester) async {
    await tester.tap(find.text('abrir-wizard'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportWizardScreen), findsOneWidget);
  }

  /// Salta al paso 2 y pega [jsonText] en el campo de respuesta.
  Future<void> pasteResponse(WidgetTester tester, String jsonText) async {
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), jsonText);
    await tester.pump();
  }

  group('paso 1 — prompt', () {
    testWidgets('modo vacía muestra el prompt maestro con marcador', (
      tester,
    ) async {
      final store = await boot();
      await pumpHome(tester, store);
      await openWizard(tester);

      // El prompt por defecto (ficha vacía) lleva las reglas y el marcador
      // (el marcador también aparece citado en el hint del modo).
      expect(find.textContaining('REGLAS OBLIGATORIAS:'), findsOneWidget);
      expect(
        find.textContaining('PEGA AQUÍ LOS DATOS DE TU PERSONAJE'),
        findsWidgets,
      );
      expect(find.text('Copiar prompt'), findsOneWidget);
    });

    testWidgets('cambiar a "Pegar ficha" muestra el campo de texto', (
      tester,
    ) async {
      final store = await boot();
      await pumpHome(tester, store);
      await openWizard(tester);

      await tester.tap(find.text('Pegar ficha'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      // Sin texto todavía: el prompt se vacía y el botón de copiar se apaga.
      expect(find.text('Copiar prompt'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Copiar prompt'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('modo enlace con link inválido: error amigable, sin red', (
      tester,
    ) async {
      final store = await boot();
      await pumpHome(tester, store);
      await openWizard(tester);

      await tester.tap(find.text('Enlace Nivel20'));
      await tester.pumpAndSettle();
      // Sin esquema: falla ANTES de hacer cualquier request.
      await tester.enterText(find.byType(TextField), 'nivel20.com/s/abc123');
      await tester.tap(find.text('Descargar ficha'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no parece válido'), findsOneWidget);
    });

    testWidgets('modo corrección: banner + lista de problemas de la ficha', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(name: 'Viejo'));
      await pumpHome(tester, store, replaceIndex: 0);
      await openWizard(tester);

      expect(find.textContaining('REEMPLAZA la actual'), findsOneWidget);
      expect(find.text('Corregir ficha con IA'), findsOneWidget);
      // En modo corrección NO existe el modo "Vacía".
      expect(find.text('Vacía'), findsNothing);
      expect(find.text('Ficha actual'), findsOneWidget);

      // La ficha fixture no declara spell_save_dc teniendo ranuras →
      // ese es el problema que lista el modo "Ficha actual".
      await tester.tap(find.text('Ficha actual'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Problemas detectados'), findsOneWidget);
      // El modo "Ficha actual" lista cada problema como "campo: mensaje".
      expect(find.textContaining('basic_info.spell_save_dc:'), findsOneWidget);
    });
  });

  group('paso 2 — respuesta', () {
    testWidgets('texto vacío: pide pegar algo y no avanza', (tester) async {
      final store = await boot();
      await pumpHome(tester, store);
      await openWizard(tester);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pegá primero el JSON'), findsOneWidget);
      expect(find.text('Revisá antes de confirmar'), findsNothing);
      expect(store.roster, isEmpty);
    });

    testWidgets('JSON inválido: error visible, no avanza, roster intacto', (
      tester,
    ) async {
      final store = await boot();
      await pumpHome(tester, store);
      await openWizard(tester);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'no soy un json');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('El texto no contiene un JSON válido'),
        findsOneWidget,
      );
      // Sigue en el paso 2.
      expect(find.text('Pegá la respuesta de la IA'), findsOneWidget);
      expect(store.roster, isEmpty);
    });
  });

  group('paso 3 — revisión y confirmación', () {
    testWidgets(
      'avisos del parche (creados/ignorados) se muestran sin bloquear',
      (tester) async {
        final character = CharacterModel.fromJson(
          buildFichaJson(id: 'char_p', name: 'Pía'),
        );
        final result = CharacterValidationResult(
          character: character,
          issues: const [
            ValidationIssue(
              severity: ValidationSeverity.warning,
              field: 'parche.patch-furia-del-barbaro',
              message: 'El parche creó el poder "Furia del bárbaro".',
            ),
            ValidationIssue(
              severity: ValidationSeverity.warning,
              field: 'parche.resources[Cero]',
              message: 'Falta el nombre o "max" no es un entero positivo.',
            ),
          ],
        );
        var confirmed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WizardStepPreview(
                result: result,
                isReplace: false,
                onConfirm: () => confirmed = true,
              ),
            ),
          ),
        );
        expect(find.textContaining('Avisos (2)'), findsOneWidget);
        expect(find.text('parche.patch-furia-del-barbaro'), findsOneWidget);
        expect(find.text('parche.resources[Cero]'), findsOneWidget);
        expect(confirmed, isFalse);
      },
    );

    testWidgets('flujo completo de alta: preview con avisos → importar', (
      tester,
    ) async {
      final store = await boot();
      await pumpHome(tester, store);
      await openWizard(tester);

      // La fixture sin spell_save_dc con ranuras → exactamente 1 aviso.
      final fichaJson = jsonEncode(
        buildFichaJson(id: 'char_k', name: 'Kaelen'),
      );
      await pasteResponse(tester, fichaJson);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      // Paso 3: resumen + avisos.
      expect(find.text('Kaelen'), findsOneWidget);
      expect(find.text('Revisá antes de confirmar'), findsOneWidget);
      expect(find.textContaining('Avisos (1)'), findsOneWidget);
      expect(find.text('basic_info.spell_save_dc'), findsOneWidget);
      // La tarjeta de corrección está bajo el fold del ListView lazy.
      await tester.scrollUntilVisible(
        find.text('Copiar prompt de corrección'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Copiar prompt de corrección'), findsOneWidget);

      // Confirmar: el roster queda poblado y activo, y el wizard salta
      // directo al taller de edición con la ficha recién importada.
      await tester.tap(find.text('Importar personaje'));
      await tester.pumpAndSettle();

      expect(find.byType(ImportWizardScreen), findsNothing);
      expect(find.byType(CharacterEditorScreen), findsOneWidget);
      expect(find.text('Editar a Kaelen'), findsOneWidget);
      expect(store.roster.length, 1);
      expect(store.activeCharacter?.basicInfo.name, 'Kaelen');
      expect(store.activeIndex, 0);
    });

    testWidgets(
      'tras importar, calibrar en el taller y guardar no duplica la ficha',
      (tester) async {
        final store = await boot();
        await pumpHome(tester, store);
        await openWizard(tester);

        await pasteResponse(
          tester,
          jsonEncode(buildFichaJson(id: 'char_k', name: 'Kaelen')),
        );
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Importar personaje'));
        await tester.pumpAndSettle();

        // Calibración: reclasificar el rasgo importado en un toque.
        await tester.tap(find.widgetWithText(Tab, 'Arsenal'));
        await tester.pumpAndSettle();
        final chip = find.byKey(const Key('cat-a1-bonusAction'));
        await tester.scrollUntilVisible(
          chip,
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('list-arsenal')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(chip);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar igual'));
        await tester.pumpAndSettle();

        expect(find.byType(CharacterEditorScreen), findsNothing);
        expect(
          store.roster,
          hasLength(1),
          reason: 'el editor reemplaza, no duplica',
        );
        expect(store.activeCharacter!.id, 'char_k');
        final abilities = store.activeCharacter!.abilitiesByAction;
        expect(abilities.action, isEmpty);
        expect(abilities.bonusAction.single.id, 'a1');
      },
    );

    testWidgets('al reemplazar con IA (corrección) NO se abre el taller', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_k', name: 'Kaelen'));
      await pumpHome(tester, store, replaceIndex: 0);
      await openWizard(tester);

      await tester.tap(find.text('Ficha actual'));
      await tester.pumpAndSettle();
      await pasteResponse(
        tester,
        jsonEncode(buildFichaJson(id: 'char_k', name: 'Kaelen II')),
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Reemplazar a'));
      await tester.pumpAndSettle();

      expect(find.byType(CharacterEditorScreen), findsNothing);
      expect(store.roster, hasLength(1));
      expect(store.activeCharacter!.basicInfo.name, 'Kaelen II');
    });

    testWidgets('ir atrás desde la revisión y corregir el JSON pegado', (
      tester,
    ) async {
      final store = await boot();
      await pumpHome(tester, store);
      await openWizard(tester);

      await pasteResponse(
        tester,
        jsonEncode(buildFichaJson(id: 'char_k', name: 'Kaelen')),
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Kaelen'), findsOneWidget);

      // Atrás → mismo texto cargado → continuar de nuevo revalida.
      await tester.tap(find.text('Atrás'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // Edito el nombre y vuelvo a revisar: la preview debe refrescar.
      final edited = jsonEncode(
        buildFichaJson(id: 'char_k', name: 'Kaelen II'),
      );
      await tester.enterText(find.byType(TextField), edited);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Kaelen II'), findsOneWidget);
      expect(store.roster, isEmpty); // todavía sin commit
    });

    testWidgets('modo reemplazo: corrige sin duplicar la ficha', (
      tester,
    ) async {
      final store = await boot();
      store.addCharacter(buildCharacter(id: 'char_viejo', name: 'Viejo'));
      await pumpHome(tester, store, replaceIndex: 0);
      await openWizard(tester);

      await pasteResponse(
        tester,
        jsonEncode(buildFichaJson(id: 'char_nuevo', name: 'Nuevo')),
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      // El CTA del modo corrección dice a quién reemplaza.
      expect(find.text('Reemplazar a Viejo'), findsOneWidget);

      await tester.tap(find.text('Reemplazar a Viejo'));
      await tester.pumpAndSettle();

      expect(find.byType(ImportWizardScreen), findsNothing);
      expect(store.roster.length, 1, reason: 'no debe duplicar la entrada');
      expect(store.activeCharacter?.basicInfo.name, 'Nuevo');
      expect(store.activeIndex, 0);
    });
  });
}
