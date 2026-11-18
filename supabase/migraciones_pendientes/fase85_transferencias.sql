-- =====================================================================
-- Fase 85 — Transferencias entre cuentas propias ("Pagar tarjeta")
--   transacciones.tipo               + 'transferencia_salida'
--                                    + 'transferencia_entrada'
--   transacciones.transferencia_id   (liga las dos caras; NULL en el resto)
--   transacciones.categoria_id       pasa a admitir NULL (solo transferencias)
-- PENDIENTE: NO se ejecutó contra Supabase. Correr a mano en el SQL
-- Editor del proyecto. Independiente de fase82..fase84b (el orden da igual).
--
-- Compatibilidad: la app ya funciona sin estos cambios
--   - al leer, una fila sin `transferencia_id` se interpreta como NULL;
--   - al escribir, `transferencia_id` solo se envía en una transferencia.
--   Hasta correr este script, REGISTRAR UNA TRANSFERENCIA en la nube falla
--   (tipo fuera del CHECK, categoria_id NULL, columna inexistente) y no
--   deja nada escrito: la primera inserción (la salida) es la que falla.
--   Ingresos, gastos, ajustes y pagos de deuda siguen igual.
--   Sin backfill: hasta hoy no existe ninguna transferencia.
-- =====================================================================

-- 0. ANTES de correr: confirmar el nombre real del CHECK de `tipo` (el
--    nombre por defecto de Postgres es transacciones_tipo_check). Si es
--    otro, reemplazarlo abajo.
--   select conname, pg_get_constraintdef(oid)
--     from pg_constraint
--    where conrelid = 'public.transacciones'::regclass and contype = 'c';

begin;

alter table public.transacciones
  add column if not exists transferencia_id uuid null;

alter table public.transacciones
  alter column categoria_id drop not null;

alter table public.transacciones
  drop constraint if exists transacciones_tipo_check;
alter table public.transacciones
  add constraint transacciones_tipo_check
  check (tipo in ('ingreso', 'gasto',
                  'transferencia_salida', 'transferencia_entrada'));

-- Coherencia: una transferencia SIEMPRE tiene transferencia_id y nunca
-- categoría; un ingreso/gasto SIEMPRE tiene categoría y nunca
-- transferencia_id.
alter table public.transacciones
  drop constraint if exists transacciones_transferencia_check;
alter table public.transacciones
  add constraint transacciones_transferencia_check
  check (
    (tipo in ('transferencia_salida', 'transferencia_entrada')
       and transferencia_id is not null and categoria_id is null)
    or
    (tipo in ('ingreso', 'gasto')
       and transferencia_id is null and categoria_id is not null)
  );

create index if not exists transacciones_transferencia_id_idx
  on public.transacciones (transferencia_id)
  where transferencia_id is not null;

comment on column public.transacciones.transferencia_id is
  'Fase 85: liga los dos movimientos de una transferencia entre cuentas '
  'propias (salida en origen, entrada en destino). No cuentan como '
  'ingreso ni gasto.';

commit;

-- ---------------------------------------------------------------------
-- 1. REVISAR el trigger `trg_notificar_transaccion` (Fase 71): se dispara
--    en TODO insert de `transacciones`. Una transferencia inserta dos
--    filas → dos notificaciones, y si la función arma el texto con
--    "ingreso"/"gasto" según `tipo`, una transferencia caería en la rama
--    equivocada. Ver la función antes de publicar:
--   select pg_get_functiondef('public.notificar_transaccion'::regproc);
--    Sugerencia: al inicio de la función,
--      if new.transferencia_id is not null then return new; end if;
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- Verificación:
--   select tipo, count(*) from public.transacciones group by tipo;
--   -- cada transferencia tiene exactamente una salida y una entrada,
--   -- mismo monto, misma moneda y cuentas distintas (debe devolver 0
--   -- filas):
--   select transferencia_id
--     from public.transacciones
--    where transferencia_id is not null
--    group by transferencia_id
--   having count(*) <> 2
--       or count(*) filter (where tipo = 'transferencia_salida') <> 1
--       or count(distinct monto) <> 1
--       or count(distinct moneda) <> 1
--       or count(distinct cuenta_id) <> 2;
-- ---------------------------------------------------------------------

-- =====================================================================
-- REVERTIR (deshacer la fase). OJO: si ya hay transferencias, borrar sus
-- filas cambia los saldos guardados en `cuentas.saldo_actual`, que NO se
-- recalculan solos. Antes de revertir, borrar las transferencias desde la
-- app (revierte los saldos) o ajustar los saldos a mano.
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
-- alter table public.transacciones alter column categoria_id set not null;
-- alter table public.transacciones drop column if exists transferencia_id;
-- commit;
-- =====================================================================
