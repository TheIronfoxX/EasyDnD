// Mochila → Notas: diario de sesiones (crear, editar, borrar, persistir).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/state/character_store.dart';
import 'package:easydnd/state/skin_controller.dart';

import 'fakes/test_fichas.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<CharacterStore> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    return store;
  }

  group('store', () {
    test('alta, edición y baja por id', () async {
      final store = await boot();
      store.addCharacter(CharacterModel.fromJson(buildFichaJson()));

      final n = store.addSessionNote(title: '  Sesión 1 ', body: 'Llegamos');
      expect(n!.title, 'Sesión 1');
      expect(store.activeCharacter!.sessionNotes, hasLength(1));

      store.updateSessionNote(n.id, body: 'Llegamos a Neverwinter');
      expect(
        store.activeCharacter!.sessionNotes.single.body,
        contains('Neverwinter'),
      );
      expect(store.activeCharacter!.sessionNotes.single.title, 'Sesión 1');

      store.updateSessionNote('no-existe', body: 'x'); // no-op
      store.deleteSessionNote('no-existe'); // no-op
      expect(store.activeCharacter!.sessionNotes, hasLength(1));

      store.deleteSessionNote(n.id);
      expect(store.activeCharacter!.sessionNotes, isEmpty);
    });

    test('sin ficha activa es no-op', () async {
      final store = await boot();
      expect(store.addSessionNote(title: 'a', body: 'b'), isNull);
      store.deleteSessionNote('x');
    });

    test('sobrevive al reinicio y fichas viejas cargan sin notas', () async {
      var store = await boot();
      store.addCharacter(CharacterModel.fromJson(buildFichaJson()));
      store.addSessionNote(
        title: 'Persistente',
        body: 'cuerpo',
        now: DateTime(2026, 5, 1),
      );
      await Future<void>.delayed(Duration.zero);
      store = await boot();
      final note = store.activeCharacter!.sessionNotes.single;
      expect(note.title, 'Persistente');
      expect(note.createdAt, DateTime(2026, 5, 1));

      final old = CharacterModel.fromJson(buildFichaJson());
      expect(old.sessionNotes, isEmpty);
    });

    test('entradas corruptas del JSON se ignoran', () {
      final json = buildFichaJson()
        ..['session_notes'] = [
          'basura',
          {'title': 'ok', 'created_at': 'no-es-fecha'},
        ];
      final c = CharacterModel.fromJson(json);
      expect(c.sessionNotes, hasLength(1));
      expect(c.sessionNotes.single.title, 'ok');
    });
  });

  group('pestaña Notas', () {
    Future<CharacterStore> pump(WidgetTester tester) async {
      final store = await boot();
      store.addCharacter(CharacterModel.fromJson(buildFichaJson(name: 'Rook')));
      final prefs = await SharedPreferences.getInstance();
      final skin = SkinController(prefs);
      await skin.init();
      await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mochila'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notas'));
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('estado vacío, crear, editar y borrar', (tester) async {
      final store = await pump(tester);
      expect(find.textContaining('Todavía no hay notas'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('add-note')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-title')),
        'Sesión 1',
      );
      await tester.enterText(find.byKey(const ValueKey('note-body')), 'Cueva');
      await tester.tap(find.byKey(const ValueKey('save-note')));
      await tester.pumpAndSettle();

      expect(find.text('Sesión 1'), findsOneWidget);
      expect(store.activeCharacter!.sessionNotes, hasLength(1));

      await tester.tap(find.text('Sesión 1'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-title')),
        'Sesión 1b',
      );
      await tester.tap(find.byKey(const ValueKey('save-note')));
      await tester.pumpAndSettle();
      expect(find.text('Sesión 1b'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar nota'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-note')));
      await tester.pumpAndSettle();
      expect(store.activeCharacter!.sessionNotes, isEmpty);
      expect(find.textContaining('Todavía no hay notas'), findsOneWidget);
    });
  });
}
