# Informe del proyecto — Finanzas Automáticas

> Auditoría de solo lectura del estado real del repositorio (`lib/`, `test/`, `pubspec.yaml`, `ios/`, `CONTEXTO.md`) realizada desde cero el 2026-08-17, recorriendo los ~111 archivos `.dart` de `lib/` y los 45 de `test/` directamente con Read/Grep, sin dar por buena ninguna afirmación del `INFORME_PROYECTO.md` anterior ni de `CONTEXTO.md` que no se pudiera verificar contra el código. Ningún archivo de código fue modificado para producir este informe.
>
> **Resultado real de las herramientas en este momento:** `flutter analyze` → 2 issues, ambos `info` (deprecación de `anonKey` en `main.dart:12` y `main_dev.dart:19`), cero errores/warnings. `flutter test` → 45 archivos, **140 tests, 140 en verde, 0 fallos**.
>
> **Hallazgo más urgente de esta auditoría (relevante para el envío a revisión de Apple en 2 días):** no existe ningún flujo de eliminación de cuenta de usuario (borrado de datos + cuenta de auth). Ver la sección 7(a) y la sección 8 — es Guideline 5.1.1(v) de Apple y, tal como está hoy el código, la app la incumple sin ambigüedad.

---

## 1. Resumen ejecutivo

Finanzas Automáticas es hoy una app Flutter de finanzas personales con **backend real en producción (Supabase)**, no una app local. El flujo completo: el usuario inicia sesión con correo/contraseña (Supabase Auth), opcionalmente configura un bloqueo local (PIN de 4 dígitos hasheado y/o Face ID/huella), completa un onboarding obligatorio de 5 pasos (bienvenida, nombre, al menos una cuenta, deudas opcionales, resumen), y llega a un dashboard oscuro con acordeones (saldo total, ingresos/gastos del mes, gasto por categoría, deudas activas, movimientos recientes), una barra inferior fija (Gasto / Deuda / Consejos / Perfil) y un carrusel de tarjetas de cuenta a tamaño real. Puede registrar gastos/ingresos, deudas (con cronograma de cuotas e interés automático o pago libre), pagos de deuda (incluyendo pagos retroactivos que no tocan el saldo), ajustar el saldo de una cuenta sin sobrescribirlo, crear categorías propias además de las predeterminadas, y pedir consejos financieros a Gemini bajo demanda.

**Estado real de producción — Supabase, confirmado por lectura directa del código, no solo por lo que dice `CONTEXTO.md`:** los 5 providers de repositorios de datos financieros (`cuentaRepositoryProvider`, `categoriaRepositoryProvider`, `transaccionRepositoryProvider`, `deudaRepositoryProvider`, `pagoDeudaRepositoryProvider`, todos en `lib/presentation/state/providers.dart:83-111`) bifurcan entre un adapter Drift y un adapter Supabase según la preferencia local `datos_en_la_nube`. Existen los 5 adapters Supabase completos en `lib/infrastructure/persistence/supabase/` (uno por puerto, todos con manejo de errores envuelto en `StateError` vía `conManejoDeErroresSupabase`), un caso de uso de migración (`MigrarDatosALaNube`) que sube todo preservando IDs y verifica conteos antes de borrar lo local, y una pantalla (`MigrarDatosScreen`) que `RootScreen` muestra automáticamente cuando detecta datos Drift sin migrar. Los adapters Drift siguen existiendo y se siguen usando como origen de la migración y como almacenamiento hasta que un dispositivo migra — la arquitectura de puertos y adapters hace este reemplazo transparente para los casos de uso, exactamente como describe `CONTEXTO.md` §3.

**Cambio importante respecto a lo que decía el informe anterior:** `lib/config/supabase_config.dart` **ya no tiene credenciales placeholder** (`TU_PROJECT_URL_AQUI`/`TU_ANON_KEY_AQUI`) — tiene una URL de proyecto Supabase (`https://oyoxbvloqqiiasiaugzm.supabase.co`) y una `publishableKey` con formato real (`sb_publishable_...`) escritas directamente en el archivo. Esto significa que, a diferencia de lo que el informe anterior advertía, `Supabase.initialize()` sí puede autenticar contra un proyecto real hoy — pero también significa que estas credenciales viajan en texto plano dentro del código fuente (ver §7 y §8).

Comparado contra el modelo de datos documentado en `CONTEXTO.md` §2, el código está casi perfectamente alineado — la única discrepancia real es que `Categoria.esPredeterminada` (un campo que sí existe en el código y en el schema Drift desde la Fase 20) nunca aparece en la lista de campos de `Categoria` en `CONTEXTO.md` §2, solo se menciona narrativamente en otras partes del documento (ver §3).

La app está funcionalmente completa para su propio alcance (Etapas 1 y 2 del roadmap de `CONTEXTO.md` §4). Lo que le falta no es funcionalidad de finanzas personales, sino requisitos de plataforma para pasar la revisión de Apple: no hay eliminación de cuenta de usuario, y la configuración de iOS (`Info.plist`) no declara el uso de Face ID que la app sí invoca en tiempo de ejecución vía `local_auth`. Ver §7 para el detalle completo.

---

## 2. Flujo de usuario end-to-end

### Diagrama de navegación

