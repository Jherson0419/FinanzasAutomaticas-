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
// Fase 81: antes #5C6862 (~3.2:1). #79857F es el tono mínimo de la misma
// familia que llega a 4.5:1 sobre `bgPage` (4.93:1) y `bgCard` (4.51:1).
const _textMutedOscuro = Color(0xFF79857F);

// Paleta clara (Fase 31) — mismo criterio tonal (fondo de página apenas más
// gris que las tarjetas, borde sutil, texto casi negro sin ser negro puro),
// espejado a valores claros.
const _bgPageClaro = Color(0xFFF5F7F5);
const _bgCardClaro = Color(0xFFFFFFFF);
const _borderCardClaro = Color(0xFFE1E6E2);
const _textPrimaryClaro = Color(0xFF15201B);
const _textSecondaryClaro = Color(0xFF5B6B63);
// Fase 80: antes #8A9690 (~3.2:1 sobre `bgPage` claro, no llega a 4.5:1).
const _textMutedClaro = Color(0xFF5D6B64);

// Fase 80 — colores semánticos COMO TEXTO. `colorSuccess`/`colorDanger`/
// `colorWarning` son tonos claros pensados para fondo oscuro: como texto
// sobre fondo claro no llegan a 4.5:1 (WCAG AA). En claro se usan tonos
// oscurecidos; en oscuro, los mismos de siempre (el modo oscuro no cambia).
const _successTextClaro = Color(0xFF0B6B4F);
const _dangerTextClaro = Color(0xFFA32F2F);
const _warningTextClaro = Color(0xFF7A4E00);
const _successBgClaro = Color(0xFFE3F4EC);
const _dangerBgClaro = Color(0xFFFBE9E9);
const _warningBgClaro = Color(0xFFFFF1D6);

// Oscuro: los mismos colores semánticos con alpha 0x29 (≈ 0.16).
const _successBgOscuro = Color(0x295DCAA5);
const _dangerBgOscuro = Color(0x29F09595);
const _warningBgOscuro = Color(0x29FAC775);

// Fase 81 — paleta de 4 colores para barras/segmentos ("Gasto del mes" y
// sus leyendas). Cada uno ≥ 3:1 contra `bgCard` en su tema (elemento
// gráfico, WCAG 1.4.11), verificado en `test/contraste_tokens_test.dart`.
// El 4.º es siempre "Otros" (gris). Nunca se usan solos: van con nombre + %.
const _graficoClaro = [
  Color(0xFF0E7A5A),
  Color(0xFF2F5BA8),
  Color(0xFFB7791F),
  Color(0xFF7A8582),
];
const _graficoOscuro = [
  Color(0xFF3FB68B),
  Color(0xFF6B93E0),
  Color(0xFFE0A33A),
  Color(0xFF8E9A94),
];

// Tarjeta "héroe" (resumen oscuro arriba del dashboard/hub de deudas):
// igual en los dos temas — es una superficie oscura a propósito.
const _heroBg = Color(0xFF0D1210);
const _heroText = Color(0xFFFFFFFF);
const _heroMuted = Color(0xFFA9BBB2);

