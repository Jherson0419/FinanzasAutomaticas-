-- =====================================================================
-- Fase 82 — Dirección de la deuda ("Debo" / "Me deben")
--   deudas.direccion  ('debo' | 'me_deben', DEFAULT 'debo')
-- PENDIENTE: NO se ejecutó contra Supabase. Orden y verificación en
-- LEEME_orden.md.
--
-- IDEMPOTENTE (Fase 88): se puede correr varias veces; lo que ya existe
-- no se vuelve a crear. Todo va en una transacción: si algo falla, no
-- queda nada a medias.
--
-- Compatibilidad: la app de la Fase 82 YA funciona sin esta columna
--   - al leer, una fila sin `direccion` se interpreta como 'debo'
--     (enum_mapeo_supabase.dart → direccionDeudaDeFila(null) = debo);
--   - al escribir, una deuda 'debo' NO envía la columna; solo una
--     'me_deben' la envía. Hasta correr este script, crear una deuda
--     "Me deben" en la nube falla (columna inexistente).
-- =====================================================================

begin;

alter table public.deudas
  add column if not exists direccion text not null default 'debo';

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'deudas_direccion_check'
       and conrelid = 'public.deudas'::regclass
  ) then
    alter table public.deudas
      add constraint deudas_direccion_check
      check (direccion in ('debo', 'me_deben'));
  end if;
end $$;

comment on column public.deudas.direccion is
  'Fase 82: debo = el dueño (user_id) le debe al acreedor; me_deben = '
  'el acreedor (nombre_acreedor / amigo_usuario_id) le debe al dueño.';

commit;

-- ---------------------------------------------------------------------
-- Verificación (justo después de migrar, todo es 'debo'):
--   select direccion, count(*) from public.deudas group by direccion;
--   select pg_get_constraintdef(oid) from pg_constraint
--    where conname = 'deudas_direccion_check';
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- REVISAR ANTES/DESPUÉS DE CORRER (ver "Triggers" en LEEME_orden.md):
--   * `notificar_deuda_pagada` (Fase 70): textos pensados para 'debo'.
--   * Trigger de "deuda_vinculada" (Fase 71): mismo tema de redacción.
--   * La app ya NO llama a `notificar_pago_a_amigo` en cobros.
-- ---------------------------------------------------------------------

-- =====================================================================
-- REVERTIR. Antes, las deudas 'me_deben' quedarían como 'debo' para
-- versiones viejas de la app; si existen, exportarlas primero:
--   select id, user_id, nombre_deuda from public.deudas
--    where direccion = 'me_deben';
--
-- begin;
-- alter table public.deudas drop constraint if exists deudas_direccion_check;
-- alter table public.deudas drop column if exists direccion;
-- commit;
-- =====================================================================
