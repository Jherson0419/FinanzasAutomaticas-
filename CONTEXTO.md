# Contexto del proyecto — Finzo

## 1. Visión y alcance

**Finzo** ("Finzo: Finanzas Automaticas" es el nombre visible completo, ver "Bundle ID y nombre de la app (Fase 27)" en la sección 3) es una app móvil de finanzas personales que elimina la fricción del registro manual de transacciones. Controla ingresos, gastos y deudas en un solo lugar.

**Etapas de desarrollo (en orden):**
1. **Etapa 1 — Local, un solo usuario (superada, Fase 21):** app 100% local en el dispositivo, sin backend. Este modo ya no es el que corre en producción — se documenta porque los adapters Drift siguen existiendo (se usan durante la migración y, hasta que un dispositivo migra, como fuente de datos).
2. **Etapa 2 — Producción/multiusuario (completada, Fase 21):** los datos financieros (`Cuenta`, `Categoria`, `Transaccion`, `Deuda`, `PagoDeuda`) viven en Supabase (PostgreSQL + Row Level Security por usuario), no en Drift. **La app dejó de ser offline-first**: registrar/editar/leer cualquier dato financiero requiere conexión a internet. Ver "Migración a Supabase (Fase 21)" en la sección 3.
3. **Etapa 3 — Automatización de captura (en progreso, Fase 25):**
   - **Android:** escucha de notificaciones push en segundo plano (`NotificationListenerService`), filtrando por `packageName` de apps bancarias/billeteras peruanas (Yape, Plin, BBVA, BCP, Scotiabank). Sin empezar.
   - **iOS:** un Atajo disparado por notificaciones de Apple Pay, y/o una regla de reenvío de correo (Yape/Plin) — ambos, en cuanto existan, llaman al mismo webhook por HTTP. Ver "Captura automática — Etapa 3 en progreso" en la sección 3 para el detalle de lo que ya está construido (el receptor) y lo que falta (el emisor: el Atajo y el Worker de correo, ninguno de los dos vive en este repo).
   - En ambos casos, el texto capturado se envía a Gemini con un prompt que devuelve un JSON estructurado (`tipo`, `monto`, `categoria_sugerida`, `concepto`).

**Fuera de alcance por ahora:** el emisor de la Etapa 3 (Atajo de iOS, Worker de correo, motor de Android). El receptor (Edge Function, token por usuario) ya está construido — ver sección 3. Las Etapas 1 y 2 ya están construidas.

**Autenticación (Fase 18), vigente sin cambios de fondo:** la app requiere iniciar sesión con Supabase Auth (correo + contraseña) antes de entrar, más un bloqueo local opcional (PIN/biométrico) para reabrir la app rápido — ver "Autenticación y bloqueo local" en la sección 2. Antes de la Fase 21 esto era "solo autenticación" (los datos financieros seguían en Drift); desde la Fase 21, la misma sesión de Supabase Auth es también la que autoriza (vía RLS) las lecturas/escrituras de datos financieros.

---

## 2. Modelo de datos (entidades y relaciones)

### Cuenta
Representa una cuenta o medio de pago del usuario (efectivo, billetera digital, tarjeta).
- `id`, `nombre`, `tipo` (`debito` | `credito` | `billetera` | `efectivo`)
- `moneda` (`PEN` | `USD`)
- `saldoActual` — se actualiza automáticamente al registrar una `Transaccion`
- `lineaCredito` (`double?`), `diaCorte` (`int?`, 1-31), `diaPago` (`int?`, 1-31) — Fase 29, **obligatorios cuando `tipo == credito`, `null` para los demás tipos** (validado por `RegistrarCuenta`/`EditarCuenta`). **No existe un campo de "monto utilizado"**: se deriva de `saldoActual` — en una cuenta de crédito, `saldoActual` se vuelve negativo a medida que se gasta (exactamente igual que en cualquier otra cuenta), y el valor absoluto de ese negativo ES lo usado de la línea; pagar la tarjeta es un `ingreso` más a esa cuenta, ya soportado sin cambios por `aplicarEfectoTransaccion`. Ver "Tarjetas de crédito — línea, corte y alertas (Fase 29)" más abajo.

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
- `fuenteCaptura` (`manual` | `notificacion_android` | `correo_ios` | `ocr_ios` | `ajuste` | `webhook_atajo`, Fase 25) — casi siempre `manual` hoy; `ajuste` para los movimientos de `AjustarSaldoCuenta`; `webhook_atajo` para los que inserta la Edge Function `capturar-transaccion` a partir de un Atajo de iOS (`correo_ios` se reutiliza para las capturas que lleguen por correo, sin necesitar un valor propio)
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
Preferencias de app (nombre, onboarding completado) se guardan localmente fuera del esquema de datos financieros, vía `shared_preferences` (`domain/repositories/preferencias_repository.dart` + adapter en `infrastructure/persistence/`, sin pasar por Drift). El puerto todavía declara `obtenerApiKeyGemini`/`guardarApiKeyGemini` (Fase 17) por compatibilidad con `GeminiConsejosRepository` (desconectado desde la Fase 24, ver "Consejos financieros con IA" más abajo), pero ninguna pantalla los usa ya — "Mi perfil" no vuelve a preguntar por una API key.

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

