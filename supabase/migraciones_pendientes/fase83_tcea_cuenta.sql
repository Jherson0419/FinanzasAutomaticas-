-- =====================================================================
-- Fase 83 — TCEA de tarjetas de crédito (cuentas.tcea)
-- PENDIENTE: NO se ejecutó contra Supabase. Orden y verificación en
-- LEEME_orden.md.
--
-- IDEMPOTENTE (Fase 88): se puede correr varias veces. Una transacción.
--
-- Formato: FRACCIÓN anual (0.65 = 65 %). La app la pide en % y la divide
-- entre 100 antes de guardarla. Solo tiene sentido en tipo = 'credito'.
--
-- Compatibilidad: la app ya funciona sin esta columna
--   - al leer, una fila sin `tcea` se interpreta como null;
--   - al escribir, solo se envía `tcea` si la cuenta tiene una. Hasta
--     correr este script, GUARDAR una TCEA en la nube falla (columna
--     inexistente); las cuentas sin TCEA siguen funcionando igual.
--   - Limitación mientras tanto: borrar la TCEA de una cuenta no la anula
--     en la nube (no se envía la columna).
-- =====================================================================

begin;

alter table public.cuentas
  add column if not exists tcea numeric;

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'cuentas_tcea_check'
       and conrelid = 'public.cuentas'::regclass
  ) then
    alter table public.cuentas
      add constraint cuentas_tcea_check
      check (tcea is null or (tcea >= 0 and tcea <= 10));
  end if;
end $$;

comment on column public.cuentas.tcea is
  'Fase 83: TCEA de la tarjeta como fracción anual (0.65 = 65 %). Opcional; '
  'solo aplica a tipo = credito. Se copia a deudas.tasa_interes (en %) de '
  'la deuda vinculada (deudas.cuenta_id).';

commit;

-- ---------------------------------------------------------------------
-- Verificación:
--   select tipo, count(*) filter (where tcea is not null) as con_tcea,
--          count(*) as total
--     from public.cuentas group by tipo;
-- ---------------------------------------------------------------------

-- =====================================================================
-- REVERTIR. La tasa ya copiada a deudas.tasa_interes de las deudas de
-- tarjeta se conserva; si se quiere limpiar también:
--   update public.deudas set tasa_interes = null, tiene_interes = false
--    where cuenta_id is not null;
--
-- begin;
-- alter table public.cuentas drop constraint if exists cuentas_tcea_check;
-- alter table public.cuentas drop column if exists tcea;
-- commit;
-- =====================================================================
