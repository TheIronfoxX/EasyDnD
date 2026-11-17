import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/domain/models/character.dart';
import 'package:easydnd/domain/roster_backup.dart';
import 'package:easydnd/state/character_store.dart';

import 'fakes/test_fichas.dart';

CharacterModel ficha({String id = 'char_a', String name = 'Rook'}) =>
    CharacterModel.fromJson(buildFichaJson(id: id, name: name));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<CharacterStore> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    return store;
  }

  group('RosterBackup', () {
    test('ida y vuelta conserva las fichas', () {
      final raw = RosterBackup.encodeBackup([
        ficha(id: 'a', name: 'A'),
        ficha(id: 'b', name: 'B'),
      ]);
      expect(RosterBackup.looksLikeBackup(raw), isTrue);

      final parsed = RosterBackup.parseBackup(raw);
      expect(parsed.isOk, isTrue);
      expect(parsed.characters.map((c) => c.basicInfo.name), ['A', 'B']);
      expect(parsed.characters.map((c) => c.id), ['a', 'b']);
    });

    test('vacía las rutas de avatar locales al exportar', () {
      final c = ficha()
        ..avatarPath = '/data/user/0/app/avatar.png'
        ..loreAvatarPath = '/data/user/0/app/lore.png';
      final map = jsonDecode(RosterBackup.encodeCharacter(c)) as Map;
      expect(map['avatar_path'], isNull);
      expect(map['lore_avatar_path'], isNull);
      // y no toca el modelo original
      expect(c.avatarPath, isNotNull);
    });

    test('una ficha corrupta se omite sin tirar el resto', () {
      final raw = jsonEncode({
        'easydnd_backup': 1,
        'characters': [
          buildFichaJson(id: 'a', name: 'A'),
          {'sin': 'basic_info'},
          'basura',
        ],
      });
      final parsed = RosterBackup.parseBackup(raw);
      expect(parsed.characters, hasLength(1));
      expect(parsed.skipped, 2);
      expect(parsed.messages, isNotEmpty);
    });

    test('una ficha suelta no es un respaldo', () {
      final raw = RosterBackup.encodeCharacter(ficha());
      expect(RosterBackup.looksLikeBackup(raw), isFalse);
      expect(RosterBackup.parseBackup(raw).fatalError, isNotNull);
      expect(RosterBackup.parseBackup('no es json').fatalError, isNotNull);
    });

    test('la ficha exportada la reimporta el validador normal', () {
      final store = ficha(name: 'Solo');
      final raw = RosterBackup.encodeCharacter(store);
      final back = CharacterModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      expect(back.basicInfo.name, 'Solo');
    });
  });

  group('CharacterStore.importBackup', () {
    test('añade al final y regenera ids repetidos', () async {
      final store = await boot();
      store.addCharacter(ficha(id: 'dup', name: 'Existente'));

      final n = store.importBackup([ficha(id: 'dup', name: 'Copia')]);
      expect(n, 1);
      expect(store.roster, hasLength(2));
      expect(store.roster.map((c) => c.id).toSet(), hasLength(2));
      expect(store.activeCharacter!.basicInfo.name, 'Copia');
    });

    test('replace sustituye todo el roster', () async {
      final store = await boot();
      store.addCharacter(ficha(id: 'x', name: 'X'));
      store.addCharacter(ficha(id: 'y', name: 'Y'));

      store.importBackup([ficha(id: 'z', name: 'Z')], replace: true);
      expect(store.roster.map((c) => c.basicInfo.name), ['Z']);
    });

    test(
      'lista vacía es no-op; importar el mismo texto dos veces no duplica ids',
      () async {
        final store = await boot();
        expect(store.importBackup([]), 0);

        final raw = RosterBackup.encodeCharacter(ficha(id: 'same'));
        store.importCharacterFromText(raw);
        store.importCharacterFromText(raw);
        expect(store.roster, hasLength(2));
        expect(store.roster[0].id, isNot(store.roster[1].id));
      },
    );

    test('persiste tras reiniciar', () async {
      var store = await boot();
      store.importBackup([
        ficha(id: 'a', name: 'A'),
        ficha(id: 'b', name: 'B'),
      ]);
      await Future<void>.delayed(Duration.zero);
      store = await boot();
      expect(store.roster, hasLength(2));
    });
  });
}
