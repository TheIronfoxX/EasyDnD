// Integración del flujo de importación de Nivel20: importación directa
// (sin IA) hasta el modelo validado, y el prompt enriquecido, ambos con
// la ficha real de Kael.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/domain/ai_prompt.dart';
import 'package:easydnd/domain/nivel20_mapper.dart';
import 'package:easydnd/domain/nivel20_patch.dart';
import 'package:easydnd/features/import/import_wizard_screen.dart';
import 'package:easydnd/features/import/nivel20_import.dart';
import 'package:easydnd/state/character_store.dart';

void main() {
  const fixturePath = 'test/fixtures/nivel20/kael_nar_ardinys.trimmed.json';
  late String fixtureText;
  late Map<String, dynamic> raw;

  setUpAll(() {
    fixtureText = File(fixturePath).readAsStringSync();
    raw = jsonDecode(fixtureText) as Map<String, dynamic>;
  });

  group('Nivel20Import (lógica)', () {
    test('parseRaw reconoce Nivel20 y descarta lo demás', () {
      expect(Nivel20Import.parseRaw(fixtureText), isNotNull);
      expect(Nivel20Import.parseRaw('texto libre de un PDF'), isNull);
      expect(Nivel20Import.parseRaw('{roto'), isNull);
      expect(Nivel20Import.parseRaw('{"basic_info": {"name": "X"}}'), isNull);
    });

    test('importación directa: del JSON de Nivel20 al modelo validado', () {
      final result = Nivel20Import.direct(Nivel20Import.parseRaw(fixtureText)!);
      expect(result.errors, isEmpty);
      expect(result.isOk, isTrue);
      final c = result.character!;
      expect(c.basicInfo.name, 'Kael`nar Ardinys');
      expect(c.basicInfo.level, 15);
      expect(c.basicInfo.hpMax, 125);
      expect(c.basicInfo.speed, 30);
      expect(c.spellSlots.slots, hasLength(8));
      expect(c.abilitiesByAction.action.map((a) => a.name), contains('Rayo de fuego'));
    });

    test('importación directa de algo sin nombre devuelve error, no excepción', () {
      final result = Nivel20Import.direct({'info': {}});
      expect(result.isOk, isFalse);
      expect(result.errors, isNotEmpty);
    });
  });

  group('AiPrompt.forNivel20Enrichment', () {
    late String prompt;
    setUpAll(() => prompt = Nivel20Import.enrichedPrompt(raw));

    test('envía solo contexto mínimo: ni ficha base ni conjuros ni números', () {
      expect(prompt, contains('Nombre: Kael`nar Ardinys'));
      expect(prompt, contains('Nivel:'));
      for (final prohibido in ['"hp_max"', '"spell_save_dc"', '"attack_bonus"', '"base_dice"', 'Tormenta de hielo', 'Bastón']) {
        expect(prompt, isNot(contains(prohibido)));
      }
    });

    test('incluye los textos crudos de rasgos, acciones caseras y equipo', () {
      expect(prompt, contains('Esculpir conjuros'));
      expect(prompt, contains('Forma cambiante'));
      expect(prompt, contains('Supernova'));
      expect(prompt, contains('Una aguja que nunca se dobla.'));
    });

    test('pide un parche con solo las cuatro claves opcionales', () {
      for (final clave in Nivel20Patch.patchKeys) {
        expect(prompt, contains('"$clave"'));
      }
      expect(prompt, contains('"Ofensivo", "Defensivo" o "Utilidad"'));
      expect(prompt, contains('mundane_items'));
      expect(prompt, contains('NO añadas ninguna otra clave'));
    });

    test('es compacto: no arrastra el ejemplo maestro ni las reglas largas', () {
      expect(prompt, isNot(contains('Kaelen el Luminoso')));
      expect(prompt, isNot(contains('REGLAS OBLIGATORIAS')));
    });

    test('secciones vacías se marcan "(sin datos)"', () {
      expect(AiPrompt.forNivel20Enrichment(), contains('(sin datos)'));
    });

    test('pide las claves opcionales purse y companions', () {
      expect(prompt, contains('"purse"'));
      expect(prompt, contains('"companions"'));
      expect(prompt, contains('"name", "type", "has_hp", "current_hp", "max_hp", "ac"'));
    });
  });

  group('Nivel20Import.mergeAiPatch', () {
    test('suma el oro del parche sin pisar el ya detectado por regex', () {
      final base = {'purse': {'gold': 50, 'silver': 0, 'copper': 0}};
      final patch = {'purse': {'gold': 10, 'silver': 5, 'copper': 0}};
      final merged = Nivel20Import.mergeAiPatch(base, patch);
      expect(merged['purse'], {'gold': 60, 'silver': 5, 'copper': 0});
    });

    test('sin "purse" en el parche, deja el de la base intacto', () {
      final base = {'purse': {'gold': 50, 'silver': 0, 'copper': 0}};
      final merged = Nivel20Import.mergeAiPatch(base, {});
      expect(merged['purse'], {'gold': 50, 'silver': 0, 'copper': 0});
    });

    test('añade companions del parche sin duplicar los ya existentes', () {
      final base = {
        'companions': [
          {'name': 'Nix', 'type': 'familiar', 'has_hp': false, 'current_hp': 0, 'max_hp': 0, 'ac': 10},
        ],
      };
      final patch = {
        'companions': [
          // Mismo nombre que uno ya existente: no debe duplicarse.
          {'name': 'Nix', 'type': 'otro', 'has_hp': true, 'current_hp': 5, 'max_hp': 5, 'ac': 12},
          {'name': 'Calion', 'type': 'aliado', 'has_hp': true, 'current_hp': 20, 'max_hp': 20, 'ac': 14},
        ],
      };
      final merged = Nivel20Import.mergeAiPatch(base, patch);
      final companions = merged['companions'] as List;
      expect(companions, hasLength(2));
      expect(companions.map((c) => c['name']), ['Nix', 'Calion']);
      // El Nix existente no se pisó con el del parche.
      expect(companions.first['type'], 'familiar');
    });

    test('sin "companions" en el parche, deja la base intacta', () {
      final base = {'companions': <Map<String, dynamic>>[]};
      final merged = Nivel20Import.mergeAiPatch(base, {'purse': {'gold': 1}});
      expect(merged['companions'], isEmpty);
    });
  });

  group('wizard: importación directa de Nivel20', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<CharacterStore> boot() async {
      final prefs = await SharedPreferences.getInstance();
      final store = CharacterStore(RosterRepository(prefs));
      await store.init();
      return store;
    }

    Future<void> pumpWizard(WidgetTester tester, CharacterStore store) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<CharacterStore>.value(
          value: store,
          child: const MaterialApp(home: ImportWizardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pegar ficha'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, fixtureText);
      await tester.pumpAndSettle();
    }

    testWidgets('JSON de Nivel20 pegado: salta al paso 3 y importa', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = await boot();
      await pumpWizard(tester, store);

      expect(find.text('Importar directo (sin IA)'), findsOneWidget);
      expect(find.text('Preparar prompt de IA (enriquecido)'), findsOneWidget);

      await tester.ensureVisible(find.text('Importar directo (sin IA)'));
      await tester.tap(find.text('Importar directo (sin IA)'));
      await tester.pumpAndSettle();

      expect(find.text('Importar personaje'), findsOneWidget); // paso 3
      expect(store.roster, isEmpty); // aún sin tocar el roster

      await tester.tap(find.text('Importar personaje'));
      await tester.pumpAndSettle();
      expect(store.roster, hasLength(1));
      expect(store.roster.single.basicInfo.name, 'Kael`nar Ardinys');
    });

    testWidgets('"Atrás" desde la revisión directa conserva el JSON pegado', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = await boot();
      await pumpWizard(tester, store);

      await tester.ensureVisible(find.text('Importar directo (sin IA)'));
      await tester.tap(find.text('Importar directo (sin IA)'));
      await tester.pumpAndSettle();
      expect(find.text('Importar personaje'), findsOneWidget);

      await tester.tap(find.text('Atrás'));
      await tester.pumpAndSettle();

      // Paso 1 de vuelta, con el modo y el texto intactos.
      expect(find.text('Conseguí el prompt para tu IA'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, fixtureText);
      expect(store.roster, isEmpty);

      // Y puede elegir la otra vía sin volver a pegar nada.
      await tester.ensureVisible(find.text('Preparar prompt de IA (enriquecido)'));
      await tester.tap(find.text('Preparar prompt de IA (enriquecido)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('DEVUELVE un único objeto JSON', findRichText: true), findsOneWidget);
    });

    testWidgets('Atrás desde la revisión tras pegar la respuesta de la IA también conserva el Paso 1', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = await boot();
      await pumpWizard(tester, store);

      await tester.tap(find.text('Continuar')); // paso 2
      await tester.pumpAndSettle();
      final ia = jsonEncode(Nivel20Mapper.toJson(raw));
      await tester.enterText(find.byType(TextField), ia);
      await tester.pump();
      await tester.tap(find.text('Continuar')); // valida -> paso 3
      await tester.pumpAndSettle();
      expect(find.text('Importar personaje'), findsOneWidget);

      await tester.tap(find.text('Atrás')); // paso 2
      await tester.pumpAndSettle();
      await tester.tap(find.text('Atrás')); // paso 1
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, fixtureText);
      expect(find.text('Importar directo (sin IA)'), findsOneWidget);
    });

    testWidgets('prompt enriquecido: reemplaza el prompt de la vista previa', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = await boot();
      await pumpWizard(tester, store);

      expect(find.textContaining('DEVUELVE un único objeto JSON', findRichText: true), findsNothing);
      await tester.ensureVisible(find.text('Preparar prompt de IA (enriquecido)'));
      await tester.tap(find.text('Preparar prompt de IA (enriquecido)'));
      await tester.pumpAndSettle();

      expect(find.text('Prompt enriquecido listo (abajo)'), findsOneWidget);
      expect(find.textContaining('DEVUELVE un único objeto JSON', findRichText: true), findsOneWidget);
    });

    testWidgets('texto que no es Nivel20: no ofrece importación directa', (tester) async {
      final store = await boot();
      await tester.pumpWidget(
        ChangeNotifierProvider<CharacterStore>.value(
          value: store,
          child: const MaterialApp(home: ImportWizardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pegar ficha'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Mago nivel 3, 20 PG');
      await tester.pumpAndSettle();
      expect(find.text('Importar directo (sin IA)'), findsNothing);
    });
  });
}
