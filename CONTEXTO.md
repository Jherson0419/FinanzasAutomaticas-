# Contexto del proyecto — Finanzas Automáticas

## 1. Visión y alcance

**Finanzas Automáticas** es una app móvil de finanzas personales que elimina la fricción del registro manual de transacciones. Controla ingresos, gastos y deudas en un solo lugar.

**Etapas de desarrollo (en orden):**
1. **Etapa 1 — Local, un solo usuario (superada, Fase 21):** app 100% local en el dispositivo, sin backend. Este modo ya no es el que corre en producción — se documenta porque los adapters Drift siguen existiendo (se usan durante la migración y, hasta que un dispositivo migra, como fuente de datos).
2. **Etapa 2 — Producción/multiusuario (completada, Fase 21):** los datos financieros (`Cuenta`, `Categoria`, `Transaccion`, `Deuda`, `PagoDeuda`) viven en Supabase (PostgreSQL + Row Level Security por usuario), no en Drift. **La app dejó de ser offline-first**: registrar/editar/leer cualquier dato financiero requiere conexión a internet. Ver "Migración a Supabase (Fase 21)" en la sección 3.
3. **Etapa 3 — Automatización de captura (futuro):**
   - **Android:** escucha de notificaciones push en segundo plano (`NotificationListenerService`), filtrando por `packageName` de apps bancarias/billeteras peruanas (Yape, Plin, BBVA, BCP, Scotiabank).
   - **iOS:** sincronización de correos bancarios (Gmail API/OAuth) y OCR de capturas de pantalla de comprobantes (`google_mlkit_text_recognition`).
   - En ambos casos, el texto capturado se envía a un LLM (Gemini/OpenAI) con un prompt unificado que devuelve un JSON estructurado (`es_transaccion`, `tipo`, `monto`, `moneda`, `concepto`, `categoria_sugerida`).

**Fuera de alcance por ahora:** todo lo de la Etapa 3 (automatización). Las Etapas 1 y 2 ya están construidas.

**Autenticación (Fase 18), vigente sin cambios de fondo:** la app requiere iniciar sesión con Supabase Auth (correo + contraseña) antes de entrar, más un bloqueo local opcional (PIN/biométrico) para reabrir la app rápido — ver "Autenticación y bloqueo local" en la sección 2. Antes de la Fase 21 esto era "solo autenticación" (los datos financieros seguían en Drift); desde la Fase 21, la misma sesión de Supabase Auth es también la que autoriza (vía RLS) las lecturas/escrituras de datos financieros.

---

## 2. Modelo de datos (entidades y relaciones)

### Cuenta
Representa una cuenta o medio de pago del usuario (efectivo, billetera digital, tarjeta).
- `id`, `nombre`, `tipo` (`debito` | `credito` | `billetera` | `efectivo`)
- `moneda` (`PEN` | `USD`)
- `saldoActual` — se actualiza automáticamente al registrar una `Transaccion`

### Categoria
Clasificación de una transacción.
- `id`, `nombre`, `tipo` (`ingreso` | `gasto`), `iconName`
- Existen categorías predeterminadas (Comida, Transporte, Salud, Entretenimiento, Servicios, Educación, Hogar, Otros gastos, Sueldo, Freelance, Otros ingresos, y "Ajuste de saldo" en ambos tipos — ingreso y gasto — para `AjustarSaldoCuenta`) y el usuario puede crear las propias.

### Transaccion
Un ingreso o gasto puntual.
- `id`, `cuentaId` (FK → Cuenta), `categoriaId` (FK → Categoria)
- `monto`, `moneda`, `tipo` (`ingreso` | `gasto`)
- `concepto`, `metodoPago` (`efectivo` | `transferencia` | `tarjeta` | `yape` | `plin` | `otro`)
- `esRecurrente` (bool — gasto/ingreso fijo mensual vs. puntual)
- `comprobanteUrl` (opcional, foto del comprobante)
- `fuenteCaptura` (`manual` | `notificacion_android` | `correo_ios` | `ocr_ios` | `ajuste`) — hoy siempre `manual`, salvo los movimientos generados por `AjustarSaldoCuenta` (`ajuste`)
- `dataRaw` (texto original, solo relevante cuando la fuente no es manual)
- `fecha`

