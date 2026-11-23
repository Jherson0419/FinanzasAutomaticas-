// Pruebas de compatibilidad del payload (Fase 88).
// Ejecutar: deno test supabase/functions/generar-consejos/normalizar_test.ts
// (no se ejecutaron en el entorno de la Fase 88: no había Deno instalado).

import { assertEquals } from 'jsr:@std/assert@1';
import {
  lineaDeuda,
  normalizarDeuda,
  normalizarDeudas,
  sinTransferencias,
} from './normalizar.ts';

Deno.test('v1 (apps publicadas): saldo = montoTotal − montoPagado', () => {
  const n = normalizarDeuda({
    tipoDeuda: 'prestamoPersonal',
    montoTotal: 4400, // total a pagar (parche de la Fase 79)
    montoPagado: 3520,
    interesTotal: 600,
    moneda: 'pen',
  })!;
  assertEquals(n.saldo, 880);
  assertEquals(n.capital, null);
  assertEquals(
    lineaDeuda(n),
    '- Tipo: prestamoPersonal, pendiente: 880.00 PEN, interés total: 600.00',
  );
});

Deno.test('v2: el saldo explícito manda; muestra el capital', () => {
  const n = normalizarDeuda({
    tipoDeuda: 'prestamoPersonal',
    montoTotal: 4400,
    montoPagado: 3520,
    interesTotal: 600,
    moneda: 'pen',
    capital: 3800,
    totalAPagar: 4400,
    saldo: 812.5, // p. ej. con una última cuota parcial (Fase 84b)
    direccion: 'debo',
  })!;
  assertEquals(n.saldo, 812.5);
  assertEquals(n.capital, 3800);
  assertEquals(
    lineaDeuda(n),
    '- Tipo: prestamoPersonal, pendiente: 812.50 PEN, capital: 3800.00, ' +
      'interés total: 600.00',
  );
});

Deno.test('v2 sin saldo: totalAPagar − montoPagado; nunca negativo', () => {
  const n = normalizarDeuda({
    tipoDeuda: 'compraCuotas',
    montoTotal: 2000,
    montoPagado: 3000,
    interesTotal: null,
    moneda: 'pen',
    totalAPagar: 2520,
  })!;
  assertEquals(n.saldo, 0);
});

Deno.test('excluye "me deben" y transferencias', () => {
  assertEquals(
    normalizarDeudas([
      {
        tipoDeuda: 'deudaInformal',
        montoTotal: 380,
        montoPagado: 0,
        interesTotal: null,
        moneda: 'pen',
        direccion: 'me_deben',
      },
    ]),
    [],
  );
  assertEquals(
    sinTransferencias([
      { categoriaNombre: 'Comida', monto: 100, moneda: 'pen' },
      {
        categoriaNombre: 'Transferencia',
        monto: 500,
        moneda: 'pen',
        esTransferencia: true,
      },
    ]).map((c) => c.categoriaNombre),
    ['Comida'],
  );
});