### Consejos financieros con IA (Fase 17, rediseñado en la Fase 24, chat persistente desde la Fase 30)
- Nuevo flujo, independiente del uso de Gemini planeado para la Etapa 3 (esa es para categorizar automáticamente notificaciones/correos capturados; esta es para pedir consejos financieros a demanda del usuario). No cambia el roadmap de la Etapa 3.
- **Fase 24 — la API key de Gemini dejó de ser de cada usuario.** Hasta la Fase 17-23, cada usuario ponía su propia API key en "Mi perfil" y la app llamaba a Gemini directo desde el dispositivo (`GeminiConsejosRepository`, `infrastructure/consejos/gemini_consejos_repository.dart` — sigue en el repo por si se quiere volver a ese modelo, pero desconectado de `providers.dart`, implementa el puerto de un solo turno `ConsejosFinancierosRepository` que sigue existiendo solo por eso). Ahora la API key es del distribuidor de la app: vive solo como secreto de una Edge Function de Supabase (`supabase/functions/generar-consejos/`, `Deno.env.get('GEMINI_API_KEY')`), nunca llega a ningún dispositivo, y "Mi perfil" ya no tiene ningún campo para configurarla.
- **Fase 30 — Consejos pasó de "un botón que genera una lista una vez" a un chat real con Gemini, con historial persistente.** La primera vez que el usuario entra a la pantalla y no tiene ningún mensaje guardado, la app arma su resumen financiero (ver abajo) y lo manda sola como el primer mensaje del chat — el usuario no tiene que tocar nada para arrancar la conversación. De ahí en adelante es un chat de ida y vuelta normal, con historial que persiste entre sesiones (`ConsejosFinancierosScreen` ya no tiene ningún botón "Generar"/"Actualizar consejos").
- **`MensajeConsejo`** (`domain/entities/mensaje_consejo.dart`): `id`, `rol` (`usuario` | `asistente`), `contenido`, `fecha`. Se persiste en `public.mensajes_consejos` (Supabase, Fase 30) — `user_id`, `rol`, `contenido`, `created_at`, con RLS que solo deja `SELECT` al dueño de la fila (igual que `uso_consejos`, Fase 24: nada de `INSERT`/`UPDATE` para el cliente, solo la Edge Function con la service role key escribe ahí).
- **`ArmarResumenParaConsejos`** (`domain/usecases/`, reemplaza a `ObtenerConsejosFinancieros` de la Fase 24-29, que además llamaba a Gemini directo en un solo turno) arma un `ResumenParaConsejos` — **agregado y anonimizado**: nunca incluye `nombreDeuda`, `nombreAcreedor` ni nombres de `Cuenta`. Solo viaja: tipo de deuda + montos + interés total + moneda por cada deuda activa, montos de ingresos/gastos del mes agrupados por nombre de categoría (una categoría como "Comida" no identifica a nadie) y moneda, y el saldo total por moneda. Este criterio de anonimización no cambió desde la Fase 24 — sigue siendo lo único que sale del dispositivo, ahora como contenido del primer mensaje de usuario del chat en vez de como body de una llamada de un solo turno.
- **`ChatConsejosRepository`** (`domain/repositories/chat_consejos_repository.dart`, puerto nuevo de la Fase 30): `obtenerHistorial()` y `enviarMensaje({mensaje, esPrimerMensaje, resumen})`. `EdgeFunctionConsejosRepository` (`infrastructure/consejos/`) es su único adapter — `obtenerHistorial()` lee `mensajes_consejos` directo contra Supabase (hay política de SELECT), `enviarMensaje()` invoca la Edge Function `generar-consejos` (`Supabase.instance.client.functions.invoke(...)`), autenticado con la sesión del usuario — la función identifica a quién le responde por el JWT de esa sesión, nunca por un id que mande el cliente.
- **La Edge Function `generar-consejos`** arma el contenido real del primer mensaje a partir del `resumen` recibido cuando `esPrimerMensaje == true` (el cliente nunca sabe el texto exacto hasta refrescar el historial), recupera el historial completo del usuario, arma el array `contents` multi-turno de Gemini (alternando `user`/`model`) con una `systemInstruction` fija (no visible en el chat) que define al asistente como un asesor financiero experto enfocado en pagar deudas rápido, ahorro e inversión simple, en español y con tono cercano, y guarda **tanto el mensaje del usuario como la respuesta del asistente juntos, en el mismo INSERT** — si Gemini falla, no se guarda nada, para no dejar nunca un mensaje de usuario huérfano sin respuesta en el historial.
- **Límite de 15 mensajes por usuario por día** (antes 5 consejos/mensajes — 5 desde la Fase 24, subido a 15 en la Fase 34 —, mismo mecanismo), controlado server-side (no en el cliente) contra la tabla `public.uso_consejos` (`user_id`, `fecha`, `conteo`) — solo la Edge Function, con la service role key, puede escribir ahí. Al alcanzarlo, la función responde 429 y el cliente lo traduce a `LimiteDiarioConsejosError`, que el chat muestra como una burbuja de sistema centrada ("Alcanzaste el límite de mensajes por hoy. Vuelve mañana.") en vez del bloque de error genérico de antes de la Fase 30.

