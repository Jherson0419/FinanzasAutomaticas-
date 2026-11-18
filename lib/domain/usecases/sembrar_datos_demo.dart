import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../calculo_saldo.dart';
import '../cronograma_cuotas.dart';
import '../entities/categoria.dart';
import '../entities/cuenta.dart';
import '../entities/deuda.dart';
import '../entities/pago_deuda.dart';
import '../entities/transaccion.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import '../repositories/transaccion_repository.dart';
import 'sincronizar_deuda_tarjeta.dart';

/// Resultado de [SembrarDatosDemo]: cuántos registros nuevos escribió.
/// `0` significa que los datos de ejemplo ya estaban cargados.
class ResultadoSembrarDatosDemo {
  final int registrosCreados;

  const ResultadoSembrarDatosDemo(this.registrosCreados);

  bool get yaEstabaCargado => registrosCreados == 0;
}

/// Carga un set de datos de ejemplo (Fase 78) para probar la app en modo
/// local sin tener que registrar todo a mano:
///
/// - 3 cuentas: Efectivo, Débito BCP y Yape.
/// - Sueldo de S/ 3,200 y S/ 2,560 de gastos del mes de [call]`(ahora:)`
///   repartidos en Comida, Transporte y Servicios.
/// - Fase 86: historial de los 3 meses ANTERIORES (para la capacidad de
///   pago y el consejero): ingresos S/ 3,800 / 3,200 / 3,600 y gastos
///   S/ 1,850 / 1,750 / 1,900 (del más reciente al más antiguo). Ese
///   historial ya está reflejado en el saldo de apertura de las cuentas:
///   NO se vuelve a aplicar a `saldoActual`.
/// - Préstamo personal: capital S/ 3,800, S/ 440 × 10 (interés S/ 600),
///   8 pagadas → saldo pendiente S/ 880.
/// - Laptop en cuotas: capital S/ 2,000, S/ 210 × 12 (interés S/ 520),
///   3 pagadas → saldo pendiente S/ 1,890.
/// - Deuda informal de pago libre (S/ 250, S/ 100 pagados).
/// - Fase 82: "Lucía te debe S/ 380" (me deben, pago libre, 0 cobrado).
/// - Fase 84: Visa BCP con TCEA 48 % (S/ 1,200 usados, mínimo S/ 120).
///
/// **Idempotente**: todos los ids son UUID v5 deterministas (válidos como
/// `uuid` en Postgres, por si estos datos llegaran a migrarse) y cada
/// registro se crea solo si todavía no existe — correrlo dos veces, o de
/// nuevo tras una falla a la mitad, nunca duplica nada ni vuelve a aplicar
/// el efecto de una transacción sobre el saldo de su cuenta.
///
/// Solo se expone desde la sección "Modo local" de "Mi perfil"; el caso de
/// uso en sí depende únicamente de los puertos, no sabe en qué modo corre.
class SembrarDatosDemo {
  final CuentaRepository _cuentaRepository;
  final CategoriaRepository _categoriaRepository;
  final TransaccionRepository _transaccionRepository;
  final DeudaRepository _deudaRepository;
  final PagoDeudaRepository _pagoDeudaRepository;

  SembrarDatosDemo({
    required CuentaRepository cuentaRepository,
    required CategoriaRepository categoriaRepository,
    required TransaccionRepository transaccionRepository,
    required DeudaRepository deudaRepository,
    required PagoDeudaRepository pagoDeudaRepository,
  }) : _cuentaRepository = cuentaRepository,
       _categoriaRepository = categoriaRepository,
       _transaccionRepository = transaccionRepository,
       _deudaRepository = deudaRepository,
       _pagoDeudaRepository = pagoDeudaRepository;

  static const _uuid = Uuid();

  /// Id determinista de un registro demo — público para poder verificarlo
  /// en pruebas sin duplicar la convención.
  static String idDemo(String clave) =>
      _uuid.v5(Namespace.url.value, 'finzo-demo/$clave');

  static final idCuentaEfectivo = idDemo('cuenta/efectivo');
  static final idCuentaBcp = idDemo('cuenta/debito-bcp');
  static final idCuentaYape = idDemo('cuenta/yape');
  static final idCuentaVisa = idDemo('cuenta/visa-bcp');
  static final idDeudaVisa = idDemo('deuda/visa-bcp');
  static final idDeudaPrestamo = idDemo('deuda/prestamo-personal');
  static final idDeudaLaptop = idDemo('deuda/laptop');
  static final idDeudaInformal = idDemo('deuda/informal');
  static final idDeudaLucia = idDemo('deuda/me-deben-lucia');