```
main.dart
  └─ WidgetsFlutterBinding + Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey)
      (config/supabase_config.dart — credenciales reales escritas en el archivo, no placeholder)
      + SharedPreferences.getInstance()
      └─ FinanzasAutomaticasApp (presentation/app.dart)
          └─ ruta '/'  →  RootScreen (screens/root_screen.dart) — 5 puertas en orden estricto
              │
              │ 1. haySesionActivaProvider [AuthRepository] → sin sesión → LoginScreen
              │
              │ 2. necesitaMigracionProvider [providers.dart:157-173]:
              │      preferencias.datosEnLaNube() == true → salta esta puerta
              │      si no: revisa Drift (cuentas/deudas/transacciones) —
              │        hay datos locales sin migrar → MigrarDatosScreen
              │        no hay nada local (instalación nueva) → marca datosEnLaNube=true
              │        sin mostrar nada y sigue de largo
              │
              │ 3. bloqueoConfiguradoProvider == false && !bloqueoOmitidoProvider
              │      → ConfigurarBloqueoScreen (se ofrece una sola vez)
              │
              │ 4. bloqueoConfiguradoProvider == true && !desbloqueadoEnEstaSesionProvider
              │      → DesbloqueoScreen (solo en cold start, no al volver de segundo plano)
              │
              │ 5. onboardingCompletadoProvider → PreferenciasRepository, sin caso de uso
              │
              ├─ onboardingCompletado == false
              │   └─ OnboardingFlowScreen (screens/onboarding/onboarding_flow_screen.dart)
              │       [contenedor con estado local `_paso` 0-4, sin rutas propias]
              │       │
              │       ├─ Paso 0 · onboarding_welcome_step.dart → "Comenzar" (sin "Atrás")
              │       ├─ Paso 1 · onboarding_nombre_step.dart → "Continuar" deshabilitado si vacío
              │       ├─ Paso 2 · onboarding_cuentas_step.dart
              │       │     embebe CuentaFormulario → RegistrarCuenta → CuentaRepository
              │       │     "Continuar" deshabilitado si 0 cuentas
              │       ├─ Paso 3 · onboarding_deudas_step.dart
              │       │     embebe DeudaFormulario → RegistrarDeuda → DeudaRepository
              │       │     "Continuar" / "Omitir por ahora" siempre habilitados
              │       └─ Paso 4 · onboarding_resumen_step.dart
              │             "Empezar a usar la app" → PreferenciasRepository.guardarNombre() +
              │               marcarOnboardingCompletado() → pushNamedAndRemoveUntil('/', false)
              │
              └─ onboardingCompletado == true
                  └─ DashboardScreen (screens/dashboard/dashboard_screen.dart)
                      [resumenDashboardProvider — corre ActualizarEstadoMora, luego
                       ObtenerResumenDashboard; ambos leen de los 5 repos bifurcados]
                      │
                      ├─ AppBar: saludo ("Hola, {nombre}" vía nombreUsuarioProvider)
                      │     + ícono billetera → '/cuentas'
                      │     + ícono escudo (gpp_good, decorativo, sin acción)
                      │     + campana (onPressed: () {}, no-op)
                      │
                      ├─ body: resumen.estaVacio → DashboardEmptyState (inalcanzable, ver §8)
                      │        si no → CuentasCarrusel, SaldoTotalCard, IngresosGastosSection,
                      │        GastoPorCategoriaSection, DeudasActivasSection (acordeón),
                      │        MovimientosRecientesSection (acordeón, "Ver todos" → '/transacciones/todas')
                      │
                      └─ bottomNavigationBar (AppBottomBar, fijo):
                            "Gasto"    → '/transacciones/nueva' → TransaccionNuevaScreen
                            "Deuda"    → '/deudas/nueva'        → DeudaNuevaScreen
                            "Consejos" → '/consejos'             → ConsejosFinancierosScreen
                            "Perfil"   → '/perfil'               → MiPerfilScreen

Pantallas devueltas directamente por RootScreen (sin ruta con nombre en la tabla `routes`):
  LoginScreen, MigrarDatosScreen, ConfigurarBloqueoScreen, DesbloqueoScreen

Rutas estáticas (app.dart, tabla `routes`):
  '/cuentas', '/categorias', '/consejos', '/perfil', '/transacciones/todas'

Rutas con argumento (app.dart, onGenerateRoute — necesitan settings.arguments):
  '/deudas/pago' (String deudaId | PagoDeudaRouteArgs), '/deudas/detalle' (String deudaId),
  '/deudas/historial' (String deudaId), '/transacciones/nueva' (String? transaccionId),
  '/deudas/nueva' (String? deudaId), '/cuentas/nueva' (String? cuentaId),
  '/categorias/nueva' (String? categoriaId), '/cuentas/movimientos' (String cuentaId)

DeudaDetalleScreen ('/deudas/detalle') — punto central de una deuda:
  mini-dashboard (interés total, progreso, próxima cuota/mora)
  cuotasFijas → cronograma (generarCronogramaCuotas); swipe en cuota pendiente
    → '/deudas/pago' con precarga (PagoDeudaRouteArgs)
  pagoLibre → ListaPagosDeuda (mismo widget que HistorialPagosDeudaScreen)
  "Editar deuda" → '/deudas/nueva' (modo edición) | "Ver historial" → '/deudas/historial'

CuentaNuevaScreen en modo edición ('/cuentas/nueva' con cuentaId) — rol central para una cuenta:
  WalletAccountCard + datos editables (nombre/tipo; moneda bloqueada con movimientos)
  sección "Saldo": solo lectura + botón "Ajustar" → modal → AjustarSaldoCuenta
  "Ver movimientos de esta cuenta" → '/cuentas/movimientos' → MovimientosCuentaScreen
  "Eliminar cuenta" (rojo, al final) → EliminarCuenta

MiPerfilScreen ('/perfil'):
  nombre (PreferenciasRepository.guardarNombre) y API key de Gemini
    (PreferenciasRepository.guardarApiKeyGemini), ambos solo en este dispositivo
  "Mis categorías" → '/categorias'
  "Cerrar sesión" (con confirmación) → AuthRepository.cerrarSesion() → popUntil(primera ruta)
    → RootScreen reactivamente muestra LoginScreen; NO borra ningún dato (ni local ni de Supabase)
  NO HAY botón de "Eliminar cuenta"/"Eliminar mi cuenta" — ver §7(a)
```

### Detalle por pantalla

