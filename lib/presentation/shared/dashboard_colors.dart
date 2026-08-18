import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// La app está fija en modo oscuro desde la Fase 19 (`ThemeMode.dark`), así
/// que estas funciones ya no necesitan ramificar por `Brightness` — siempre
/// devuelven los tokens semánticos de `app_theme.dart`. Se mantiene la firma
/// `Function(BuildContext)` para no tocar cada sitio donde se llaman.
Color colorIngreso(BuildContext context) => colorSuccess;

Color colorGasto(BuildContext context) => colorDanger;