  int _creados = 0;

  Future<ResultadoSembrarDatosDemo> call({DateTime? ahora}) async {
    _creados = 0;
    final hoy = ahora ?? DateTime.now();

    await _sembrarCuentas();
    final categorias = await _resolverCategorias();
    await _sembrarTransacciones(hoy, categorias);
    await _sembrarHistorial(hoy, categorias);
    await _sembrarDeudas(hoy);
    await _sembrarVisa(hoy);

    return ResultadoSembrarDatosDemo(_creados);
  }

  // ---------------------------------------------------------------------
  // Cuentas
  // ---------------------------------------------------------------------

  /// Saldos de apertura — tras aplicar las transacciones del mes quedan en
  /// Efectivo S/ 60, Débito BCP S/ 3,160 y Yape S/ 70.
  /// Fase 84 — Visa BCP con TCEA 48 % (para ver el plan de pago con una
  /// tarjeta). S/ 1,200 usados de S/ 5,000; pago mínimo S/ 120; corte el
  /// 10 y pago el 28. Su deuda vinculada (Fase 62) hereda la TCEA (Fase 83).
  /// No mueve el saldo total: las tarjetas nunca cuentan como fondos.
  Future<void> _sembrarVisa(DateTime hoy) async {
    final visa = Cuenta(
      id: idCuentaVisa,
      nombre: 'Visa BCP',
      tipo: TipoCuenta.credito,
      moneda: Moneda.pen,
      saldoActual: -1200,
      lineaCredito: 5000,
      fechaCorte: DateTime(hoy.year, hoy.month - 1, 10),
      fechaPago: DateTime(hoy.year, hoy.month - 1, 28),
      ultimosDigitos: '7731',
      pagoMinimo: 120,
      tcea: 0.48,
    );
    if (await _cuentaRepository.obtenerPorId(visa.id) == null) {
      await _cuentaRepository.crear(visa);
      _creados++;
    }
    await _crearDeudaSiFalta(
      deudaConTceaDeTarjeta(
        Deuda(
          id: idDeudaVisa,
          nombreDeuda: 'Visa BCP',
          tipoDeuda: TipoDeuda.tarjetaCredito,
          tipoAcreedor: TipoAcreedor.entidadFinanciera,
          nombreAcreedor: 'Visa BCP',
          moneda: Moneda.pen,
          montoTotal: 5000,
          montoPagado: 3800, // crédito disponible (Fase 62)
          tieneInteres: false,
          estructuraPago: EstructuraPago.pagoLibre,
          pagoMinimo: 120,
          fechaInicio: DateTime(hoy.year, hoy.month - 1, 10),
          enMora: false,
          estado: EstadoDeuda.activa,
          cuentaId: idCuentaVisa,
        ),
        visa.tcea,
        pagoMinimo: visa.pagoMinimo,
      ),
      const [],
    );
  }

  Future<void> _sembrarCuentas() async {
    final cuentas = [
      Cuenta(
        id: idCuentaEfectivo,
        nombre: 'Efectivo',
        tipo: TipoCuenta.efectivo,
        moneda: Moneda.pen,
        saldoActual: 500,
      ),
      Cuenta(
        id: idCuentaBcp,
        nombre: 'Débito BCP',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
        saldoActual: 1200,
        ultimosDigitos: '4821',
      ),
      Cuenta(
        id: idCuentaYape,
        nombre: 'Yape',
        tipo: TipoCuenta.billetera,
        moneda: Moneda.pen,
        saldoActual: 950,
      ),
    ];
    for (final cuenta in cuentas) {
      if (await _cuentaRepository.obtenerPorId(cuenta.id) != null) continue;
      await _cuentaRepository.crear(cuenta);
      _creados++;
    }
  }

  // ---------------------------------------------------------------------
  // Categorías
  // ---------------------------------------------------------------------