| # | Archivo | Ruta | Casos de uso invocados | Lleva a |
|---|---|---|---|---|
| 1 | `lib/main.dart` | entry point | ninguno | `FinanzasAutomaticasApp` |
| 2 | `lib/main_dev.dart` | entry point alterno (`-t lib/main_dev.dart`) | ninguno (overrides con fixtures, salta login/bloqueo) | `FinanzasAutomaticasApp` |
| 3 | `lib/presentation/app.dart` | define `MaterialApp` | ninguno | ruta `/` |
| 4 | `lib/presentation/screens/root_screen.dart` | `/` | ninguno propio (lee 5 providers de puerta) | `LoginScreen`, `MigrarDatosScreen`, `ConfigurarBloqueoScreen`, `DesbloqueoScreen`, `OnboardingFlowScreen` o `DashboardScreen` |
| 5 | `onboarding_flow_screen.dart` + 5 pasos | — (interno) | `RegistrarCuenta` (paso 2), `RegistrarDeuda` (paso 3) | `RootScreen` al terminar |
| 6 | `dashboard_screen.dart` | `/` (onboarding completo) | `ObtenerResumenDashboard` (+ `ActualizarEstadoMora` automático) | `MisCuentasScreen`, `CuentaNuevaScreen`, `PagoDeudaNuevoScreen`, `TransaccionNuevaScreen`, `DeudaNuevaScreen`, `ConsejosFinancierosScreen`, `MiPerfilScreen`, `TodosLosMovimientosScreen` |
| 7 | `mis_cuentas_screen.dart` | `/cuentas` | ninguno (lee `cuentasProvider`) | `CuentaNuevaScreen` |
| 8 | `cuenta_nueva_screen.dart` + `cuenta_formulario.dart` | `/cuentas/nueva` (arg. `cuentaId`) | `RegistrarCuenta` \| `EditarCuenta` \| `EliminarCuenta` \| `AjustarSaldoCuenta` (modal) | pop |
| 9 | `placeholders/transaccion_nueva_screen.dart` | `/transacciones/nueva` (arg. `transaccionId`) | `RegistrarGasto` \| `RegistrarIngreso` \| `EditarTransaccion` \| `EliminarTransaccion`; embebe `CategoriaFormulario` (bottom sheet "+ Crear categoría nueva") → `CrearCategoria` | pop |
| 10 | `placeholders/deuda_nueva_screen.dart` + `deuda_formulario.dart` | `/deudas/nueva` (arg. `deudaId`) | `RegistrarDeuda` \| `EditarDeuda` \| `EliminarDeuda` | pop, o `/deudas/historial` |
| 11 | `pago_deuda_nuevo_screen.dart` | `/deudas/pago` (arg. `deudaId` o `PagoDeudaRouteArgs`) | `RegistrarPagoDeuda` | pop |
| 12 | `deuda_detalle_screen.dart` | `/deudas/detalle` (arg. `deudaId`) | ninguno propio (deriva cronograma con `generarCronogramaCuotas`) | `DeudaNuevaScreen`, `HistorialPagosDeudaScreen`, `PagoDeudaNuevoScreen` |
| 13 | `movimientos_cuenta_screen.dart` | `/cuentas/movimientos` (arg. `cuentaId`) | ninguno propio | `TransaccionNuevaScreen` (edición) |
| 14 | `todos_los_movimientos_screen.dart` | `/transacciones/todas` | ninguno propio (`TransaccionRepository.obtenerTodas`) | `TransaccionNuevaScreen` (edición) |
| 15 | `historial_pagos_deuda_screen.dart` | `/deudas/historial` (arg. `deudaId`) | ninguno propio | — |
| 16 | `consejos_financieros_screen.dart` | `/consejos` | `ObtenerConsejosFinancieros` (solo al tocar el botón) | `MiPerfilScreen` (si falta API key) |
| 17 | `mis_categorias_screen.dart` | `/categorias` | `EliminarCategoria` | `categoria_nueva_screen.dart` |
| 18 | `categoria_nueva_screen.dart` + `categoria_formulario.dart` | `/categorias/nueva` (arg. `categoriaId`) | `CrearCategoria` \| `EditarCategoria` | pop |
| 19 | `mi_perfil_screen.dart` | `/perfil` | ninguno propio (`PreferenciasRepository`/`AuthRepository` directo) | `/categorias`; "Cerrar sesión" → `popUntil` primera ruta |
| 20 | `login_screen.dart` | sin ruta con nombre | ninguno propio (`AuthRepository.iniciarSesion`) | `CrearCuentaScreen` |
| 21 | `crear_cuenta_screen.dart` | empujada desde `LoginScreen` | ninguno propio (`AuthRepository.crearCuenta`) | pop → `LoginScreen` |
| 22 | `configurar_bloqueo_screen.dart` | sin ruta con nombre | ninguno propio (`PreferenciasRepository` directo, `local_auth` para detectar biometría) | reactivo vía `RootScreen` |
| 23 | `desbloqueo_screen.dart` | sin ruta con nombre | ninguno propio | reactivo vía `RootScreen`, o `LoginScreen` si cierra sesión |
| 24 | `migrar_datos_screen.dart` | sin ruta con nombre | `MigrarDatosALaNube` | `pushNamedAndRemoveUntil('/', false)` |

Nota de nomenclatura vigente: `transaccion_nueva_screen.dart` y `deuda_nueva_screen.dart` siguen viviendo en `presentation/screens/placeholders/`, un nombre de carpeta que ya no describe su contenido (son formularios completos, no placeholders).

---

## 3. Modelo de datos real vs. documentado

| Entidad | Campos en código (`domain/entities/*`) | ¿Coincide con `CONTEXTO.md` §2? |
|---|---|---|
| `Cuenta` | id, nombre, tipo, moneda, saldoActual (5) | Sí, idéntico |
| `Categoria` | id, nombre, tipo, iconName, **esPredeterminada** (5) | **No exactamente** — `CONTEXTO.md` §2 solo lista 4 campos (id, nombre, tipo, iconName); `esPredeterminada` (agregado en la Fase 20, presente en `categoria.dart:12` y en la tabla Drift `Categorias.esPredeterminada`) nunca aparece en la lista estructurada de campos, solo se menciona narrativamente ("Existen categorías predeterminadas... y el usuario puede crear las propias"). Es un campo real del dominio sin entrada formal en el modelo de datos documentado. |
| `Transaccion` | id, cuentaId, categoriaId, monto, moneda, tipo, concepto, metodoPago, esRecurrente, comprobanteUrl, fuenteCaptura, dataRaw, fecha (13) | Sí, idéntico |
| `Deuda` | 27 campos incl. `notas`, `periodicidadCuotas`, `interesTotal` | Sí — los campos base y los de la Fase 14 (`periodicidadCuotas`, `interesTotal`) están documentados en secciones separadas de `CONTEXTO.md` §2, coinciden |
| `PagoDeuda` | id, deudaId, cuentaId (nullable), montoPagado, montoCapital, montoInteres, fechaPago, numeroCuota (8) | Sí, incl. la nota de que `cuentaId` es opcional para pagos retroactivos |

Enums verificados uno por uno contra el código (`TipoCuenta`, `Moneda`, `MetodoPago`, `FuenteCaptura`, `TipoDeuda`, `TipoAcreedor`, `TipoTasa`, `EstructuraPago`, `EstadoDeuda`, `PeriodicidadCuota`): **todos coinciden** en valores y — donde importa — en orden.

**`PreferenciasRepository`** (`domain/repositories/preferencias_repository.dart`) sigue sin ser una entidad de dominio: es una interfaz con 14 métodos (nombre, onboarding, API key de Gemini, PIN hash, bloqueo biométrico, bloqueo omitido, y — nuevo desde la Fase 21 — `datosEnLaNube`/`marcarDatosEnLaNube`) que persisten como pares clave-valor en `shared_preferences` vía `PreferenciasRepositorySharedPrefs`. `CONTEXTO.md` documenta estos campos, pero repartidos en tres secciones distintas (§2 "Preferencias de app", "Autenticación y bloqueo local", "Migración a Supabase") en vez de una única lista de campos como las demás entidades — el mismo patrón que ya señalaba el informe anterior, todavía vigente.

**Estado real de `EstadoDeuda.enMora`:** sigue siendo el único valor del enum que solo se activa por lógica automática (`ActualizarEstadoMora`, corre en cada carga del dashboard), nunca manualmente desde un formulario — comportamiento correcto y documentado, no un hallazgo.

---

## 4. Casos de uso y qué UI los consume

19 clases en `domain/usecases/` (excluyendo DTOs en `dto/`):

