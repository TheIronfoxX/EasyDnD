import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/theme_notifier.dart';
import 'theme/app_theme_extension.dart';
import 'providers/character_provider.dart';
import 'services/websocket_service.dart';
import 'screens/main_hud_screen.dart';
import 'screens/welcome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EasyDnDApp());
}

class EasyDnDApp extends StatelessWidget {
  const EasyDnDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => CharacterProvider()),
        ChangeNotifierProvider(create: (_) => WebSocketService()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, _) {
          return MaterialApp(
            title: 'EasyDnD',
            debugShowCheckedModeBanner: false,
            theme: themeNotifier.themeData,
            home: const AppStartupGate(),
          );
        },
      ),
    );
  }
}

class AppStartupGate extends StatefulWidget {
  const AppStartupGate({super.key});

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final themeNotifier = context.read<ThemeNotifier>();
    final characterProvider = context.read<CharacterProvider>();
    final webSocketService = context.read<WebSocketService>();

    // Activa el escuchador de ciclo de vida (foreground/background) para
    // que reconecte solo al volver a primer plano, aunque la pantalla se
    // haya apagado o la app haya pasado a background esperando el turno.
    webSocketService.startObservingLifecycle();

    await Future.wait([
      themeNotifier.init(),
      characterProvider.init(),
    ]);

    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      final accent = context.watch<ThemeNotifier>().accentColor;
      return Scaffold(
        backgroundColor: context.appColors.background,
        body: SafeArea( // <-- ESTE ES EL ESCUDO TÁCTICO
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: accent),
                const SizedBox(height: 16),
                Text(
                  'Recuperando tu ficha...',
                  style: TextStyle(color: accent, fontFamily: 'serif', fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final characterProvider = context.watch<CharacterProvider>();

    if (characterProvider.roster.isEmpty) {
      return const WelcomeScreen();
    }

    return MainHudScreen();
  }
}