# Despliegue de `generar-consejos` (Fase 88)

**No se desplegó.** Estos pasos los hace el dueño del proyecto: primero en
**staging**, después en producción (Fase 89).

## Qué cambió y por qué es compatible

La app manda un resumen con sus deudas para el primer mensaje del chat.

| | Apps publicadas (v1) | Apps desde la Fase 88 (v2) |
|---|---|---|
| `montoTotal` | Total a pagar (parche de la Fase 79) | Igual que v1 |
| `montoPagado` | Sí | Igual que v1 |
| `capital`, `totalAPagar`, `saldo`, `direccion` | — | Nuevos, explícitos |
| `resumen.version` | Ausente | `2` |

- **Función vieja + app nueva:** funciona. La función ignora los campos
  nuevos y sigue calculando `montoTotal − montoPagado`, que la app sigue
  mandando como total a pagar.
- **Función nueva + app vieja:** funciona. Sin `saldo` ni `totalAPagar`, la
  función cae en `montoTotal − montoPagado`, como antes.
- **Función nueva + app nueva:** usa `saldo` (exacto incluso con la última
  cuota parcial de la Fase 84b) y muestra el capital.
- **Exclusiones:** deudas con `direccion = 'me_deben'` y categorías con
  `esTransferencia = true`. La app ya las excluye; esto es una defensa del
  lado del servidor.

Código: `supabase/functions/generar-consejos/normalizar.ts` (puro) y sus
pruebas `normalizar_test.ts`.

## 1. Probar en local (opcional)

Requiere [Deno](https://deno.com):

```bash
deno test supabase/functions/generar-consejos/normalizar_test.ts
```

(En la Fase 88 no se ejecutaron: no había Deno en el entorno.)

## 2. Desplegar en staging

```bash
supabase login
supabase link --project-ref <ref-de-staging>
# Secretos (solo la primera vez en staging; el valor NUNCA va al repo):
supabase secrets set GEMINI_API_KEY=<clave>
supabase functions deploy generar-consejos
```

Comprueba que `supabase link` apunte a staging antes de desplegar:
`supabase projects list` marca el proyecto enlazado.

## 3. Verificar

1. Supabase Dashboard → Edge Functions → `generar-consejos` → **Logs**.
2. Abre la app compilada contra staging
   (`flutter run --dart-define-from-file=config/staging.json`) → Consejos →
   inicia una conversación nueva.
3. En la tabla `mensajes_consejos` de staging, el primer mensaje de
   usuario debe:
   - listar las deudas con "pendiente" igual al saldo que muestra la app
     (incluida una deuda con abono y última cuota parcial);
   - mostrar "capital: …";
   - **no** incluir la deuda "Me deben";
   - **no** incluir transferencias en ingresos ni gastos.
4. Prueba también con una app **publicada** (TestFlight actual) contra
   staging, si es posible: debe seguir funcionando (payload v1).

## 4. Producción (Fase 89)

Los mismos comandos, enlazando el proyecto de producción. Es compatible
con las apps ya publicadas, así que puede desplegarse antes o después de
publicar la app nueva.

Reversión: volver a desplegar la versión anterior del archivo
(`git show <commit>:supabase/functions/generar-consejos/index.ts`). No hay
cambios de esquema asociados.
