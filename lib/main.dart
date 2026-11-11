// Punto de entrada único de EasyDnD.
//
// Rework (rama `rework`): el bootstrap es a propósito lo más chico
// posible. Cualquier inicialización que crezca (plugins, crash
// reporting, orientación) vive en la capa que la necesita, no acá,
// para que este archivo no vuelva a engordar nunca.
//
// Lo único que hace además de runApp: construir el CharacterStore con
// su repositorio y cargarlo ANTES de pintar. Así ninguna pantalla ve un
// roster a medio cargar (la migración del roster viejo también corre
// acá, una sola vez por arranque).

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/easydnd_app.dart';
import 'data/roster_repository.dart';
import 'state/character_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final store = CharacterStore(RosterRepository(prefs));
  await store.init();

  runApp(EasyDnDApp(store: store));
}
