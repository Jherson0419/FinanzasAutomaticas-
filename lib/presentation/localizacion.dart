import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Idioma de la app (Fase 89).
///
/// Solo afecta a los widgets del FRAMEWORK: selectores de fecha y hora,
/// menús del sistema, textos de accesibilidad ("Atrás", "Cerrar"…). Los
/// montos y las fechas propias de Finzo siguen con sus formatos de siempre
/// (`shared/formatters.dart`), y el dominio sigue sin depender de Flutter.
const localeApp = Locale('es');

/// Español genérico y de Perú (el país de la app); el framework usa 'es'
/// para ambos.
const localesSoportados = [Locale('es'), Locale('es', 'PE')];

const delegadosDeLocalizacion = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Carga los datos de fecha de `intl` en español (nombres de meses y días
/// para `DateFormat`). Se llama una vez al arrancar, en `main.dart` y
/// `main_local.dart`. No cambia `Intl.defaultLocale`.
Future<void> inicializarIdioma() => initializeDateFormatting('es');
