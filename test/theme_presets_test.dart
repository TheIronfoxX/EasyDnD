// Sistema multi-tema (rework estético): catálogo de diecinueve temas,
// TacticalThemeTokens, persistencia y contrato con el modo claro/oscuro.
//
// El contrato que se verifica acá: hay dos temas claros (Pergamino por
// defecto y Marfil y Azur) y diez oscuros, y el toggle de siempre alterna
// entre el último tema claro y el último oscuro elegidos.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easydnd/core/theme/app_fonts.dart';
import 'package:easydnd/core/theme/app_palette.dart';
import 'package:easydnd/core/theme/app_theme.dart';
import 'package:easydnd/core/theme/app_theme_colors.dart';
import 'package:easydnd/core/theme/font_presets.dart';
import 'package:easydnd/core/theme/tactical_theme_tokens.dart';
import 'package:easydnd/core/theme/theme_presets.dart';
import 'package:easydnd/core/theme/theme_style_tokens.dart';
import 'package:easydnd/core/ui/pip_shape.dart';
import 'package:easydnd/core/ui/stat_dial.dart';
import 'package:easydnd/core/ui/tactical_background.dart';
import 'package:easydnd/core/ui/tactical_card.dart';
import 'package:easydnd/state/skin_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Controlador nuevo sobre el mismo almacenamiento: "reiniciar la app".
  Future<SkinController> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final skin = SkinController(prefs);
    await skin.init();
    return skin;
  }

  group('catálogo', () {
    test(
      'son veintitrés temas con id único: cuatro claros y diecinueve oscuros',
      () {
        expect(AppThemePreset.values, hasLength(23));
        expect(
          AppThemePreset.values.map((p) => p.id).toSet(),
          hasLength(AppThemePreset.values.length),
        );
        expect(AppThemePreset.values.where((p) => !p.isDark), [
          AppThemePreset.pergamino,
          AppThemePreset.marfilAzur,
          AppThemePreset.zooPastel,
          AppThemePreset.sedaCarmesi,
        ]);
        expect(AppThemePreset.values.map((p) => p.id), [
          'grimorio',
          'pergamino',
          'velo_astral',
          'forja_arcana',
          'sangre_y_hierro',
          'senda_silvestre',
          'escarcha',
          'necropolis',
          'dragon_dorado',
          'mar_profundo',
          'mazmorra',
          'marfil_azur',
          'ruido_perdido',
          'zoo_pastel',
          'borahae',
          'mandarina',
          'fuego_kitsune',
          'seda_carmesi',
          'panda_blindado',
          'eclipse_sombrio',
          'rito_carmesi',
          'cresta_forja',
          'filigrana_maldita',
        ]);
        expect(AppThemePreset.defaultDark, AppThemePreset.grimorio);
        expect(AppThemePreset.defaultLight, AppThemePreset.pergamino);
      },
    );

    test('Grimorio y Pergamino son las paletas oscura y clara de fábrica', () {
      expect(AppThemePreset.grimorio.palette, AppPalette.dark);
      expect(AppThemePreset.grimorio.accent, AppTheme.goldAccent);
      expect(AppThemePreset.pergamino.palette, AppPalette.light);
    });

    test(
      'cada tema arma un ThemeData con su paleta y su TacticalThemeTokens',
      () {
        for (final preset in AppThemePreset.values) {
          final theme = AppTheme.build(preset: preset);
          final colors = theme.extension<AppThemeColors>()!;
          final tactical = theme.extension<TacticalThemeTokens>()!;

          expect(theme.brightness, preset.brightness, reason: preset.id);
          expect(theme.scaffoldBackgroundColor, preset.palette.background);
          expect(theme.colorScheme.primary, preset.accent);
          expect(colors.surface, preset.palette.surface);
          expect(tactical, same(preset.tactical));
          expect(tactical.primary, preset.accent);

          // Los cinco roles de juego se distinguen entre sí dentro del tema.
          final roles = {
            tactical.weapon,
            tactical.spell,
            tactical.ability,
            tactical.heal,
            tactical.damage,
          };
          expect(roles, hasLength(5), reason: preset.id);
        }
      },
    );

    test('alto contraste: tinta y roles legibles sobre la superficie', () {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance();
        final lb = b.computeLuminance();
        final hi = la > lb ? la : lb;
        final lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final preset in AppThemePreset.values) {
        final surface = preset.palette.surface;
        final t = preset.tactical;
        expect(
          contrast(preset.palette.textPrimary, surface),
          greaterThan(7),
          reason: '${preset.id}: textPrimary',
        );
        expect(
          contrast(preset.palette.textSecondary, surface),
          greaterThan(4.5),
          reason: '${preset.id}: textSecondary',
        );
        for (final role in [
          preset.accent,
          t.weapon,
          t.spell,
          t.ability,
          t.heal,
          t.damage,
        ]) {
          expect(
            contrast(role, surface),
            greaterThan(4),
            reason: '${preset.id}: $role',
          );
        }
      }
    });

    test('TacticalThemeTokens interpola y copia como ThemeExtension', () {
      final a = AppThemePreset.grimorio.tactical;
      final b = AppThemePreset.forjaArcana.tactical;

      expect(a.lerp(b, 0).spell, a.spell);
      expect(a.lerp(b, 1).spell, b.spell);
      expect(a.lerp(b, 0.5).spell, Color.lerp(a.spell, b.spell, 0.5));
      expect(a.lerp(null, 0.5), same(a));
      expect(a.copyWith(heal: b.heal).heal, b.heal);
      expect(a.copyWith(heal: b.heal).weapon, a.weapon);
      expect(a.headerGradient.colors, [a.headerStart, a.headerEnd]);
    });

    test('byId resuelve ids conocidos y devuelve null con el resto', () {
      expect(AppThemePreset.byId('forja_arcana'), AppThemePreset.forjaArcana);
      expect(AppThemePreset.byId('no-existe'), isNull);
      expect(AppThemePreset.byId(null), isNull);
    });
  });

  group('geometría y atmósfera', () {
    OutlinedBorder card(AppThemePreset p) => p.tactical.cardShape;

    test('cada skin tiene su forma de tarjeta y de botón', () {
      const radius10 = BorderRadius.all(Radius.circular(10));
      final grimorio = AppThemePreset.grimorio.tactical;
      expect(grimorio.cardShape, isA<RoundedRectangleBorder>());
      expect(
        (grimorio.cardShape as RoundedRectangleBorder).borderRadius,
        radius10,
      );

      expect(
        (card(AppThemePreset.pergamino) as RoundedRectangleBorder).borderRadius,
        const BorderRadius.all(Radius.circular(4)),
      );

      // Velo Astral: cristal tallado asimétrico, en tarjetas y botones.
      const crystal = BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(4),
      );
      final astral = AppThemePreset.veloAstral.tactical;
      expect(
        (astral.cardShape as RoundedRectangleBorder).borderRadius,
        crystal,
      );
      expect(
        (astral.buttonShape as RoundedRectangleBorder).borderRadius,
        crystal,
      );

      // Forja Arcana: biseles.
      final forge = AppThemePreset.forjaArcana.tactical;
      expect(forge.cardShape, isA<BeveledRectangleBorder>());
      expect(forge.buttonShape, isA<BeveledRectangleBorder>());

      // Sangre y Hierro: bisel grande y borde grueso.
      final blood = AppThemePreset.sangreYHierro.tactical;
      expect(blood.cardShape, isA<BeveledRectangleBorder>());
      expect(blood.borderWidth, 2.2);
      expect(blood.shadowStyle, ShadowStyle.hardMartial);

      // Senda Silvestre: píldora y tarjetas superelipse.
      final wild = AppThemePreset.sendaSilvestre.tactical;
      expect(wild.buttonShape, isA<StadiumBorder>());
      expect(wild.cardShape, isA<ContinuousRectangleBorder>());

      // Mazmorra: esquinas rectas y borde de piedra.
      final dungeon = AppThemePreset.mazmorra.tactical;
      expect(
        (dungeon.cardShape as RoundedRectangleBorder).borderRadius,
        BorderRadius.zero,
      );
      expect(dungeon.borderWidth, 2.4);
    });

    test('fondos y pips: uno distinto por skin', () {
      expect({
        for (final p in AppThemePreset.values) p.tactical.backgroundPattern,
      }, hasLength(23));
      expect(
        [for (final p in AppThemePreset.values) p.tactical.pipShape],
        [
          PipShape.circle,
          PipShape.circle,
          PipShape.star,
          PipShape.diamond,
          PipShape.square,
          PipShape.leaf,
          PipShape.diamond,
          PipShape.circle,
          PipShape.star,
          PipShape.circle,
          PipShape.square,
          PipShape.diamond,
          PipShape.bolt,
          PipShape.paw,
          PipShape.heart,
          PipShape.leaf,
          PipShape.flame,
          PipShape.star,
          PipShape.star,
          PipShape.diamond,
          PipShape.circle,
          PipShape.diamond,
          PipShape.diamond,
        ],
      );
    });

    test('los temas de botones, chips y tipografía siguen a la skin', () {
      for (final preset in AppThemePreset.values) {
        final theme = AppTheme.build(preset: preset);
        final shape = preset.tactical.buttonShape;

        for (final button in [
          theme.filledButtonTheme.style,
          theme.elevatedButtonTheme.style,
          theme.outlinedButtonTheme.style,
        ]) {
          final resolved = button!.shape!.resolve({});
          expect(
            resolved.runtimeType,
            shape.runtimeType,
            reason: '${preset.id}: botón',
          );
        }
        expect(theme.chipTheme.shape.runtimeType, shape.runtimeType);
        expect(
          theme.outlinedButtonTheme.style!.side!.resolve({})!.width,
          preset.tactical.borderWidth,
        );
        expect(
          theme.textTheme.titleLarge?.letterSpacing,
          preset.tactical.headerFont.letterSpacing,
        );
      }
      // Cabeceras sans en Forja y Sangre; serif en el resto (preset Diario).
      expect(
        AppTheme.build(
          preset: AppThemePreset.forjaArcana,
        ).textTheme.titleLarge?.fontFamily,
        AppFonts.inter,
      );
      expect(
        AppTheme.build(
          preset: AppThemePreset.veloAstral,
        ).textTheme.titleLarge?.fontFamily,
        AppFonts.cinzel,
      );
    });

    test('pipPath devuelve un contorno no vacío para cada forma', () {
      for (final shape in PipShape.values) {
        final bounds = pipPath(shape, 10).getBounds();
        expect(bounds.isEmpty, isFalse, reason: '$shape');
        expect(bounds.width, lessThanOrEqualTo(10.01));
        expect(bounds.height, lessThanOrEqualTo(10.01));
      }
    });

    testWidgets('el fondo atmosférico es estático y no bloquea el settle', (
      tester,
    ) async {
      for (final preset in AppThemePreset.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build(preset: preset),
            home: const Scaffold(
              body: TacticalScaffoldBackground(child: Text('contenido')),
            ),
          ),
        );
        // Si hubiera animación infinita esto agotaría el tiempo.
        await tester.pumpAndSettle();
        expect(find.text('contenido'), findsOneWidget, reason: preset.id);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('TacticalCard y ResourcePips adoptan la skin activa', (
      tester,
    ) async {
      for (final preset in AppThemePreset.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build(preset: preset),
            home: const Scaffold(
              body: Column(
                children: [
                  TacticalCard(child: Text('carta')),
                  ResourcePips(current: 2, max: 3),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = tester.widget<AnimatedContainer>(
          find.ancestor(
            of: find.text('carta'),
            matching: find.byType(AnimatedContainer),
          ),
        );
        final decoration = container.decoration! as ShapeDecoration;
        final side = (decoration.shape as OutlinedBorder).side;
        expect(
          decoration.shape.runtimeType,
          preset.tactical.cardShape.runtimeType,
          reason: preset.id,
        );
        expect(side.width, preset.tactical.borderWidth, reason: preset.id);
        expect(find.byType(PipGlyph), findsNWidgets(3), reason: preset.id);
      }
    });
  });

  group('Contraste entre temas (fase 2)', () {
    test('las formas de tarjeta son de varias familias', () {
      final kinds = {
        for (final p in AppThemePreset.values) p.tactical.cardShape.runtimeType,
      };
      expect(
        kinds,
        containsAll([
          RoundedRectangleBorder,
          BeveledRectangleBorder,
          ContinuousRectangleBorder,
        ]),
      );
    });

    test('los estilos de cabecera, botón y barra están todos en uso', () {
      final all = AppThemePreset.values.map((p) => p.tactical.components);
      expect(all.map((c) => c.header).toSet(), HeaderStyle.values.toSet());
      expect(all.map((c) => c.button).toSet(), ButtonStyleKind.values.toSet());
      expect(all.map((c) => c.bar).toSet(), BarStyle.values.toSet());
    });

    test('cada tema trae una fuente de firma válida y variada', () {
      final ids = {for (final p in AppThemePreset.values) p.fontPresetId};
      for (final p in AppThemePreset.values) {
        expect(
          FontPresets.all.map((f) => f.id),
          contains(p.fontPresetId),
          reason: p.id,
        );
      }
      expect(ids.length, greaterThanOrEqualTo(4));
    });

    test('el fondo de Mazmorra es el más marcado', () {
      final intensity = {
        for (final p in AppThemePreset.values)
          p: p.tactical.background.patternOpacity,
      };
      final max = intensity.values.reduce((a, b) => a > b ? a : b);
      expect(intensity[AppThemePreset.mazmorra], max);
    });

    test('Stray Kids y BTS: tres temas nuevos reconocibles', () {
      const noise = AppThemePreset.ruidoPerdido;
      expect(noise.isDark, isTrue);
      expect(noise.tactical.cardShape, isA<BeveledRectangleBorder>());
      expect(noise.tactical.shadowStyle, ShadowStyle.hudGlow);
      expect(
        noise.tactical.backgroundPattern,
        BackgroundPatternStyle.glitchNoise,
      );
      expect(noise.fontPresetId, 'consola');
      expect(noise.label, 'Señal Rota');
      expect(noise.tagline, isNot(contains('Stray Kids')));

      const zoo = AppThemePreset.zooPastel;
      expect(zoo.isDark, isFalse);
      expect(zoo.tactical.cardShape, isA<ContinuousRectangleBorder>());
      expect(zoo.tactical.pipShape, PipShape.paw);
      expect(zoo.fontPresetId, 'cuento');
      expect(zoo.tagline, contains('SKZOO'));

      const bts = AppThemePreset.borahae;
      expect(bts.isDark, isTrue);
      expect(bts.tactical.pipShape, PipShape.heart);
      expect(
        bts.tactical.backgroundPattern,
        BackgroundPatternStyle.purpleOcean,
      );
      expect(bts.tagline, contains('BTS'));
      // Se separa de Velo Astral: otro fondo y otro color principal.
      const velo = AppThemePreset.veloAstral;
      expect(bts.palette.background, isNot(velo.palette.background));
      expect(bts.tactical.primary, isNot(velo.tactical.primary));
    });

    test('Minsung: oscuro, naranja y verde hoja', () {
      const m = AppThemePreset.mandarina;
      expect(m.label, 'Minsung');
      expect(m.isDark, isTrue);
      expect(m.tactical.backgroundPattern, BackgroundPatternStyle.citrusGrove);
      // Naranja como acento y verde en superficies y bordes.
      expect(m.tactical.primary.r, greaterThan(m.tactical.primary.b));
      expect(
        m.palette.surfaceElevated.g,
        greaterThan(m.palette.surfaceElevated.b),
      );
      expect(m.tactical.metalBorder.g, greaterThan(m.tactical.metalBorder.b));
    });

    testWidgets('los fondos nuevos se pintan a tamaño móvil y tablet', (
      tester,
    ) async {
      for (final preset in [
        AppThemePreset.ruidoPerdido,
        AppThemePreset.zooPastel,
        AppThemePreset.borahae,
        AppThemePreset.mandarina,
      ]) {
        for (final size in const [Size(360, 640), Size(1200, 800)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.build(preset: preset),
              home: const Scaffold(
                body: TacticalScaffoldBackground(child: SizedBox.expand()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${preset.id} $size');
        }
      }
    });

    testWidgets('SectionHeader y TacticalCard se pintan en cada tema', (
      tester,
    ) async {
      for (final preset in AppThemePreset.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build(preset: preset),
            home: const Scaffold(
              body: Column(
                children: [
                  SectionHeader(title: 'Titulo', icon: Icons.add),
                  TacticalCard(child: Text('carta')),
                  VitalBar(value: 0.6, color: Colors.red),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Titulo'), findsOneWidget, reason: preset.id);
        expect(tester.takeException(), isNull, reason: preset.id);
      }
    });
  });

  group('SkinController', () {
    test('arranca en Grimorio', () async {
      final skin = await boot();
      expect(skin.themePreset, AppThemePreset.grimorio);
      expect(skin.isDarkMode, isTrue);
      expect(skin.hasCustomAccent, isFalse);
    });

    test('elegir un tema aplica su fuente de firma y se persiste', () async {
      final skin = await boot();
      await skin.setThemePreset(AppThemePreset.sendaSilvestre);
      expect(skin.fontPreset.id, AppThemePreset.sendaSilvestre.fontPresetId);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(SkinController.fontKey),
        AppThemePreset.sendaSilvestre.fontPresetId,
      );
    });

    test(
      'la fuente elegida después manda y el toggle claro/oscuro no la toca',
      () async {
        final skin = await boot();
        await skin.setThemePreset(AppThemePreset.mazmorra);
        await skin.setFontPreset(FontPresets.table);
        await skin.toggleThemeMode();
        await skin.toggleThemeMode();
        expect(skin.fontPreset, FontPresets.table);
      },
    );

    test('cada tema elegido sobrevive al reinicio', () async {
      for (final preset in AppThemePreset.values) {
        final first = await boot();
        await first.setThemePreset(preset);

        final second = await boot();
        expect(second.themePreset, preset, reason: preset.id);
        expect(second.themeData.brightness, preset.brightness);
      }
    });

    test('un segundo tema claro se recuerda y el toggle vuelve a él', () async {
      final skin = await boot();
      await skin.setThemePreset(AppThemePreset.escarcha);
      await skin.setThemePreset(AppThemePreset.marfilAzur);

      expect(skin.isDarkMode, isFalse);
      expect(skin.lightPreset, AppThemePreset.marfilAzur);
      expect(skin.darkPreset, AppThemePreset.escarcha);

      await skin.toggleThemeMode();
      expect(skin.themePreset, AppThemePreset.escarcha);
      await skin.toggleThemeMode();
      expect(skin.themePreset, AppThemePreset.marfilAzur);

      final restarted = await boot();
      expect(restarted.themePreset, AppThemePreset.marfilAzur);
      expect(restarted.darkPreset, AppThemePreset.escarcha);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(SkinController.lightThemeKey),
        AppThemePreset.marfilAzur.id,
      );
    });

    test('elegir Pergamino equivale a pasar a modo claro', () async {
      final skin = await boot();
      await skin.setThemePreset(AppThemePreset.sendaSilvestre);
      await skin.setThemePreset(AppThemePreset.pergamino);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SkinController.darkModeKey), isFalse);
      // Pergamino no pisa el oscuro guardado.
      expect(
        prefs.getString(SkinController.themeKey),
        AppThemePreset.sendaSilvestre.id,
      );
    });

    test('clearCustomAccent vuelve al acento de firma', () async {
      final skin = await boot();
      await skin.setAccentColor(const Color(0xFF7C4DFF));
      await skin.clearCustomAccent();

      expect(skin.accentColor, AppTheme.defaultAccent);
      expect((await boot()).hasCustomAccent, isFalse);
    });

    test('un id de tema desconocido o claro cae a Grimorio', () async {
      SharedPreferences.setMockInitialValues({
        SkinController.themeKey: 'tema-del-futuro',
      });
      expect((await boot()).themePreset, AppThemePreset.grimorio);

      SharedPreferences.setMockInitialValues({
        SkinController.themeKey: AppThemePreset.pergamino.id,
      });
      final skin = await boot();
      expect(skin.isDarkMode, isTrue);
      expect(skin.darkPreset, AppThemePreset.grimorio);
    });

    test('reelegir el tema activo no notifica', () async {
      final skin = await boot();
      await skin.setThemePreset(AppThemePreset.forjaArcana);

      var notifications = 0;
      skin.addListener(() => notifications++);
      await skin.setThemePreset(AppThemePreset.forjaArcana);
      expect(notifications, 0);
    });
  });

  group('Tokens de estilo ampliados', () {
    test('los defaults reproducen el comportamiento previo', () {
      const shapes = ShapeTokens();
      expect(shapes.dialogRadius, 16);
      expect(shapes.inputRadius, 12);
      expect(shapes.tooltipRadius, 8);
      expect(shapes.overlayElevation, 0);
      expect(const MotionTokens().durationScale, 1.0);
      expect(const DensityTokens().scale, 1.0);
      expect(const BackgroundTokens().patternOpacity, 1.0);
      expect(const CardTokens().highlightAlpha, 0.55);
      expect(const IconTokens().style, IconStyle.rounded);
    });

    test('todos los presets definen valores válidos', () {
      for (final p in AppThemePreset.values) {
        final t = p.tactical;
        expect(t.density.scale, inInclusiveRange(0.8, 1.2), reason: p.id);
        expect(
          t.motion.durationScale,
          inInclusiveRange(0.5, 2.0),
          reason: p.id,
        );
        expect(
          t.background.patternOpacity,
          inInclusiveRange(0.0, 2.5),
          reason: p.id,
        );
        expect(t.shapes.dialogRadius, greaterThanOrEqualTo(0), reason: p.id);
        expect(t.cards.highlightAlpha, inInclusiveRange(0.0, 1.0));
      }
    });

    test('los temas difieren de verdad en radios, iconos y ritmo', () {
      final all = AppThemePreset.values.map((p) => p.tactical).toList();
      expect(
        all.map((t) => t.shapes.dialogRadius).toSet().length,
        greaterThan(4),
      );
      expect(all.map((t) => t.icons.style).toSet(), IconStyle.values.toSet());
      expect(all.map((t) => t.icons.diceShape).toSet().length, greaterThan(2));
      expect(
        all.map((t) => t.motion.durationScale).toSet().length,
        greaterThan(4),
      );
    });

    test('lerp interpola numéricos y cambia discretos a mitad', () {
      final a = AppThemePreset.mazmorra.tactical;
      final b = AppThemePreset.marProfundo.tactical;
      final mid = a.lerp(b, 0.5);
      expect(mid.shapes.dialogRadius, closeTo(14, 0.001));
      expect(a.lerp(b, 0.4).icons.style, a.icons.style);
      expect(a.lerp(b, 0.6).icons.style, b.icons.style);
    });

    testWidgets('el ThemeData toma radios y elevación del preset', (t) async {
      final theme = AppTheme.dark(preset: AppThemePreset.mazmorra);
      final shape = theme.dialogTheme.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(0));
      expect(theme.dialogTheme.elevation, 2);
    });
  });
}
