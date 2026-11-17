import 'package:easydnd/domain/models/ability.dart';
import 'package:easydnd/domain/power_category.dart';
import 'package:flutter_test/flutter_test.dart';

Ability _a(Map<String, dynamic> extra) =>
    Ability.fromJson({'id': 'a', 'name': 'Poder', 'type': 'spell', ...extra});

void main() {
  group('categoryOf', () {
    test('power_role manda sobre todo lo demás', () {
      final a = _a({'power_role': 'Apoyo', 'damage_dice': '8d6'});
      expect(categoryOf(a), PowerCategory.support);
    });

    test('tactical_role de las pasivas se traduce', () {
      expect(
        categoryOf(_a({'tactical_role': 'Ofensivo'})),
        PowerCategory.damage,
      );
      expect(
        categoryOf(_a({'tactical_role': 'Defensivo'})),
        PowerCategory.defense,
      );
      expect(
        categoryOf(_a({'tactical_role': 'Utilidad'})),
        PowerCategory.utility,
      );
    });

    test('sin rol: daño, curación, palabras clave y utilidad', () {
      expect(categoryOf(_a({'damage_dice': '1d10'})), PowerCategory.damage);
      expect(categoryOf(_a({'heal_dice': '1d8'})), PowerCategory.support);
      expect(
        categoryOf(
          _a({'name': 'Escudo', 'success_description': '+5 a tu CA.'}),
        ),
        PowerCategory.defense,
      );
      expect(
        categoryOf(
          _a({'success_description': 'Hasta tres aliados suman 1d4.'}),
        ),
        PowerCategory.support,
      );
      expect(categoryOf(_a({'name': 'Mano del Mago'})), PowerCategory.utility);
    });

    test('tryParse acepta variantes y rechaza basura', () {
      expect(PowerCategory.tryParse(' daño '), PowerCategory.damage);
      expect(PowerCategory.tryParse('Soporte'), PowerCategory.support);
      expect(PowerCategory.tryParse('xyz'), isNull);
      expect(PowerCategory.tryParse(null), isNull);
    });
  });

  group('plainSummaryOf', () {
    test('usa plain_summary y si no, cae al resumen o la descripción', () {
      expect(
        plainSummaryOf(_a({'plain_summary': 'Lanzas fuego a un enemigo.'})),
        'Lanzas fuego a un enemigo.',
      );
      expect(
        plainSummaryOf(_a({'tactical_summary': 'Daño a distancia. Muy útil.'})),
        'Daño a distancia.',
      );
      expect(plainSummaryOf(_a({})), '');
    });
  });

  group('serialización', () {
    test('power_role y plain_summary viajan en el JSON solo si existen', () {
      final a = _a({
        'power_role': 'Daño',
        'plain_summary': 'Quema.',
        'when_to_use': 'Contra un enemigo lejos.',
      });
      final json = a.toJson(category: 'action');
      expect(json['power_role'], 'Daño');
      expect(json['plain_summary'], 'Quema.');
      expect(json['when_to_use'], 'Contra un enemigo lejos.');
      expect(
        _a({}).toJson(category: 'action').containsKey('power_role'),
        isFalse,
      );
      final back = Ability.fromJson(json);
      expect(back.powerRole, 'Daño');
      expect(back.plainSummary, 'Quema.');
      expect(back.whenToUse, 'Contra un enemigo lejos.');
    });
  });
}
