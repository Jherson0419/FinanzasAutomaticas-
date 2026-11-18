import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/capacidad_pago.dart';
import 'package:finanzas_automaticas/domain/consejero.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/plan_pago.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/preferencias_consejero_repository_shared_prefs.dart';

/// Fase 86 (D) — consejero de reglas locales.
final _ahora = DateTime(2026, 11, 16, 10);

Deuda _libre(
  String id,
  double capital, {
  double? tea,
  double? minimo,
  bool tieneInteres = true,
  DateTime? proxima,
  bool enMora = false,
  int? diasMora,
  DireccionDeuda direccion = DireccionDeuda.debo,
  String? cuentaId,
}) => Deuda(
  id: id,
  nombreDeuda: 'Deuda $id',
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'Banco',
  moneda: Moneda.pen,
  montoTotal: capital,
  montoPagado: 0,
  tieneInteres: tieneInteres,
  tasaInteres: tea,
  estructuraPago: EstructuraPago.pagoLibre,
  pagoMinimo: minimo,
  fechaInicio: DateTime(2026, 1, 1),
  proximaFechaPago: proxima,
  enMora: enMora,
  diasMora: diasMora,
  estado: enMora ? EstadoDeuda.enMora : EstadoDeuda.activa,
  direccion: direccion,
  cuentaId: cuentaId,
);

/// 10 cuotas de 300 (sin interés), 2 pagadas; próxima en [proxima].
Deuda _cuotas(DateTime proxima) => Deuda(
  id: 'cuotas',
  nombreDeuda: 'Préstamo',
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'BCP',
  moneda: Moneda.pen,
  montoTotal: 3000,
  montoPagado: 600,
  tieneInteres: false,
  estructuraPago: EstructuraPago.cuotasFijas,
  numeroCuotasTotal: 10,
  numeroCuotasPagadas: 2,
  montoCuota: 300,
  periodicidadCuotas: PeriodicidadCuota.mensual,
  fechaInicio: DateTime(2026, 9, 18),
  proximaFechaPago: proxima,
  enMora: false,
  estado: EstadoDeuda.activa,
);

Cuenta _debito(double saldo) => Cuenta(
  id: 'debito',
  nombre: 'Débito BCP',
  tipo: TipoCuenta.debito,
  moneda: Moneda.pen,
  saldoActual: saldo,
);

Cuenta _tarjeta(double saldo, {DateTime? fechaPago, double? minimo}) => Cuenta(
  id: 'visa',
  nombre: 'Visa BCP',
  tipo: TipoCuenta.credito,
  moneda: Moneda.pen,
  saldoActual: saldo,
  lineaCredito: 1000,
  fechaCorte: DateTime(2026, 10, 1),
  fechaPago: fechaPago,
  pagoMinimo: minimo,
);

var _n = 0;
Transaccion _t(
  DateTime fecha,
  TipoTransaccion tipo,
  double monto, {
  String categoriaId = 'comida',
  String cuentaId = 'debito',
}) => Transaccion(
  id: 't${_n++}',
  cuentaId: cuentaId,
  categoriaId: tipo.esTransferencia ? null : categoriaId,
  monto: monto,
  moneda: Moneda.pen,
  tipo: tipo,
  concepto: '',
  metodoPago: MetodoPago.efectivo,
  esRecurrente: false,
  fuenteCaptura: FuenteCaptura.manual,
  fecha: fecha,
  transferenciaId: tipo.esTransferencia ? 'tr$_n' : null,
);

/// 3 meses completos (ago–oct): ingreso 3000, gasto [comida] cada mes.
List<Transaccion> _historial({double comida = 100}) => [
  for (final mes in [8, 9, 10]) ...[
    _t(
      DateTime(2026, mes, 1),
      TipoTransaccion.ingreso,
      3000,
      categoriaId: 'sueldo',
    ),
    _t(DateTime(2026, mes, 10), TipoTransaccion.gasto, comida),
    _t(
      DateTime(2026, mes, 11),
      TipoTransaccion.gasto,
      900,
      categoriaId: 'servicios',
    ),
  ],
];

ContextoConsejero _ctx({
  List<Deuda> deudas = const [],
  List<Cuenta>? cuentas,
  List<Transaccion> transacciones = const [],
  List<PagoDeuda> pagos = const [],
  double extra = 0,
  EstrategiaPago? estrategia,
}) => ContextoConsejero(
  ahora: _ahora,
  deudas: deudas,
  cuentas: cuentas ?? [_debito(500)],
  transacciones: transacciones,
  pagosDeuda: pagos,
  extraMensual: extra,
  estrategia: estrategia,
  nombresCategoria: const {'comida': 'Comida', 'servicios': 'Servicios'},
);

