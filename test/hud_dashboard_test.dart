// Tests del tablero de combate (Etapa 5b): vida, economía de turno,
// condiciones, recursos, ranuras y descansos.
//
// Son tests de UI de punta a punta contra el store real (prefs
// mockeadas): tocan los botones como lo haría el jugador y verifican el
// efecto en la ficha, no solo que el widget exista. El detalle de las
// reglas ya lo cubren character_store_test y dnd_rules_test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/app/easydnd_app.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/state/character_store.dart';
import 'package:easydnd/state/skin_controller.dart';

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

  Future<void> pumpHud(WidgetTester tester, CharacterStore store) async {
    final prefs = await SharedPreferences.getInstance();
    final skin = SkinController(prefs);
    await skin.init();
    await tester.pumpWidget(EasyDnDApp(store: store, skin: skin));
    await tester.pumpAndSettle();
  }

  /// Deja el `finder` dentro del viewport del ListView del tablero.
  /// `ensureVisible` lo alinea arriba, así no queda tapado por la barra
  /// de navegación inferior.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('muestra vida, defensas, dados de golpe y estado', (
    tester,
  ) async {
    final store = await boot();
    store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
    await pumpHud(tester, store);

    expect(find.text('Vida'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('/ 20 PG'), findsOneWidget);
    expect(find.text('Ileso'), findsOneWidget);
    expect(find.text('CA'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('9 m'), findsOneWidget);
    expect(find.text('5/5 d10'), findsOneWidget);
  });

  testWidgets('daño y curación pasan por el diálogo y clampean', (
    tester,
  ) async {
    final store = await boot();
    store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
    await pumpHud(tester, store);

    await tester.tap(find.text('Daño'));
    await tester.pumpAndSettle();
    expect(find.text('Aplicar daño'), findsWidgets);

    await tester.enterText(find.byType(TextFormField), '7');
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar daño'));
    await tester.pumpAndSettle();

    expect(store.activeCharacter!.basicInfo.currentHp, 13);
    expect(find.text('13'), findsOneWidget);
    expect(find.text('Herido'), findsOneWidget);

    await tester.tap(find.text('Curación'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2');
    await tester.tap(find.widgetWithText(FilledButton, 'Curar'));
    await tester.pumpAndSettle();

    expect(store.activeCharacter!.basicInfo.currentHp, 15);
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('economía de turno: chips, movimiento y reinicio', (
    tester,
  ) async {
    final store = await boot();
    store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
    await pumpHud(tester, store);

    await scrollTo(tester, find.text('Terminar turno'));

    await tester.tap(find.widgetWithText(FilterChip, 'Acción'));
    await tester.pumpAndSettle();
    expect(store.activeCharacter!.turnStatus.actionUsed, isTrue);

    await tester.tap(find.widgetWithText(FilterChip, 'Reacción'));
    await tester.pumpAndSettle();
    expect(store.activeCharacter!.turnStatus.reactionUsed, isTrue);

    await scrollTo(tester, find.byTooltip('Restar 1 m de movimiento'));
    await tester.tap(find.byTooltip('Restar 1 m de movimiento'));
    await tester.pumpAndSettle();
    expect(store.activeCharacter!.turnStatus.movementRemaining, 8);

    await tester.tap(find.byTooltip('Sumar 1 m de movimiento'));
    await tester.pumpAndSettle();
    expect(store.activeCharacter!.turnStatus.movementRemaining, 9);

    await scrollTo(tester, find.text('Terminar turno'));
    await tester.tap(find.text('Terminar turno'));
    await tester.pumpAndSettle();

    final status = store.activeCharacter!.turnStatus;
    expect(status.actionUsed, isFalse);
    expect(status.bonusActionUsed, isFalse);
    expect(status.reactionUsed, isFalse);
    expect(status.movementRemaining, 9);
  });

  testWidgets('condiciones: alta del catálogo, aviso de desventaja y baja', (
    tester,
  ) async {
    final store = await boot();
    store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
    await pumpHud(tester, store);

    await scrollTo(tester, find.text('Condiciones'));
    expect(find.text('Sin condiciones activas.'), findsOneWidget);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar condición'), findsOneWidget);

    await tester.tap(find.text('Envenenado'));
    await tester.pumpAndSettle();

    expect(store.activeCharacter!.activeConditions, ['Envenenado']);
    expect(find.text('Envenenado'), findsOneWidget);
    expect(
      find.textContaining('Desventaja en tiradas de ataque'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Quitar Envenenado'));
    await tester.pumpAndSettle();

    expect(store.activeCharacter!.activeConditions, isEmpty);
    expect(find.text('Sin condiciones activas.'), findsOneWidget);
    expect(
      find.textContaining('Desventaja en tiradas de ataque'),
      findsNothing,
    );
  });

  testWidgets('acepta una condición casera fuera del catálogo', (tester) async {
    final store = await boot();
    store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
    await pumpHud(tester, store);

    await scrollTo(tester, find.text('Condiciones'));
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Bendecido por la luna');
    await tester.tap(find.byTooltip('Agregar condición personalizada'));
    await tester.pumpAndSettle();

    expect(store.activeCharacter!.activeConditions, ['Bendecido por la luna']);
    expect(find.text('Bendecido por la luna'), findsOneWidget);
    // Fuera del catálogo: no aporta el aviso de desventaja.
    expect(
      find.textContaining('Desventaja en tiradas de ataque'),
      findsNothing,
    );
  });

  testWidgets('recursos y ranuras se gastan y se recuperan de a uno', (
    tester,
  ) async {
    final store = await boot();
    store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
    await pumpHud(tester, store);

    await scrollTo(tester, find.text('Recursos'));
    expect(find.text('Furia'), findsOneWidget);
    expect(find.text('2 de 3 usos'), findsOneWidget);

    await tester.tap(find.byTooltip('Gastar un punto de Furia'));
    await tester.pumpAndSettle();
    expect(store.activeCharacter!.resources.single.current, 1);

    await tester.tap(find.byTooltip('Recuperar un punto de Furia'));
    await tester.pumpAndSettle();
    expect(store.activeCharacter!.resources.single.current, 2);

    await tester.tap(find.byTooltip('Recargar recursos'));
    await tester.pumpAndSettle();
    expect(store.activeCharacter!.resources.single.current, 3);

    await scrollTo(tester, find.text('Ranuras de conjuro'));
    await tester.tap(find.byTooltip('Gastar ranura de nivel 1'));
    await tester.pumpAndSettle();
    expect(store.activeCharacter!.spellSlots.slots.single.current, 3);

    await tester.tap(find.byTooltip('Recuperar ranura de nivel 1'));
    await tester.pumpAndSettle();
    expect(store.activeCharacter!.spellSlots.slots.single.current, 4);

    await tester.tap(find.byTooltip('Recargar ranuras'));
    await tester.pumpAndSettle();
    expect(store.activeCharacter!.spellSlots.slots.single.current, 4);
  });

  testWidgets('descanso corto gasta dados de golpe', (tester) async {
    final store = await boot();
    store.addCharacter(buildCharacter(id: 'char_rook', name: 'Rook'));
    await pumpHud(tester, store);

    await scrollTo(tester, find.text('Descanso corto'));
    expect(find.textContaining('Gastá dados de golpe (5/5)'), findsOneWidget);

    await tester.tap(find.text('Descanso corto'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Descanso corto'),
      ),
      findsOneWidget,
    );
    expect(find.text('Dados de golpe a gastar'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Descansar'));
    await tester.pumpAndSettle();

    expect(store.activeCharacter!.basicInfo.hitDiceCurrent, 4);
    expect(find.textContaining('Gastá dados de golpe (4/5)'), findsOneWidget);
  });

  testWidgets('descanso largo restaura vida, ranuras y dados de golpe', (
    tester,
  ) async {
    final store = await boot();
    store.addCharacter(
      buildCharacter(
        id: 'char_rook',
        name: 'Rook',
        hpCurrent: 4,
        slotCurrent: 0,
        hitDiceCurrent: 2,
      ),
    );
    await pumpHud(tester, store);

    await scrollTo(tester, find.text('Descanso largo'));
    await tester.tap(find.text('Descanso largo'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descanso largo?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Descansar'));
    await tester.pumpAndSettle();

    final character = store.activeCharacter!;
    expect(character.basicInfo.currentHp, 20);
    expect(character.spellSlots.slots.single.current, 4);
    expect(character.basicInfo.hitDiceCurrent, 5);

    // Volver arriba para ver el estado de vida ya actualizado.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('Ileso'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('descanso personalizado aplica solo lo marcado', (tester) async {
    final store = await boot();
    store.addCharacter(
      buildCharacter(
        id: 'char_rook',
        name: 'Rook',
        hpCurrent: 4,
        slotCurrent: 0,
        weaponChargesCurrent: 0,
      ),
    );
    await pumpHud(tester, store);

    await scrollTo(tester, find.text('Descanso personalizado'));
    await tester.tap(find.text('Descanso personalizado'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Descanso personalizado'),
      ),
      findsOneWidget,
    );

    // Solo vida: ranuras y cargas quedan como estaban.
    await tester.tap(find.text('Vida al máximo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pumpAndSettle();

    var character = store.activeCharacter!;
    expect(character.basicInfo.currentHp, 20);
    expect(character.spellSlots.slots.single.current, 0);
    expect(character.inventory.weapons.single.magicCharges.current, 0);

    // Segunda pasada: ranuras y cargas.
    await scrollTo(tester, find.text('Descanso personalizado'));
    await tester.tap(find.text('Descanso personalizado'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Ranuras de conjuro'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Cargas de armas y habilidades'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pumpAndSettle();

    character = store.activeCharacter!;
    expect(character.spellSlots.slots.single.current, 4);
    expect(character.inventory.weapons.single.magicCharges.current, 3);
  });
}
