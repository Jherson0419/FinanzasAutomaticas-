import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_para_consejos.dart';
import 'package:finanzas_automaticas/infrastructure/consejos/edge_function_consejos_repository.dart';

import 'helpers/supabase_cliente.dart';

/// Fase 88 (F) — payload v2 de `generar-consejos`, compatible con la
/// función ya desplegada (que solo lee los campos de v1).
void main() {
  test('mantiene los campos v1 y agrega capital, totalAPagar, saldo y '
      'direccion', () {
    final repo = EdgeFunctionConsejosRepository(clienteSupabaseFalso());
    final json = repo.resumenAJson(
      const ResumenParaConsejos(
        deudasActivas: [
          DeudaParaConsejos(
            tipoDeuda: TipoDeuda.prestamoPersonal,
            montoTotal: 4400, // total a pagar (parche Fase 79)
            montoPagado: 3520,
            interesTotal: 600,
            moneda: Moneda.pen,
            capital: 3800,
          ),
        ],
        ingresosPorCategoriaMes: [],
        gastosPorCategoriaMes: [],
        saldoTotalPorMoneda: {Moneda.pen: 1000},
        tarjetasCredito: [],
      ),
    );
    expect(json['version'], 2);
    final deuda = (json['deudasActivas'] as List).single as Map;
    // v1 intacto: una función vieja calcula 4400 − 3520 = 880.
    expect(deuda['montoTotal'], 4400);
    expect(deuda['montoPagado'], 3520);
    expect(deuda['interesTotal'], 600);
    expect(deuda['tipoDeuda'], 'prestamoPersonal');
    expect(deuda['moneda'], 'pen');
    // v2 explícito.
    expect(deuda['capital'], 3800);
    expect(deuda['totalAPagar'], 4400);
    expect(deuda['saldo'], 880);
    expect(deuda['direccion'], 'debo');
  });
}
