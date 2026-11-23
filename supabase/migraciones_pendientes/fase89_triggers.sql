-- fase89_triggers.sql
-- Corrige los triggers de producción para que entiendan los datos nuevos
-- (transferencias, deudas "me deben", abonos a capital).
--
-- REQUISITOS: correr DESPUÉS de fase82, fase83, fase84, fase84b y fase85.
-- Usa deudas.direccion y los tipos 'transferencia_entrada' / 'transferencia_salida'.
-- Si se corre antes, los pagos de deuda fallan con "column direccion does not exist".
--
-- ANTES DE CORRER: probar en un proyecto Supabase de pruebas y guardar los
-- cuerpos originales de estas 5 funciones (reversión = volver a crearlos).
--
-- NO tocar: notificar_transaccion (ya ignora los tipos nuevos).
-- NO se crean tipos de notificación nuevos: se reutilizan 'deuda_pagada' y
-- 'deuda_vinculada' porque la app decide ícono y texto según el tipo.

begin;

-- 1) Saldo por transacción: correcto también para transferencias.
--    Antes: 'ingreso' suma y TODO lo demás resta.
create or replace function public.fn_actualizar_saldo_cuenta()
returns trigger language plpgsql as $$
begin
  update public.cuentas
  set saldo_actual = coalesce(saldo_actual, 0) + (
    case new.tipo
      when 'ingreso'               then  new.monto
      when 'transferencia_entrada' then  new.monto
      when 'gasto'                 then -new.monto
      when 'transferencia_salida'  then -new.monto
      else 0
    end)
  where id = new.cuenta_id;
  return new;
end;
$$;

-- 2) Saldo por pago: un cobro de una deuda "me deben" suma; un pago resta.
create or replace function public.fn_actualizar_saldo_por_pago_deuda()
returns trigger language plpgsql as $$
declare v_direccion text;
begin
  if new.cuenta_id is not null then
    select coalesce(direccion, 'debo') into v_direccion
    from public.deudas where id = new.deuda_id;
    update public.cuentas
    set saldo_actual = coalesce(saldo_actual, 0) +
      case when v_direccion = 'me_deben' then new.monto_pagado
           else -new.monto_pagado end
    where id = new.cuenta_id;
  end if;
  return new;
end;
$$;

-- 3) Deuda tras pago: solo acumula lo pagado.
--    Cuotas, estado y mora los escribe la app, que conoce el total real
--    (capital + interés + abonos). Antes sumaba 1 cuota siempre y marcaba
--    'pagada' al alcanzar el capital, lo que disparaba un aviso falso.
create or replace function public.fn_actualizar_deuda_tras_pago()
returns trigger language plpgsql as $$
begin
  update public.deudas
  set monto_pagado = coalesce(monto_pagado, 0) + new.monto_pagado,
      updated_at = now()
  where id = new.deuda_id;
  return new;
end;
$$;

-- 4) Deuda saldada: texto según la dirección; sin aviso al amigo en "me deben".
create or replace function public.notificar_deuda_pagada()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if old.estado is distinct from 'pagada' and new.estado = 'pagada' then
    if coalesce(new.direccion, 'debo') = 'me_deben' then
      insert into public.notificaciones (usuario_id, tipo, mensaje, data)
      values (new.user_id, 'deuda_pagada',
        'Cobraste todo lo de "' || new.nombre_deuda || '" 🎉',
        jsonb_build_object('deuda_id', new.id));
    else
      insert into public.notificaciones (usuario_id, tipo, mensaje, data)
      values (new.user_id, 'deuda_pagada',
        '¡Terminaste de pagar "' || new.nombre_deuda || '"! 🎉',
        jsonb_build_object('deuda_id', new.id));
      if new.amigo_usuario_id is not null then
        insert into public.notificaciones (usuario_id, tipo, mensaje, data)
        values (new.amigo_usuario_id, 'deuda_amigo_pagada',
          (select nick from public.usuarios where id = new.user_id) ||
            ' terminó de pagarte "' || new.nombre_deuda || '"',
          jsonb_build_object('deuda_id', new.id));
      end if;
    end if;
  end if;
  return new;
end;
$$;

-- 5) Deuda vinculada: la frase cambia si el dueño dice que el amigo le debe.
create or replace function public.notificar_deuda_vinculada()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_nick text; v_amigo_anterior uuid;
begin
  v_amigo_anterior := case when TG_OP = 'UPDATE' then old.amigo_usuario_id else null end;
  if new.amigo_usuario_id is not null
     and new.amigo_usuario_id is distinct from v_amigo_anterior
     and new.amigo_usuario_id != new.user_id then
    select nick into v_nick from public.usuarios where id = new.user_id;
    insert into public.notificaciones (usuario_id, tipo, mensaje, data)
    values (new.amigo_usuario_id, 'deuda_vinculada',
      case when coalesce(new.direccion, 'debo') = 'me_deben'
        then coalesce(v_nick, 'Alguien') || ' registró que le debes ' || new.monto_total
        else coalesce(v_nick, 'Alguien') || ' te vinculó una deuda de ' || new.monto_total
      end,
      jsonb_build_object('deuda_id', new.id, 'monto', new.monto_total));
  end if;
  return new;
end;
$$;

commit;