### Deuda
Cualquier obligación de pago pendiente, con estructura flexible para cubrir distintos tipos.
- `id`, `nombreDeuda`
- `tipoDeuda` (`tarjeta_credito` | `prestamo_personal` | `prestamo_vehicular` | `hipoteca` | `prestamo_estudiantil` | `compra_cuotas` | `deuda_informal` | `otro`)
- `tipoAcreedor` (`entidad_financiera` | `persona_natural` | `comercio`), `nombreAcreedor`
- `moneda`, `montoTotal`, `montoPagado` (caché, la fuente real es `PagoDeuda`)
- `tieneInteres` (bool), `tasaInteres`, `tipoTasa` (`fija` | `variable`)
- `estructuraPago` (`cuotas_fijas` | `pago_libre`)
- `numeroCuotasTotal`, `numeroCuotasPagadas`, `montoCuota`, `pagoMinimo` (relevante para tarjetas)
- `fechaInicio`, `fechaVencimientoFinal`, `diaPago`, `proximaFechaPago`
- `enMora` (bool), `diasMora`, `tasaInteresMoratorio`
- `estado` (`activa` | `pagada` | `en_mora` | `refinanciada` | `cancelada`)
- `notas` (opcional, texto libre)

### PagoDeuda
Historial de abonos a una `Deuda` (reemplaza un simple acumulador por trazabilidad real).
- `id`, `deudaId` (FK → Deuda), `cuentaId` (FK → Cuenta, de dónde salió el pago)
- `montoPagado`, `montoCapital`, `montoInteres` (desglose cuando la deuda tiene interés)
- `fechaPago`, `numeroCuota`

### Preferencias de app
Preferencias de app (nombre, onboarding completado, API key de Gemini) se guardan localmente fuera del esquema de datos financieros, vía `shared_preferences` (`domain/repositories/preferencias_repository.dart` + adapter en `infrastructure/persistence/`, sin pasar por Drift). La API key de Gemini (Fase 17) nunca sale de este dispositivo salvo hacia la propia API de Gemini al pedir consejos financieros.

### Relaciones clave
- Una `Cuenta` tiene muchas `Transaccion` y puede financiar muchos `PagoDeuda`.
- Una `Categoria` tiene muchas `Transaccion`.
- Una `Deuda` tiene muchos `PagoDeuda`.
- Al insertar un `PagoDeuda` → se actualiza `montoPagado` y `numeroCuotasPagadas` de su `Deuda`, y su `estado` pasa a `pagada` si se cubre el `montoTotal`.
- Al insertar una `Transaccion` → se actualiza `saldoActual` de su `Cuenta` (suma si es ingreso, resta si es gasto).

### Campos añadidos en Fase 14 (interés automático, cronograma de cuotas, pagos retroactivos)
- `Deuda.periodicidadCuotas` (`mensual` | `quincenal`): requerido cuando `estructuraPago = cuotas_fijas`, `null` para `pago_libre`. Define el espaciado entre cuotas del cronograma.
- `Deuda.interesTotal`: solo para `cuotas_fijas`. Calculado, nunca manual: `(montoCuota × numeroCuotasTotal) − montoTotal`. Para esa estructura, `tieneInteres` se deriva de `interesTotal != null && interesTotal > 0` (ya no es un switch manual). Para `pago_libre` se mantiene el switch manual `tieneInteres` + `tasaInteres` sin cambios.
- Para `cuotas_fijas`, `proximaFechaPago` y `fechaVencimientoFinal` ya no se piden ni se guardan como campos manuales: se derivan dinámicamente del cronograma de cuotas (`domain/cronograma_cuotas.dart`) cada vez que se lee la deuda. `diaPago` queda en el esquema solo por compatibilidad con datos antiguos; el formulario ya no lo pide para deudas nuevas.
- **Cronograma de cuotas**: para una deuda `cuotas_fijas`, `generarCronogramaCuotas(deuda, pagos)` genera `numeroCuotasTotal` cuotas programadas (número, fecha de vencimiento, monto esperado, si está pagada y con qué `PagoDeuda`), cruzando contra los pagos ya registrados. Es un concepto puramente derivado — no se persiste como tabla propia.
- `PagoDeuda.cuentaId` ahora es opcional (`null` cuando el pago es retroactivo, ver abajo).
- **Pago retroactivo**: al registrar un pago se puede marcar como "ya ocurrió antes" — en ese caso no se asocia ninguna `Cuenta` (`cuentaId = null`), no se descuenta ningún `saldoActual` y no se valida coincidencia de moneda. Es un diseño intencional para registrar historial pasado sin afectar el estado financiero actual.

