import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Color de TEXTO (y del ícono que lo acompaña) para montos de ingreso,
/// gasto y avisos. Fase 80: resuelven a los tokens accesibles del tema
/// activo (`successText`/`dangerText`/`warningText`) — en oscuro siguen
/// siendo `colorSuccess`/`colorDanger`/`colorWarning`; en claro, tonos
/// oscurecidos que sí llegan a 4.5:1. Para rellenos (barras, fondos) se
/// usan los `colorX` de `app_theme.dart` directamente.
Color colorIngreso(BuildContext context) => context.successText;

Color colorGasto(BuildContext context) => context.dangerText;

Color colorAviso(BuildContext context) => context.warningText;
