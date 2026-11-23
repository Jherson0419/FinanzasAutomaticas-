# Checklist manual en staging (después de las migraciones 82–85 y 89)

Usa la app compilada contra staging
(`flutter run --dart-define-from-file=config/staging.json`), una cuenta de
prueba y, para el punto 6, una segunda cuenta de usuario "amiga". Anota
cada saldo **antes** de cada prueba. Revisa los avisos en la campana de la
app **y** en la tabla `notificaciones` de staging.

Consulta útil para mirar saldos y deudas en el SQL Editor:

```sql
select nombre, tipo, saldo_actual from public.cuentas order by nombre;
select nombre_deuda, direccion, monto_total, monto_pagado,
       numero_cuotas_total, numero_cuotas_pagadas, estado,
       monto_abonado_capital, monto_ultima_cuota
  from public.deudas order by nombre_deuda;
select tipo, mensaje, created_at from public.notificaciones
 order by created_at desc limit 10;
```

## 1. Transferencia entre dos cuentas

- [ ] Débito S/ 1,000 y Ahorros S/ 200. Registra una transferencia de
      S/ 300 de Débito a Ahorros.
- [ ] Débito queda en **S/ 700** y Ahorros en **S/ 500** (app y tabla).
- [ ] `transacciones`: 2 filas con el mismo `transferencia_id`,
      `categoria_id` NULL, tipos `transferencia_salida` y
      `transferencia_entrada`.
- [ ] Ingresos y gastos del mes **no cambian**.
- [ ] **Ningún aviso** nuevo en `notificaciones`.
- [ ] Repite hacia una **tarjeta** ("Pagar tarjeta"): la deuda de la tarjeta
      baja en el mismo monto.
- [ ] Borra la transferencia: ambos saldos vuelven a su valor inicial.

## 2. Cobro de una deuda "Me deben"

- [ ] Crea "Préstamo a Lucía" (me deben S/ 380). Saldo de Débito: anótalo.
- [ ] Registra un cobro de S/ 100 recibido en Débito.
- [ ] Débito **sube** S/ 100 (no baja).
- [ ] La deuda queda con `monto_pagado` 100 y estado `activa`.

## 3. Abono a capital

- [ ] Préstamo en cuotas fijas con interés (p. ej. S/ 10,000 en 36 de
      S/ 450, 12 pagadas). Anota `numero_cuotas_pagadas` y el estado.
- [ ] Registra un abono a capital de S/ 200.
- [ ] `numero_cuotas_pagadas` **no cambia** (un abono no es una cuota).
- [ ] `monto_abonado_capital` = 200 y `monto_ultima_cuota` con un valor
      (≈ S/ 54.49 en este ejemplo).
- [ ] **Ningún aviso** "terminaste de pagar".
- [ ] El saldo de la cuenta baja S/ 200.

## 4. Préstamo con intereses: cuota 9 de 10

- [ ] Préstamo de capital S/ 3,800 en 10 cuotas de S/ 440 (total S/ 4,400),
      con 8 pagadas (S/ 3,520 pagados).
- [ ] Paga la cuota 9 (S/ 440 → pagado S/ 3,960, **más que el capital**).
- [ ] Estado sigue `activa`; `numero_cuotas_pagadas` = 9.
- [ ] **Ningún aviso** "¡Terminaste de pagar…!" (con los triggers viejos
      este paso lo disparaba porque comparaban contra el capital).

## 5. Saldar una deuda normal

- [ ] Paga la cuota 10 de la deuda del punto 4.
- [ ] Estado `pagada`.
- [ ] **Exactamente un** aviso "¡Terminaste de pagar "…"! 🎉".

## 6. Deuda vinculada con un amigo, en ambas direcciones

Con dos usuarios de prueba (A y B) que ya sean amigos:

- [ ] A crea una deuda **"debo"** vinculada a B por S/ 500.
      B recibe: "{nick de A} te vinculó una deuda de 500".
- [ ] A crea una deuda **"me deben"** vinculada a B por S/ 300.
      B recibe: "{nick de A} registró que le debes 300".
- [ ] A salda la deuda "debo": A recibe "¡Terminaste de pagar…!" y B
      recibe "{nick de A} terminó de pagarte…".
- [ ] A cobra todo de la deuda "me deben": A recibe "Cobraste todo lo de
      …"; **B no recibe nada**.
- [ ] Repite el primer punto con un usuario A **sin nick** (si es posible):
      el saldo de la deuda debe guardarse igual (ver riesgo del nick nulo
      en `LEEME_orden.md`).

## 7. Borrar una categoría con movimientos

- [ ] Crea una categoría propia "Prueba" y registra 2 gastos con ella.
- [ ] Borra la categoría desde la app.
- [ ] El borrado **funciona** (no lo bloquea ninguna restricción).
- [ ] Los 2 gastos siguen existiendo con `categoria_id` NULL y la app los
      muestra como "Sin categoría".
- [ ] La verificación de la 85 ("con categoría NULL, por tipo") los cuenta
      en `gasto`.

## Al terminar

- [ ] Corre otra vez los 6 SQL (idempotencia): sin errores.
- [ ] Migración local → nube con los datos de ejemplo: saldos y deudas en
      staging iguales a los del teléfono, sin avisos falsos.
