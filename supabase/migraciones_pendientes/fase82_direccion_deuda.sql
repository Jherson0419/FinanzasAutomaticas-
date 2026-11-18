-- =====================================================================
-- Fase 82 — Dirección de la deuda ("Debo" / "Me deben")
-- PENDIENTE: NO se ejecutó contra Supabase. Correr a mano en el SQL
-- Editor del proyecto (o con `supabase db push` si se mueve a
-- supabase/migrations/).
--
-- Compatibilidad: la app de la Fase 82 YA funciona sin esta columna
--   - al leer, una fila sin `direccion` se interpreta como 'debo'
--     (enum_mapeo_supabase.dart → direccionDeudaDeFila(null) = debo);
--   - al escribir, una deuda 'debo' NO envía la columna; solo una
--     'me_deben' la envía. Hasta correr este script, crear una deuda
--     "Me deben" en la nube falla (columna inexistente) — las deudas
--     normales siguen funcionando igual.
-- =====================================================================

begin;

alter table public.deudas
  add column if not exists direccion text not null default 'debo';

-- Restricción con nombre propio para poder quitarla al revertir.
alter table public.deudas
  drop constraint if exists deudas_direccion_check;
alter table public.deudas
  add constraint deudas_direccion_check
  check (direccion in ('debo', 'me_deben'));

comment on column public.deudas.direccion is
  'Fase 82: debo = el dueño (user_id) le debe al acreedor; me_deben = '
  'el acreedor (nombre_acreedor / amigo_usuario_id) le debe al dueño.';

commit;

-- ---------------------------------------------------------------------
-- Verificación (debe devolver 0 filas con dirección distinta de 'debo'
-- justo después de migrar):
--   select direccion, count(*) from public.deudas group by direccion;
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- REVISAR ANTES/DESPUÉS DE CORRER (no incluido aquí: las funciones no
-- están en este repositorio y no se modifican a ciegas):
--   * Trigger `notificar_deuda_pagada` (Fase 70): al saldar una deuda
--     'me_deben' notifica "deuda_pagada" al dueño y "deuda_amigo_pagada"
--     al amigo con textos pensados para 'debo'. Conviene ramificar por
--     new.direccion (p. ej. "{amigo} terminó de pagarte").
--   * Trigger de "deuda_vinculada" (Fase 71): mismo tema de redacción.
--   * La app ya NO llama a `notificar_pago_a_amigo` en cobros
--     ('me_deben'), así que ese RPC no necesita cambios.
-- ---------------------------------------------------------------------

-- =====================================================================
-- REVERTIR (solo si hace falta deshacer la fase). Antes de revertir,
-- las deudas 'me_deben' quedarían como 'debo' para versiones viejas de
-- la app; si existen, conviene eliminarlas o exportarlas primero:
--   select id, user_id, nombre_deuda from public.deudas
--    where direccion = 'me_deben';
--
-- begin;
-- alter table public.deudas drop constraint if exists deudas_direccion_check;
-- alter table public.deudas drop column if exists direccion;
-- commit;
-- =====================================================================
