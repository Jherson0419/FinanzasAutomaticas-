/// Umbral de días para considerar una fecha de corte/pago/cuota "por
/// vencer" (Fase 29) — 3 días o menos. Compartido por
/// `ObtenerAlertasTarjetasCredito` y el orden/color de "Deudas activas" por
/// vencimiento (`domain/urgencia_deuda.dart`, Fase 68), para no duplicar el
/// mismo criterio en dos lugares.
const umbralDiasAlertaVencimiento = 3;
