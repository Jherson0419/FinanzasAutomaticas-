import 'package:flutter/material.dart';

/// Sistema de diseño propio de la app (Fase 19, claro/oscuro elegible desde
/// la Fase 31): antes (Fase 19) la app estaba fija en modo oscuro
/// permanente; ahora `MaterialApp.themeMode` sigue la preferencia guardada
/// en `PreferenciasRepository` (ver `presentation/state/providers.dart`,
/// `temaProvider`), con `ThemeMode.system` como opción también disponible.
///
/// Todo el resto de la app sigue leyendo colores vía
/// `Theme.of(context).colorScheme` (convención desde la Fase 5) para todo
/// lo que tiene un rol estándar de Material. Para los tokens propios que no
/// tienen un rol de Material 1:1 (`bgPage`, `bgCard`, `borderCard`,
/// `textPrimary`, `textSecondary`, `textMuted`) — Fase 31: dejaron de ser
/// `Color` fijos porque su valor depende del tema activo; ahora se leen vía
/// la extensión de contexto de más abajo (`context.bgCard`, etc.), nunca
/// como identificador suelto.
///
/// `colorSuccess`/`colorDanger`/`colorWarning` SÍ siguen siendo `Color`
/// fijos de nivel superior: son colores de **estado** (éxito/peligro/aviso),
/// no de fondo — su significado no cambia entre temas claro/oscuro.
const colorSuccess = Color(0xFF5DCAA5);
const colorDanger = Color(0xFFF09595);
const colorWarning = Color(0xFFFAC775);

/// Texto/ícono legible sobre `colorSuccess`/`colorDanger`/`colorWarning`
/// (los tres son tonos claros): un solo tono oscuro fijo, por la misma
/// razón que esos tres colores no cambian entre temas. Reemplaza los usos
/// de `bgPage` como "color de contraste" que había antes de la Fase 31 —
/// ese uso nunca fue realmente "el fondo de la página", coincidía con él
/// solo porque la app siempre estuvo en oscuro.
const colorSobreEstado = Color(0xFF0D1210);

// Paleta oscura (Fase 19).
const _bgPageOscuro = Color(0xFF0D1210);
const _bgCardOscuro = Color(0xFF161C19);
const _borderCardOscuro = Color(0xFF26302B);
const _textPrimaryOscuro = Color(0xFFF4F6F4);
const _textSecondaryOscuro = Color(0xFF8A9690);
const _textMutedOscuro = Color(0xFF5C6862);

// Paleta clara (Fase 31) — mismo criterio tonal (fondo de página apenas más
// gris que las tarjetas, borde sutil, texto casi negro sin ser negro puro),
// espejado a valores claros.
const _bgPageClaro = Color(0xFFF5F7F5);
const _bgCardClaro = Color(0xFFFFFFFF);
const _borderCardClaro = Color(0xFFE1E6E2);
const _textPrimaryClaro = Color(0xFF15201B);
const _textSecondaryClaro = Color(0xFF5B6B63);
const _textMutedClaro = Color(0xFF8A9690);

/// Estilo de las etiquetas de sección en mayúsculas ("SALDO TOTAL",
/// "INGRESOS"). El color se resuelve en tiempo de uso (no aquí, que es
/// `const`) — `SectionLabel` lo aplica con `context.textMuted`.
const sectionLabelTextStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.06,
);

