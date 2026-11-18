import 'package:flutter/material.dart';

/// Cifras tabulares (Fase 80): todos los dígitos con el mismo ancho, para
/// que los montos no "bailen" al cambiar y se alineen en columnas. Úsalo en
/// TODO `Text` que muestre un monto (`formatearMonto`).
const cifrasTabulares = [FontFeature.tabularFigures()];

/// Devuelve [estilo] con cifras tabulares. Acepta `null` (lo que devuelve
/// `theme.textTheme.x?.copyWith(...)`) y entonces arma un estilo solo con
/// la característica, que se combina con el estilo heredado.
TextStyle estiloMonto(TextStyle? estilo) =>
    (estilo ?? const TextStyle()).copyWith(fontFeatures: cifrasTabulares);