### Captura automática — Etapa 3 en progreso (Fase 25)

La Etapa 3 (§1) tiene dos mitades: un **emisor** (algo fuera de la app que detecta un movimiento de dinero y manda el texto crudo) y un **receptor** (algo que recibe ese texto, lo clasifica y crea la `Transaccion`). La Fase 25 construyó el receptor completo; el emisor todavía no existe.

**Ya construido (este repo):**
- **Token por usuario:** columna `token_webhook` (`UUID`) en `public.usuarios`, generada con `gen_random_uuid()` al crear el usuario. Identifica de forma segura de quién es cada envío externo — nunca se autentica con el JWT de sesión normal, porque quien llama al webhook es un Atajo o un Worker externo, no la app logueada. Regenerable en cualquier momento desde "Mi perfil → Automatización" (invalida el token viejo de inmediato).
- **Edge Function `capturar-transaccion`** (`supabase/functions/capturar-transaccion/`): recibe `{ token, textoCrudo, fuente }` (el token también puede ir como query param `?token=...`, para que la URL sola sirva de credencial en herramientas que no arman un body a mano), busca el usuario dueño de ese token, le pide a Gemini que clasifique el texto (`tipo`, `monto`, `categoria_sugerida`, `concepto`) y crea la `Transaccion` directo por SQL (sin pasar por `RegistrarGasto`/`RegistrarIngreso`, que son código de la app, no del servidor) — incluyendo actualizar `saldo_actual` de la cuenta a mano, con rollback de la transacción si eso falla.
- **Simplificaciones temporales, documentadas para revisar más adelante:**
  - **Cuenta destino:** siempre la primera cuenta del usuario en soles (PEN) — el Atajo/correo todavía no puede indicar con qué medio se pagó. Si el usuario no tiene ninguna cuenta en PEN, la función responde con un error claro en vez de adivinar.
  - **Método de pago:** siempre `otro` — ni el Atajo ni el correo mandan esa información hoy, y Gemini tampoco la infiere (no se le pide).
- **`AutomatizacionScreen`** (`/automatizacion`, accesible desde "Mi perfil"): muestra la URL completa del webhook (endpoint + token) con botón "Copiar", advierte que no hay que compartirlo, y permite regenerar el token.
- **Dashboard en tiempo real:** `transaccionesEnVivoProvider` (`providers.dart`) escucha `transacciones` por Supabase Realtime; `DashboardScreen` lo usa para invalidar `resumenDashboardProvider` en cuanto detecta un cambio, así que una captura automática aparece sola, sin que el usuario tenga que salir y volver a entrar.