### Ajuste de saldo de cuenta (Fase 16)
- `saldoActual` de una `Cuenta` sigue sin ser un campo editable directamente (se deriva de sus movimientos). Para corregirlo a un valor real conocido existe `AjustarSaldoCuenta`: recibe el saldo real informado por el usuario, calcula la diferencia contra `saldoActual` y registra esa diferencia como una `Transaccion` más (tipo `ingreso` si la diferencia es positiva, `gasto` si es negativa), en vez de sobrescribir el número. Si la diferencia es exactamente cero, no se crea ningún movimiento.
- Esas transacciones usan las categorías predeterminadas "Ajuste de saldo" (una de tipo `ingreso`, otra de tipo `gasto`) y `fuenteCaptura: ajuste`, lo que permite distinguirlas visualmente de un movimiento manual en el historial y en "Movimientos recientes".

### Consejos financieros con IA (Fase 17)
- Nuevo flujo, independiente del uso de Gemini planeado para la Etapa 3 (esa es para categorizar automáticamente notificaciones/correos capturados; esta es para pedir consejos financieros a demanda del usuario, ya en la Etapa 1 local). No cambia el roadmap de la Etapa 3.
- `ObtenerConsejosFinancieros` arma un `ResumenParaConsejos` — **agregado y anonimizado**: nunca incluye `nombreDeuda`, `nombreAcreedor` ni nombres de `Cuenta`. Solo viaja: tipo de deuda + montos + interés total + moneda por cada deuda activa, montos de ingresos/gastos del mes agrupados por nombre de categoría (una categoría como "Comida" no identifica a nadie) y moneda, y el saldo total por moneda.
- Ese resumen es lo único que sale del dispositivo, y solo hacia la API de Gemini (`generateContent`), nunca a otro destino. La API key de Gemini se guarda en `PreferenciasRepository` y solo se usa para esa llamada.
- Sin API key configurada, `ConsejosFinancierosRepository` no intenta llamar a la red: lanza `ApiKeyGeminiFaltanteError` de inmediato, y la pantalla ofrece ir directo a "Mi perfil" a configurarla.
- Los consejos no se persisten entre sesiones — se piden explícitamente (botón "Generar consejos"/"Actualizar"), nunca automáticamente al abrir la pantalla.