| Caso de uso | Pantalla(s) que lo invoca | Repositorios que toca |
|---|---|---|
| `RegistrarGasto` | `transaccion_nueva_screen.dart` (tipo=gasto) | `CuentaRepository`, `TransaccionRepository` |
| `RegistrarIngreso` | `transaccion_nueva_screen.dart` (tipo=ingreso) | `CuentaRepository`, `TransaccionRepository` |
| `EditarTransaccion` | `transaccion_nueva_screen.dart` (modo edición) | `CuentaRepository`, `TransaccionRepository` |
| `EliminarTransaccion` | `transaccion_nueva_screen.dart` (botón eliminar) | `CuentaRepository`, `TransaccionRepository` |
| `RegistrarCuenta` | `cuenta_formulario.dart` → `CuentaNuevaScreen`, `OnboardingCuentasStep` | `CuentaRepository` |
| `EditarCuenta` | `cuenta_formulario.dart` (modo edición) | `CuentaRepository`, `TransaccionRepository`, `PagoDeudaRepository` |
| `EliminarCuenta` | `cuenta_formulario.dart` (botón "Eliminar cuenta") | `CuentaRepository`, `TransaccionRepository`, `PagoDeudaRepository` |
| `AjustarSaldoCuenta` | `cuenta_formulario.dart` (modal "Ajustar") | `CuentaRepository`, `TransaccionRepository`, `CategoriaRepository` |
| `RegistrarDeuda` | `deuda_formulario.dart` → `DeudaNuevaScreen`, `OnboardingDeudasStep` | `DeudaRepository` |
| `EditarDeuda` | `deuda_formulario.dart` (modo edición) | `DeudaRepository`, `PagoDeudaRepository` |
| `EliminarDeuda` | `deuda_nueva_screen.dart` (ícono eliminar en AppBar) | `DeudaRepository`, `PagoDeudaRepository` |
| `RegistrarPagoDeuda` | `pago_deuda_nuevo_screen.dart` | `PagoDeudaRepository`, `DeudaRepository`, `CuentaRepository` |
| `ActualizarEstadoMora` | automático en `resumenDashboardProvider` (no hay UI que lo invoque directo) | `DeudaRepository`, `PagoDeudaRepository` |
| `ObtenerResumenDashboard` | `dashboard_screen.dart` vía `resumenDashboardProvider` | `CuentaRepository`, `TransaccionRepository`, `CategoriaRepository`, `DeudaRepository` |
| `CrearCategoria` | `categoria_formulario.dart` (crear, incl. modo rápido embebido en `transaccion_nueva_screen.dart`) | `CategoriaRepository` |
| `EditarCategoria` | `categoria_formulario.dart` (editar) | `CategoriaRepository`, `TransaccionRepository` |
| `EliminarCategoria` | `mis_categorias_screen.dart` (ícono eliminar por fila) | `CategoriaRepository`, `TransaccionRepository` |
| `ObtenerConsejosFinancieros` | `consejos_financieros_screen.dart` | `DeudaRepository`, `TransaccionRepository`, `CategoriaRepository`, `CuentaRepository`, `ConsejosFinancierosRepository` |
| `MigrarDatosALaNube` | `migrar_datos_screen.dart` (botón "Subir mis datos"/"Reintentar") | los 5 repositorios financieros, instanciados dos veces cada uno (Drift explícito como origen, Supabase explícito como destino) |

**Los 19 casos de uso tienen consumidor de UI real — no se encontró ningún caso de uso muerto.**

**Cambio respecto al informe anterior: ya no hay ningún método de repositorio sin consumidor en producción.** Se verificó uno por uno:

- ~~`CategoriaRepository.obtenerPorId` nunca se llama~~ — **ya no es cierto**: `categoriaPorIdProvider` (`providers.dart:338-343`) lo invoca y lo consume `categoria_formulario.dart` en modo edición.
- ~~`PagoDeudaRepository.obtenerPorDeuda` nunca se llama~~ — sigue resuelto (Fase 13): lo usan `pagosPorDeudaProvider`, `ActualizarEstadoMora`, `EditarDeuda`, `EliminarDeuda`, `MigrarDatosALaNube`.
- `PagoDeudaRepository.obtenerPorCuenta` — usado por `pagosPorCuentaProvider`, consumido por `cuenta_formulario.dart` para decidir si la moneda de una cuenta es editable.
- ~~`TransaccionRepository.obtenerTodas()` nunca se llama~~ — sigue resuelto (Fase 17): lo usan `todasLasTransaccionesProvider` (`todos_los_movimientos_screen.dart`) y `MigrarDatosALaNube`.
- `TransaccionRepository.obtenerPorCategoria` — usado por `transaccionesPorCategoriaProvider`, consumido por `categoria_formulario.dart`, `EditarCategoria`, `EliminarCategoria`.

**No existe ningún caso de uso para leer/escribir Preferencias** más allá de llamadas directas al repositorio desde `RootScreen`, `MiPerfilScreen`, `ConfigurarBloqueoScreen`, `DesbloqueoScreen` y `OnboardingResumenStep` — mismo patrón que el informe anterior señalaba, sigue vigente.

**Código muerto encontrado en esta auditoría (nuevo, no señalado antes):** `lib/domain/calculo_fechas.dart` exporta `calcularProximaFechaPago(int? diaPago)`, documentado en su propio comentario como "compartido entre `RegistrarDeuda` y `RegistrarPagoDeuda`" — pero ninguno de los dos lo usa hoy (ambos usan `generarCronogramaCuotas`/`cronograma_cuotas.dart` desde la Fase 14). Un `grep` de `calcularProximaFechaPago` en todo `lib/` solo encuentra su propia definición. Es una función huérfana que quedó de antes del cronograma de cuotas.

---

## 5. Arquitectura real

Verificación contra `CONTEXTO.md` §3.

### `domain/` — ¿importa Flutter, infrastructure/ o paquetes externos?

- **No importa Flutter** en ningún archivo (verificado sobre todos los `import` de `lib/domain/`).
- **No importa `infrastructure/`** en ningún archivo.
- **Sí importa paquetes externos**, igual que en la auditoría anterior: `package:uuid` (`registrar_gasto.dart:1`, `registrar_ingreso.dart:1`, `registrar_cuenta.dart:1`, `registrar_deuda.dart:1`, `registrar_pago_deuda.dart:1`) y `package:crypto` (`pin_hash.dart:3`). Sigue siendo una violación literal de "sin dependencias de... paquetes externos" en `CONTEXTO.md` §3, aunque pragmática (generación de IDs, hashing) y sin acoplar el dominio a Drift/Supabase.

### `presentation/` — ¿accede a `infrastructure/` saltándose `domain/`?