/// Tokens de color propios de la app que no tienen un rol 1:1 en
/// `ColorScheme` — se registran como `ThemeExtension` para que cada uno
/// tenga un valor distinto en el tema claro y en el oscuro sin volverse
/// `Color` globales fijos. Acceso vía la extensión de contexto de abajo.
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  final Color bgPage;
  final Color bgCard;
  final Color borderCard;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const AppColorTokens({
    required this.bgPage,
    required this.bgCard,
    required this.borderCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  static const oscuro = AppColorTokens(
    bgPage: _bgPageOscuro,
    bgCard: _bgCardOscuro,
    borderCard: _borderCardOscuro,
    textPrimary: _textPrimaryOscuro,
    textSecondary: _textSecondaryOscuro,
    textMuted: _textMutedOscuro,
  );

  static const claro = AppColorTokens(
    bgPage: _bgPageClaro,
    bgCard: _bgCardClaro,
    borderCard: _borderCardClaro,
    textPrimary: _textPrimaryClaro,
    textSecondary: _textSecondaryClaro,
    textMuted: _textMutedClaro,
  );

  @override
  AppColorTokens copyWith({
    Color? bgPage,
    Color? bgCard,
    Color? borderCard,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) {
    return AppColorTokens(
      bgPage: bgPage ?? this.bgPage,
      bgCard: bgCard ?? this.bgCard,
      borderCard: borderCard ?? this.borderCard,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) return this;
    return AppColorTokens(
      bgPage: Color.lerp(bgPage, other.bgPage, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      borderCard: Color.lerp(borderCard, other.borderCard, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

/// Acceso ergonómico a [AppColorTokens] del tema activo — `context.bgCard`
/// en vez de `Theme.of(context).extension<AppColorTokens>()!.bgCard` en
/// cada sitio. [appThemeClaro]/[appThemeOscuro] siempre registran la
/// extensión, pero cualquier `Theme`/`MaterialApp` que no pase por esas dos
/// funciones (todo el `MaterialApp` de prueba suelto en `test/`, que no
/// pasa por `presentation/app.dart`) no la tiene — en vez de reventar ahí,
/// se usa `AppColorTokens.oscuro` como respaldo (mismo look que tenía la
/// app antes de la Fase 31).
extension AppColorTokensContext on BuildContext {
  AppColorTokens get _tokens =>
      Theme.of(this).extension<AppColorTokens>() ?? AppColorTokens.oscuro;
  Color get bgPage => _tokens.bgPage;
  Color get bgCard => _tokens.bgCard;
  Color get borderCard => _tokens.borderCard;
  Color get textPrimary => _tokens.textPrimary;
  Color get textSecondary => _tokens.textSecondary;
  Color get textMuted => _tokens.textMuted;
}

/// `ColorScheme.dark(...)`/`ColorScheme.light(...)` en vez de
/// `ColorScheme.fromSeed(...)` porque necesitamos que los roles caigan
/// exactamente en los hex aprobados, no en tonos derivados automáticamente.
/// `primary` es `colorSuccess` (verde) y no un "morado de marca": no existe
/// tal token en la paleta aprobada. `onPrimary`/`onSecondary`/`onError` son
/// `colorSobreEstado` (fijo) en los dos temas — ver la nota de ese
/// constante: NO deben depender del tema, a diferencia de `bgPage`.
ColorScheme _colorScheme(AppColorTokens t, Brightness brightness) {
  final base = brightness == Brightness.dark
      ? ColorScheme.dark(
          surface: t.bgCard,
          onSurface: t.textPrimary,
          onSurfaceVariant: t.textSecondary,
          surfaceContainerHigh: t.bgCard,
          surfaceContainerHighest: t.borderCard,
          outline: t.textMuted,
          outlineVariant: t.borderCard,
        )
      : ColorScheme.light(
          surface: t.bgCard,
          onSurface: t.textPrimary,
          onSurfaceVariant: t.textSecondary,
          surfaceContainerHigh: t.bgCard,
          surfaceContainerHighest: t.borderCard,
          outline: t.textMuted,
          outlineVariant: t.borderCard,
        );
  return base.copyWith(
    primary: colorSuccess,
    onPrimary: colorSobreEstado,
    primaryContainer: colorSuccess.withValues(alpha: 0.18),
    onPrimaryContainer: colorSuccess,
    secondary: colorSuccess,
    onSecondary: colorSobreEstado,
    secondaryContainer: t.borderCard,
    onSecondaryContainer: t.textPrimary,
    error: colorDanger,
    onError: colorSobreEstado,
    errorContainer: colorDanger.withValues(alpha: 0.15),
    onErrorContainer: colorDanger,
  );
}

ThemeData _construirTema(AppColorTokens tokens, Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: _colorScheme(tokens, brightness),
    // Rol conceptual "background → bgPage" del prompt original de la Fase
    // 19: `ColorScheme` ya no trae los campos `background`/`onBackground`
    // (deprecados), así que el fondo de página se fija directamente aquí en
    // vez de en el scheme.
    scaffoldBackgroundColor: tokens.bgPage,
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.bgPage,
      foregroundColor: tokens.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: tokens.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.borderCard, width: 0.5),
      ),
    ),
    extensions: [tokens],
  );
}

ThemeData appThemeOscuro() =>
    _construirTema(AppColorTokens.oscuro, Brightness.dark);

ThemeData appThemeClaro() =>
    _construirTema(AppColorTokens.claro, Brightness.light);