### Autenticación y bloqueo local (Fase 18)
- **Qué protege Supabase Auth y qué no:** una sesión de Supabase (correo + contraseña, `supabase_flutter`) es la puerta de entrada a la app — sin sesión activa, `RootScreen` muestra `LoginScreen`/`CrearCuentaScreen` en vez del dashboard. Supabase **no** almacena ni ve ningún dato financiero: solo autentica. Todo el resto de la app (Drift, casos de uso, providers) es exactamente igual que antes de esta fase.
- **Puerto vs. adapter:** igual que con Gemini, el dominio depende de `AuthRepository` (puerto), nunca de Supabase directamente; `SupabaseAuthRepository` (`infrastructure/auth/`) es el único archivo que toca `Supabase.instance`. Esto permite testear toda la UI de login/bloqueo con un `AuthRepository` fake, sin llamar a la red.
- **Bloqueo local (PIN/biométrico), opcional y adicional a la sesión:** justo después del primer login (y solo esa vez, salvo que se vuelva a preguntar tras un logout), `ConfigurarBloqueoScreen` ofrece configurar un PIN de 4 dígitos y/o Face ID/huella (`package:local_auth`), con opción de "Omitir por ahora" (se recuerda en `PreferenciasRepository`, no se vuelve a preguntar solo). El PIN se guarda **hasheado** (`domain/pin_hash.dart`, sha256 + salt fijo — suficiente para este alcance de bloqueo local, no para proteger datos en un servidor), nunca en texto plano.
- **`DesbloqueoScreen`** solo aparece en aperturas en frío (cold start) de la app cuando ya hay bloqueo configurado — no al volver de segundo plano. Intenta biométrico automáticamente si está activo; si falla/cancela o solo hay PIN, pide el PIN y compara hashes. "Usar mi correo y contraseña" cierra la sesión de Supabase y vuelve al login — no hay pregunta de seguridad aparte, recuperar acceso es volver a autenticarse.
- **Cerrar sesión** (`mi_perfil_screen.dart`) cierra la sesión de Supabase pero **nunca borra los datos locales de Drift** — son cosas independientes.

---

## 3. Decisiones de arquitectura

- **Arquitectura hexagonal (Ports & Adapters)**, para que migrar de almacenamiento local a Supabase en la Etapa 2 sea reemplazar adapters, no reescribir casos de uso.
  - `domain/`: entidades y reglas de negocio puras, sin dependencias de Flutter ni de paquetes externos.
  - `domain/repositories/`: interfaces abstractas (ports) — `DeudaRepository`, `TransaccionRepository`, `CuentaRepository`.
  - `application/`: orquestación de casos de uso, DTOs.
  - `infrastructure/persistence/drift/`: adapters concretos que implementan los ports usando Drift (SQLite local).
  - `presentation/`: UI (screens, widgets, gestión de estado), depende solo de `application/` y `domain/`, nunca de `infrastructure/` directamente.
- **Stack Etapa 1 (histórico):** Flutter (Dart) + Drift (SQLite local). Se eligió Drift sobre Hive/sqflite plano porque el modelo es relacional (FKs entre Deuda, PagoDeuda, Transaccion, Cuenta, Categoria) y su estructura se tradujo casi 1:1 al esquema de Supabase/PostgreSQL de la Fase 21 — los adapters `infrastructure/persistence/drift/` siguen en el repo (se usan como origen durante la migración, y como destino hasta que un dispositivo migra), pero ya no son el almacenamiento de producción.
- **Stack Etapa 2 (Fase 21):** Supabase (PostgreSQL + Row Level Security por usuario) reemplazando al adapter de Drift para datos financieros — ver "Migración a Supabase (Fase 21)" más abajo.
- **Stack Etapa 3 (futuro):** API de LLM (Gemini/OpenAI) para categorización, Google ML Kit para OCR en iOS, Gmail API/OAuth para sincronización de correos.
- **Cálculos derivados** (saldo de cuenta, monto pagado de deuda) se actualizan mediante lógica de aplicación al insertar registros — en `domain/usecases/`, igual en ambos adapters (Drift/Supabase); no hay triggers SQL, la fuente de verdad de esa lógica es el caso de uso.

