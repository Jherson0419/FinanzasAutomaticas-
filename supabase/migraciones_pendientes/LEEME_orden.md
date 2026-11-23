# Migraciones pendientes (Fases 82–85 y 89)

Ninguna se ejecutó contra Supabase. Primero en **staging**
([`docs/nube/staging.md`](../../docs/nube/staging.md) y
[`docs/nube/checklist_staging.md`](../../docs/nube/checklist_staging.md)),
después en producción.

> **Sin probar en un Postgres real.** Los archivos se revisaron a mano,
> pero en este entorno no hubo una base donde ejecutarlos. Córrelos en
> staging **dos veces seguidas**: la segunda debe terminar sin errores y
> sin cambios (eso prueba la idempotencia de 82–85; la 89 usa
> `create or replace`, que también se puede repetir).

## Orden de ejecución

| # | Archivo | Qué hace | Necesario para |
|---|---|---|---|
| 1 | `fase82_direccion_deuda.sql` | `deudas.direccion` ('debo' / 'me_deben') | Deudas "Me deben" |
| 2 | `fase83_tcea_cuenta.sql` | `cuentas.tcea` (fracción anual) | Guardar la TCEA de una tarjeta |
| 3 | `fase84_tipo_pago.sql` | `pagos_deuda.tipo`, `deudas.monto_abonado_capital` | Abonos a capital |
| 4 | `fase84b_ultima_cuota.sql` | `deudas.monto_ultima_cuota` | Abonos a capital (va **junto** con la 3) |
| 5 | `fase85_transferencias.sql` | Tipos de transferencia en el CHECK, `transferencia_id` | Transferencias y "Pagar tarjeta" |
| 6 | `fase89_triggers.sql` | Reescribe 5 funciones de trigger | Saldos y avisos correctos con lo anterior |

La 6 **exige** las cinco anteriores: usa `deudas.direccion` y los tipos de
transferencia. Si se corre antes, cada pago de deuda falla con
`column "direccion" does not exist`.

## Requisitos previos

- Esquema base cargado (tablas `cuentas`, `deudas`, `pagos_deuda`,
  `transacciones`, `notificaciones`, `usuarios`, con RLS y triggers). En
  staging, cargarlo primero (`docs/nube/staging.md`, paso 2).
- Ejecutar como `postgres` (SQL Editor o `psql`).
- **Antes de la 6, respaldar las 5 funciones originales** en
  `supabase/respaldo/` (ver "Reversión de la 89"). **Esa carpeta todavía
  no existe en el repositorio.**

## Cada archivo

- 82–85: `ADD COLUMN IF NOT EXISTS`; restricciones creadas solo si no
  existen (bloques `DO` que consultan `pg_constraint`); la 85 además
  reemplaza el CHECK de `tipo` si no admite transferencias.
- Todos en una transacción (`begin; … commit;`).
- Cada uno trae su verificación y su reversión (comentada).

## Verificación (después de las 6)

```sql
-- Columnas nuevas (6 filas)
select table_name, column_name, is_nullable, column_default
  from information_schema.columns
 where table_schema = 'public'
   and (table_name, column_name) in (
     ('deudas', 'direccion'), ('cuentas', 'tcea'),
     ('pagos_deuda', 'tipo'), ('deudas', 'monto_abonado_capital'),
     ('deudas', 'monto_ultima_cuota'), ('transacciones', 'transferencia_id'))
 order by table_name, column_name;

-- Restricciones (7 filas)
select conrelid::regclass as tabla, conname, pg_get_constraintdef(oid)
  from pg_constraint
 where conname in ('deudas_direccion_check', 'cuentas_tcea_check',
                   'pagos_deuda_tipo_check',
                   'deudas_monto_abonado_capital_check',
                   'deudas_monto_ultima_cuota_check',
                   'transacciones_tipo_check',
                   'transacciones_transferencia_check');

-- Funciones reescritas por la 89 (deben mencionar 'me_deben' o
-- 'transferencia_entrada' según el caso)
select proname, pg_get_functiondef(oid) like '%me_deben%' as con_me_deben,
       pg_get_functiondef(oid) like '%transferencia_entrada%' as con_transf
  from pg_proc
 where proname in ('fn_actualizar_saldo_cuenta',
                   'fn_actualizar_saldo_por_pago_deuda',
                   'fn_actualizar_deuda_tras_pago',
                   'notificar_deuda_pagada', 'notificar_deuda_vinculada');
```