Solo **`lib/presentation/state/providers.dart`** importa `infrastructure/` (los 5 pares de adapters Drift/Supabase + el adapter de `shared_preferences` + `SupabaseAuthRepository` + `GeminiConsejosRepository`) — es el composition root de Riverpod, necesario. Ningún widget ni pantalla importa `infrastructure/` directamente (verificado con `grep` sobre todo `lib/presentation/`, un solo archivo coincide). **No hay violación de esta regla.**

### Adapters de Supabase — columnas asumidas, sin forma de verificarlas contra un esquema real

Se buscó exhaustivamente en todo el repositorio (`find -iname "*.sql"`) algún archivo `schema_finanzas_v3.sql` o similar que documente el esquema real de las tablas de Supabase. **No existe ningún archivo `.sql` en el repositorio.** Esto significa que el mapeo de columnas de los 5 adapters (`infrastructure/persistence/supabase/*.dart`) — todos con métodos `aFila`/`aDominio` marcados `@visibleForTesting` — es una conversión mecánica asumida, no verificada contra el backend real:

- Tablas: `cuentas`, `categorias`, `transacciones`, `deudas`, `pagos_deuda`, todas con columna `user_id`.
- snake_case mecánico de cada campo camelCase (`cuentaId → cuenta_id`, `montoTotal → monto_total`, `esPredeterminada → es_predeterminada`, etc.), consistente en los 5 archivos.
- Enums serializados con `.name` (camelCase real de Dart: `tarjetaCredito`, `prestamoPersonal`, no `tarjeta_credito` como sugeriría una convención snake_case en la base de datos).
- Categorías predeterminadas: `user_id IS NULL`, filtro `.or('user_id.eq.<uid>,user_id.is.null')` en `CategoriaRepositorySupabase`.

**Esto ya no es una nota abstracta como en el informe anterior — ahora que `supabase_config.dart` tiene credenciales que parecen apuntar a un proyecto real (ver §1 y §7), cualquier discrepancia entre este mapeo asumido y el esquema real de Postgres hará que cada lectura/escritura falle con un error de Postgrest envuelto en "No se pudo guardar, intenta de nuevo." (`supabase_errores.dart:16`) — un fallo silencioso y genérico desde el punto de vista del usuario, sin indicar qué columna o tabla falló.** Antes de confiar en que la app funciona contra ese proyecto de Supabase, hay que verificar el esquema real (por ejemplo consultando el SQL Editor o el Table Editor del proyecto) contra esta lista de columnas asumidas.

### Otras observaciones (no son violaciones de la regla escrita)

Igual que en la auditoría anterior: varias lecturas van directo de un provider de Riverpod al repositorio sin pasar por un caso de uso (`cuentasProvider`, `categoriasProvider`, `deudaPorIdProvider`, `deudasProvider`, `cuentaPorIdProvider`, `categoriaPorIdProvider`, `transaccionPorIdProvider`, `pagosPorDeudaProvider`, `transaccionesPorCuentaProvider`, `transaccionesPorCategoriaProvider`, `pagosPorCuentaProvider`, `todasLasTransaccionesProvider`, todos en `providers.dart`). Como dependen de la interfaz abstracta de `domain/repositories/`, esto no viola la regla escrita en `CONTEXTO.md` §3, pero mantiene la misma inconsistencia de rigor que antes: escrituras con lógica de negocio pasan por casos de uso, lecturas simples no.

---

## 6. Estado de las pruebas

**45 archivos en `test/`, 140 tests, 140 pasan (verificado ejecutando `flutter test` en este momento, salida completa capturada — `00:00 ... 01:37 +140: All tests passed!`).** Ninguno toca la red real de Supabase o Gemini (los adapters de red se prueban con clientes falsos/mockeados).