  /// Reutiliza las categorías predeterminadas que ya siembra Drift
  /// (`_seedCategoriasDefault`) buscándolas por nombre+tipo; solo crea la
  /// que falte (p. ej. si el usuario la borró o renombró).
  Future<Map<String, String>> _resolverCategorias() async {
    const requeridas = <String, (TipoCategoria, String)>{
      'Sueldo': (TipoCategoria.ingreso, 'payments'),
      'Freelance': (TipoCategoria.ingreso, 'work'),
      'Comida': (TipoCategoria.gasto, 'restaurant'),
      'Transporte': (TipoCategoria.gasto, 'directions_bus'),
      'Servicios': (TipoCategoria.gasto, 'bolt'),
    };
    final existentes = await _categoriaRepository.obtenerTodas();
    final ids = <String, String>{};
    for (final MapEntry(key: nombre, value: (tipo, icono))
        in requeridas.entries) {
      final existente = existentes
          .where((c) => c.nombre == nombre && c.tipo == tipo)
          .firstOrNull;
      if (existente != null) {
        ids[nombre] = existente.id;
        continue;
      }
      final categoria = Categoria(
        id: idDemo('categoria/$nombre'),
        nombre: nombre,
        tipo: tipo,
        iconName: icono,
      );
      if (await _categoriaRepository.obtenerPorId(categoria.id) == null) {
        await _categoriaRepository.crear(categoria);
        _creados++;
      }
      ids[nombre] = categoria.id;
    }
    return ids;
  }

  // ---------------------------------------------------------------------
  // Transacciones
  // ---------------------------------------------------------------------

  Future<void> _sembrarTransacciones(
    DateTime hoy,
    Map<String, String> categorias,
  ) async {
    final movimientos = <_MovimientoDemo>[
      // Ingreso
      _MovimientoDemo(
        'sueldo',
        1,
        idCuentaBcp,
        'Sueldo',
        3200,
        'Sueldo',
        MetodoPago.transferencia,
        TipoTransaccion.ingreso,
      ),
      // Comida — S/ 1,500
      _MovimientoDemo(
        'supermercado',
        3,
        idCuentaBcp,
        'Comida',
        520,
        'Supermercado Plaza Vea',
        MetodoPago.tarjeta,
      ),
      _MovimientoDemo(
        'mercado',
        6,
        idCuentaEfectivo,
        'Comida',
        300,
        'Mercado de abastos',
        MetodoPago.efectivo,
      ),
      _MovimientoDemo(
        'almuerzos',
        8,
        idCuentaYape,
        'Comida',
        380,
        'Almuerzos de la oficina',
        MetodoPago.yape,
      ),
      _MovimientoDemo(
        'delivery',
        12,
        idCuentaYape,
        'Comida',
        140,
        'Delivery de pizza',
        MetodoPago.yape,
      ),
      _MovimientoDemo(
        'cena',
        14,
        idCuentaYape,
        'Comida',
        160,
        'Cena de cumpleaños',
        MetodoPago.yape,
      ),
      // Transporte — S/ 340
      _MovimientoDemo(
        'pasajes',
        2,
        idCuentaEfectivo,
        'Transporte',
        140,
        'Pasajes de la semana',
        MetodoPago.efectivo,
      ),
      _MovimientoDemo(
        'metropolitano',
        4,
        idCuentaYape,
        'Transporte',
        80,
        'Recarga tarjeta del Metropolitano',
        MetodoPago.yape,
      ),
      _MovimientoDemo(
        'taxi',
        9,
        idCuentaYape,
        'Transporte',
        120,
        'Viajes en taxi',
        MetodoPago.yape,
      ),
      // Servicios — S/ 720
      _MovimientoDemo(
        'luz',
        5,
        idCuentaBcp,
        'Servicios',
        160,
        'Recibo de luz',
        MetodoPago.transferencia,
      ),
      _MovimientoDemo(
        'agua',
        5,
        idCuentaBcp,
        'Servicios',
        75,
        'Recibo de agua',
        MetodoPago.transferencia,
      ),
      _MovimientoDemo(
        'internet',
        7,
        idCuentaBcp,
        'Servicios',
        130,
        'Internet y cable',
        MetodoPago.tarjeta,
      ),
      _MovimientoDemo(
        'celular',
        10,
        idCuentaBcp,
        'Servicios',
        70,
        'Plan de celular',
        MetodoPago.tarjeta,
      ),
      _MovimientoDemo(
        'streaming',
        11,
        idCuentaBcp,
        'Servicios',
        45,
        'Suscripciones de streaming',
        MetodoPago.tarjeta,
      ),
      _MovimientoDemo(
        'gas',
        13,
        idCuentaBcp,
        'Servicios',
        60,
        'Balón de gas',
        MetodoPago.transferencia,
      ),
      _MovimientoDemo(
        'mantenimiento',
        15,
        idCuentaBcp,
        'Servicios',
        180,
        'Mantenimiento del edificio',
        MetodoPago.transferencia,
      ),
    ];

    final mes = '${hoy.year}-${hoy.month}';
    for (final m in movimientos) {
      // El id incluye el mes: volver a sembrar en un mes nuevo agrega el
      // mes nuevo en vez de dejar el dashboard del mes actual vacío.
      final id = idDemo('transaccion/$mes/${m.clave}');
      if (await _transaccionRepository.obtenerPorId(id) != null) continue;

      final cuenta = await _cuentaRepository.obtenerPorId(m.cuentaId);
      if (cuenta == null) continue; // el usuario borró la cuenta demo

      await _transaccionRepository.crear(
        Transaccion(
          id: id,
          cuentaId: m.cuentaId,
          categoriaId: categorias[m.categoria]!,
          monto: m.monto,
          moneda: Moneda.pen,
          tipo: m.tipo,
          concepto: m.concepto,
          metodoPago: m.metodoPago,
          esRecurrente: false,
          fuenteCaptura: FuenteCaptura.manual,
          // Nunca en el futuro: si hoy es día 3, todo lo posterior cae hoy.
          fecha: DateTime(hoy.year, hoy.month, math.min(m.dia, hoy.day), 12),
        ),
      );
      await _cuentaRepository.actualizar(
        cuenta.copyWith(
          saldoActual: aplicarEfectoTransaccion(
            cuenta.saldoActual,
            m.tipo,
            m.monto,
          ),
        ),
      );
      _creados++;
    }
  }