### Migración a Supabase (Fase 21)
- **La app dejó de ser offline-first.** Antes de esta fase, los datos financieros vivían 100% en Drift; ahora viven en Supabase (tablas de `schema_finanzas_v3.sql`, RLS por `user_id`) y cada lectura/escritura de cuentas, categorías propias, deudas, transacciones o pagos requiere conexión a internet. `Preferencias` (nombre, PIN, biométrico, API key de Gemini, y el flag `datosEnLaNube` que decide todo esto) sigue siendo 100% local vía `shared_preferences` — eso no cambió y no va a cambiar.
- **Adapters** (`infrastructure/persistence/supabase/`): uno por puerto existente (`CuentaRepositorySupabase`, `CategoriaRepositorySupabase`, `TransaccionRepositorySupabase`, `DeudaRepositorySupabase`, `PagoDeudaRepositorySupabase`), todos filtrando explícitamente por `Supabase.instance.client.auth.currentUser!.id` además de confiar en RLS (defensa en profundidad). Categorías predeterminadas: `user_id IS NULL` en la tabla, sembradas server-side una sola vez por el script SQL — la app nunca las vuelve a insertar, solo las lee (`.or('user_id.eq.<uid>,user_id.is.null')`). Los errores de red/Postgrest se envuelven en `StateError` con mensaje claro (`conManejoDeErroresSupabase`), mismo criterio que `SupabaseAuthRepository` (Fase 18).
- **Bifurcación en `providers.dart`:** los 5 providers de repositorios de datos financieros (`cuentaRepositoryProvider`, etc.) resuelven a Drift o a Supabase según `datosEnLaNubeProvider` (lectura síncrona de la preferencia `datos_en_la_nube`, necesaria porque esos providers son síncronos). `PreferenciasRepository` nunca bifurca.
- **`MigrarDatosALaNube`** (`domain/usecases/migrar_datos_a_la_nube.dart`): lee todo Drift (categorías solo las propias, `esPredeterminada == false`) e inserta en Supabase preservando los mismos IDs (uuid string en ambos lados → sin remapeo de FKs), en orden estricto por dependencias: cuentas → categorías propias → deudas → transacciones → pagos de deuda. Si un paso falla, lanza `MigracionFallidaException` con el nombre del paso y no continúa — nada local se toca durante este caso de uso, eso es responsabilidad exclusiva de la pantalla. Al terminar de subir, vuelve a contar en Supabase y compara contra los conteos locales antes de darse por exitoso.
- **`MigrarDatosScreen`** (mostrada por `RootScreen` entre "sesión activa" y "bloqueo/onboarding"): confirmación explícita antes de subir (mismo patrón de diálogo que "Eliminar cuenta") — advierte que la app pasa a requerir internet y que los datos locales se borran una vez confirmada la subida. Si falla, los datos locales quedan intactos y se puede reintentar. Si tiene éxito, borra las tablas locales (cuentas y todo lo demás completo; categorías, solo las propias — las predeterminadas locales se quedan, ya no se usan), marca `datosEnLaNube`, invalida los providers bifurcados y navega al dashboard.
- **Cuentas nuevas sin datos locales:** si no hay ninguna cuenta/deuda/transacción local (instalación nueva, verificado de verdad contra Drift, no asumido), `datosEnLaNube` se marca `true` automáticamente sin mostrar la pantalla — el onboarding que sigue ya escribe directo en Supabase.