| Archivo | Qué cubre |
|---|---|
| `widget_test.dart` | Dashboard con datos de fixture y el estado vacío (`DashboardEmptyState`) |
| `transaccion_nueva_screen_test.dart` | Botón Guardar deshabilitado en vacío; se habilita al completar monto/cuenta/categoría |
| `transaccion_nueva_screen_editar_test.dart` | Modo edición precarga datos; eliminar con confirmación invoca `EliminarTransaccion` y revierte el saldo |
| `transaccion_nueva_screen_crear_categoria_test.dart` | "+ Crear categoría nueva" crea y selecciona la categoría sin perder los demás campos del formulario |
| `deuda_nueva_screen_test.dart` | Botón deshabilitado en vacío; campos de interés/estructura de pago aparecen/desaparecen según el switch |
| `deuda_nueva_screen_editar_test.dart` | Modo edición precarga datos; eliminar una deuda con pagos muestra error en diálogo (no la borra) |
| `deuda_nueva_screen_historial_test.dart` | "Ver historial de pagos" solo aparece en modo edición |
| `pago_deuda_nuevo_screen_test.dart` | Deshabilitado en vacío; error inline si capital+interés no cuadra; dropdown de cuenta filtrado por moneda de la deuda |
| `registrar_pago_deuda_test.dart` | Un pago que salda una deuda en mora limpia `enMora`/`diasMora`; rechaza moneda distinta; pago retroactivo (`cuentaId: null`) no descuenta saldo |
| `actualizar_estado_mora_test.dart` | Deuda vencida pasa a `enMora`; una que ya no está vencida vuelve a `activa`; `pagoLibre` nunca cambia; no reescribe si nada cambió |
| `registrar_deuda_test.dart` | `interesTotal` derivado de cuota×cuotas−total; `proximaFechaPago`/`fechaVencimientoFinal` derivados del cronograma |
| `cronograma_cuotas_test.dart` | Lista vacía para `pagoLibre`; fechas mensual/quincenal (respetando fin de mes); pagos legacy sin `numeroCuota` se asignan por orden de fecha |
| `deuda_detalle_screen_test.dart` | Deuda `cuotasFijas` muestra resumen y cronograma; `pagoLibre` muestra "Sin cuota fija" e historial embebido |
| `app_database_migracion_test.dart` | La migración a `schemaVersion` 3 asigna `periodicidadCuotas = mensual` solo a deudas `cuotasFijas` legacy sin periodicidad |
| `integracion_saldo_cuenta_test.dart` | Integración real contra `AppDatabase` en memoria (sin fakes): ingreso/gasto/edición/eliminación/pago actualizan `saldoActual` de verdad en Drift |
| `refresco_saldo_tras_ingreso_test.dart` | Tras registrar un ingreso, el carrusel de cuentas refleja el saldo actualizado sin reiniciar la app |
| `cuenta_nueva_screen_test.dart` | Deshabilitado sin nombre; guardar crea la cuenta |
| `cuenta_nueva_screen_editar_test.dart` | Modo edición precarga datos, saldo de solo lectura; eliminar una cuenta con movimientos muestra error |
| `ajustar_saldo_cuenta_test.dart` | Diferencia positiva/negativa crea una `Transaccion` de la categoría "Ajuste de saldo"; diferencia cero no crea nada |
| `cuenta_ajuste_saldo_modal_test.dart` | El modal "Ajustar" invoca `AjustarSaldoCuenta` con la diferencia correcta; dropdown de moneda deshabilitado con movimientos |
| `movimientos_cuenta_screen_test.dart` | Lista solo los movimientos de la cuenta indicada, ordenados por fecha descendente; badge "Ajuste"; estado vacío |
| `cuentas_carrusel_test.dart` | Cada tarjeta ocupa ~85% del ancho; indicador de página; deslizar avanza; con 0 cuentas solo queda la de "agregar" |
| `historial_pagos_deuda_screen_test.dart` | Lista pagos por fecha descendente; desglose capital/interés; estado vacío |
| `root_screen_test.dart` | Sin sesión → login; con sesión sin bloqueo → sigue el flujo; con sesión y bloqueo sin desbloquear → `DesbloqueoScreen` |
| `necesita_migracion_provider_test.dart` | Instalación nueva sin datos locales marca `datosEnLaNube` sin mostrar la pantalla; con datos locales sí la muestra; si `datosEnLaNube` ya es true, no toca Drift |
| `providers_bifurcacion_test.dart` | `datosEnLaNubeProvider` lee la preferencia correctamente; los 5 repositorios financieros resuelven a Drift o Supabase según esa preferencia |
| `migrar_datos_a_la_nube_test.dart` | Sube todo preservando IDs en el orden correcto (sin categorías predeterminadas); un fallo a mitad de camino propaga el error y no sigue ni toca lo local; si la verificación final no cuadra los conteos, lanza `MigracionFallidaException` |
| `supabase_adapters_mapeo_test.dart` | `aDominio`/`aFila` de los 5 adapters Supabase mapean columnas snake_case correctamente (incluye casteo de `num`→`double`, categoría predeterminada con `user_id null`, pago retroactivo con `cuenta_id null`) — sin red real |
| `onboarding_nombre_step_test.dart` | "Continuar" deshabilitado sin texto |
| `onboarding_cuentas_step_test.dart` | "Continuar" deshabilitado sin cuentas; se habilita tras guardar una cuenta |
| `onboarding_deudas_step_test.dart` | "Omitir por ahora" avanza sin crear ninguna deuda |
| `onboarding_flow_screen_test.dart` | Recorrido completo del wizard; un "relanzamiento" simulado ya no muestra el onboarding |
| `preferencias_repository_test.dart` | Guarda/lee API key de Gemini, PIN hash, bloqueo biométrico y bloqueo omitido, todos independientes entre sí |
| `obtener_consejos_financieros_test.dart` | `ResumenParaConsejos` agrega correctamente y verifica que NO contiene identificadores de deuda/acreedor/cuenta |
| `gemini_consejos_repository_test.dart` | Sin API key lanza error sin llamar a la red; parsea 200; 403 da mensaje sobre la API key; fallo de red no expone la excepción cruda |
| `mi_perfil_screen_test.dart` | Precarga nombre y API key; guardarlos invoca al repositorio; campo de API key oculto por defecto |
| `todos_los_movimientos_screen_test.dart` | Usa `obtenerTodas()`, no `obtenerPorCuenta`/`obtenerRecientes`; estado vacío |
| `dashboard_acordeon_test.dart` | `DeudasActivasSection`/`MovimientosRecientesSection` expanden/colapsan sin ocultar el encabezado |
| `pin_hash_test.dart` | Mismo PIN → mismo hash; PINs distintos → hashes distintos; el hash nunca es el PIN en texto plano |
| `login_screen_test.dart` | Deshabilitado en vacío/correo inválido/contraseña corta; datos válidos invocan `AuthRepository.iniciarSesion`; error muestra mensaje traducido |
| `crear_cuenta_screen_test.dart` | Deshabilitado en vacío/contraseña corta; contraseñas distintas muestran error inline; correo ya registrado muestra mensaje traducido |
| `configurar_bloqueo_screen_test.dart` | PIN válido se guarda hasheado; PIN/confirmación distintos deshabilitan "Guardar PIN"; "Omitir por ahora" marca el bloqueo omitido |
| `desbloqueo_screen_test.dart` | PIN incorrecto muestra error y no desbloquea; PIN correcto desbloquea (probado de punta a punta vía `RootScreen`); "Usar mi correo y contraseña" cierra sesión |
| `categoria_usecases_test.dart` | `CrearCategoria` siempre crea con `esPredeterminada: false`; `EditarCategoria`/`EliminarCategoria` rechazan tocar una predeterminada; elimina una propia sin movimientos |
| `categoria_formulario_test.dart` | El selector de ícono cambia el ícono elegido antes de guardar |

### Partes del flujo de usuario sin ningún test

- **`MisCuentasScreen`: cero tests** — no existe ningún archivo `mis_cuentas_screen_test.dart` ni ninguna prueba que monte esta pantalla (verificado con `grep` sobre todo `test/`). Sigue siendo el mismo hueco que señalaba el informe anterior.
- **`MigrarDatosScreen` (Fase 21) no tiene ningún test a nivel de widget** — existe cobertura sólida de la lógica pura (`migrar_datos_a_la_nube_test.dart`, `necesita_migracion_provider_test.dart`, `providers_bifurcacion_test.dart`), pero ningún test monta la pantalla real y toca "Subir mis datos" para verificar el diálogo de confirmación, el estado de progreso por etapas, o el flujo de reintento tras un error — el único componente de la migración que queda sin probar es exactamente la UI que el usuario ve.
- **Guardado real de `RegistrarGasto`/`RegistrarIngreso`/`RegistrarDeuda`/`RegistrarPagoDeuda` desde el botón "Guardar" de sus pantallas**: los tests de esas pantallas cubren habilitación de campos, no el guardado real end-to-end (eso sí está cubierto a nivel de caso de uso puro con repos fake en `registrar_deuda_test.dart`/`registrar_pago_deuda_test.dart`, pero no como interacción de UI).
- **Navegación real desde el dashboard**: tap en la tarjeta "+" del carrusel, ícono "Registrar pago" por fila de deuda, y los 4 botones del `bottomNavigationBar` — ninguno se prueba con un tap real que dispare `Navigator.pushNamed`.
- **`app.dart` / tabla de rutas real y `onGenerateRoute`**: ningún test monta `FinanzasAutomaticasApp` completo; todos montan la pantalla bajo prueba en un `MaterialApp` propio.
- **`ObtenerResumenDashboard` como unidad**: no hay un test que lo invoque directo contra repos fake y verifique sus cálculos (`deudasEnMoraCount`, `deudasPorVencerEstaSemanaCount`, agregación por moneda) de forma aislada.
- **Ramas de error (`AsyncError`)**: `DashboardScreen`, `RootScreen`, `MisCuentasScreen` tienen manejo de error en código, pero ningún test fuerza que un repositorio falle para verificarlo.
- **Nada prueba contra un proyecto de Supabase real** — es coherente con ser tests unitarios/widget, pero significa que la corrección del esquema de columnas asumido (§5) no tiene ninguna red de seguridad automatizada.
- **No hay ningún test relacionado con eliminación de cuenta de usuario**, porque la funcionalidad no existe (ver §7a).
- **No hay ningún test de `local_auth` real ni de comportamiento en iOS específicamente** (esperable — son pruebas de Flutter/Dart, no de la plataforma nativa), pero significa que el hueco de `Info.plist` (§7c) no lo detecta ningún test.