  // ---------------------------------------------------------------------
  // Historial (Fase 86)
  // ---------------------------------------------------------------------

  /// Meses completos anteriores: (meses atrás, sueldo, freelance, comida,
  /// transporte, servicios). El 2.º mes es de ingreso bajo (sin freelance).
  static const historialDemo = <(int, double, double, double, double, double)>[
    (1, 3200, 600, 900, 300, 650),
    (2, 3200, 0, 850, 250, 650),
    (3, 3200, 400, 950, 300, 650),
  ];

  Future<void> _sembrarHistorial(
    DateTime hoy,
    Map<String, String> categorias,
  ) async {
    for (final (atras, sueldo, freelance, comida, transporte, servicios)
        in historialDemo) {
      final mes = DateTime(hoy.year, hoy.month - atras);
      final movimientos =
          <(String, int, String, String, double, String, TipoTransaccion)>[
            (
              'sueldo',
              1,
              idCuentaBcp,
              'Sueldo',
              sueldo,
              'Sueldo',
              TipoTransaccion.ingreso,
            ),
            if (freelance > 0)
              (
                'freelance',
                18,
                idCuentaBcp,
                'Freelance',
                freelance,
                'Proyecto freelance',
                TipoTransaccion.ingreso,
              ),
            (
              'comida',
              10,
              idCuentaYape,
              'Comida',
              comida,
              'Comida del mes',
              TipoTransaccion.gasto,
            ),
            (
              'transporte',
              12,
              idCuentaEfectivo,
              'Transporte',
              transporte,
              'Transporte del mes',
              TipoTransaccion.gasto,
            ),
            (
              'servicios',
              5,
              idCuentaBcp,
              'Servicios',
              servicios,
              'Servicios del mes',
              TipoTransaccion.gasto,
            ),
          ];
      for (final (clave, dia, cuentaId, categoria, monto, concepto, tipo)
          in movimientos) {
        final id = idDemo('historial/${mes.year}-${mes.month}/$clave');
        if (await _transaccionRepository.obtenerPorId(id) != null) continue;
        if (await _cuentaRepository.obtenerPorId(cuentaId) == null) continue;
        await _transaccionRepository.crear(
          Transaccion(
            id: id,
            cuentaId: cuentaId,
            categoriaId: categorias[categoria]!,
            monto: monto,
            moneda: Moneda.pen,
            tipo: tipo,
            concepto: concepto,
            metodoPago: tipo == TipoTransaccion.ingreso
                ? MetodoPago.transferencia
                : MetodoPago.tarjeta,
            esRecurrente: false,
            fuenteCaptura: FuenteCaptura.manual,
            fecha: DateTime(mes.year, mes.month, dia, 12),
          ),
        );
        _creados++;
      }
    }
  }

  // ---------------------------------------------------------------------
  // Deudas
  // ---------------------------------------------------------------------

