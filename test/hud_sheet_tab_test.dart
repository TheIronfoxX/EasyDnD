// Tests de la pestaña Ficha (Etapa 5d).
//
// Es de SOLO LECTURA: atributos, competencias, lore y códice se pintan
// tal como están en el modelo y no hay campos editables. La edición
// sigue viviendo en CharacterEditorScreen (cubierta en
// character_editor_test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easydnd/core/theme/app_theme.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/domain/models/stats.dart';
import 'package:easydnd/features/hud/hud_sheet_tab.dart';

import 'fakes/test_fichas.dart';

void main() {
  Future<void> pumpSheet(WidgetTester tester, CharacterModel character) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: HudSheetTab(character: character)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('atributos', () {
    testWidgets('muestra los seis valores con su modificador', (tester) async {
      await pumpSheet(tester, buildCharacter(id: 'char_sheet', name: 'Rook'));

      expect(find.text('Atributos'), findsOneWidget);
      for (final label in [
        'Fuerza',
        'Destreza',
        'Constitución',
        'Inteligencia',
        'Sabiduría',
        'Carisma',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      // Valores de la ficha de prueba (16/12/14/10/10/10).
      expect(find.text('16'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('10'), findsNWidgets(3));

      // Modificadores formateados con signo (+3, +1, +2 y tres +0).
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('+0'), findsNWidgets(3));
    });
  });

  group('competencias', () {
    testWidgets('lista nombre, atributo y modificador final', (tester) async {
      final character = buildCharacter(id: 'char_skills', name: 'Rook');
      character.skills.addAll([
        Skill(name: 'Atletismo', relatedStat: 'str', modifier: 5),
        Skill(name: 'Sigilo', relatedStat: 'dex', modifier: 3),
      ]);

      await pumpSheet(tester, character);

      expect(find.text('Competencias'), findsOneWidget);
      expect(find.text('Atletismo'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('Sigilo'), findsOneWidget);
      // +3 también es el modificador de Fuerza en Atributos: acotamos al
      // ListTile de Sigilo para no confundir ambas apariciones.
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Sigilo'),
          matching: find.text('+3'),
        ),
        findsOneWidget,
      );
      // El atributo aparece en la tarjeta y como subtítulo de la skill.
      expect(find.text('Fuerza'), findsNWidgets(2));
      expect(find.text('Destreza'), findsNWidgets(2));
    });

    testWidgets('sin competencias muestra un estado vacío', (tester) async {
      await pumpSheet(tester, buildCharacter(id: 'char_noskills'));

      expect(find.text('La ficha no trae competencias.'), findsOneWidget);
    });
  });

  group('lore y códice', () {
    testWidgets('pinta los campos narrativos y las notas', (tester) async {
      final character = buildCharacter(id: 'char_lore', name: 'Rook');
      character.loreInfo
        ..backstory = 'Criado entre mercenarios.'
        ..personalityTraits = 'Habla poco y observa mucho.'
        ..ideals = 'La libertad no se negocia.'
        ..bonds = 'Debe una deuda a Mira.'
        ..flaws = 'No confía en la magia.';
      character.aiTips = 'Usá Furia en el primer turno.';
      character.userTactics = 'Guardar la reacción para el jefe.';
      character.adventureNotes = 'Día 3: la cripta de sal.';

      await pumpSheet(tester, character);

      expect(find.text('Historia y personalidad'), findsOneWidget);
      expect(find.text('Criado entre mercenarios.'), findsOneWidget);
      expect(find.text('Habla poco y observa mucho.'), findsOneWidget);
      expect(find.text('La libertad no se negocia.'), findsOneWidget);
      expect(find.text('Debe una deuda a Mira.'), findsOneWidget);
      expect(find.text('No confía en la magia.'), findsOneWidget);

      expect(find.text('Códice'), findsOneWidget);
      expect(find.text('NOTAS DE LA IA'), findsOneWidget);
      expect(find.text('Usá Furia en el primer turno.'), findsOneWidget);
      expect(find.text('TÁCTICAS DEL JUGADOR'), findsOneWidget);
      expect(find.text('Guardar la reacción para el jefe.'), findsOneWidget);
      expect(find.text('DIARIO DE AVENTURA'), findsOneWidget);
      expect(find.text('Día 3: la cripta de sal.'), findsOneWidget);

      // De solo lectura: ni un solo campo de texto en toda la pestaña.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('sin lore ni notas muestra estados vacíos', (tester) async {
      final character = buildCharacter(id: 'char_blank', name: 'Rook');
      character.loreInfo = LoreInfo(
        backstory: '',
        personalityTraits: '',
        ideals: '',
        bonds: '',
        flaws: '',
      );

      await pumpSheet(tester, character);

      expect(
        find.text('La ficha no trae historia ni personalidad.'),
        findsOneWidget,
      );
      expect(find.text('Sin notas en el códice todavía.'), findsOneWidget);
    });
  });
}
