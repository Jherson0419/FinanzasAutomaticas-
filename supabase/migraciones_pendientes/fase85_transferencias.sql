-- =====================================================================
-- Fase 85 — Transferencias entre cuentas propias ("Pagar tarjeta")
--   transacciones.tipo               + 'transferencia_salida'
--                                    + 'transferencia_entrada'
--   transacciones.transferencia_id   (liga las dos caras; NULL en el resto)
-- PENDIENTE: NO se ejecutó contra Supabase. Orden y verificación en
-- LEEME_orden.md. Después de este archivo va fase89_triggers.sql.
--
-- IDEMPOTENTE (Fase 88): se puede correr varias veces. Una transacción.
--
-- Datos confirmados en producción (Fase 88b):
--   * transacciones_tipo_check solo admite 'ingreso' y 'gasto' → se
--     reemplaza (los textos nuevos son EXACTAMENTE los de
--     enum_mapeo_supabase.dart: 'transferencia_salida' y
--     'transferencia_entrada').
--   * transacciones.categoria_id YA es nullable y su FK es
--     ON DELETE SET NULL: borrar una categoría deja sus movimientos con
--     categoria_id NULL. Por eso NO se exige "ingreso/gasto con categoría"
--     (impediría borrar cualquier categoría con movimientos).
--   * notificar_transaccion no notifica tipos distintos de gasto/ingreso:
--     las transferencias no generan avisos.
--
-- Compatibilidad: la app ya funciona sin estos cambios
--   - al leer, una fila sin `transferencia_id` se interpreta como NULL;
--   - al escribir, `transferencia_id` solo se envía en una transferencia.
--   Hasta correr este script, REGISTRAR UNA TRANSFERENCIA en la nube falla
--   (tipo fuera del CHECK, columna inexistente) y no deja nada escrito: la
--   primera inserción (la salida) es la que falla.
--   Sin backfill: hasta hoy no existe ninguna transferencia.
-- =====================================================================

begin;

alter table public.transacciones
  add column if not exists transferencia_id uuid null;

-- Sin efecto en producción (ya es nullable); se deja por si el esquema
-- de staging viniera de un volcado más viejo.
alter table public.transacciones
  alter column categoria_id drop not null;

do $$
declare
  definicion text;
begin
  -- 1. CHECK de `tipo`: reemplazar el de solo ingreso/gasto por uno que
  --    admita las transferencias. Si ya las admite, no se toca.
  select pg_get_constraintdef(oid) into definicion
    from pg_constraint
   where conname = 'transacciones_tipo_check'
     and conrelid = 'public.transacciones'::regclass;
  if definicion is not null and definicion not ilike '%transferencia_salida%'
  then
    alter table public.transacciones
      drop constraint transacciones_tipo_check;
    definicion := null;
  end if;
  if definicion is null then
    alter table public.transacciones
      add constraint transacciones_tipo_check
      check (tipo in ('ingreso', 'gasto',
                      'transferencia_salida', 'transferencia_entrada'));
  end if;

  -- 2. Coherencia de transferencias:
  --    transferencia  → con transferencia_id y SIN categoría;
  --    ingreso/gasto  → SIN transferencia_id (la categoría puede ser NULL
  --                     por el ON DELETE SET NULL de su FK).
  --    Una versión anterior de este archivo exigía además categoría en
  --    ingreso/gasto: si quedó creada (p. ej. en staging), se reemplaza.
  select pg_get_constraintdef(oid) into definicion
    from pg_constraint
   where conname = 'transacciones_transferencia_check'
     and conrelid = 'public.transacciones'::regclass;
  if definicion is not null and definicion ilike '%categoria_id IS NOT NULL%'
  then
    alter table public.transacciones
      drop constraint transacciones_transferencia_check;
    definicion := null;
  end if;
  if definicion is null then
    alter table public.transacciones
      add constraint transacciones_transferencia_check
      check (
        (tipo in ('transferencia_salida', 'transferencia_entrada')
           and transferencia_id is not null and categoria_id is null)
        or
        (tipo in ('ingreso', 'gasto') and transferencia_id is null)
      );
  end if;
end $$;

create index if not exists transacciones_transferencia_id_idx
  on public.transacciones (transferencia_id)
  where transferencia_id is not null;

comment on column public.transacciones.transferencia_id is
  'Fase 85: liga los dos movimientos de una transferencia entre cuentas '
  'propias (salida en origen, entrada en destino). No cuentan como '
  'ingreso ni gasto.';

commit;

-- ---------------------------------------------------------------------
-- Verificación:
--   select tipo, count(*) from public.transacciones group by tipo;
--
--   -- transacciones con categoría NULL, por tipo: en ingreso/gasto solo
--   -- deberían ser las de categorías borradas (ON DELETE SET NULL); en
--   -- transferencias, TODAS.
--   select tipo,
--          count(*) filter (where categoria_id is null) as sin_categoria,
--          count(*) as total
--     from public.transacciones
--    group by tipo
--    order by tipo;
--
--   -- cada transferencia: una salida y una entrada, mismo monto y
--   -- moneda, cuentas distintas (debe devolver 0 filas):
--   select transferencia_id
--     from public.transacciones
--    where transferencia_id is not null
--    group by transferencia_id
--   having count(*) <> 2
--       or count(*) filter (where tipo = 'transferencia_salida') <> 1
--       or count(distinct monto) <> 1
--       or count(distinct moneda) <> 1
--       or count(distinct cuenta_id) <> 2;
--
--   select conname, pg_get_constraintdef(oid) from pg_constraint
--    where conname in ('transacciones_tipo_check',
--                      'transacciones_transferencia_check');
-- ---------------------------------------------------------------------

-- =====================================================================
-- REVERTIR. OJO: si ya hay transferencias, borrar sus filas cambia los
-- saldos guardados en `cuentas.saldo_actual`, que NO se recalculan solos.
-- Antes de revertir, borrar las transferencias desde la app (revierte los
-- saldos) o ajustar los saldos a mano. `categoria_id` se deja nullable:
-- así estaba en producción antes de esta fase.
--
-- begin;
-- alter table public.transacciones
--   drop constraint if exists transacciones_transferencia_check;
-- drop index if exists public.transacciones_transferencia_id_idx;
-- -- solo si no quedan transferencias:
-- -- delete from public.transacciones where transferencia_id is not null;
-- alter table public.transacciones
--   drop constraint if exists transacciones_tipo_check;
-- alter table public.transacciones
--   add constraint transacciones_tipo_check
--   check (tipo in ('ingreso', 'gasto'));
-- alter table public.transacciones drop column if exists transferencia_id;
-- commit;
-- =====================================================================
