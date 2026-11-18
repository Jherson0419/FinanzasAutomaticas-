import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';

/// Fase 79 — todos los campos de [Deuda] como mapa, para pruebas de "ida y
/// vuelta": si se agrega un campo a `Deuda` hay que agregarlo aquí (y
/// `deudaConTodosLosCampos` lo exige porque usa el constructor completo).
Map<String, Object?> camposDeuda(Deuda d) => {
  'id': d.id,
  'nombreDeuda': d.nombreDeuda,
  'tipoDeuda': d.tipoDeuda,
  'tipoAcreedor': d.tipoAcreedor,
  'nombreAcreedor': d.nombreAcreedor,
  'moneda': d.moneda,
  'montoTotal': d.montoTotal,
  'montoPagado': d.montoPagado,
  'tieneInteres': d.tieneInteres,
  'tasaInteres': d.tasaInteres,
  'tipoTasa': d.tipoTasa,
  'estructuraPago': d.estructuraPago,
  'numeroCuotasTotal': d.numeroCuotasTotal,
  'numeroCuotasPagadas': d.numeroCuotasPagadas,
  'montoCuota': d.montoCuota,
  'pagoMinimo': d.pagoMinimo,
  'periodicidadCuotas': d.periodicidadCuotas,
  'interesTotal': d.interesTotal,
  'fechaInicio': d.fechaInicio,
  'fechaVencimientoFinal': d.fechaVencimientoFinal,
  'diaPago': d.diaPago,
  'proximaFechaPago': d.proximaFechaPago,
  'enMora': d.enMora,
  'diasMora': d.diasMora,
  'tasaInteresMoratorio': d.tasaInteresMoratorio,
  'estado': d.estado,
  'notas': d.notas,
  'cuentaId': d.cuentaId,
  'amigoUsuarioId': d.amigoUsuarioId,
  'direccion': d.direccion,
  'montoAbonadoCapital': d.montoAbonadoCapital,
  'montoUltimaCuota': d.montoUltimaCuota,
};

/// Compara todos los campos salvo [tocados].
Map<String, Object?> camposSin(Deuda d, Set<String> tocados) =>
    Map.of(camposDeuda(d))..removeWhere((k, _) => tocados.contains(k));

/// Deuda con TODOS los campos opcionales en un valor no nulo — un campo
/// que un caso de uso olvide copiar aparece como `null` y rompe la prueba.
Deuda deudaConTodosLosCampos({
  String id = 'd1',
  EstructuraPago estructuraPago = EstructuraPago.pagoLibre,
  double montoTotal = 1000,
  double montoPagado = 100,
  double? montoCuota = 50,
  int? numeroCuotasTotal = 20,
  int? numeroCuotasPagadas = 2,
  PeriodicidadCuota? periodicidadCuotas = PeriodicidadCuota.mensual,
  String? cuentaId = 'cuenta-1',
  String? amigoUsuarioId = 'amigo-1',
  EstadoDeuda estado = EstadoDeuda.activa,
  bool enMora = false,
  DateTime? fechaInicio,
  DireccionDeuda direccion = DireccionDeuda.debo,
  double montoAbonadoCapital = 0,
  // Fase 84b: `null` por defecto (un valor cambiaría el saldo de las
  // pruebas existentes); las que la cubren pasan un valor.
  double? montoUltimaCuota,
}) => Deuda(
  id: id,
  nombreDeuda: 'Préstamo de Ana',
  tipoDeuda: TipoDeuda.deudaInformal,
  tipoAcreedor: TipoAcreedor.personaNatural,
  nombreAcreedor: 'Ana',
  moneda: Moneda.pen,
  montoTotal: montoTotal,
  montoPagado: montoPagado,
  tieneInteres: true,
  tasaInteres: 5,
  tipoTasa: TipoTasa.fija,
  estructuraPago: estructuraPago,
  numeroCuotasTotal: numeroCuotasTotal,
  numeroCuotasPagadas: numeroCuotasPagadas,
  montoCuota: montoCuota,
  pagoMinimo: 30,
  periodicidadCuotas: periodicidadCuotas,
  interesTotal: 12,
  fechaInicio: fechaInicio ?? DateTime(2026, 1, 10),
  fechaVencimientoFinal: DateTime(2027, 8, 10),
  diaPago: 10,
  proximaFechaPago: DateTime(2026, 12, 10),
  enMora: enMora,
  diasMora: 4,
  tasaInteresMoratorio: 1.5,
  estado: estado,
  notas: 'notas',
  cuentaId: cuentaId,
  amigoUsuarioId: amigoUsuarioId,
  direccion: direccion,
  montoAbonadoCapital: montoAbonadoCapital,
  montoUltimaCuota: montoUltimaCuota,
);
