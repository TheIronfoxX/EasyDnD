// Ajustes → Tema: los cuatro mandos (claro/oscuro, forma, color principal y
// secundario) cambian el SkinController y sobreviven a reiniciar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/core/theme/accent_presets.dart';
import 'package:easydnd/core/theme/clean_theme.dart';
import 'package:easydnd/data/roster_repository.dart';
import 'package:easydnd/features/hud/settings_screen.dart';
import 'package:easydnd/state/character_store.dart';
import 'package:easydnd/state/skin_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SkinController> bootSkin() async {
    final prefs = await SharedPreferences.getInstance();
    final skin = SkinController(prefs);
    await skin.init();
    return skin;
  }

  Future<SkinController> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final store = CharacterStore(RosterRepository(prefs));
    await store.init();
    final skin = await bootSkin();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CharacterStore>.value(value: store),
          ChangeNotifierProvider<SkinController>.value(value: skin),
        ],
        child: MaterialApp(
          theme: skin.lightTheme,
          darkTheme: skin.darkTheme,
          themeMode: skin.themeMode,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return skin;
  }

  testWidgets('modo claro/oscuro', (tester) async {
    final skin = await pumpSettings(tester);
    final initial = skin.isDarkMode;

    await tester.tap(find.text(initial ? 'Claro' : 'Oscuro'));
    await tester.pumpAndSettle();

    expect(skin.isDarkMode, !initial);
  });

  testWidgets('forma: elegir otra silueta', (tester) async {
    final skin = await pumpSettings(tester);
    final other = CleanThemeStyle.values.firstWhere(
      (s) => s != skin.themeStyle,
    );

    await skin.setThemeStyle(other);
    await tester.pumpAndSettle();

    expect(skin.themeStyle, other);
  });

  testWidgets('color principal: un preset lo fija', (tester) async {
    final skin = await pumpSettings(tester);
    final preset = AccentPresets.all.firstWhere(
      (p) => p.color != skin.accentColor,
    );

    final swatch = find.byKey(ValueKey('accent-${preset.label}'));
    await tester.ensureVisible(swatch);
    await tester.tap(swatch);
    await tester.pumpAndSettle();

    expect(skin.accentColor, preset.color);
  });

  testWidgets('color secundario: sugerido y vuelta a automático', (
    tester,
  ) async {
    final skin = await pumpSettings(tester);
    expect(skin.hasCustomSecondary, isFalse);

    final rec = skin.secondaryRecommendations[1];
    final swatch = find.byKey(ValueKey('secondary-${rec.label}'));
    await tester.ensureVisible(swatch);
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    expect(skin.hasCustomSecondary, isTrue);
    expect(skin.secondaryColor, rec.color);

    final auto = find.byKey(const ValueKey('secondary-auto'));
    await tester.ensureVisible(auto);
    await tester.tap(auto);
    await tester.pumpAndSettle();
    expect(skin.hasCustomSecondary, isFalse);
  });

  testWidgets('los cambios sobreviven a reiniciar', (tester) async {
    final skin = await pumpSettings(tester);
    final preset = AccentPresets.all.firstWhere(
      (p) => p.color != skin.accentColor,
    );
    await skin.setAccentColor(preset.color);
    await skin.setDarkMode(!skin.isDarkMode);
    final dark = skin.isDarkMode;

    final reloaded = await bootSkin();
    expect(reloaded.accentColor, preset.color);
    expect(reloaded.isDarkMode, dark);
  });
}