  Future<void> _sembrarDeudas(DateTime hoy) async {
    await _sembrarDeudaEnCuotas(
      hoy: hoy,
      id: idDeudaPrestamo,
      clave: 'prestamo',
      nombre: 'Préstamo personal',
      tipoDeuda: TipoDeuda.prestamoPersonal,
      tipoAcreedor: TipoAcreedor.entidadFinanciera,
      nombreAcreedor: 'BCP',
      // Capital S/ 3,800 + S/ 600 de interés = 10 cuotas de S/ 440 (mismo
      // criterio que `RegistrarDeuda`: `interesTotal` se deriva). Con 8
      // pagadas, saldo pendiente S/ 880.
      capital: 3800,
      montoCuota: 440,
      cuotasTotal: 10,
      cuotasPagadas: 8,
      diaPago: 20,
      notas: 'Datos de ejemplo',
    );
    await _sembrarDeudaEnCuotas(
      hoy: hoy,
      id: idDeudaLaptop,
      clave: 'laptop',
      nombre: 'Laptop Lenovo',
      tipoDeuda: TipoDeuda.compraCuotas,
      tipoAcreedor: TipoAcreedor.comercio,
      nombreAcreedor: 'Saga Falabella',
      // Capital S/ 2,000 + S/ 520 de interés = 12 cuotas de S/ 210. Con 3
      // pagadas, saldo pendiente S/ 1,890.
      capital: 2000,
      montoCuota: 210,
      cuotasTotal: 12,
      cuotasPagadas: 3,
      diaPago: 5,
      notas: 'Datos de ejemplo',
    );
    await _sembrarDeudaInformal(hoy);
    await _sembrarMeDebenLucia(hoy);
  }

  Future<void> _sembrarDeudaEnCuotas({
    required DateTime hoy,
    required String id,
    required String clave,
    required String nombre,
    required TipoDeuda tipoDeuda,
    required TipoAcreedor tipoAcreedor,
    required String nombreAcreedor,
    required double capital,
    required double montoCuota,
    required int cuotasTotal,
    required int cuotasPagadas,
    required int diaPago,
    String? notas,
  }) async {
    // La próxima cuota (la primera sin pagar) vence en la próxima
    // ocurrencia de `diaPago` — así nunca nace en mora.
    final proximaCuota = hoy.day <= diaPago
        ? DateTime(hoy.year, hoy.month, diaPago)
        : DateTime(hoy.year, hoy.month + 1, diaPago);
    final fechaInicio = DateTime(
      proximaCuota.year,
      proximaCuota.month - cuotasPagadas,
      diaPago,
    );
    final interesTotal = montoCuota * cuotasTotal - capital;
    // Redondeado a céntimos (520 / 12 no es exacto).
    final interesPorCuota = (interesTotal / cuotasTotal * 100).round() / 100;

    final deuda = Deuda(
      id: id,
      nombreDeuda: nombre,
      tipoDeuda: tipoDeuda,
      tipoAcreedor: tipoAcreedor,
      nombreAcreedor: nombreAcreedor,
      moneda: Moneda.pen,
      montoTotal: capital,
      montoPagado: montoCuota * cuotasPagadas,
      tieneInteres: interesTotal > 0,
      estructuraPago: EstructuraPago.cuotasFijas,
      numeroCuotasTotal: cuotasTotal,
      numeroCuotasPagadas: cuotasPagadas,
      montoCuota: montoCuota,
      periodicidadCuotas: PeriodicidadCuota.mensual,
      interesTotal: interesTotal,
      fechaInicio: fechaInicio,
      diaPago: diaPago,
      enMora: false,
      estado: EstadoDeuda.activa,
      notas: notas,
    );

    final cronogramaSinPagos = generarCronogramaCuotas(deuda, const []);
    final pagos = [
      for (final cuota in cronogramaSinPagos.take(cuotasPagadas))
        PagoDeuda(
          id: idDemo('pago/$clave/${cuota.numero}'),
          deudaId: id,
          montoPagado: montoCuota,
          montoCapital: montoCuota - interesPorCuota,
          montoInteres: interesPorCuota,
          fechaPago: cuota.fechaVencimiento,
          numeroCuota: cuota.numero,
        ),
    ];
    final cronograma = generarCronogramaCuotas(deuda, pagos);

    await _crearDeudaSiFalta(
      Deuda(
        id: deuda.id,
        nombreDeuda: deuda.nombreDeuda,
        tipoDeuda: deuda.tipoDeuda,
        tipoAcreedor: deuda.tipoAcreedor,
        nombreAcreedor: deuda.nombreAcreedor,
        moneda: deuda.moneda,
        montoTotal: deuda.montoTotal,
        montoPagado: deuda.montoPagado,
        tieneInteres: deuda.tieneInteres,
        estructuraPago: deuda.estructuraPago,
        numeroCuotasTotal: deuda.numeroCuotasTotal,
        numeroCuotasPagadas: deuda.numeroCuotasPagadas,
        montoCuota: deuda.montoCuota,
        periodicidadCuotas: deuda.periodicidadCuotas,
        interesTotal: deuda.interesTotal,
        fechaInicio: deuda.fechaInicio,
        fechaVencimientoFinal: fechaVencimientoFinalDesdeCronograma(cronograma),
        diaPago: deuda.diaPago,
        proximaFechaPago: proximaFechaPagoDesdeCronograma(cronograma),
        enMora: false,
        estado: EstadoDeuda.activa,
        notas: deuda.notas,
      ),
      pagos,
    );
  }