---

## 7. Huecos y pendientes

### (a) Eliminación de cuenta de usuario — Apple Guideline 5.1.1(v)

**No existe ningún flujo de eliminación de cuenta.** Verificado exhaustivamente:

- `domain/repositories/auth_repository.dart` define exactamente 3 métodos: `haySesionActiva`, `iniciarSesion`, `crearCuenta`, `cerrarSesion`. No hay `eliminarCuenta`, `deleteAccount`, ni nada equivalente.
- `SupabaseAuthRepository` (`infrastructure/auth/supabase_auth_repository.dart`) implementa exactamente esos 3 métodos — no llama a ningún endpoint de borrado de usuario (ni `auth.admin.deleteUser`, que de todas formas requeriría `service_role` y no debería vivir en el cliente).
- `mi_perfil_screen.dart` (la única pantalla de ajustes de cuenta) solo tiene "Guardar" (nombre/API key) y "Cerrar sesión" — no hay ningún botón de "Eliminar mi cuenta" ni enlace a un flujo de borrado.
- Búsqueda de `TODO`/`FIXME`/palabras clave de borrado de cuenta (`eliminarCuentaUsuario`, `deleteUser`, `GDPR`, `5.1.1`) en todo `lib/`: **cero resultados**. No hay ni siquiera un TODO marcando esto como pendiente conocido — no está en progreso.

Apple exige (Guideline 5.1.1(v)) que si una app permite crear cuenta, también debe ofrecer un mecanismo para iniciar el borrado de esa cuenta y sus datos asociados directamente desde dentro de la app (no basta con un correo o un enlace externo). Con el estado actual del código, la app **no cumple este requisito**. Esto es lo primero que hay que resolver antes de enviar a revisión.

### (b) `lib/config/supabase_config.dart` — credenciales reales, no placeholder

Confirmado por lectura directa: el archivo tiene `supabaseUrl = 'https://oyoxbvloqqiiasiaugzm.supabase.co'` y `supabaseAnonKey = 'sb_publishable_QhGrHcVMjCCPol9U31k2lA_fQwMS3PQ'` — ya no son los placeholders `TU_PROJECT_URL_AQUI`/`TU_ANON_KEY_AQUI` que describía el informe anterior. El comentario que encabeza el archivo (líneas 1-8) sigue redactado como si fueran placeholders ("reemplaza estos dos valores... antes de compilar contra un backend real"), lo cual está desactualizado y puede confundir a quien lea el archivo. En principio esto significa que `Supabase.initialize()` puede autenticar contra un proyecto real — pero no fue posible verificar desde este entorno de auditoría (sin acceso de red ni credenciales del panel de Supabase) si el proyecto está realmente activo, si las tablas del esquema asumido en §5 existen con esos nombres de columna, ni si las políticas RLS están configuradas. Antes de dar por buena la Fase 21 en producción, hay que confirmarlo contra el panel real de Supabase.

### (c) TODO/FIXME/HACK

**Cero resultados** en una búsqueda exhaustiva de `TODO|FIXME|HACK` sobre todo `lib/`. Igual que en la auditoría anterior, todo lo señalado en este informe se encontró revisando la lógica, no porque el código mismo lo marcara como pendiente.

### (d) Configuración iOS

