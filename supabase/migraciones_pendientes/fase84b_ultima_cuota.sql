-- =====================================================================
-- Fase 84b — Última cuota parcial tras un abono a capital
--   deudas.monto_ultima_cuota   (null = la última cuota es la normal)
-- PENDIENTE: NO se ejecutó contra Supabase. Correr DESPUÉS de (o junto
-- con) fase84_tipo_pago.sql: ambas son necesarias para registrar abonos
-- a capital en la nube. Orden y verificación en LEEME_orden.md.
--
-- IDEMPOTENTE (Fase 88): se puede correr varias veces. Una transacción.
--
-- Compatibilidad: la app ya funciona sin esta columna
--   - al leer, una fila sin `monto_ultima_cuota` (o con NULL) se
--     interpreta como "última cuota normal";
--   - al escribir, `monto_ultima_cuota` se envía si la deuda tiene abonos
--     (monto_abonado_capital <> 0) o un valor no nulo. Una deuda sin
--     abonos nunca la manda. Hasta correr este script, REGISTRAR UN ABONO
--     A CAPITAL en la nube falla (columna inexistente) — y también
--     cualquier pago o edición POSTERIOR de una deuda que ya tenga abonos.
--   - Sin backfill: hasta hoy ninguna deuda tiene última cuota parcial.
-- =====================================================================

begin;

alter table public.deudas
  add column if not exists monto_ultima_cuota numeric null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'deudas_monto_ultima_cuota_check'
       and conrelid = 'public.deudas'::regclass
  ) then
    -- 0 < F <= cuota (la app nunca guarda 0: sin parcial guarda NULL).
    alter table public.deudas
      add constraint deudas_monto_ultima_cuota_check
      check (
        monto_ultima_cuota is null
        or (monto_ultima_cuota > 0
            and (monto_cuota is null
                 or monto_ultima_cuota <= monto_cuota + 0.01))
      );
  end if;
end $$;

comment on column public.deudas.monto_ultima_cuota is
  'Fase 84b: monto de la última cuota cuando un abono a capital la dejó '
  'menor que monto_cuota. NULL = última cuota normal. Total a pagar en '
  'cuotas fijas = monto_cuota * (numero_cuotas_total - 1) + '
  'monto_ultima_cuota + monto_abonado_capital.';

commit;

-- ---------------------------------------------------------------------
-- Verificación:
--   select count(*) filter (where monto_ultima_cuota is not null)
--            as con_ultima_parcial,
--          count(*) as total
--     from public.deudas;
--   -- coherencia: solo deudas en cuotas fijas con abonos tienen parcial
--   select id, estructura_pago, monto_abonado_capital, monto_ultima_cuota
--     from public.deudas
--    where monto_ultima_cuota is not null
--      and (estructura_pago <> 'cuotas_fijas'
--           or monto_abonado_capital <= 0);   -- debe devolver 0 filas
-- ---------------------------------------------------------------------

-- =====================================================================
-- REVERTIR. OJO: si alguna deuda ya tiene última cuota parcial, al borrar
-- la columna su total a pagar vuelve a contar la última cuota completa
-- (sobrestima el saldo hasta en una cuota).
--
-- begin;
-- alter table public.deudas
--   drop constraint if exists deudas_monto_ultima_cuota_check;
-- alter table public.deudas drop column if exists monto_ultima_cuota;
-- commit;
-- =====================================================================
