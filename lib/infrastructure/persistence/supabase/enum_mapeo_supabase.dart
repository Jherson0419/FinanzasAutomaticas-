import '../../../domain/entities/categoria.dart';
import '../../../domain/entities/cuenta.dart';
import '../../../domain/entities/deuda.dart';
import '../../../domain/entities/transaccion.dart';

/// Conversión explícita enum↔string para cada columna con `CHECK` en el
/// esquema real de Supabase (Fase 26 — corrige un bug real de producción:
/// crear una cuenta fallaba con `violates check constraint
/// "cuentas_moneda_check"` porque `CuentaRepositorySupabase` mandaba
/// `Moneda.pen.name` → `'pen'`, y el `CHECK` de la columna exige
/// `'PEN'`/`'USD'` en mayúsculas).
///
/// Los `CHECK`s reales se confirmaron consultando el proyecto de Supabase
/// enlazado (`supabase db query --linked` contra `pg_constraint`), no se
/// asumieron. Varios enums coinciden con `.name` tal cual (p. ej.
/// `TipoCuenta`, `MetodoPago`) — igual tienen su función explícita acá,
/// para que ningún adapter vuelva a depender de `.name`/`byName` directo
/// contra la base de datos: si mañana cambia el nombre de un valor de
/// enum en Dart (algo interno, se siente "seguro" de renombrar), el
/// `CHECK` de Supabase no se entera y el `byName` empieza a fallar en
/// silencio — exactamente el bug de esta fase, con otro enum.
///
/// Cada función `xDeFila` lanza `FormatException` ante un valor que no
/// reconoce, en vez de un `byName` que lanza `ArgumentError` genérico —
/// mismo criterio, mensaje más claro sobre qué adapter/columna falló.

// ---------------------------------------------------------------------
// Moneda — cuentas.moneda, deudas.moneda, transacciones.moneda
// CHECK: moneda = ANY (ARRAY['PEN', 'USD'])
// ---------------------------------------------------------------------
String monedaAFila(Moneda valor) => switch (valor) {
  Moneda.pen => 'PEN',
  Moneda.usd => 'USD',
};

Moneda monedaDeFila(String valor) => switch (valor) {
  'PEN' => Moneda.pen,
  'USD' => Moneda.usd,
  _ => throw FormatException('Moneda desconocida en Supabase: $valor'),
};

// ---------------------------------------------------------------------
// TipoCuenta — cuentas.tipo
// CHECK: tipo = ANY (ARRAY['debito', 'credito', 'billetera', 'efectivo'])
// ---------------------------------------------------------------------
String tipoCuentaAFila(TipoCuenta valor) => switch (valor) {
  TipoCuenta.debito => 'debito',
  TipoCuenta.credito => 'credito',
  TipoCuenta.billetera => 'billetera',
  TipoCuenta.efectivo => 'efectivo',
};

TipoCuenta tipoCuentaDeFila(String valor) => switch (valor) {
  'debito' => TipoCuenta.debito,
  'credito' => TipoCuenta.credito,
  'billetera' => TipoCuenta.billetera,
  'efectivo' => TipoCuenta.efectivo,
  _ => throw FormatException('Tipo de cuenta desconocido en Supabase: $valor'),
};

// ---------------------------------------------------------------------
// TipoCategoria — categorias.tipo
// CHECK: tipo = ANY (ARRAY['ingreso', 'gasto'])
// ---------------------------------------------------------------------
String tipoCategoriaAFila(TipoCategoria valor) => switch (valor) {
  TipoCategoria.ingreso => 'ingreso',
  TipoCategoria.gasto => 'gasto',
};

TipoCategoria tipoCategoriaDeFila(String valor) => switch (valor) {
  'ingreso' => TipoCategoria.ingreso,
  'gasto' => TipoCategoria.gasto,
  _ => throw FormatException(
    'Tipo de categoría desconocido en Supabase: $valor',
  ),
};

// ---------------------------------------------------------------------
// TipoTransaccion — transacciones.tipo
// CHECK: tipo = ANY (ARRAY['ingreso', 'gasto'])
// ---------------------------------------------------------------------
String tipoTransaccionAFila(TipoTransaccion valor) => switch (valor) {
  TipoTransaccion.ingreso => 'ingreso',
  TipoTransaccion.gasto => 'gasto',
};

TipoTransaccion tipoTransaccionDeFila(String valor) => switch (valor) {
  'ingreso' => TipoTransaccion.ingreso,
  'gasto' => TipoTransaccion.gasto,
  _ => throw FormatException(
    'Tipo de transacción desconocido en Supabase: $valor',
  ),
};