- **`ios/Runner/Info.plist` no declara ningún `NSFaceIDUsageDescription`** (ni ninguna otra clave de uso de permisos: no hay `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, etc.). El archivo solo tiene las claves mínimas que genera `flutter create` (nombre, orientaciones, storyboard). Sin embargo, la app **sí invoca biometría en tiempo de ejecución**: `configurar_bloqueo_screen.dart` llama `LocalAuthentication().canCheckBiometrics` y ofrece activar "Face ID / huella", y `desbloqueo_screen.dart` llama `_localAuth.authenticate(...)` con `biometricOnly: true` automáticamente al abrir la pantalla si el bloqueo biométrico está activo. **En iOS, invocar Face ID sin `NSFaceIDUsageDescription` en `Info.plist` hace que la app crashee** en el momento en que se intenta usar — no es un error silencioso, es un crash. Esto es tanto un bug funcional (la app se cae en un dispositivo real si el usuario activa el bloqueo biométrico) como un motivo de rechazo directo en revisión de Apple.
- No se encontró ningún archivo `codemagic.yaml` ni configuración de Codemagic en el repositorio (`find . -iname "codemagic*"` sin resultados) — si el build/deploy a TestFlight depende de Codemagic, esa configuración no vive en este repositorio o no existe todavía.
- El resto de `ios/Runner/` (bundle id vía `$(PRODUCT_BUNDLE_IDENTIFIER)`, `AppIcon.appiconset` con los tamaños estándar completos, `LaunchScreen.storyboard`) tiene la forma estándar de un proyecto Flutter recién generado, sin señales de personalización adicional más allá de `CFBundleDisplayName = "Finanzas Automaticas"`.

### Huecos funcionales heredados de fases anteriores (siguen vigentes salvo que se indique lo contrario)

- **No hay manejo de errores de base de datos/red más allá de mostrar un mensaje** — sigue vigente, ahora con dos fuentes de error en vez de una: Drift (local) y Postgrest/Supabase (`supabase_errores.dart`, mensajes genéricos "No se pudo guardar, intenta de nuevo." o "Sin conexión a internet.").
- **No hay selector de mes en el dashboard** — `ObtenerResumenDashboard` sigue calculando siempre sobre el mes calendario en curso (`obtener_resumen_dashboard.dart:28-32`). Sigue vigente.
- **El ícono de notificaciones del dashboard sigue sin hacer nada** (`dashboard_screen.dart:49-52`, `onPressed: () {}`) — puramente decorativo. El ícono de escudo junto a él (`gpp_good_outlined`, línea 47) tampoco tiene acción — es nuevo respecto al informe anterior y también decorativo.
- ~~La app dejó de ser offline-first (Fase 21)~~ — **confirmado, sigue vigente como comportamiento esperado, no como bug**: cada lectura/escritura de datos financieros requiere conexión a internet una vez migrado a Supabase.
- **`DashboardEmptyState` sigue siendo efectivamente inalcanzable** desde que el onboarding obligatorio impide llegar al dashboard con cero cuentas — el widget y su test siguen existiendo y pasando, pero ejercitan una ruta que el usuario real no puede alcanzar.

---

## 8. Deuda técnica conocida

Auditoría exhaustiva y sin suavizar — esto se usa para decidir qué corregir antes de una revisión de Apple en 2 días.

### Bloqueantes reales para la revisión de Apple

- 🔴 **No hay flujo de eliminación de cuenta de usuario** (Guideline 5.1.1(v)) — ver §7(a). Es un rechazo casi seguro si Apple revisa el flujo de cuenta, que sí lo hace de forma rutinaria cuando una app tiene login. No hay ningún trabajo en progreso visible en el código (sin TODOs, sin pantallas a medio construir, sin métodos de repositorio parcialmente implementados apuntando a esto).
- 🔴 **`local_auth` se invoca sin la clave `NSFaceIDUsageDescription` en `Info.plist`** — crashea en un iPhone real con Face ID en cuanto se activa el bloqueo biométrico (`configurar_bloqueo_screen.dart`) o se reabre la app en frío con bloqueo biométrico ya activo (`desbloqueo_screen.dart` lo intenta automáticamente). Esto es tanto un bug de crash en producción como un motivo de rechazo en revisión.

### Riesgos de seguridad/configuración

- ⚠️ **`lib/config/supabase_config.dart` tiene una URL de proyecto y una `anonKey`/`publishableKey` con formato real escritas en texto plano en el código fuente**, con un comentario que todavía dice que son placeholders (desactualizado). Una `anon`/`publishable key` de Supabase está diseñada para ser pública (protegida por RLS, no es un secreto de servidor), así que esto no es en sí mismo una vulnerabilidad grave — pero si esta URL/key corresponden a un proyecto real de desarrollo/producción, conviene confirmar que las políticas RLS estén activas y correctas antes de asumir que los datos están protegidos, y considerar si el proyecto apuntado es el que realmente se quiere usar en producción o si es un proyecto de pruebas que no debería quedar hardcodeado permanentemente.
- ⚠️ **El esquema de columnas de Supabase usado por los 5 adapters (`infrastructure/persistence/supabase/`) sigue sin poder verificarse contra un `schema_finanzas_v3.sql` real** — ese archivo no existe en el repositorio. A diferencia de la auditoría anterior (donde las credenciales eran placeholder y por lo tanto esto era un riesgo teórico), ahora que hay credenciales con forma real, cualquier discrepancia entre el mapeo snake_case asumido y el esquema real hace fallar cada operación con un mensaje genérico ("No se pudo guardar, intenta de nuevo."), sin indicar la causa real ni en la UI ni en logs accesibles al usuario (solo `debugPrint`, que no llega a producción). Antes de confiar en que Supabase funciona de verdad, hay que confirmarlo contra el proyecto real.

### Deuda de arquitectura (vigente, sin cambios de fondo respecto a la auditoría anterior)

- **`domain/` sigue dependiendo de paquetes externos** (`package:uuid`, `package:crypto`), contradiciendo literalmente `CONTEXTO.md` §3. Ver archivos citados en §5.
- **`Deuda.copyWith()` sigue sin poder poner un campo nullable de vuelta a `null`** (`domain/entities/deuda.dart:85-122`, patrón `campo ?? this.campo`). `RegistrarPagoDeuda` sigue resolviéndolo reconstruyendo el objeto `Deuda` a mano en vez de usar `copyWith` cuando necesita anular `proximaFechaPago`. Sigue siendo una trampa latente para cualquier código nuevo que asuma que `copyWith` se comporta como en la mayoría de las clases Dart.
- **Validaciones que siguen existiendo solo en la UI, no en el dominio:** ningún caso de uso (`RegistrarGasto`, `RegistrarIngreso`, `RegistrarDeuda`, `RegistrarPagoDeuda`) valida que los montos sean positivos — esa validación vive únicamente en los `_esValido` de cada formulario. La regla "capital + interés debe sumar el monto pagado" sigue viviendo solo en `pago_deuda_nuevo_screen.dart` (`_errorDesglose`), no en `RegistrarPagoDeuda`. Cualquier caller que no sea la UI actual (otro adapter, un test, una futura API) podría violar ambas reglas sin que el dominio lo impida.
- **`_seedCategoriasDefault`/`_seedCategoriasAjuste` solo corren en `onCreate`/migraciones de `AppDatabase`** (Drift) — no hay forma de re-sembrar categorías por defecto desde la app si la tabla local queda vacía por otra vía. Con la migración a Supabase, además, el sembrado de categorías predeterminadas en la nube depende de un script SQL corrido manualmente (mencionado en `CONTEXTO.md` pero sin el script en el repo) — si ese sembrado no se hizo o falla, no hay ningún mecanismo de la app que lo repare.
- **Ningún repositorio ni caso de uso envuelve errores de Drift/`shared_preferences` en excepciones propias del dominio** — sigue vigente. Los adapters de Supabase sí envuelven sus errores (`conManejoDeErroresSupabase`), pero los de Drift y `shared_preferences` propagan la excepción cruda tal cual hasta la UI.

### Hallazgos nuevos de esta auditoría

- **`lib/domain/calculo_fechas.dart` (`calcularProximaFechaPago`) es código muerto** — no lo usa ningún caller real desde que `cronograma_cuotas.dart` reemplazó ese cálculo en la Fase 14. No aparece en ningún `import` fuera de sí mismo. Candidato a borrar.
- **`Categoria.esPredeterminada` no está en la lista de campos de `CONTEXTO.md` §2** aunque existe en el código y en el schema desde la Fase 20 — ver §3. Es una discrepancia de documentación, no de código, pero puede llevar a alguien a asumir que el modelo de `Categoria` tiene 4 campos cuando tiene 5.
- **El comentario de cabecera de `supabase_config.dart` está desactualizado** (sigue hablando de placeholders cuando ya no lo son) — riesgo de que alguien reemplace credenciales reales pensando que está "completando" un placeholder, o que no note que ya hay credenciales reales configuradas.

### Hallazgos del informe anterior ya resueltos (confirmado por esta auditoría)

- ~~`CategoriaRepository.obtenerPorId` nunca se llama~~ — resuelto en la Fase 20 (`categoriaPorIdProvider` + `categoria_formulario.dart`).
- ~~`lib/config/supabase_config.dart` tiene credenciales placeholder sin llenar~~ — ya no: tiene credenciales con forma real (ver arriba, esto ahora es una nota distinta, no el mismo hallazgo).
- ~~El carrusel de cuentas / rediseño del dashboard / autenticación / ajuste de saldo / categorías propias / consejos con IA~~ — todo esto sigue construido y funcionando exactamente como describía el informe anterior, sin regresiones detectadas.

---

*Fin del informe.*