/// Familia tipográfica de la app (Fase 80), declarada en `pubspec.yaml`.
const fuenteApp = 'Manrope';

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
///
/// Fase 80 — pares de contraste verificados (≥ 4.5:1) en
/// `test/contraste_tokens_test.dart`:
/// - `successText`/`dangerText`/`warningText`: texto de estado (montos de
///   ingreso/gasto, "En mora", avisos). Para rellenos e íconos decorativos
///   siguen existiendo `colorSuccess`/`colorDanger`/`colorWarning`.
/// - `successBg`/`dangerBg`/`warningBg`: fondo de chips de estado.
/// - `heroBg`/`heroText`/`heroMuted`: tarjeta resumen oscura.
/// - `brandAction`: botones y rellenos de marca — NUNCA como texto sobre
///   fondo claro.
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  final Color bgPage;
  final Color bgCard;
  final Color borderCard;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color successText;
  final Color dangerText;
  final Color warningText;
  final Color successBg;
  final Color dangerBg;
  final Color warningBg;
  final Color heroBg;
  final Color heroText;
  final Color heroMuted;
  final Color brandAction;

  /// Paleta de gráficos (Fase 81): 4 colores, el último para "Otros".
  final List<Color> grafico;

  const AppColorTokens({
    required this.bgPage,
    required this.bgCard,
    required this.borderCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.successText,
    required this.dangerText,
    required this.warningText,
    required this.successBg,
    required this.dangerBg,
    required this.warningBg,
    this.heroBg = _heroBg,
    this.heroText = _heroText,
    this.heroMuted = _heroMuted,
    this.brandAction = colorSuccess,
    required this.grafico,
  });

  static const oscuro = AppColorTokens(
    bgPage: _bgPageOscuro,
    bgCard: _bgCardOscuro,
    borderCard: _borderCardOscuro,
    textPrimary: _textPrimaryOscuro,
    textSecondary: _textSecondaryOscuro,
    textMuted: _textMutedOscuro,
    successText: colorSuccess,
    dangerText: colorDanger,
    warningText: colorWarning,
    successBg: _successBgOscuro,
    dangerBg: _dangerBgOscuro,
    warningBg: _warningBgOscuro,
    grafico: _graficoOscuro,
  );

  static const claro = AppColorTokens(
    bgPage: _bgPageClaro,
    bgCard: _bgCardClaro,
    borderCard: _borderCardClaro,
    textPrimary: _textPrimaryClaro,
    textSecondary: _textSecondaryClaro,
    textMuted: _textMutedClaro,
    successText: _successTextClaro,
    dangerText: _dangerTextClaro,
    warningText: _warningTextClaro,
    successBg: _successBgClaro,
    dangerBg: _dangerBgClaro,
    warningBg: _warningBgClaro,
    grafico: _graficoClaro,
  );

  @override
  AppColorTokens copyWith({
    Color? bgPage,
    Color? bgCard,
    Color? borderCard,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? successText,
    Color? dangerText,
    Color? warningText,
    Color? successBg,
    Color? dangerBg,
    Color? warningBg,
    Color? heroBg,
    Color? heroText,
    Color? heroMuted,
    Color? brandAction,
    List<Color>? grafico,
  }) {
    return AppColorTokens(
      bgPage: bgPage ?? this.bgPage,
      bgCard: bgCard ?? this.bgCard,
      borderCard: borderCard ?? this.borderCard,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      successText: successText ?? this.successText,
      dangerText: dangerText ?? this.dangerText,
      warningText: warningText ?? this.warningText,
      successBg: successBg ?? this.successBg,
      dangerBg: dangerBg ?? this.dangerBg,
      warningBg: warningBg ?? this.warningBg,
      heroBg: heroBg ?? this.heroBg,
      heroText: heroText ?? this.heroText,
      heroMuted: heroMuted ?? this.heroMuted,
      brandAction: brandAction ?? this.brandAction,
      grafico: grafico ?? this.grafico,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColorTokens(
      bgPage: l(bgPage, other.bgPage),
      bgCard: l(bgCard, other.bgCard),
      borderCard: l(borderCard, other.borderCard),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      successText: l(successText, other.successText),
      dangerText: l(dangerText, other.dangerText),
      warningText: l(warningText, other.warningText),
      successBg: l(successBg, other.successBg),
      dangerBg: l(dangerBg, other.dangerBg),
      warningBg: l(warningBg, other.warningBg),
      heroBg: l(heroBg, other.heroBg),
      heroText: l(heroText, other.heroText),
      heroMuted: l(heroMuted, other.heroMuted),
      brandAction: l(brandAction, other.brandAction),
      grafico: [
        for (var i = 0; i < grafico.length; i++)
          l(grafico[i], other.grafico[i]),
      ],
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
  Color get successText => _tokens.successText;
  Color get dangerText => _tokens.dangerText;
  Color get warningText => _tokens.warningText;
  Color get successBg => _tokens.successBg;
  Color get dangerBg => _tokens.dangerBg;
  Color get warningBg => _tokens.warningBg;
  Color get heroBg => _tokens.heroBg;
  Color get heroText => _tokens.heroText;
  Color get heroMuted => _tokens.heroMuted;
  Color get brandAction => _tokens.brandAction;
  List<Color> get grafico => _tokens.grafico;
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
    // Fase 80: Manrope empaquetada en assets/fonts/ (ver pubspec.yaml).
    fontFamily: fuenteApp,
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