// ---------------------------------------------------------------------
// MetodoPago — transacciones.metodo_pago
// CHECK: metodo_pago = ANY (ARRAY['efectivo', 'transferencia', 'tarjeta',
//                                  'yape', 'plin', 'otro'])
// ---------------------------------------------------------------------
String metodoPagoAFila(MetodoPago valor) => switch (valor) {
  MetodoPago.efectivo => 'efectivo',
  MetodoPago.transferencia => 'transferencia',
  MetodoPago.tarjeta => 'tarjeta',
  MetodoPago.yape => 'yape',
  MetodoPago.plin => 'plin',
  MetodoPago.otro => 'otro',
};

MetodoPago metodoPagoDeFila(String valor) => switch (valor) {
  'efectivo' => MetodoPago.efectivo,
  'transferencia' => MetodoPago.transferencia,
  'tarjeta' => MetodoPago.tarjeta,
  'yape' => MetodoPago.yape,
  'plin' => MetodoPago.plin,
  'otro' => MetodoPago.otro,
  _ => throw FormatException('Método de pago desconocido en Supabase: $valor'),
};

// ---------------------------------------------------------------------
// FuenteCaptura — transacciones.fuente_captura
// CHECK (al momento de esta fase): fuente_captura = ANY (ARRAY['manual',
//   'notificacion_android', 'correo_ios', 'ocr_ios', 'ajuste'])
//
// ⚠️ 'webhook_atajo' (Fase 25, `FuenteCaptura.webhookAtajo`) TODAVÍA NO
// está en ese `CHECK` — el `ALTER TABLE` para agregarlo nunca se corrió.
// La función de mapeo ya lo soporta (para cuando se corra el SQL, ver el
// reporte de esta fase); hasta entonces, cualquier intento de insertar
// una transacción con esta fuente sigue fallando por el `CHECK`, igual
// que fallaba `moneda` antes de esta fase — no es un bug de esta
// conversión, es un `CHECK` desactualizado pendiente en Supabase.
// ---------------------------------------------------------------------
String fuenteCapturaAFila(FuenteCaptura valor) => switch (valor) {
  FuenteCaptura.manual => 'manual',
  FuenteCaptura.notificacionAndroid => 'notificacion_android',
  FuenteCaptura.correoIOS => 'correo_ios',
  FuenteCaptura.ocrIOS => 'ocr_ios',
  FuenteCaptura.ajuste => 'ajuste',
  FuenteCaptura.webhookAtajo => 'webhook_atajo',
};

FuenteCaptura fuenteCapturaDeFila(String valor) => switch (valor) {
  'manual' => FuenteCaptura.manual,
  'notificacion_android' => FuenteCaptura.notificacionAndroid,
  'correo_ios' => FuenteCaptura.correoIOS,
  'ocr_ios' => FuenteCaptura.ocrIOS,
  'ajuste' => FuenteCaptura.ajuste,
  'webhook_atajo' => FuenteCaptura.webhookAtajo,
  _ => throw FormatException(
    'Fuente de captura desconocida en Supabase: $valor',
  ),
};

// ---------------------------------------------------------------------
// TipoDeuda — deudas.tipo_deuda
// CHECK: tipo_deuda = ANY (ARRAY['tarjeta_credito', 'prestamo_personal',
//   'prestamo_vehicular', 'hipoteca', 'prestamo_estudiantil',
//   'compra_cuotas', 'deuda_informal', 'otro'])
// ---------------------------------------------------------------------
String tipoDeudaAFila(TipoDeuda valor) => switch (valor) {
  TipoDeuda.tarjetaCredito => 'tarjeta_credito',
  TipoDeuda.prestamoPersonal => 'prestamo_personal',
  TipoDeuda.prestamoVehicular => 'prestamo_vehicular',
  TipoDeuda.hipoteca => 'hipoteca',
  TipoDeuda.prestamoEstudiantil => 'prestamo_estudiantil',
  TipoDeuda.compraCuotas => 'compra_cuotas',
  TipoDeuda.deudaInformal => 'deuda_informal',
  TipoDeuda.otro => 'otro',
};

TipoDeuda tipoDeudaDeFila(String valor) => switch (valor) {
  'tarjeta_credito' => TipoDeuda.tarjetaCredito,
  'prestamo_personal' => TipoDeuda.prestamoPersonal,
  'prestamo_vehicular' => TipoDeuda.prestamoVehicular,
  'hipoteca' => TipoDeuda.hipoteca,
  'prestamo_estudiantil' => TipoDeuda.prestamoEstudiantil,
  'compra_cuotas' => TipoDeuda.compraCuotas,
  'deuda_informal' => TipoDeuda.deudaInformal,
  'otro' => TipoDeuda.otro,
  _ => throw FormatException('Tipo de deuda desconocido en Supabase: $valor'),
};

