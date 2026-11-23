// Normalización del resumen que manda la app (Fase 88). Módulo PURO (sin
// Deno.serve ni red) para poder probarlo con `deno test`.
//
// COMPATIBILIDAD — la función acepta dos formas del payload:
//
// v1 (apps publicadas hasta la Fase 87):
//   deuda = { tipoDeuda, montoTotal, montoPagado, interesTotal, moneda }
//   * Desde la Fase 79 la app manda en `montoTotal` el TOTAL A PAGAR
//     (capital + interés) — parche para que `montoTotal − montoPagado` diera
//     el saldo real sin redesplegar. Apps anteriores a la Fase 79 mandaban
//     ahí el capital: con v1 no hay forma de distinguirlas, así que se sigue
//     usando `montoTotal − montoPagado` (lo mismo que hacía esta función).
//   * Esas apps ya excluyen "me deben" (Fase 82) y nunca mandan
//     transferencias (Fase 85) en el resumen.
//
// v2 (apps desde la Fase 88), `resumen.version = 2`: los mismos campos de
// v1 (para que una función VIEJA siga funcionando con una app nueva) MÁS
// campos explícitos por deuda:
//   capital      — lo prestado (deudas.monto_total)
//   totalAPagar  — capital + interés
//   saldo        — lo que falta pagar (fuente de verdad si viene)
//   direccion    — 'debo' | 'me_deben'
// y, por categoría, `esTransferencia` (nunca debería ser true: la app ya
// las excluye; es una defensa del lado del servidor).
//
// Reglas: el saldo se toma de `saldo`; si no, de `totalAPagar − montoPagado`;
// si no, de `montoTotal − montoPagado` (v1). Nunca negativo. Se excluyen las
// deudas 'me_deben' y las categorías marcadas como transferencia.

export interface DeudaEntrada {
  tipoDeuda: string;
  montoTotal: number;
  montoPagado: number;
  interesTotal: number | null;
  moneda: string;
  // v2
  capital?: number | null;
  totalAPagar?: number | null;
  saldo?: number | null;
  direccion?: string | null;
}

export interface CategoriaEntrada {
  categoriaNombre: string;
  monto: number;
  moneda: string;
  esTransferencia?: boolean;
}

export interface DeudaNormalizada {
  tipoDeuda: string;
  capital: number | null;
  totalAPagar: number;
  saldo: number;
  interesTotal: number | null;
  moneda: string;
}

function numero(valor: unknown): number | null {
  return typeof valor === 'number' && Number.isFinite(valor) ? valor : null;
}

/** Normaliza una deuda; `null` si no corresponde (me deben). */
export function normalizarDeuda(d: DeudaEntrada): DeudaNormalizada | null {
  if (d.direccion === 'me_deben') return null;
  const montoPagado = numero(d.montoPagado) ?? 0;
  const totalAPagar = numero(d.totalAPagar) ?? numero(d.montoTotal) ?? 0;
  const saldo = numero(d.saldo) ?? totalAPagar - montoPagado;
  return {
    tipoDeuda: d.tipoDeuda,
    capital: numero(d.capital),
    totalAPagar,
    saldo: Math.max(saldo, 0),
    interesTotal: numero(d.interesTotal),
    moneda: d.moneda,
  };
}

export function normalizarDeudas(deudas: DeudaEntrada[]): DeudaNormalizada[] {
  const r: DeudaNormalizada[] = [];
  for (const d of deudas ?? []) {
    const n = normalizarDeuda(d);
    if (n) r.push(n);
  }
  return r;
}

export function sinTransferencias(
  categorias: CategoriaEntrada[] | undefined,
): CategoriaEntrada[] {
  return (categorias ?? []).filter((c) => c.esTransferencia !== true);
}

/** Línea de una deuda para el primer mensaje (sin nombres). */
export function lineaDeuda(d: DeudaNormalizada): string {
  const capitalTexto =
    d.capital != null ? `, capital: ${d.capital.toFixed(2)}` : '';
  const interesTexto =
    d.interesTotal != null && d.interesTotal > 0
      ? `, interés total: ${d.interesTotal.toFixed(2)}`
      : '';
  return (
    `- Tipo: ${d.tipoDeuda}, pendiente: ${d.saldo.toFixed(2)} ` +
    `${d.moneda.toUpperCase()}${capitalTexto}${interesTexto}`
  );
}