**Todavía no existe (fuera de este repo):**
- El **Atajo de iOS** que detecta una notificación de Apple Pay y llama al webhook — depende de que el usuario lo instale y configure a mano con su URL de "Automatización".
- El **Worker de correo** (pensado como Cloudflare Worker) que reciba los reenvíos de correos de Yape/Plin y los pase al mismo webhook con `fuente: 'correo_ios'`.
- El motor de captura de Android (`NotificationListenerService`, §1) — sin empezar, es una pieza separada del emisor de iOS.

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

### Sistema de diseño (Fase 19, claro/oscuro elegible desde la Fase 31)
- La app tiene un sistema de diseño propio en `presentation/theme/app_theme.dart`, en vez del `ColorScheme.fromSeed` genérico usado hasta la Fase 18.
- **Fase 31 — la app volvió a seguir un tema elegible.** La Fase 19 había fijado `MaterialApp.themeMode` en `ThemeMode.dark` permanente; ahora sigue la preferencia guardada por el usuario (`TemaApp.claro` | `TemaApp.oscuro` | `TemaApp.sistema`, `domain/entities/tema_app.dart`) desde "Mi perfil → Apariencia", con `TemaApp.oscuro` como valor por defecto para no cambiarle el look a nadie que actualice sin haber elegido nada. `app.dart` traduce `TemaApp` a `ThemeMode` de Flutter en la capa de UI — el dominio nunca importa Flutter.
- **Tokens de color** — dos grupos con tratamiento distinto:
  - `colorSuccess`/`colorDanger`/`colorWarning` (y, desde la Fase 31, `colorSobreEstado`): `Color` fijos de nivel superior en `app_theme.dart`, **iguales en ambos temas** — son colores de estado (éxito/peligro/aviso) y su contraste (`colorSobreEstado`, un tono oscuro fijo), no de fondo.
  - `bgPage`, `bgCard`, `borderCard`, `textPrimary`, `textSecondary`, `textMuted`: desde la Fase 31 **ya no son `Color` fijos** (antes lo eran, cuando solo existía el tema oscuro) — viven en la clase `AppColorTokens` (`ThemeExtension`, con una instancia `.oscuro` y una `.claro`), registrada en `ThemeData.extensions` por `appThemeOscuro()`/`appThemeClaro()`. Se leen vía la extensión de contexto `context.bgCard`, `context.textSecondary`, etc. (nunca como identificador suelto) — si el `Theme` activo no registra la extensión (p. ej. un `MaterialApp` de test que no pasa por `app.dart`), cae de vuelta a `AppColorTokens.oscuro` en vez de fallar.
  - Ambos grupos se mapean también a roles estándar de `ColorScheme` (`surface → bgCard`, `onSurface → textPrimary`, `primary → colorSuccess`, `onPrimary → colorSobreEstado`, `error → colorDanger`, etc.) para que el código que ya usaba `Theme.of(context).colorScheme` (convención desde la Fase 5) siga funcionando sin tocarlo. El fondo de página (`scaffoldBackgroundColor`) se fija aparte en `bgPage` porque `ColorScheme.background` está deprecado.
- **`AppCard`** (`presentation/shared/app_card.dart`): tarjeta de contenido estándar — fondo `bgCard`, borde `borderCard` de 0.5px, `borderRadius: 14`. Reemplaza el `Card(elevation: 0, color: colorScheme.surfaceContainerHigh, ...)` que se repetía en cada sección del dashboard y varias pantallas de detalle/formulario.
- **`SectionLabel`** (`presentation/shared/section_label.dart`): encabezado de sección con ícono pequeño + etiqueta en mayúsculas (`sectionLabelTextStyle`: 11px, `letterSpacing: 0.06`, `textMuted`). Usado en Saldo total, Ingresos/Gastos, Gasto por categoría, Deudas activas y Movimientos recientes del dashboard.
- **`AppBottomBar`** (`presentation/shared/app_bottom_bar.dart`): la barra inferior de 4 botones (Fase 17) ahora es un widget compartido, no solo del dashboard — también se muestra en Consejos financieros y Mi perfil, para poder resaltar en `colorSuccess` con negrita el botón de la pantalla donde el usuario ya está (Gasto/Deuda son acciones, nunca se resaltan).
- **`WalletAccountCard`** conserva la paleta de degradados por `TipoCuenta` de la Fase 8 (`wallet_card_colors.dart`, sin cambios) — la Fase 19 le agregó un borde sutil (versión más clara del color de inicio del degradado) y puso la etiqueta de tipo de cuenta en mayúsculas con letter-spacing. **Fase 31 — textura sutil:** un `CustomPainter` de líneas diagonales finas (opacidad ~6%) sobre todo el degradado, más el ícono del tipo de cuenta agrandado y muy tenue (opacidad ~8%) asomando en la esquina inferior derecha — ambos puramente decorativos (`ExcludeSemantics`), sin cambiar la paleta por tipo de cuenta ni afectar la legibilidad del texto encima.
- Cualquier color que no venga de estos tokens o de la paleta de `WalletCardEstilo` se considera fuera del sistema de diseño y debe corregirse (ver `dashboard_colors.dart`, que ahora devuelve `colorSuccess`/`colorDanger` en vez de shades de `Colors.green`/`Colors.red`).