// ---------------------------------------------------------------------
// TipoAcreedor — deudas.tipo_acreedor
// CHECK: tipo_acreedor = ANY (ARRAY['entidad_financiera', 'persona_natural',
//                                    'comercio'])
// ---------------------------------------------------------------------
String tipoAcreedorAFila(TipoAcreedor valor) => switch (valor) {
  TipoAcreedor.entidadFinanciera => 'entidad_financiera',
  TipoAcreedor.personaNatural => 'persona_natural',
  TipoAcreedor.comercio => 'comercio',
};

TipoAcreedor tipoAcreedorDeFila(String valor) => switch (valor) {
  'entidad_financiera' => TipoAcreedor.entidadFinanciera,
  'persona_natural' => TipoAcreedor.personaNatural,
  'comercio' => TipoAcreedor.comercio,
  _ => throw FormatException(
    'Tipo de acreedor desconocido en Supabase: $valor',
  ),
};

// ---------------------------------------------------------------------
// TipoTasa — deudas.tipo_tasa
// CHECK: tipo_tasa = ANY (ARRAY['fija', 'variable'])
// ---------------------------------------------------------------------
String tipoTasaAFila(TipoTasa valor) => switch (valor) {
  TipoTasa.fija => 'fija',
  TipoTasa.variable => 'variable',
};

TipoTasa tipoTasaDeFila(String valor) => switch (valor) {
  'fija' => TipoTasa.fija,
  'variable' => TipoTasa.variable,
  _ => throw FormatException('Tipo de tasa desconocido en Supabase: $valor'),
};

// ---------------------------------------------------------------------
// EstructuraPago — deudas.estructura_pago
// CHECK: estructura_pago = ANY (ARRAY['cuotas_fijas', 'pago_libre'])
// ---------------------------------------------------------------------
String estructuraPagoAFila(EstructuraPago valor) => switch (valor) {
  EstructuraPago.cuotasFijas => 'cuotas_fijas',
  EstructuraPago.pagoLibre => 'pago_libre',
};

EstructuraPago estructuraPagoDeFila(String valor) => switch (valor) {
  'cuotas_fijas' => EstructuraPago.cuotasFijas,
  'pago_libre' => EstructuraPago.pagoLibre,
  _ => throw FormatException(
    'Estructura de pago desconocida en Supabase: $valor',
  ),
};

// ---------------------------------------------------------------------
// PeriodicidadCuota — deudas.periodicidad_cuotas
// CHECK: periodicidad_cuotas = ANY (ARRAY['mensual', 'quincenal'])
// ---------------------------------------------------------------------
String periodicidadCuotaAFila(PeriodicidadCuota valor) => switch (valor) {
  PeriodicidadCuota.mensual => 'mensual',
  PeriodicidadCuota.quincenal => 'quincenal',
};

PeriodicidadCuota periodicidadCuotaDeFila(String valor) => switch (valor) {
  'mensual' => PeriodicidadCuota.mensual,
  'quincenal' => PeriodicidadCuota.quincenal,
  _ => throw FormatException(
    'Periodicidad de cuotas desconocida en Supabase: $valor',
  ),
};

// ---------------------------------------------------------------------
// EstadoDeuda — deudas.estado
// CHECK: estado = ANY (ARRAY['activa', 'pagada', 'en_mora', 'refinanciada',
//                             'cancelada'])
// ---------------------------------------------------------------------
String estadoDeudaAFila(EstadoDeuda valor) => switch (valor) {
  EstadoDeuda.activa => 'activa',
  EstadoDeuda.pagada => 'pagada',
  EstadoDeuda.enMora => 'en_mora',
  EstadoDeuda.refinanciada => 'refinanciada',
  EstadoDeuda.cancelada => 'cancelada',
};

EstadoDeuda estadoDeudaDeFila(String valor) => switch (valor) {
  'activa' => EstadoDeuda.activa,
  'pagada' => EstadoDeuda.pagada,
  'en_mora' => EstadoDeuda.enMora,
  'refinanciada' => EstadoDeuda.refinanciada,
  'cancelada' => EstadoDeuda.cancelada,
  _ => throw FormatException('Estado de deuda desconocido en Supabase: $valor'),
};
