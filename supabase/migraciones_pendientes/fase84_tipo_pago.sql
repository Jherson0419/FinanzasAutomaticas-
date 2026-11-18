-- =====================================================================
-- Fase 84 — Abonos a capital y adelanto de cuotas
--   pagos_deuda.tipo               ('cuota' | 'abono_capital')
--   deudas.monto_abonado_capital   (suma de los abonos a capital)
-- PENDIENTE: NO se ejecutó contra Supabase. Correr a mano en el SQL
-- Editor del proyecto. Independiente de fase82 / fase83 (el orden da
-- igual).
--
-- Compatibilidad: la app ya funciona sin estas columnas
--   - al leer, una fila sin `tipo` se interpreta como 'cuota' y una sin
--     `monto_abonado_capital` como 0;
--   - al escribir, `tipo` solo se envía en un abono ('abono_capital') y
--     `monto_abonado_capital` solo si es distinto de 0. Hasta correr este
--     script, REGISTRAR UN ABONO A CAPITAL en la nube falla (columna
--     inexistente); pagar cuotas y adelantar cuotas siguen funcionando.
--   - Los DEFAULT ('cuota' y 0) dejan las filas existentes correctas sin
--     backfill: hasta hoy todos los pagos eran cuotas y no había abonos.
-- =====================================================================

begin;

alter table public.pagos_deuda
  add column if not exists tipo text not null default 'cuota';

alter table public.pagos_deuda
  drop constraint if exists pagos_deuda_tipo_check;
alter table public.pagos_deuda
  add constraint pagos_deuda_tipo_check
  check (tipo in ('cuota', 'abono_capital'));

comment on column public.pagos_deuda.tipo is
  'Fase 84: cuota (pago normal, usa numero_cuota en cuotas fijas) o '
  'abono_capital (pago extra a capital: no consume cuota, numero_cuota null).';

alter table public.deudas
  add column if not exists monto_abonado_capital numeric not null default 0;

alter table public.deudas
  drop constraint if exists deudas_monto_abonado_capital_check;
alter table public.deudas
  add constraint deudas_monto_abonado_capital_check
  check (monto_abonado_capital >= 0);

comment on column public.deudas.monto_abonado_capital is
  'Fase 84: suma de los abonos a capital (pagos_deuda.tipo = abono_capital). '
  'Total a pagar en cuotas fijas = monto_cuota * numero_cuotas_total + '
  'monto_abonado_capital.';

commit;

-- ---------------------------------------------------------------------
-- Verificación:
--   select tipo, count(*) from public.pagos_deuda group by tipo;
--   select count(*) filter (where monto_abonado_capital > 0) as con_abonos,
--          count(*) as total
--     from public.deudas;
--   -- coherencia: lo abonado en la deuda = suma de sus pagos abono_capital
--   select d.id, d.monto_abonado_capital, coalesce(sum(p.monto_pagado), 0)
--     from public.deudas d
--     left join public.pagos_deuda p
--       on p.deuda_id = d.id and p.tipo = 'abono_capital'
--    group by d.id, d.monto_abonado_capital
--   having abs(d.monto_abonado_capital - coalesce(sum(p.monto_pagado), 0))
--          > 0.01;   -- debe devolver 0 filas
-- ---------------------------------------------------------------------

-- =====================================================================
-- REVERTIR (deshacer la fase). OJO: si ya hay abonos registrados, al
-- borrar las columnas esos pagos pasarían a leerse como cuotas y el
-- total a pagar de la deuda perdería lo abonado. Revisar antes con la
-- verificación de arriba.
--
-- begin;
-- alter table public.pagos_deuda drop constraint if exists pagos_deuda_tipo_check;
-- alter table public.pagos_deuda drop column if exists tipo;
-- alter table public.deudas
--   drop constraint if exists deudas_monto_abonado_capital_check;
-- alter table public.deudas drop column if exists monto_abonado_capital;
-- commit;
-- =====================================================================