### Sistema de diseño (Fase 19)
- La app tiene un sistema de diseño propio en `presentation/theme/app_theme.dart`, en vez del `ColorScheme.fromSeed` genérico usado hasta la Fase 18. **La app ya no sigue el tema del sistema**: `MaterialApp.themeMode` está fijo en `ThemeMode.dark`, pensado para transmitir confianza financiera con una paleta oscura consistente en toda la app (no solo el dashboard).
- **Tokens de color** (constantes top-level en `app_theme.dart`): `bgPage`, `bgCard`, `borderCard`, `textPrimary`, `textSecondary`, `textMuted`, `colorSuccess`, `colorDanger`, `colorWarning`. Se mapean a roles estándar de `ColorScheme` (`surface → bgCard`, `onSurface → textPrimary`, `primary → colorSuccess`, `error → colorDanger`, etc.) para que todo el código existente que ya usaba `Theme.of(context).colorScheme` (convención desde la Fase 5) siga funcionando sin tocarlo. El fondo de página (`scaffoldBackgroundColor`) se fija aparte en `bgPage` porque `ColorScheme.background` está deprecado.
- **`AppCard`** (`presentation/shared/app_card.dart`): tarjeta de contenido estándar — fondo `bgCard`, borde `borderCard` de 0.5px, `borderRadius: 14`. Reemplaza el `Card(elevation: 0, color: colorScheme.surfaceContainerHigh, ...)` que se repetía en cada sección del dashboard y varias pantallas de detalle/formulario.
- **`SectionLabel`** (`presentation/shared/section_label.dart`): encabezado de sección con ícono pequeño + etiqueta en mayúsculas (`sectionLabelTextStyle`: 11px, `letterSpacing: 0.06`, `textMuted`). Usado en Saldo total, Ingresos/Gastos, Gasto por categoría, Deudas activas y Movimientos recientes del dashboard.
- **`AppBottomBar`** (`presentation/shared/app_bottom_bar.dart`): la barra inferior de 4 botones (Fase 17) ahora es un widget compartido, no solo del dashboard — también se muestra en Consejos financieros y Mi perfil, para poder resaltar en `colorSuccess` con negrita el botón de la pantalla donde el usuario ya está (Gasto/Deuda son acciones, nunca se resaltan).
- **`WalletAccountCard`** conserva la paleta de degradados por `TipoCuenta` de la Fase 8 (`wallet_card_colors.dart`, sin cambios) — la Fase 19 solo le agrega un borde sutil (versión más clara del color de inicio del degradado) y pone la etiqueta de tipo de cuenta en mayúsculas con letter-spacing.
- Cualquier color que no venga de estos tokens o de la paleta de `WalletCardEstilo` se considera fuera del sistema de diseño y debe corregirse (ver `dashboard_colors.dart`, que ahora devuelve `colorSuccess`/`colorDanger` en vez de shades de `Colors.green`/`Colors.red`).

---

## 4. Roadmap por fases

**Etapa 1 — Local (histórica, superada en la Fase 21)**
1. Esqueleto de arquitectura hexagonal + entidades del dominio
2. Persistencia local con Drift (tablas + repositories concretos)
3. Casos de uso base: `RegistrarGasto`, `RegistrarIngreso`, `RegistrarDeuda`, `RegistrarPagoDeuda`, `ObtenerResumenDashboard`
4. Dashboard (UI): saldo total y por cuenta, ingresos vs. gastos del mes, gasto por categoría, resumen de deudas activas con alertas de vencimiento, movimientos recientes
5. Pantallas de registro manual: agregar gasto/ingreso, agregar deuda (formulario adaptable según `tipoDeuda`/`estructuraPago`), registrar pago de deuda

**Etapa 2 — Producción/multiusuario (completada, Fase 21)**
- ~~Migrar el adapter de persistencia de Drift a Supabase~~ — hecho: `infrastructure/persistence/supabase/`, ver sección 3.
- ~~Autenticación de usuarios~~ — hecho en la Fase 18 (Supabase Auth), adelantada respecto al resto de esta etapa.
- ~~Row Level Security~~ — hecho: cada tabla filtra por `user_id` vía RLS + el filtro explícito de cada adapter.

**Etapa 3 — Automatización**
- Fase A: motor de captura Android (notificaciones)
- Fase B: motor de captura iOS (correo + OCR)
- Fase C: motor de IA (categorización y estructuración vía LLM) + sincronización

---

## 5. Glosario de términos del dominio

- **Deuda informal:** deuda contraída con una persona natural (familiar, amigo) en vez de una entidad financiera; normalmente sin interés y sin cuota fija.
- **Estructura de pago — cuotas fijas:** la deuda tiene un número total de cuotas y un monto de cuota pactado (ej. préstamo personal, compra a plazos).
- **Estructura de pago — pago libre:** no hay cuotas fijas, solo un pago mínimo por período (ej. tarjeta de crédito).
- **En mora:** la deuda tiene un pago vencido sin cubrir; puede acumular interés moratorio adicional (`tasaInteresMoratorio`).
- **Fuente de captura:** origen del registro de una transacción — `manual` (Etapa 1), o automatizado (`notificacion_android`, `correo_ios`, `ocr_ios`) en la Etapa 3.
- **Transacción recurrente:** ingreso o gasto que se repite periódicamente (ej. alquiler, sueldo), marcado con `esRecurrente` para diferenciarlo de gastos puntuales.