### Tarjetas de crédito — línea, corte y alertas (Fase 29)
- **Sin campo de "monto utilizado" propio** — ver la nota en `Cuenta` (sección 2): se deriva de `saldoActual` (negativo = usado).
- **`proximaFecha(diaDelMes, desde)`** (`domain/proxima_fecha_dia_mes.dart`): función pura que calcula la próxima ocurrencia de un día del mes (1-31) a partir de una fecha — si ese día ya pasó este mes, cae en el mes siguiente. Mismo enfoque de aritmética de fechas (respeta fin de mes) que `_sumarMeses` de `domain/cronograma_cuotas.dart` (Fase 14), pero expuesta como función genérica y pública porque la usa un caso de uso distinto al de cuotas de deuda. No reemplaza a `calcularProximaFechaPago` de `domain/calculo_fechas.dart` (código muerto documentado en `INFORME_PROYECTO.md`, sin relación con tarjetas de crédito).
- **`ObtenerAlertasTarjetasCredito`** (`domain/usecases/`): recorre las cuentas tipo `credito`, calcula la próxima fecha de corte (`diaCorte`) y de pago (`diaPago`) de cada una con `proximaFecha`, y marca una alerta (`AlertaTarjetaCredito`, `domain/usecases/dto/`) cuando faltan **3 días o menos**. Se ejecuta automáticamente al cargar el dashboard vía `alertasTarjetasCreditoProvider` (`presentation/state/dashboard/dashboard_providers.dart`) — mismo disparador automático que `ActualizarEstadoMora` (basta con que `DashboardScreen` lo observe, sin acción del usuario), pero como `FutureProvider` propio en vez de un campo más de `ResumenDashboard`, porque a diferencia de `ActualizarEstadoMora` no escribe nada — es una lectura derivada de las cuentas.
- **UI:** `WalletAccountCard` (dashboard) muestra "Usado S/ X de S/ Y" + una barra de progreso (verde bajo ~80% de uso, roja desde ahí) en vez del saldo plano cuando `tipo == credito`. `DashboardScreen` muestra un banner por cada alerta activa (`AlertasTarjetasCreditoBanner`, mismo estilo que el banner de "deudas por vencer esta semana"). `CuentaFormulario` muestra los 3 campos nuevos con una transición animada cuando se elige tipo Crédito (mismo patrón `AnimatedSize` que los campos condicionales de `DeudaFormulario`); en modo edición se pueden seguir editando aunque la cuenta ya tenga movimientos, porque no afectan el saldo histórico (a diferencia de la moneda).

### Perfil enriquecido, nick único y tema elegible (Fase 31)
- **Nick único, obligatorio para cuentas nuevas.** Se elige en un paso nuevo del onboarding (**paso 2 de 6**, entre nombre y cuentas — `OnboardingNickStep`), con validación de disponibilidad en vivo (debounce de 450ms) contra la función de Postgres `nick_disponible` (`SECURITY DEFINER`, ver el SQL del reporte de la Fase 31 — necesaria porque RLS de `usuarios` solo deja leer la fila propia, y verificar si el nick de OTRO usuario existe requiere más privilegio que el del usuario que pregunta, sin exponerle el resto de esa fila). Se guarda recién en el paso de resumen, junto con el nombre. **De solo lectura después del onboarding** (decisión explícita, documentada en `MiPerfilScreen`): así un futuro sistema social siempre encuentra a alguien por el mismo nick que usó desde el principio, sin que lo haya cambiado después.
- **`avatar_id` e `instagram`**, ambos opcionales y editables en cualquier momento desde "Mi perfil". El avatar es prediseñado — un catálogo fijo de 12 combinaciones ícono+color sólido (`presentation/shared/avatares.dart`, `avataresDisponibles`), elegido con un grid seleccionable (mismo patrón que el selector de íconos de categorías, Fase 20); solo se persiste el `id` del catálogo, nunca una imagen.
- **`PerfilRepository`** (`domain/repositories/perfil_repository.dart`, adapter `PerfilRepositorySupabase`): puerto nuevo para estos 3 campos, todos en `public.usuarios` (Supabase) — deliberadamente NO en `PreferenciasRepository` local, mismo criterio que `AutomatizacionRepository` (Fase 25): tienen sentido en la nube, no en este dispositivo. No bifurca Drift/Supabase.
- **Tema de la app, vuelve a ser elegible** — ver "Sistema de diseño" más arriba. A diferencia de nick/avatar/Instagram, esto SÍ vive en `PreferenciasRepository` (100% local, `TemaApp.claro`/`.oscuro`/`.sistema`): no tiene ningún motivo para estar en la nube.

