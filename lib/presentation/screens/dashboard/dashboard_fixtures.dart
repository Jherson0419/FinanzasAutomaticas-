import '../../../domain/entities/cuenta.dart';
import '../../../domain/entities/deuda.dart';
import '../../../domain/entities/transaccion.dart';
import '../../../domain/usecases/dto/resumen_dashboard.dart';

/// Cuentas de prueba para el carrusel wallet (ver `lib/main_dev.dart`).
/// Coinciden con `saldosPorCuenta` del fixture de abajo.
final cuentasDashboardFixture = [
  const Cuenta(
    id: 'cta-1',
    nombre: 'BCP Cuenta sueldo',
    tipo: TipoCuenta.debito,
    moneda: Moneda.pen,
    saldoActual: 3250.40,
  ),
  const Cuenta(
    id: 'cta-2',
    nombre: 'Yape',
    tipo: TipoCuenta.billetera,
    moneda: Moneda.pen,
    saldoActual: 180.00,
  ),
  const Cuenta(
    id: 'cta-3',
    nombre: 'Ahorros USD',
    tipo: TipoCuenta.debito,
    moneda: Moneda.usd,
    saldoActual: 420.00,
  ),
];

/// Datos de prueba únicamente para previsualizar la UI del dashboard
/// (ver `lib/main_dev.dart`). Nunca se referencia desde `main.dart`.
final resumenDashboardFixture = ResumenDashboard(
  saldosPorCuenta: const [
    SaldoCuenta(
      id: 'cta-1',
      nombre: 'BCP Cuenta sueldo',
      moneda: Moneda.pen,
      saldoActual: 3250.40,
    ),
    SaldoCuenta(
      id: 'cta-2',
      nombre: 'Yape',
      moneda: Moneda.pen,
      saldoActual: 180.00,
    ),
    SaldoCuenta(
      id: 'cta-3',
      nombre: 'Ahorros USD',
      moneda: Moneda.usd,
      saldoActual: 420.00,
    ),
  ],
  saldoTotalPorMoneda: const {Moneda.pen: 3430.40, Moneda.usd: 420.00},
  ingresosMesPorMoneda: const {Moneda.pen: 4200.00},
  gastosMesPorMoneda: const {Moneda.pen: 1850.75},
  gastoPorCategoriaMes: const [
    GastoPorCategoria(
      categoriaId: 'cat-comida',
      nombre: 'Comida',
      iconName: 'restaurant',
      moneda: Moneda.pen,
      monto: 720.50,
      porcentajeDelTotal: 0.39,
    ),
    GastoPorCategoria(
      categoriaId: 'cat-transporte',
      nombre: 'Transporte',
      iconName: 'directions_bus',
      moneda: Moneda.pen,
      monto: 430.00,
      porcentajeDelTotal: 0.23,
    ),
    GastoPorCategoria(
      categoriaId: 'cat-servicios',
      nombre: 'Servicios',
      iconName: 'bolt',
      moneda: Moneda.pen,
      monto: 380.25,
      porcentajeDelTotal: 0.21,
    ),
    GastoPorCategoria(
      categoriaId: 'cat-entretenimiento',
      nombre: 'Entretenimiento',
      iconName: 'movie',
      moneda: Moneda.pen,
      monto: 320.00,
      porcentajeDelTotal: 0.17,
    ),
  ],
  deudasActivas: [
    DeudaActivaResumen(
      id: 'deuda-1',
      nombreDeuda: 'Tarjeta BBVA',
      estructuraPago: EstructuraPago.pagoLibre,
      proximaFechaPago: DateTime.now().add(const Duration(days: 3)),
      enMora: false,
      diasMora: null,
      montoPagado: 600.00,
      montoTotal: 2500.00,
      montoCuota: null,
      moneda: Moneda.pen,
    ),
    DeudaActivaResumen(
      id: 'deuda-2',
      nombreDeuda: 'Préstamo personal',
      estructuraPago: EstructuraPago.cuotasFijas,
      proximaFechaPago: DateTime.now().subtract(const Duration(days: 5)),
      enMora: true,
      diasMora: 5,
      montoPagado: 1200.00,
      montoTotal: 6000.00,
      montoCuota: 300.00,
      moneda: Moneda.pen,
    ),
  ],
  totalAdeudadoPorMoneda: const {Moneda.pen: 6700.00},
  movimientosRecientes: [
    MovimientoReciente(
      id: 'mov-1',
      concepto: 'Almuerzo',
      monto: 25.00,
      moneda: Moneda.pen,
      tipo: TipoTransaccion.gasto,
      categoriaNombre: 'Comida',
      categoriaIconName: 'restaurant',
      fuenteCaptura: FuenteCaptura.manual,
      fecha: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    MovimientoReciente(
      id: 'mov-2',
      concepto: 'Sueldo agosto',
      monto: 4200.00,
      moneda: Moneda.pen,
      tipo: TipoTransaccion.ingreso,
      categoriaNombre: 'Sueldo',
      categoriaIconName: 'payments',
      fuenteCaptura: FuenteCaptura.manual,
      fecha: DateTime.now().subtract(const Duration(days: 1)),
    ),
    MovimientoReciente(
      id: 'mov-3',
      concepto: 'Pasaje bus',
      monto: 3.50,
      moneda: Moneda.pen,
      tipo: TipoTransaccion.gasto,
      categoriaNombre: 'Transporte',
      categoriaIconName: 'directions_bus',
      fuenteCaptura: FuenteCaptura.manual,
      fecha: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
    ),
    MovimientoReciente(
      id: 'mov-4',
      concepto: 'Luz',
      monto: 95.30,
      moneda: Moneda.pen,
      tipo: TipoTransaccion.gasto,
      categoriaNombre: 'Servicios',
      categoriaIconName: 'bolt',
      fuenteCaptura: FuenteCaptura.manual,
      fecha: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ],
);

/// Fixture del estado vacío (instalación recién hecha, sin datos).
final resumenDashboardVacioFixture = ResumenDashboard(
  saldosPorCuenta: const [],
  saldoTotalPorMoneda: const {},
  ingresosMesPorMoneda: const {},
  gastosMesPorMoneda: const {},
  gastoPorCategoriaMes: const [],
  deudasActivas: const [],
  totalAdeudadoPorMoneda: const {},
  movimientosRecientes: const [],
);