void main() {
  group('1. vence en ≤ 3 días', () {
    test('dispara, compara con la cuenta con más saldo (alcanza / falta)', () {
      final c = reglaVencePronto(
        _ctx(deudas: [_cuotas(DateTime(2026, 11, 18))]),
      ).single;
      expect(c.titulo, 'Paga S/ 300.00 de Préstamo');
      expect(c.texto, contains('vence en 2 días'));
      expect(c.texto, contains('Débito BCP, tiene S/ 500.00: te alcanza'));
      expect(c.prioridad, 98);
      final falta = reglaVencePronto(
        _ctx(
          deudas: [_cuotas(DateTime(2026, 11, 18))],
          cuentas: [_debito(200)],
        ),
      ).single;
      expect(falta.texto, contains('te faltan S/ 100.00'));
    });

    test('límite: a 3 días sí, a 4 no; lo vencido no (es mora)', () {
      expect(
        reglaVencePronto(_ctx(deudas: [_cuotas(DateTime(2026, 11, 19))])),
        hasLength(1),
      );
      expect(
        reglaVencePronto(_ctx(deudas: [_cuotas(DateTime(2026, 11, 20))])),
        isEmpty,
      );
      expect(
        reglaVencePronto(_ctx(deudas: [_cuotas(DateTime(2026, 11, 15))])),
        isEmpty,
      );
    });

    test(
      'tarjeta: fecha de pago de la cuenta, su mínimo y "Pagar tarjeta"',
      () {
        final c = reglaVencePronto(
          _ctx(
            deudas: [
              _libre(
                't',
                1000,
                minimo: 120,
                cuentaId: 'visa',
              ).copyWith(montoPagado: 600),
            ],
            cuentas: [
              _debito(500),
              _tarjeta(-400, fechaPago: DateTime(2026, 10, 17), minimo: 120),
            ],
          ),
        ).single;
        expect(c.titulo, contains('S/ 120.00'));
        expect(c.texto, contains('mañana'));
        expect(c.accion!.ruta, '/transferencias/nueva');
      },
    );

    test('sin monto conocido: avisa la fecha sin inventar cifras', () {
      final c = reglaVencePronto(
        _ctx(deudas: [_libre('x', 500, proxima: DateTime(2026, 11, 16))]),
      ).single;
      expect(c.titulo, 'Deuda x vence hoy');
      expect(c.texto, isNot(contains('S/')));
    });
  });

  group('2. pagar primero', () {
    final a = _libre('A', 3000, tea: 60, minimo: 150);
    final b = _libre('B', 1500, tea: 20, minimo: 100);

    test('avalancha: la de mayor tasa y el costo de esperar un mes', () {
      // Elegida a mano: con estrategia `null` manda la recomendada, que
      // aquí es la bola de nieve (diferencia "casi igual").
      final c = reglaPagaPrimero(
        _ctx(deudas: [b, a], estrategia: EstrategiaPago.avalancha),
      ).single;
      final costo = 3000 * (math.pow(1.6, 1 / 12) - 1);
      expect(c.datos['deudaId'], 'A');
      expect(c.datos['costoMes'], closeTo(costo, 1e-9));
      expect(c.texto, contains('60 % al año'));
      expect(c.titulo, 'Pon tu pago extra en Deuda A');
    });

    test('bola de nieve: la más pequeña', () {
      final c = reglaPagaPrimero(
        _ctx(deudas: [a, b], estrategia: EstrategiaPago.bolaDeNieve),
      ).single;
      expect(c.datos['deudaId'], 'B');
      expect(c.texto, contains('más pequeña'));
    });

    test('no dispara con una sola deuda ni si la primera no tiene tasa', () {
      expect(reglaPagaPrimero(_ctx(deudas: [a])), isEmpty);
      expect(
        reglaPagaPrimero(
          _ctx(
            deudas: [
              _libre('X', 100, minimo: 10),
              _libre('Y', 200, minimo: 10, tieneInteres: false),
            ],
            estrategia: EstrategiaPago.bolaDeNieve,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('3. capacidad por encima del extra', () {
    // Seguro: 3000 − 1000 − 250 (mínimos) − 300 (colchón) = 1450.
    final deudas = [
      _libre('A', 3000, tea: 60, minimo: 150),
      _libre('B', 1500, tea: 20, minimo: 100),
    ];
    test('dispara con la diferencia', () {
      final c = reglaCapacidad(
        _ctx(deudas: deudas, transacciones: _historial(), extra: 100),
      ).single;
      expect(c.titulo, 'Podrías pagar S/ 1,350.00 más');
      expect(c.datos['recomendado'], 1450);
    });

    test('límite: diferencia de S/ 10 sí, de 9.99 no; sin datos no', () {
      expect(
        reglaCapacidad(
          _ctx(deudas: deudas, transacciones: _historial(), extra: 1440),
        ),
        hasLength(1),
      );
      expect(
        reglaCapacidad(
          _ctx(deudas: deudas, transacciones: _historial(), extra: 1440.01),
        ),
        isEmpty,
      );
      expect(reglaCapacidad(_ctx(deudas: deudas)), isEmpty);
    });

    test('si no alcanza, no sugiere pagar más', () {
      expect(
        reglaCapacidad(
          _ctx(
            deudas: [_libre('A', 9000, tea: 60, minimo: 2500)],
            transacciones: _historial(),
          ),
        ),
        isEmpty,
      );
    });
  });

  group('4. uso de tarjeta', () {
    ContextoConsejero conUso(double saldo) =>
        _ctx(cuentas: [_debito(500), _tarjeta(saldo)]);
    test('30 % no; 30.1 % sí (prioridad 40); 70 % 40; 70.1 % sube a 80', () {
      expect(reglaUsoTarjeta(conUso(-300)), isEmpty);
      expect(reglaUsoTarjeta(conUso(-301)).single.prioridad, 40);
      expect(reglaUsoTarjeta(conUso(-700)).single.prioridad, 40);
      final alto = reglaUsoTarjeta(conUso(-701)).single;
      expect(alto.prioridad, 80);
      expect(alto.titulo, 'Usas el 70 % de tu Visa BCP');
      expect(alto.huella, 'alto');
    });
    test('sin línea no dispara', () {
      expect(
        reglaUsoTarjeta(
          _ctx(
            cuentas: [
              const Cuenta(
                id: 'v',
                nombre: 'V',
                tipo: TipoCuenta.credito,
                moneda: Moneda.pen,
                saldoActual: -900,
              ),
            ],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('5. mora', () {
    test('dispara con días; no si está al día o si es "me deben"', () {
      final c = reglaMora(
        _ctx(deudas: [_libre('M', 500, enMora: true, diasMora: 12)]),
      ).single;
      expect(c.prioridad, 90);
      expect(c.texto, contains('12 días'));
      expect(reglaMora(_ctx(deudas: [_libre('M', 500)])), isEmpty);
      expect(
        reglaMora(
          _ctx(
            deudas: [
              _libre('L', 500, enMora: true, direccion: DireccionDeuda.meDeben),
            ],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('6. falta la tasa', () {
    test('dispara con acceso a editar; no si tiene tasa', () {
      final c = reglaFaltaTasa(
        _ctx(deudas: [_libre('S', 500, minimo: 50)]),
      ).single;
      expect(c.accion!.ruta, '/deudas/nueva');
      expect(c.accion!.argumentos, 'S');
      expect(
        reglaFaltaTasa(_ctx(deudas: [_libre('S', 500, tea: 30)])),
        isEmpty,
      );
      // Sin interés (0 %) no "falta" nada.
      expect(
        reglaFaltaTasa(_ctx(deudas: [_libre('S', 500, tieneInteres: false)])),
        isEmpty,
      );
    });
    test('tarjeta sin TCEA: lleva a la cuenta', () {
      final c = reglaFaltaTasa(
        _ctx(deudas: [_libre('T', 500, cuentaId: 'visa', tea: null)]),
      ).single;
      expect(c.accion!.ruta, '/cuentas/nueva');
      expect(c.accion!.argumentos, 'visa');
    });
  });

  group('7. gasto de una categoría', () {
    List<Transaccion> conMes(double comidaNov) => [
      ..._historial(),
      _t(DateTime(2026, 11, 5), TipoTransaccion.gasto, comidaNov),
    ];
    test('151 > 1.5 × 100 dispara; 150 no (límite)', () {
      final c = reglaGastoCategoria(_ctx(transacciones: conMes(151))).single;
      expect(c.titulo, 'Este mes llevas S/ 151.00 en Comida');
      expect(c.texto, contains('1.5 veces'));
      expect(reglaGastoCategoria(_ctx(transacciones: conMes(150))), isEmpty);
    });
    test('sin los 3 meses anteriores con datos no dispara', () {
      final sinAgosto = conMes(999).where((t) => t.fecha.month != 8).toList();
      expect(reglaGastoCategoria(_ctx(transacciones: sinAgosto)), isEmpty);
    });
    test('las transferencias no cuentan', () {
      expect(
        reglaGastoCategoria(
          _ctx(
            transacciones: [
              ..._historial(),
              _t(
                DateTime(2026, 11, 5),
                TipoTransaccion.transferenciaSalida,
                5000,
              ),
            ],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('8. abono sugerido', () {
    final deudas = [
      _libre('A', 3000, tea: 60, minimo: 150),
      _libre('B', 1500, tea: 20, minimo: 100),
    ];
    test('usa la simulación real', () {
      final c = reglaAbonoSugerido(_ctx(deudas: deudas, extra: 100)).single;
      final esperado = simularEscenario(
        deudas: deudas,
        moneda: Moneda.pen,
        extraActual: 100,
        estrategiaActual: EstrategiaPago.avalancha,
        extraEscenario: 100,
        estrategiaEscenario: EstrategiaPago.avalancha,
        pagoUnico: PagoUnico(mes: 1, monto: 100),
      );
      expect(c.datos['ahorro'], esperado.interesAhorrado);
      expect(c.datos['deudaId'], 'A');
      expect(c.titulo, 'Si abonas S/ 100.00 a Deuda A');
      expect(c.texto, startsWith('Ahorras S/ '));
    });
    test('sin interés no hay ahorro: no se emite; sin deudas tampoco', () {
      expect(
        reglaAbonoSugerido(
          _ctx(deudas: [_libre('Z', 1000, tieneInteres: false, minimo: 100)]),
        ),
        isEmpty,
      );
      expect(reglaAbonoSugerido(_ctx()), isEmpty);
    });
  });

  group('motor', () {
    final muchos = _ctx(
      deudas: [
        _cuotas(DateTime(2026, 11, 17)), // vence (99)
        _libre('M', 500, enMora: true, diasMora: 5, tea: 30), // mora (90)
        _libre('A', 3000, tea: 60, minimo: 150), // paga primero (60) …
        _libre('S', 400, minimo: 40), // falta tasa (30)
      ],
      cuentas: [_debito(500), _tarjeta(-800)], // uso alto (80)
    );

    test('ordena por prioridad y muestra a lo sumo 3', () {
      final todos = generarConsejos(muchos);
      expect([
        for (var i = 1; i < todos.length; i++) todos[i - 1].prioridad,
      ], everyElement(isA<int>()));
      for (var i = 1; i < todos.length; i++) {
        expect(
          todos[i - 1].prioridad,
          greaterThanOrEqualTo(todos[i].prioridad),
        );
      }
      final v = consejosVisibles(todos, const {}, _ahora);
      expect(v.principales, hasLength(maximoConsejosVisibles));
      expect(v.principales.map((c) => c.regla), [
        ReglaConsejo.vencePronto,
        ReglaConsejo.mora,
        ReglaConsejo.usoTarjeta,
      ]);
      expect(v.mas, isNotEmpty);
      expect(v.principales.length + v.mas.length, todos.length);
    });

    test('descartar: oculto mientras la huella no cambie', () {
      final todos = generarConsejos(muchos);
      final tarjeta = todos.firstWhere(
        (c) => c.regla == ReglaConsejo.usoTarjeta,
      );
      final estados = {
        tarjeta.id: EstadoConsejo(
          tipo: TipoEstadoConsejo.descartado,
          fecha: _ahora,
          huella: tarjeta.huella,
        ),
      };
      final v = consejosVisibles(
        todos,
        estados,
        _ahora.add(const Duration(days: 365)),
      );
      expect(
        [...v.principales, ...v.mas].any((c) => c.id == tarjeta.id),
        isFalse,
      );
      // Pasa de "alto" (>70 %) a "medio": la huella cambia → vuelve.
      final medio = generarConsejos(
        _ctx(cuentas: [_debito(500), _tarjeta(-400)]),
      );
      expect(
        consejosVisibles(medio, estados, _ahora).principales.map((c) => c.id),
        contains(tarjeta.id),
      );
    });

    test('posponer: oculto 7 días, vuelve al 7.º', () {
      final todos = generarConsejos(muchos);
      final primero = todos.first;
      final estados = {
        primero.id: EstadoConsejo(
          tipo: TipoEstadoConsejo.pospuesto,
          fecha: _ahora,
          huella: primero.huella,
        ),
      };
      bool visible(DateTime cuando) => consejosVisibles(
        todos,
        estados,
        cuando,
      ).principales.any((c) => c.id == primero.id);
      expect(visible(_ahora.add(const Duration(days: 6, hours: 23))), isFalse);
      expect(visible(_ahora.add(const Duration(days: 7))), isTrue);
    });

    test('sin datos: ninguna regla emite nada', () {
      expect(generarConsejos(_ctx(cuentas: const [])), isEmpty);
      expect(consejosVisibles(const [], const {}, _ahora).vacio, isTrue);
    });

    test('ids únicos y estables', () {
      final a = generarConsejos(muchos).map((c) => c.id).toList();
      final b = generarConsejos(muchos).map((c) => c.id).toList();
      expect(a, b);
      expect(a.toSet(), hasLength(a.length));
    });
  });

  test('revisión semanal: últimos 7 días y próximos 7', () {
    final ctx = _ctx(
      deudas: [_cuotas(DateTime(2026, 11, 20))],
      cuentas: [_debito(500), _tarjeta(-400)],
      transacciones: [
        _t(DateTime(2026, 11, 12), TipoTransaccion.ingreso, 1000),
        _t(DateTime(2026, 11, 14), TipoTransaccion.gasto, 80),
        _t(DateTime(2026, 11, 2), TipoTransaccion.gasto, 999), // > 7 días
        _t(
          DateTime(2026, 11, 13),
          TipoTransaccion.transferenciaEntrada,
          200,
          cuentaId: 'visa',
        ), // pagar tarjeta
        _t(DateTime(2026, 11, 13), TipoTransaccion.transferenciaSalida, 200),
      ],
      pagos: [
        PagoDeuda(
          id: 'p',
          deudaId: 'cuotas',
          montoPagado: 300,
          fechaPago: DateTime(2026, 11, 10),
          numeroCuota: 2,
        ),
        PagoDeuda(
          id: 'viejo',
          deudaId: 'cuotas',
          montoPagado: 300,
          fechaPago: DateTime(2026, 10, 1),
          numeroCuota: 1,
        ),
      ],
    );
    final r = revisionSemanal(ctx);
    expect(r.ingresos, 1000);
    expect(r.gastado, 80);
    expect(r.pagadoADeudas, 500);
    expect(r.proximos.single.fecha, DateTime(2026, 11, 20));
    expect(r.proximos.single.monto, 300);
  });

  test('cero IA y cero red: el dominio no importa nada de red ni de IA', () {
    for (final archivo in [
      'lib/domain/consejero.dart',
      'lib/domain/capacidad_pago.dart',
    ]) {
      final codigo = File(archivo).readAsStringSync();
      final imports = RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(codigo).map((m) => m.group(1)!);
      for (final i in imports) {
        expect(i, isNot(startsWith('package:')), reason: '$archivo: $i');
        expect(i, isNot(contains('http')));
        expect(i, isNot(contains('supabase')));
        expect(i, isNot(contains('gemini')));
        expect(i, isNot(contains('infrastructure')));
      }
    }
  });

  test(
    'estado en SharedPreferences: ida y vuelta; valor ilegible se ignora',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferenciasConsejeroRepositorySharedPrefs(prefs);
      expect(repo.leer(), isEmpty);
      await repo.guardar(
        'usoTarjeta:visa',
        EstadoConsejo(
          tipo: TipoEstadoConsejo.descartado,
          fecha: _ahora,
          huella: 'alto',
        ),
      );
      final leido = repo.leer()['usoTarjeta:visa']!;
      expect(leido.tipo, TipoEstadoConsejo.descartado);
      expect(leido.fecha, _ahora);
      expect(leido.huella, 'alto');
      await prefs.setString(
        PreferenciasConsejeroRepositorySharedPrefs.clave,
        'no es json',
      );
      expect(repo.leer(), isEmpty);
    },
  );

  test('capacidad inyectada: la regla 3 no recalcula', () {
    final c = reglaCapacidad(
      _ctx(deudas: [_libre('A', 3000, tea: 60, minimo: 150)]),
      capacidad: const CapacidadSinDatos(
        moneda: Moneda.pen,
        otrasMonedas: [],
        mesesConDatos: 1,
      ),
    );
    expect(c, isEmpty);
  });
}