Luego, las pruebas manuales de `docs/nube/checklist_staging.md`.

## Triggers (confirmado en producción, Fase 88b)

| Función | Hoy en producción | Con `fase89_triggers.sql` |
|---|---|---|
| `fn_actualizar_saldo_cuenta` (INSERT en `transacciones`) | 'ingreso' suma; **todo lo demás resta** (una transferencia de entrada restaría) | ingreso y transferencia_entrada suman; gasto y transferencia_salida restan; otro tipo: 0 |
| `fn_actualizar_saldo_por_pago_deuda` (INSERT en `pagos_deuda`) | **Siempre resta** (un cobro "me deben" restaría) | 'me_deben' suma; 'debo' resta; sin cuenta no toca nada |
| `fn_actualizar_deuda_tras_pago` (INSERT en `pagos_deuda`) | +monto, **+1 cuota siempre** (también en abonos), y 'pagada' si `monto_pagado >= monto_total` (el **capital**: dispara un "terminaste" falso en préstamos con interés) | Solo acumula `monto_pagado`; cuotas, estado y mora los escribe la app |
| `notificar_deuda_pagada` | Texto como si siempre debieras tú | 'me_deben': "Cobraste todo lo de …", sin aviso al amigo |
| `notificar_deuda_vinculada` | Texto como si siempre debieras tú | 'me_deben': "… registró que le debes …" |
| `notificar_transaccion` | No notifica tipos distintos de gasto/ingreso | **Sin cambios**: las transferencias no generan avisos |

Otros datos confirmados: `transacciones.categoria_id` ya es nullable con
FK `ON DELETE SET NULL`; `notificaciones.tipo` no tiene CHECK (los tipos
'deuda_pagada', 'deuda_vinculada', 'deuda_amigo_pagada' ya los muestra la
app con su ícono).

### Por qué la app no se descuadra con los triggers actuales

Todas las versiones de la app (incluida la 1.0.2 publicada) leen la cuenta
y la deuda **antes** de insertar, y **después** escriben valores absolutos
(`saldo_actual`, `monto_pagado`, `numero_cuotas_pagadas`, `estado`). Esa
escritura final pisa lo que hizo el trigger. Lo que NO se puede pisar son
los **avisos**: si el trigger marca 'pagada' un instante, la notificación
ya salió. Por eso la 89 es necesaria aunque los saldos "cuadren".

### Revisión de `fase89_triggers.sql` (Fase 88b, sin cambiar su lógica)

- **Sintaxis:** correcta a la lectura (`create or replace function …
  returns trigger language plpgsql`). `create or replace` mantiene los
  triggers que ya apuntan a cada función.
- **Columnas y textos:** coinciden con el código (`pagos_deuda.deuda_id`,
  `cuenta_id`, `monto_pagado`; `notificaciones.usuario_id`, `tipo`,
  `mensaje`, `data`; `usuarios.nick`; 'me_deben', 'transferencia_entrada',
  'transferencia_salida' tal como los escribe `enum_mapeo_supabase.dart`).
- **Verificar antes de correrla** (no se puede desde el repositorio):
  1. **`deudas.updated_at`** (usada en la función 3): el código de la app
     no la usa nunca. Si la columna no existe, **todo pago de deuda
     fallaría**. Confirmar con
     `select 1 from information_schema.columns where table_name = 'deudas' and column_name = 'updated_at';`
  2. **`SECURITY DEFINER` / `search_path`:** las funciones 1–3 se crean sin
     `security definer`. `create or replace` reemplaza también esos
     atributos: si las originales eran `security definer`, pasarían a
     ejecutarse con los permisos del usuario (bajo RLS). Para el dueño de
     la cuenta funciona, pero conviene **copiar el mismo encabezado que las
     originales**.
  3. **Nick nulo en la función 4:** `(select nick …) || ' terminó de
     pagarte …'` da NULL si el dueño no tiene nick; si
     `notificaciones.mensaje` es NOT NULL, el insert falla y **revierte el
     UPDATE que saldó la deuda**. La función 5 ya usa
     `coalesce(v_nick, 'Alguien')`. Propuesta (no aplicada): usar lo mismo
     en la 4. Revisar si la original ya tenía este riesgo.
  4. Que los triggers estén definidos solo `AFTER INSERT` (las funciones 1–3
     usan solo `new`; en un DELETE `new` es NULL).
