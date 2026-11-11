// Punto de entrada único de EasyDnD.
//
// Rework (rama `rework`): el bootstrap es a propósito lo más chico
// posible. Cualquier inicialización que crezca (plugins, crash
// reporting, orientación) vive en la capa que la necesita, no acá,
// para que este archivo no vuelva a engordar nunca.

import 'package:flutter/material.dart';

import 'app/easydnd_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EasyDnDApp());
}