### Bundle ID y nombre de la app (Fase 27)
- **Bundle ID real**: `com.finzoapp.movil` en los 3 lugares que importan de cara a Apple/Google/Codemagic — `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`, Runner y RunnerTests), `android/app/build.gradle.kts` (`applicationId`) y `codemagic.yaml` (`BUNDLE_ID`). Antes era `com.finanzasautomaticas.finanzasAutomaticas` (iOS) / `com.finanzasautomaticas.finanzas_automaticas` (Android, ya venían distintos entre sí).
- **Nombre visible**: "Finzo" como nombre corto (`CFBundleDisplayName`/`CFBundleName` en iOS, `android:label` en Android, `MaterialApp.title`, título de `LoginScreen`), "Finzo: Finanzas Automaticas" como nombre completo donde hay espacio para él (bienvenida del onboarding).
- **A propósito NO se tocó**: el paquete Dart interno (`pubspec.yaml` `name:`, imports, la clase `FinanzasAutomaticasApp`) ni el namespace/paquete Kotlin de Android (`com.finanzasautomaticas.finanzas_automaticas`, todavía usado por `MainActivity.kt` y el `namespace` de Gradle) — son identificadores internos sin impacto de cara al usuario ni a Apple, y renombrarlos de verdad implica mover archivos/directorios sin ningún beneficio a cambio.

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

**Etapa 3 — Automatización (en progreso, Fase 25)**
- ~~Fase C (receptor): motor de IA (categorización y estructuración vía LLM) + endpoint que reciba texto crudo externo~~ — hecho en la Fase 25: Edge Function `capturar-transaccion` + token por usuario + dashboard en tiempo real. Ver "Captura automática — Etapa 3 en progreso" en la sección 3.
- Fase A: motor de captura Android (notificaciones) — sin empezar.
- Fase B (emisor iOS): Atajo de iOS disparado por Apple Pay + Worker de correo para Yape/Plin — sin empezar, son las dos piezas que le van a mandar texto al receptor ya construido.

---

## 5. Glosario de términos del dominio

- **Deuda informal:** deuda contraída con una persona natural (familiar, amigo) en vez de una entidad financiera; normalmente sin interés y sin cuota fija.
- **Estructura de pago — cuotas fijas:** la deuda tiene un número total de cuotas y un monto de cuota pactado (ej. préstamo personal, compra a plazos).
- **Estructura de pago — pago libre:** no hay cuotas fijas, solo un pago mínimo por período (ej. tarjeta de crédito).
- **En mora:** la deuda tiene un pago vencido sin cubrir; puede acumular interés moratorio adicional (`tasaInteresMoratorio`).
- **Fuente de captura:** origen del registro de una transacción — `manual` (Etapa 1), o automatizado (`notificacion_android`, `correo_ios`, `ocr_ios`, `webhook_atajo` desde la Fase 25) en la Etapa 3.
- **Token de webhook:** credencial opaca por usuario (`usuarios.token_webhook`) que identifica de quién es un envío externo a `capturar-transaccion` — no es una sesión, no expira, y se puede regenerar para invalidar cualquier automatización configurada con el valor anterior.
- **Transacción recurrente:** ingreso o gasto que se repite periódicamente (ej. alquiler, sueldo), marcado con `esRecurrente` para diferenciarlo de gastos puntuales.
- **Nick (Fase 31):** identificador único del usuario (`usuarios.nick`), elegido en el onboarding y de solo lectura después — pensado para un futuro sistema social, no tiene ningún uso funcional todavía dentro de la app.