- **Coherencia con la app de la 1.0.2 publicada:** esa versión escribe
  `numero_cuotas_pagadas` y `estado` ella misma, así que quitarle eso a la
  función 3 no la afecta. Pero la 1.0.2 calcula 'pagada' con
  `monto_pagado >= monto_total` (capital): **para sus usuarios el aviso
  "terminaste" temprano seguirá saliendo** hasta que actualicen la app
  (ya no por el trigger, sino por la propia escritura de la app).

### Reversión de la 89

Las definiciones originales deben estar en **`supabase/respaldo/`**
(carpeta que el dueño debe crear antes de correr la 89; hoy no existe en
el repositorio). Para generarlas, en producción (solo lectura):

```sql
select proname, pg_get_functiondef(oid)
  from pg_proc
 where proname in ('fn_actualizar_saldo_cuenta',
                   'fn_actualizar_saldo_por_pago_deuda',
                   'fn_actualizar_deuda_tras_pago',
                   'notificar_deuda_pagada', 'notificar_deuda_vinculada');
```

Guardar cada resultado como `supabase/respaldo/<función>.sql`. Revertir =
ejecutar esos cinco archivos (cada uno es un `create or replace function`
completo). No cambia datos ni esquema.

## Reversión de 82–85

En orden **inverso** (85 → 82), con el bloque comentado al final de cada
archivo, y **después** de revertir la 89 (la 89 depende de ellas). Avisos:

- **85:** si ya hay transferencias, borrarlas en SQL **no** devuelve los
  saldos. Bórralas desde la app primero.
- **84b y 84:** si ya hay abonos, el total a pagar pierde lo abonado.
- **82:** las deudas 'me_deben' se leerían como 'debo' en apps viejas.

## Riesgos conocidos

1. **`categoria_id` nulo.** Ya era nullable (FK `ON DELETE SET NULL`). Con
   la 85, además, toda transferencia tiene categoría NULL. Cualquier
   consulta del servidor que haga `inner join categorias` deja fuera las
   transferencias y los movimientos de categorías borradas.
   `generar-consejos` ya excluye las transferencias.
2. **CHECK de `tipo`.** Se reemplaza el de solo 'ingreso'/'gasto'. Una app
   anterior a la Fase 85 (incluida la **1.0.2**) que lea una transferencia
   lanza `FormatException` en `tipoTransaccionDeFila`: **no crear
   transferencias en una cuenta mientras su dueño use la 1.0.2**.
3. **Qué falla en la nube si falta cada SQL** (app de la Fase 87+):

   | Falta | Falla | Sigue funcionando |
   |---|---|---|
   | 82 | Deudas "Me deben"; además la 89 no se puede correr | Todo lo "debo" |
   | 83 | Guardar una TCEA | Cuentas sin TCEA |
   | 84 | Registrar un abono a capital | Pagar y adelantar cuotas |
   | 84b | Abonos, **y luego cualquier pago o edición** de una deuda con abonos | Deudas sin abonos |
   | 85 | Transferencias y "Pagar tarjeta" (falla la 1.ª inserción, sin dejar nada a medias) | Ingresos, gastos, ajustes, pagos |
   | 89 | Saldos correctos al final (la app los reescribe), **pero**: aviso "terminaste" falso en préstamos con interés y tras un abono; textos de "me deben" como si debieras tú | Todo lo demás |

4. **Migración local → nube** (Fase 88b): los triggers re-aplican cada
   transacción y pago subidos sobre cuentas y deudas que ya llegaron con
   su valor final. `MigrarDatosALaNube` ahora reescribe al final todas las
   cuentas y deudas con los valores del teléfono. **Correr la 89 antes de
   ofrecer la migración**: con la función 3 original, subir pagos puede
   marcar deudas como 'pagada' un instante y **enviar avisos falsos**.
   Además, `notificar_deuda_vinculada` avisa al amigo por cada deuda
   vinculada que se suba (ya pasaba antes de la Fase 88).
5. **Concurrencia:** el patrón "leer, insertar, escribir absoluto" de la
   app pisa cambios hechos en paralelo desde otro dispositivo en esa misma
   cuenta o deuda (ya pasaba en la 1.0.2).
