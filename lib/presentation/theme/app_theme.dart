import 'package:flutter/material.dart';

/// Sistema de diseño propio de la app (Fase 19): paleta fija en modo oscuro,
/// pensada para transmitir confianza financiera. Reemplaza el
/// `ColorScheme.fromSeed` genérico usado hasta la Fase 18 — la app ya no
/// sigue el tema del sistema (ver `themeMode: ThemeMode.dark` en `app.dart`).
///
/// Todo el resto de la app sigue leyendo colores vía
/// `Theme.of(context).colorScheme` (convención desde la Fase 5), así que
/// estos tokens se mapean a roles estándar de Material en [appTheme] en vez
/// de usarse sueltos en los widgets.
const bgPage = Color(0xFF0D1210);
const bgCard = Color(0xFF161C19);
const borderCard = Color(0xFF26302B);
const textPrimary = Color(0xFFF4F6F4);
const textSecondary = Color(0xFF8A9690);
const textMuted = Color(0xFF5C6862);
const colorSuccess = Color(0xFF5DCAA5);
const colorDanger = Color(0xFFF09595);
const colorWarning = Color(0xFFFAC775);

/// Estilo de las etiquetas de sección en mayúsculas ("SALDO TOTAL",
/// "INGRESOS"). El texto se pasa por `.toUpperCase()` en el widget que lo
/// use — este `TextStyle` solo define tipografía/color.
const sectionLabelTextStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.06,
  color: textMuted,
);

/// `ColorScheme.dark(...)` en vez de `ColorScheme.fromSeed(...)` porque
/// necesitamos que los roles caigan exactamente en los hex aprobados, no en
/// tonos derivados automáticamente. `primary` es `colorSuccess` (verde) y no
/// un "morado de marca": no existe tal token en la paleta aprobada, y el
/// verde conecta con el ícono de confianza de la Fase 19.5.
final _colorScheme = ColorScheme.dark(
  surface: bgCard,
  onSurface: textPrimary,
  onSurfaceVariant: textSecondary,
  surfaceContainerHigh: bgCard,
  surfaceContainerHighest: borderCard,
  outline: textMuted,
  outlineVariant: borderCard,
  primary: colorSuccess,
  onPrimary: bgPage,
  primaryContainer: colorSuccess.withValues(alpha: 0.18),
  onPrimaryContainer: colorSuccess,
  secondary: colorSuccess,
  onSecondary: bgPage,
  secondaryContainer: borderCard,
  onSecondaryContainer: textPrimary,
  error: colorDanger,
  onError: bgPage,
  errorContainer: colorDanger.withValues(alpha: 0.15),
  onErrorContainer: colorDanger,
);

ThemeData appTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: _colorScheme,
    // Rol conceptual "background → bgPage" del prompt: `ColorScheme` ya no
    // trae los campos `background`/`onBackground` (deprecados), así que el
    // fondo de página se fija directamente aquí en vez de en el scheme.
    scaffoldBackgroundColor: bgPage,
    appBarTheme: const AppBarTheme(
      backgroundColor: bgPage,
      foregroundColor: textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderCard, width: 0.5),
      ),
    ),
  );
}