  /// Fase 82 — un préstamo que hice: "Lucía te debe S/ 380". Registrarlo
  /// no mueve cuentas (el dinero salió antes del periodo de los datos).
  Future<void> _sembrarMeDebenLucia(DateTime hoy) async {
    await _crearDeudaSiFalta(
      Deuda(
        id: idDeudaLucia,
        nombreDeuda: 'Préstamo a Lucía',
        tipoDeuda: TipoDeuda.deudaInformal,
        tipoAcreedor: TipoAcreedor.personaNatural,
        nombreAcreedor: 'Lucía',
        moneda: Moneda.pen,
        montoTotal: 380,
        montoPagado: 0,
        tieneInteres: false,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(hoy.year, hoy.month, hoy.day - 20),
        enMora: false,
        estado: EstadoDeuda.activa,
        notas: 'Datos de ejemplo',
        direccion: DireccionDeuda.meDeben,
      ),
      const [],
    );
  }

  Future<void> _sembrarDeudaInformal(DateTime hoy) async {
    final inicio = DateTime(hoy.year, hoy.month, hoy.day - 45);
    final deuda = Deuda(
      id: idDeudaInformal,
      nombreDeuda: 'Préstamo de Luis',
      tipoDeuda: TipoDeuda.deudaInformal,
      tipoAcreedor: TipoAcreedor.personaNatural,
      nombreAcreedor: 'Luis (primo)',
      moneda: Moneda.pen,
      montoTotal: 250,
      montoPagado: 100,
      tieneInteres: false,
      estructuraPago: EstructuraPago.pagoLibre,
      fechaInicio: inicio,
      enMora: false,
      estado: EstadoDeuda.activa,
      notas: 'Datos de ejemplo',
    );
    final pagos = [
      PagoDeuda(
        id: idDemo('pago/informal/1'),
        deudaId: deuda.id,
        montoPagado: 60,
        montoCapital: 60,
        montoInteres: 0,
        fechaPago: DateTime(hoy.year, hoy.month, hoy.day - 30),
      ),
      PagoDeuda(
        id: idDemo('pago/informal/2'),
        deudaId: deuda.id,
        montoPagado: 40,
        montoCapital: 40,
        montoInteres: 0,
        fechaPago: DateTime(hoy.year, hoy.month, hoy.day - 10),
      ),
    ];
    await _crearDeudaSiFalta(deuda, pagos);
  }

  /// Los pagos demo no tienen `cuentaId` (pagos retroactivos, igual que los
  /// que registra el onboarding): no deben mover el saldo de ninguna cuenta
  /// porque corresponden a meses anteriores al de las transacciones demo.
  Future<void> _crearDeudaSiFalta(Deuda deuda, List<PagoDeuda> pagos) async {
    if (await _deudaRepository.obtenerPorId(deuda.id) == null) {
      await _deudaRepository.crear(deuda);
      _creados++;
    }
    final existentes = {
      for (final p in await _pagoDeudaRepository.obtenerPorDeuda(deuda.id))
        p.id,
    };
    for (final pago in pagos) {
      if (existentes.contains(pago.id)) continue;
      await _pagoDeudaRepository.crear(pago);
      _creados++;
    }
  }
}

class _MovimientoDemo {
  final String clave;
  final int dia;
  final String cuentaId;
  final String categoria;
  final double monto;
  final String concepto;
  final MetodoPago metodoPago;
  final TipoTransaccion tipo;

  const _MovimientoDemo(
    this.clave,
    this.dia,
    this.cuentaId,
    this.categoria,
    this.monto,
    this.concepto,
    this.metodoPago, [
    this.tipo = TipoTransaccion.gasto,
  ]);
}
