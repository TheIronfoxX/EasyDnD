// Pantalla dedicada que sigue a la ficha activa.
//
// Los modelos se mutan en el sitio y el store avisa con notifyListeners;
// una pantalla empujada con Navigator no está debajo del shell, así que
// necesita escuchar el store por su cuenta para repintarse. Si la ficha
// desaparece (se borró), la pantalla se cierra sola.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/clean_kit.dart';
import '../../domain/models/character.dart';
import '../../core/theme/design_tokens.dart';
import '../../state/character_store.dart';
import 'hud_status_tab.dart';

class ActiveCharacterPage extends StatelessWidget {
  const ActiveCharacterPage({
    super.key,
    required this.title,
    required this.builder,
    this.scrollable = true,
    this.floatingActionButton,
  });

  final String title;

  /// Contenido de la pantalla para la ficha activa.
  final List<Widget> Function(BuildContext context, CharacterModel character)
  builder;

  /// false = el contenido ya trae su propio scroll (se usa el primer
  /// widget que devuelve [builder] como cuerpo entero).
  final bool scrollable;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final character = context.watch<CharacterStore>().activeCharacter;
    if (character == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold();
    }
    final children = builder(context, character);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: floatingActionButton,
      body: scrollable
          ? CleanList(children: children)
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kCleanMaxWidth),
                child: children.first,
              ),
            ),
    );
  }
}

/// Abre una [ActiveCharacterPage].
Future<void> pushCharacterPage(
  BuildContext context, {
  required String title,
  required List<Widget> Function(BuildContext, CharacterModel) builder,
  bool scrollable = true,
}) => pushPage<void>(
  context,
  ActiveCharacterPage(title: title, builder: builder, scrollable: scrollable),
);

/// Hoja de Vida (daño, curación, PG temporales). Se abre desde la píldora
/// de la barra superior y desde la tarjeta de vida de Combate.
void showLifeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Consumer<CharacterStore>(
      builder: (context, store, _) {
        final c = store.activeCharacter;
        if (c == null) return const SizedBox(height: 120);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: HudHealthSection(character: c),
        );
      },
    ),
  );
}
