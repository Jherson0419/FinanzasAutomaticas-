# Inventario de interfaces — Finzo

> Catálogo de solo lectura de cada pantalla de `lib/presentation/screens/` desde el punto de vista de qué ve y qué puede hacer el usuario (UI/UX). Es un documento distinto de `INFORME_PROYECTO.md` (arquitectura/código): aquí no se repite ese análisis salvo cuando hace falta para explicar una limitación de interfaz.
>
> Verificado leyendo cada uno de los 40 archivos `.dart` bajo `lib/presentation/screens/` (recursivo) con Read, más `lib/presentation/state/providers.dart`, `lib/presentation/state/dashboard/dashboard_providers.dart`, `lib/presentation/theme/app_theme.dart` y `lib/presentation/shared/*.dart`. Ningún archivo de código fue modificado. `INFORME_PROYECTO.md` §2 se usó como punto de partida pero varios detalles estaban desactualizados — el más importante: ese informe afirma que "no existe ningún flujo de eliminación de cuenta de usuario", pero el código actual (`lib/presentation/screens/mi_perfil_screen.dart`, `lib/domain/usecases/eliminar_cuenta_de_usuario.dart`, `eliminarCuentaDeUsuarioProvider` en `providers.dart:429-440`) ya tiene ese flujo completo, marcado como "Fase 22". Se documenta abajo tal como existe hoy.

---

## 1. RootScreen

**Archivo:** `lib/presentation/screens/root_screen.dart`
**Ruta de navegación:** `'/'`
**Propósito:** puerta de entrada de la app — decide, en orden estricto, si mostrar login, migración de datos, configuración/desbloqueo de PIN, onboarding, o el dashboard. No es una pantalla que el usuario "use", es un despachador reactivo.
**Cómo se llega aquí:** siempre, al abrir la app (ruta inicial `/`), y cada vez que algo hace `pushNamedAndRemoveUntil('/', false)` (fin del onboarding, fin de la migración).

**Elementos visibles:**
- Mientras resuelve `haySesionActivaProvider` → `necesitaMigracionProvider` → `bloqueoConfiguradoProvider`/`bloqueoOmitidoProvider` → `onboardingCompletadoProvider` (todos en `providers.dart`): un `Scaffold` en blanco con `CircularProgressIndicator` centrado, sin texto.
- Si cualquiera de esos providers lanza un error: `_ErrorScaffold` — texto centrado "No se pudo iniciar la app.\n$error" (el error se muestra crudo, sin traducir con `mensajeDeError`).
- No hay ningún botón ni campo propio: en cuanto resuelve, delega en `LoginScreen`, `MigrarDatosScreen`, `ConfigurarBloqueoScreen`, `DesbloqueoScreen`, `OnboardingFlowScreen` o `DashboardScreen`.

**Estados que maneja:** cargando SÍ (spinner mientras resuelve cada puerta, potencialmente varias veces en cascada). Vacío no aplica. Error SÍ (`_ErrorScaffold`, texto crudo). Éxito no aplica (es una transición, no un estado final).

**Sistema de diseño:** no usa `AppCard`/`SectionLabel` (no le hace falta, es solo spinner/texto). No tiene colores crudos fuera de los tokens del `Theme`.

**Limitaciones conocidas:** `_ErrorScaffold` no tiene ningún botón "Reintentar" — si un provider de puerta falla (por ejemplo sin conexión a internet, ya que desde la Fase 21 leer Drift/Supabase puede fallar), la única salida es cerrar y reabrir la app por completo. El mensaje de error se muestra crudo (`$error`, con el prefijo técnico de Dart) en vez de pasar por `mensajeDeError`, inconsistente con el resto de la app.

---

## 2. LoginScreen

**Archivo:** `lib/presentation/screens/login_screen.dart`
**Ruta de navegación:** sin ruta con nombre (`RootScreen` la retorna directamente cuando no hay sesión)
**Propósito:** autenticar con correo y contraseña contra Supabase Auth para poder entrar a la app.
**Cómo se llega aquí:** automáticamente al abrir la app sin sesión activa (puerta 1 de `RootScreen`); también al cerrar sesión desde `MiPerfilScreen` o desde `DesbloqueoScreen` ("Usar mi correo y contraseña").

**Elementos visibles:**
- Ícono decorativo + título "Finzo" (nombre corto — Fase 27, antes decía "Finanzas Automáticas").
- `TextFormField` Correo — texto, obligatorio, validado con regex de email en vivo (sin `errorText` visible, solo condiciona el botón).
- `TextFormField` Contraseña — texto oculto, obligatorio (mínimo 6 caracteres), botón de mostrar/ocultar.
- Botón "Iniciar sesión" (`FilledButton`) — deshabilitado hasta que el correo sea válido y la contraseña tenga ≥6 caracteres; invoca `AuthRepository.iniciarSesion`.
- Botón de texto "Crear cuenta" → `Navigator.push` a `CrearCuentaScreen`.

**Estados que maneja:** cargando SÍ (spinner dentro del botón mientras `_iniciandoSesion`). Vacío no aplica. Error SÍ (`SnackBar` con `mensajeDeError`, mensajes traducidos — verificado por `login_screen_test.dart`). Éxito: NO hay confirmación visual propia — solo `ref.invalidate(haySesionActivaProvider)`, y es `RootScreen` quien reactivamente navega a la siguiente puerta; no hay ningún mensaje "Sesión iniciada".

**Sistema de diseño:** consistente — usa `Theme.of(context).colorScheme` correctamente, sin `Colors.*` crudos. No usa `AppCard` (no le hace falta, es un formulario centrado simple).

**Limitaciones conocidas:** no hay "Olvidé mi contraseña" ni ningún flujo de recuperación de cuenta por correo. No hay inicio de sesión social (Google/Apple) — puede ser un requisito adicional de Apple para apps con login. El error de validación del correo nunca se muestra como texto (`errorText`); el usuario solo ve que el botón está deshabilitado, sin saber por qué. No hay biometría en el login inicial (eso solo existe después, como bloqueo local, no como método de inicio de sesión).

---

## 3. CrearCuentaScreen

**Archivo:** `lib/presentation/screens/crear_cuenta_screen.dart`
**Ruta de navegación:** sin ruta con nombre (empujada directamente desde `LoginScreen` con `Navigator.push`)
**Propósito:** registrar una cuenta de usuario nueva en Supabase Auth.
**Cómo se llega aquí:** botón "Crear cuenta" en `LoginScreen`.

**Elementos visibles:**
- `AppBar` "Crear cuenta" con botón atrás nativo.
- `TextFormField` Correo — obligatorio, validado con regex de email.
- `TextFormField` Contraseña — obligatorio (mínimo 6, `helperText` "Mínimo 6 caracteres"), toggle de visibilidad.
- `TextFormField` Confirmar contraseña — obligatorio, `errorText` inline "Las contraseñas no coinciden" si no calzan (comparte el toggle de visibilidad del campo anterior).
- Botón "Crear cuenta" (`FilledButton`) — deshabilitado hasta que los tres campos sean válidos; invoca `AuthRepository.crearCuenta`.
- Botón de texto "Ya tengo cuenta" → `Navigator.pop`.

**Estados que maneja:** cargando SÍ (spinner en el botón). Vacío no aplica. Error SÍ (`SnackBar` con `mensajeDeError`, p. ej. correo ya registrado — verificado por `crear_cuenta_screen_test.dart`). Éxito: `pop()` automático a `LoginScreen` tras crear la cuenta; no hay `SnackBar` de confirmación — el `pop` es la única señal.

**Sistema de diseño:** consistente, sin colores crudos, sin `AppCard` (no aplica).

**Limitaciones conocidas:** no hay medidor de fortaleza de contraseña. No hay checkbox de aceptación de términos/política de privacidad. Tras crear la cuenta, el usuario vuelve a `LoginScreen` y debe volver a escribir sus credenciales manualmente (sin auto-login). No hay indicación en la UI de si Supabase exige verificación de correo.

---

## 4. ConfigurarBloqueoScreen

**Archivo:** `lib/presentation/screens/configurar_bloqueo_screen.dart`
**Ruta de navegación:** sin ruta con nombre
**Propósito:** ofrecer, una sola vez tras el primer login, configurar un PIN de 4 dígitos y/o biometría como bloqueo local rápido (más ágil que reautenticar con Supabase cada vez).
**Cómo se llega aquí:** puerta 3 de `RootScreen` — sesión activa, sin migración pendiente, y sin bloqueo configurado ni "omitido" previamente.

**Elementos visibles:**
- Texto explicativo.
- `TextFormField` "Nuevo PIN" — numérico, oculto, `maxLength` 4.
- `TextFormField` "Confirmar PIN" — numérico, oculto, `maxLength` 4.
- `OutlinedButton` "Guardar PIN" (cambia a "PIN guardado ✓" tras éxito) — deshabilitado hasta 4 dígitos numéricos que coincidan entre ambos campos; guarda `hashPin(...)` vía `PreferenciasRepository`.
- `SwitchListTile` "Usar Face ID / huella" — solo visible si `LocalAuthentication().canCheckBiometrics` devuelve `true`.
- Botón "Continuar" (`FilledButton`) — habilitado solo si hay PIN guardado o biometría activa.
- Botón de texto "Omitir por ahora".

**Estados que maneja:** cargando parcial — no hay spinner de pantalla completa, pero sí feedback puntual (`_guardandoPin`, `_procesandoOmitir`). Vacío no aplica. Error SÍ (`SnackBar` si falla guardar el PIN o la preferencia biométrica). Éxito SÍ — `SnackBar` "PIN guardado" + el texto del botón cambia a "PIN guardado ✓"; es la única pantalla del flujo de autenticación con confirmación textual explícita de éxito.

**Sistema de diseño:** consistente, sin colores crudos, sin `AppCard` (formulario plano, no aplica).

**Limitaciones conocidas:** activar/desactivar el switch de biometría no tiene confirmación — se aplica al instante y solo se revierte silenciosamente si falla (con `SnackBar`, pero el switch ya cambió visualmente antes). "Omitir por ahora" no advierte que la app quedará sin ninguna capa extra de seguridad. Si la biometría no está disponible en el dispositivo, la única alternativa es PIN u "omitir" — no hay patrón de dibujo ni otra alternativa. No hay botón para cancelar/volver sin decidir nada.

---

## 5. DesbloqueoScreen

**Archivo:** `lib/presentation/screens/desbloqueo_screen.dart`
**Ruta de navegación:** sin ruta con nombre
**Propósito:** reautenticación rápida (PIN y/o biométrico) al abrir la app en frío, cuando ya hay bloqueo configurado — evita tener que volver a iniciar sesión con Supabase cada vez.
**Cómo se llega aquí:** puerta 4 de `RootScreen` — bloqueo configurado y `desbloqueadoEnEstaSesionProvider == false` (solo en cold start, nunca al volver de segundo plano).

**Elementos visibles:**
- Ícono de candado + título "Ingresa tu PIN".
- `TextFormField` PIN — numérico, oculto, `maxLength` 4, centrado, autoenvío al completar 4 dígitos (`onFieldSubmitted`).
- Botón "Desbloquear" (`FilledButton`) — deshabilitado hasta 4 dígitos.
- Botón de texto "Usar mi correo y contraseña" → cierra la sesión de Supabase y vuelve a `LoginScreen`.
- Intento automático de biometría al montar la pantalla (sin UI propia — delega el prompt nativo al sistema operativo).

**Estados que maneja:** cargando SÍ (spinner en el botón mientras se compara el hash). Vacío no aplica. Error SÍ ("PIN incorrecto" como `errorText` bajo el campo, que además se limpia solo). Éxito: NO hay confirmación visual — solo cambia `desbloqueadoEnEstaSesionProvider` a `true` y `RootScreen` navega reactivamente.

**Sistema de diseño:** consistente, sin `AppCard` (no aplica), sin colores crudos.

**Limitaciones conocidas:** no hay límite de intentos fallidos de PIN — sin bloqueo temporal tras varios intentos incorrectos seguidos (riesgo de fuerza bruta local, aunque acotado porque solo protege acceso local, no la cuenta de Supabase en sí). Si el biométrico falla o se cancela, no se muestra ningún mensaje (el `catch` está vacío) — el usuario no sabe si falló su huella/rostro o simplemente debe usar el PIN. No hay "olvidé mi PIN" salvo cerrar sesión por completo (no hay recuperación intermedia sin perder la sesión).

---

## 6. MigrarDatosScreen

**Archivo:** `lib/presentation/screens/migrar_datos_screen.dart`
**Ruta de navegación:** sin ruta con nombre
**Propósito:** subir los datos financieros locales (Drift) a Supabase la primera vez que se detectan datos sin migrar — a partir de ahí la app deja de ser offline-first.
**Cómo se llega aquí:** puerta 2 de `RootScreen` — sesión activa y hay datos financieros en Drift sin migrar.

**Elementos visibles:**
- `AppCard` explicativo (íconos, texto en `colorWarning` avisando que los datos locales se borrarán tras confirmar).
- Botón "Subir mis datos" (`FilledButton`) → abre `confirmarAccion` (debe tocar "Subir y continuar" para proceder) antes de ejecutar nada.
- Mientras migra: `CircularProgressIndicator` + texto de la etapa actual (`_etapaActual`, alimentado por el callback `onProgreso` de `MigrarDatosALaNube`).
- Si falla: `AppCard` de error con el mensaje (`mensajeDeError`) + texto "Tus datos locales siguen intactos" + botón "Reintentar".

**Estados que maneja:** cargando SÍ — es la única pantalla de todo el flujo de autenticación/migración con progreso etapa por etapa visible. Vacío no aplica. Error SÍ (`AppCard` roja + "Reintentar", que repite el flujo de confirmación). Éxito: NO hay pantalla de confirmación — al terminar navega automáticamente con `pushNamedAndRemoveUntil('/', false)` sin mostrar ningún mensaje de "listo" antes de irse.

**Sistema de diseño:** usa `AppCard` y los tokens (`colorSuccess`, `colorWarning`, `colorDanger`, `textSecondary`) de forma consistente — es el ejemplo más limpio de aplicación del sistema de diseño de todo el flujo inicial.

**Limitaciones conocidas:** no se puede cancelar la migración una vez iniciada (sin botón "Cancelar" mientras `_migrando == true`). El progreso es solo textual por etapa, sin barra numérica/porcentual. Si el usuario cierra la app a mitad de la subida, no hay ninguna indicación en la UI de en qué quedó (el caso de uso es idempotente por diseño, pero eso no se comunica). No hay salida "Más tarde" — es una puerta obligatoria sin forma de posponerla.

---

## 7. OnboardingFlowScreen (contenedor del wizard)

**Archivo:** `lib/presentation/screens/onboarding/onboarding_flow_screen.dart`
**Ruta de navegación:** sin ruta con nombre (mostrada directamente por `RootScreen` cuando el onboarding no está completo)
**Propósito:** contenedor con estado local (`_paso`, 0-5) de los 6 pasos del onboarding (Fase 31 agregó el paso de nick, entre nombre y cuentas); mantiene vivos los controllers de nombre y nick entre pasos.
**Cómo se llega aquí:** puerta 5 de `RootScreen`.

**Elementos visibles:**
- Barra de progreso superior — 6 segmentos (`AnimatedContainer`), el actual y los anteriores resaltados en `colorScheme.primary`, el resto en `colorScheme.surfaceContainerHighest`.
- El paso actual, embebido en un `Expanded` (ver entradas 8-13 para el contenido de cada paso).

**Estados que maneja:** no tiene estados propios de carga/vacío/error/éxito — delega por completo en el paso montado.

**Sistema de diseño:** usa roles de `colorScheme` (mapeados desde los tokens de `app_theme.dart`), consistente.

**Limitaciones conocidas:** los segmentos de la barra de progreso no son tocables — no se puede saltar directamente a un paso ya completado. Si la app se cierra a mitad del onboarding, el wizard siempre reinicia desde el paso 0 (lo que ya se guardó en el backend — cuentas/deudas creadas, o el nick, si llegó a guardarse — persiste, pero el paso actual y el nombre/nick tecleados se pierden si no se llegó al resumen).

---

## 8. OnboardingWelcomeStep (paso 0 de 6)

**Archivo:** `lib/presentation/screens/onboarding/onboarding_welcome_step.dart`
**Ruta de navegación:** sin ruta propia — paso 0 embebido en `OnboardingFlowScreen`
**Propósito:** pantalla de bienvenida, presenta brevemente la app.
**Cómo se llega aquí:** primer paso del wizard, mostrado automáticamente al terminar las puertas de autenticación/bloqueo si el onboarding no está completo.

**Elementos visibles:**
- Ícono decorativo, título "Bienvenido a Finzo: Finanzas Automáticas" (nombre completo — Fase 27, antes decía solo "Finanzas Automáticas"), texto descriptivo.
- Botón "Comenzar" (`FilledButton`) → avanza al paso 1. Sin botón "Atrás" (es el primer paso).

**Estados que maneja:** ninguno de los 4 aplica — es estático, sin datos remotos.

**Sistema de diseño:** consistente (usa `Theme.of(context)` correctamente), sin `AppCard` (no hace falta).

**Limitaciones conocidas:** no hay forma de omitir el onboarding completo desde aquí. No indica cuántos pasos totales hay más allá de la barra de progreso genérica del contenedor (sin texto tipo "Paso 1 de 5").

---

## 9. OnboardingNombreStep (paso 1 de 6)

**Archivo:** `lib/presentation/screens/onboarding/onboarding_nombre_step.dart`
**Ruta de navegación:** sin ruta propia — paso 1 embebido en `OnboardingFlowScreen`
**Propósito:** capturar el nombre del usuario para personalizar el saludo del dashboard.
**Cómo se llega aquí:** botón "Comenzar" del paso 0.

**Elementos visibles:**
- `TextFormField` "Nombre" — texto, obligatorio ("Continuar" deshabilitado si está vacío tras `trim()`).
- Botón "Atrás" (`OutlinedButton`) / Botón "Continuar" (`FilledButton`).

**Estados que maneja:** ninguno de los 4 aplica (sin datos remotos).

**Sistema de diseño:** consistente.

**Limitaciones conocidas:** no valida longitud mínima ni caracteres especiales/emoji. El nombre no se persiste hasta el paso 6 (resumen) — vive solo en un `TextEditingController` en memoria del contenedor; si la app se cierra entre este paso y el resumen, se pierde por completo y hay que volver a escribirlo.

---

## 10. OnboardingNickStep (paso 2 de 6, Fase 31)

**Archivo:** `lib/presentation/screens/onboarding/onboarding_nick_step.dart`
**Ruta de navegación:** sin ruta propia — paso 2 embebido en `OnboardingFlowScreen`
**Propósito:** capturar un nick único (identificador social del usuario, pensado para un futuro sistema social) y validar en vivo que nadie más lo tenga.
**Cómo se llega aquí:** botón "Continuar" del paso 1 (nombre).

**Elementos visibles:**
- `TextFormField` "Nick" — texto, obligatorio, prefijo `@`, formato validado en vivo (3-20 caracteres, solo letras/números/guion bajo). `helperText` dinámico bajo el campo: "Usa entre 3 y 20 letras..." (formato inválido, `colorWarning`), "Verificando disponibilidad..." (mientras espera, `textSecondary`, con un spinner chico como `suffixIcon`), "Disponible" (`colorSuccess`, con ícono de check) o "Ya está en uso" (`colorDanger`).
- La verificación contra `PerfilRepository.nickDisponible` tiene debounce de 450ms — no se dispara en cada tecla, solo cuando el usuario deja de escribir.
- Botón "Atrás" (`OutlinedButton`) / Botón "Continuar" (`FilledButton`) — deshabilitado hasta que la última verificación resuelta corresponda exactamente al texto actual del campo y diga "disponible".

**Estados que maneja:** cargando SÍ (mientras verifica, ver arriba). Vacío no aplica. Error SÍ ("No se pudo verificar. Revisa tu conexión." si `nickDisponible` lanza). Éxito: el propio `helperText` "Disponible" en verde es la confirmación — no hay `SnackBar` aparte.

**Sistema de diseño:** consistente — usa los tokens de `app_theme.dart` (`colorSuccess`/`colorDanger`/`colorWarning`/`textSecondary`) para los 4 estados del `helperText`.

**Limitaciones conocidas:** el nick, igual que el nombre, no se guarda hasta el paso 6 (resumen) — se pierde si la app se cierra antes de llegar ahí. No hay sugerencias automáticas si el nick elegido ya está tomado (el usuario tiene que pensar uno distinto por su cuenta). El nick no se puede volver a cambiar después de este paso (ver `MiPerfilScreen`, decisión documentada ahí).

---

## 11. OnboardingCuentasStep (paso 3 de 6)

**Archivo:** `lib/presentation/screens/onboarding/onboarding_cuentas_step.dart`
**Ruta de navegación:** sin ruta propia — paso 3 embebido en `OnboardingFlowScreen`
**Propósito:** obligar a registrar al menos una cuenta antes de continuar (la app no tiene sentido sin al menos una).
**Cómo se llega aquí:** botón "Continuar" del paso 2 (nick).

**Elementos visibles:**
- Lista de cuentas ya creadas — `WalletAccountCard` en modo `compacto`, alimentada por `cuentasProvider` (`CuentaRepository.obtenerTodas`, bifurcado Drift/Supabase).
- Formulario de creación de cuenta embebido (`CuentaFormulario`, sin `cuentaId` → siempre modo creación; ver sección Verificación — no cuenta como pantalla aparte, se documentan sus campos aquí): `TextFormField` Nombre (obligatorio), `DropdownButtonFormField` Tipo de cuenta, `DropdownButtonFormField` Moneda, `TextFormField` Saldo inicial (numérico, obligatorio, con prefijo del símbolo de moneda), botón "Guardar".
- Botón "Atrás" / Botón "Continuar" — deshabilitado hasta que `cuentasProvider` tenga al menos un elemento.

**Estados que maneja:** cargando SÍ (spinner mientras carga `cuentasProvider`). Vacío parcial — si no hay cuentas, simplemente no se muestra nada en la lista (`SizedBox.shrink()`), sin ningún texto tipo "aún no tienes cuentas". Error SÍ (texto genérico "No se pudieron cargar las cuentas."). Éxito: no hay confirmación textual — el formulario se limpia solo y la cuenta nueva aparece en la lista de arriba.

**Sistema de diseño:** consistente (no usa `AppCard`, es una lista simple — correcto, no hace falta).

**Limitaciones conocidas:** no se puede editar ni eliminar una cuenta recién creada desde este mismo paso — hay que esperar a llegar a "Mis cuentas" después de terminar el onboarding. Sin mensaje explícito de "cuenta guardada" (solo se infiere porque aparece en la lista).

---

## 12. OnboardingDeudasStep (paso 4 de 6)

**Archivo:** `lib/presentation/screens/onboarding/onboarding_deudas_step.dart`
**Ruta de navegación:** sin ruta propia — paso 4 embebido en `OnboardingFlowScreen`
**Propósito:** paso opcional para registrar deudas ya existentes durante el onboarding.
**Cómo se llega aquí:** botón "Continuar" del paso 3 (cuentas).

**Elementos visibles:**
- Lista de deudas ya agregadas — `DeudaListaItem` (ver Verificación), alimentada por `deudasProvider`.
- Formulario de creación de deuda embebido (`DeudaFormulario`, siempre modo creación; ver Verificación — mismos campos que se documentan en la entrada 20, `DeudaNuevaScreen`).
- Botón "Atrás" / Botón "Continuar" (siempre habilitado) / botón de texto "Omitir por ahora".

**Estados que maneja:** cargando SÍ (`deudasProvider`). Vacío parcial (igual patrón que el paso de cuentas: sin lista, sin texto). Error SÍ (texto genérico). Éxito: sin confirmación textual.

**Sistema de diseño:** consistente.

**Limitaciones conocidas:** "Omitir por ahora" y "Continuar" son funcionalmente idénticos — ambos llaman a `onContinuar()` sin ninguna diferencia de comportamiento; tener dos botones que hacen exactamente lo mismo es confuso para el usuario (¿por qué existen los dos?).

---

## 13. OnboardingResumenStep (paso 5 de 6)

**Archivo:** `lib/presentation/screens/onboarding/onboarding_resumen_step.dart`
**Ruta de navegación:** sin ruta propia — paso 5 embebido en `OnboardingFlowScreen`
**Propósito:** revisar lo configurado (nombre, nick, cuentas, deudas) antes de terminar el onboarding y entrar al dashboard.
**Cómo se llega aquí:** botón "Continuar" del paso 4 (deudas) u "Omitir por ahora".

**Elementos visibles:**
- Texto "Nombre" de solo lectura (viene del controller del paso 1, todavía no guardado).
- Texto "Nick" de solo lectura, con `@` (Fase 31, viene del controller del paso 2, todavía no guardado).
- Lista de cuentas (`WalletAccountCard` compacto, vía `cuentasProvider`).
- Lista de deudas (`DeudaListaItem`, vía `deudasProvider`) o texto "Sin deudas registradas." si está vacía.
- Botón "Empezar a usar la app" (`FilledButton`) → `PreferenciasRepository.guardarNombre()` + `PerfilRepository.guardarNick()` (Fase 31) + `marcarOnboardingCompletado()`, invalida varios providers, navega a `/`.

**Estados que maneja:** cargando SÍ (spinner por cada lista). Vacío SÍ para deudas ("Sin deudas registradas."); las cuentas no muestran mensaje vacío explícito (aunque siempre habrá ≥1 por la validación del paso 2). Error SÍ (mensajes genéricos por lista). Éxito: no hay pantalla de confirmación — transición directa al dashboard.

**Sistema de diseño:** consistente.

**Limitaciones conocidas:** no se puede volver a un paso anterior para corregir algo puntual sin usar el botón "Atrás" genérico (no hay accesos "Editar" junto a cada bloque del resumen). Si "Empezar a usar la app" falla, el error se muestra con `Text('No se pudo completar: $error')` (`onboarding_resumen_step.dart:41`) — **sin pasar por `mensajeDeError`**, a diferencia de prácticamente todos los demás formularios de la app; el usuario ve el error crudo de Dart en vez de un mensaje traducido, y además queda atascado en este paso sin ninguna alternativa clara más allá de reintentar.

---

## 14. DashboardScreen

**Archivo:** `lib/presentation/screens/dashboard/dashboard_screen.dart`
**Ruta de navegación:** `'/'` (cuando el onboarding ya está completo)
**Propósito:** vista general de la situación financiera — punto central de la app tras el onboarding.
**Cómo se llega aquí:** puerta 5 de `RootScreen` tras onboarding completo; destino de retorno (`pop`) tras completar prácticamente cualquier acción (crear cuenta, guardar transacción, registrar pago, etc.).

**Elementos visibles:**
- `AppBar`: saludo dinámico "Hola, {nombre}" (`nombreUsuarioProvider`, con fallback a "Hola" si no hay nombre) + ícono billetera → `/cuentas` + ícono escudo decorativo `gpp_good_outlined` sin acción + ícono campana `notifications_none` sin acción (`onPressed: () {}`, `dashboard_screen.dart:49-52`).
- `CuentasCarrusel` (embebido, ver Verificación) — **tercer rediseño de este componente (Fase 33): fila con peek en la Fase 8 → carrusel horizontal `PageView` con página "agregar" en la Fase 17/18 → esta pila vertical con gesto de deslizar hacia arriba.**
  - **Estructura:** `Stack` vertical — la cuenta activa va al frente, a tamaño completo; hasta 2 cuentas siguientes asoman detrás, desplazadas 16px y 32px hacia arriba con opacidad 0.75 y 0.5 respectivamente (nunca más de 3 tarjetas visibles a la vez, sin importar cuántas cuentas tenga el usuario). Con 1 sola cuenta no hay ninguna tarjeta fantasma; con 2, solo la primera. El orden de la pila es independiente del que devuelva el repositorio — se conserva entre refrescos del provider (p. ej. tras editar el saldo de una cuenta desde otra pantalla) en vez de resetear cuál tarjeta está al frente.
  - **Gesto de deslizar hacia arriba:** un `GestureDetector` sobre toda la pila detecta un swipe vertical hacia arriba (por velocidad mínima o por distancia acumulada, lo que ocurra primero) y rota la pila — la cuenta al frente pasa al final del orden, la siguiente cuenta avanza al frente. Deslizar hacia abajo, o insuficientemente hacia arriba, no hace nada. La rotación se anima (~280ms, `AnimationController` + `Curves.easeOutCubic`): la tarjeta saliente sube y se desvanece mientras el resto de la pila avanza un puesto, sin sentirse abrupto.
  - **Botón "Añadir cuenta" con recorte cóncavo (solo en la tarjeta frontal, nunca en las de atrás):** un `CustomClipper<Path>` resta un círculo (mismo radio que el botón, 20px) de la esquina inferior derecha del rectángulo redondeado de la tarjeta (`Path.combine(PathOperation.difference, ...)`), y el botón — una pill con ícono `+` y texto, fondo `bgPage` (Fase 31: el mismo token de fondo de la app en el tema activo, para que "se hunda" visualmente en el recorte) — se centra sobre ese mismo círculo, sangrando levemente fuera del borde de la tarjeta. Toca `/cuentas/nueva` sin id (modo creación). Se ve correcto en ambos temas porque `bgPage`/`borderCard` se leen del token activo, no de un valor fijo.
  - Debajo de la pila, un texto pequeño y sutil ("Desliza hacia arriba para ver la siguiente cuenta") — solo visible si hay más de 1 cuenta.
  - Sin ninguna cuenta (borde prácticamente inalcanzable, ver §7 de `INFORME_PROYECTO.md`): sin tarjeta frontal no hay dónde encajar el recorte, así que se muestra un prompt simple ("+ Añadir cuenta" con borde punteado) en su lugar — mismo destino `/cuentas/nueva`.
- `AlertasTarjetasCreditoBanner` (Fase 29, embebido) — un banner por cada alerta de corte/pago próximo (3 días o menos) de una cuenta tipo crédito, mismo estilo que el banner de "deudas por vencer esta semana" de `DeudasActivasSection`. Vacío (sin renderizar nada) si no hay ninguna alerta activa.
- `SaldoTotalCard` (embebido).
- `IngresosGastosSection` (embebido, dos `AppCard` lado a lado).
- `GastoPorCategoriaSection` (embebido).
- `DeudasActivasSection` (embebido, acordeón expandible por defecto).
- `MovimientosRecientesSection` (embebido, acordeón expandible, "Ver todos" → `/transacciones/todas`).
- `AppBottomBar` fijo (Fase 32 — pasó de 4 a 5 botones, con estilo "glass" estilo iOS): "Gasto" → `/transacciones/nueva`, "Deuda" → `/deudas/nueva`, "Inicio" (nuevo, círculo central) → sin acción aquí (`Navigator.popUntil` a la primera ruta, no-op porque ya se está en el dashboard), "Consejos" → `/consejos`, "Perfil" → `/perfil`. Ver el párrafo dedicado abajo para el rediseño completo — Consejos/Perfil (entradas 26/27) solo enlazan aquí en vez de repetir la descripción.
  - **Rediseño "glass" de la Fase 32:** el fondo sólido de la barra se reemplazó por un efecto de vidrio esmerilado — `BackdropFilter` (`ImageFilter.blur`, sigma 18) acotado con `ClipRect` al área fija de la barra (nunca a la pantalla completa) más un tinte semitransparente (`bgCard` al 75% de opacidad) y un borde superior sutil (`borderCard` al 60%), ambos leídos del token de tema activo — se ve correcto en claro y oscuro sin cambiar el blur, solo el tinte. Envuelto en `RepaintBoundary` para que el scroll del contenido del dashboard (un widget completamente distinto, fuera de este árbol) no fuerce un repintado del filtro.
  - **Botón "Inicio" (nuevo, quinto botón, centro exacto entre Deuda y Consejos):** ícono `home_rounded` dentro de un círculo de 60px sólido en `colorSuccess` — nunca gris, ni siquiera inactivo, a propósito distinto de los otros 4 (que sí quedan en `textSecondary` cuando no están resaltados) — con sombra y posicionado 24px por encima del borde superior de la barra (`Stack`/`Positioned`, no alineado en la misma fila que los demás íconos), como una muesca/FAB integrado. Cuando el dashboard es la pantalla actual se suma un anillo y una sombra más marcada (mismo lenguaje de "resaltado" que el `colorSuccess` + negrita de los otros 4). Navega con `Navigator.popUntil((route) => route.isFirst)` en vez de `pushNamed`/`pushNamedAndRemoveUntil`: como Dashboard/Consejos/Perfil son las únicas pantallas con esta barra y siempre están apiladas sobre la primera ruta (`/`), esto vuelve a la instancia ya existente del dashboard sin crear una nueva ni importar cuántos niveles de profundidad haya (p. ej. Consejos abierto desde Perfil).
- Todos los datos de solo lectura vienen de `resumenDashboardProvider` (`dashboard_providers.dart`, que corre `ActualizarEstadoMora` y luego `ObtenerResumenDashboard`, tocando `CuentaRepository`, `TransaccionRepository`, `CategoriaRepository`, `DeudaRepository`, todos bifurcados Drift/Supabase según `datosEnLaNubeProvider`).

**Estados que maneja:** cargando SÍ (spinner de pantalla completa). Vacío SÍ (`DashboardEmptyState`, aunque — confirmado también por `INFORME_PROYECTO.md` §7 — es prácticamente inalcanzable hoy porque el onboarding obligatorio siempre deja al menos una cuenta creada). Error SÍ (texto centrado con el error crudo). Éxito no aplica como estado aparte (siempre visible mientras haya datos).

**Sistema de diseño:** consistente — usa `AppCard`/`SectionLabel` en cada sección salvo `CuentasCarrusel` (que usa `WalletAccountCard` con su propio degradado por tipo de cuenta, documentado y correcto por diseño desde la Fase 8/19).

**Limitaciones conocidas:** la campana de notificaciones no hace nada y no tiene ni siquiera un `tooltip` que aclare "Próximamente" — el usuario puede tocarla esperando algo y no pasa absolutamente nada, sin ninguna pista. El ícono de escudo tampoco tiene acción ni tooltip. No hay selector de mes/periodo (siempre el mes calendario actual — confirmado, vigente desde el informe anterior). No hay gesto de "pull to refresh" manual — el dashboard solo se refresca cuando algo invalida sus providers desde otra pantalla. Las secciones acordeón ("Deudas activas"/"Movimientos recientes") pierden su estado expandido/colapsado si se navega fuera del dashboard y se vuelve (se resetean a expandido).

---

## 15. MisCuentasScreen

**Archivo:** `lib/presentation/screens/mis_cuentas_screen.dart`
**Ruta de navegación:** `'/cuentas'`
**Propósito:** listar todas las cuentas del usuario y dar acceso a agregar una nueva.
**Cómo se llega aquí:** ícono de billetera en el `AppBar` del dashboard.

**Elementos visibles:**
- Lista de `WalletAccountCard` (tamaño normal, centradas) — tap → `/cuentas/nueva` con `cuentaId` (modo edición).
- Botón "Agregar cuenta" (`FilledButton.icon`) → `/cuentas/nueva` sin id.
- Texto "Aún no tienes cuentas registradas." si la lista está vacía.
- Datos: `cuentasProvider` (`CuentaRepository.obtenerTodas`, bifurcado).

**Estados que maneja:** cargando SÍ. Vacío SÍ (texto centrado). Error SÍ (texto genérico con el error crudo interpolado). Éxito no aplica.

**Sistema de diseño:** consistente (no usa `AppCard`, correcto — reutiliza las mismas `WalletAccountCard` del resto de la app).

**Limitaciones conocidas:** sin buscador ni filtro por moneda/tipo de cuenta. Sin reordenar cuentas manualmente (el orden es el que devuelve el repositorio). Sin saldo total resumido en esta vista (hay que volver al dashboard para verlo). Confirmado además por `INFORME_PROYECTO.md` §6: es la única pantalla del flujo principal con **cero tests**.

---

## 16. CuentaNuevaScreen

**Archivo:** `lib/presentation/screens/cuenta_nueva_screen.dart` (con `lib/presentation/screens/cuenta_formulario.dart` embebido)
**Ruta de navegación:** `'/cuentas/nueva'` (arg. `cuentaId` opcional — `null` = crear, con valor = editar)
**Propósito:** crear una cuenta nueva, o editar/ajustar el saldo/ver movimientos/eliminar una existente.
**Cómo se llega aquí:** `MisCuentasScreen` (tap en una cuenta o "Agregar cuenta"), botón "Añadir cuenta" integrado en el recorte cóncavo de la tarjeta frontal del `CuentasCarrusel` del dashboard (Fase 33 — antes una página "+" aparte del carrusel horizontal).

**Elementos visibles (delegados a `CuentaFormulario`, documentados aquí porque es lo único que el usuario ve en esta ruta — ver Verificación):**
- *Modo creación:* `TextFormField` Nombre (obligatorio), `DropdownButtonFormField` Tipo de cuenta, campos de crédito (ver abajo, solo si el tipo es Crédito), `DropdownButtonFormField` Moneda, `TextFormField` Saldo inicial (numérico, obligatorio, prefijo de símbolo de moneda), botón "Guardar".
- *Modo edición:* `WalletAccountCard` de la cuenta; `TextFormField` Nombre; `DropdownButtonFormField` Tipo; campos de crédito (ver abajo); `DropdownButtonFormField` Moneda (bloqueado, con `helperText`, si la cuenta ya tiene transacciones o pagos de deuda asociados — `transaccionesPorCuentaProvider`/`pagosPorCuentaProvider`); bloque de solo lectura "Saldo actual" + botón "Ajustar" (abre un modal `_ModalAjusteSaldo` con un único campo "Saldo real" → invoca `AjustarSaldoCuenta`, que registra la diferencia como una transacción de ajuste); botón "Ver movimientos de esta cuenta" → `/cuentas/movimientos`; botón "Guardar cambios"; separador; botón "Eliminar cuenta" (rojo, invoca `EliminarCuenta` — falla con un diálogo de error si la cuenta tiene movimientos).
- **Campos de crédito (Fase 29):** cuando el tipo elegido es "Crédito", aparecen con una transición animada (`AnimatedSize`, mismo patrón que los campos condicionales de `DeudaFormulario`) `TextFormField` Línea de crédito (numérico, obligatorio, prefijo de moneda), `TextFormField` Día de corte y `TextFormField` Día de pago (ambos numéricos, obligatorios, 1-31). A diferencia de la moneda, estos 3 campos se pueden seguir editando aunque la cuenta ya tenga movimientos — no afectan el saldo histórico. Al cambiar el tipo de Crédito a otro, los 3 valores se descartan (se guardan como `null`).

**Estados que maneja:** cargando SÍ (mientras carga `cuentaPorIdProvider` en modo edición). Vacío parcial — texto "Esta cuenta ya no existe." si el id no resuelve. Error SÍ (texto con el error crudo al cargar; `SnackBar` al guardar/ajustar). Éxito: SÍ desde la Fase 23.1 — `SnackBar` "Cuenta creada"/"Cambios guardados" justo antes del `Navigator.pop()`, y "Saldo ajustado" en el modal de ajuste.

**Sistema de diseño:** casi consistente — el texto de ayuda bajo "Saldo actual" usa `Theme.of(context).colorScheme.onSurfaceVariant` en vez del token semántico `textSecondary` directamente (`cuenta_formulario.dart:271-273`); funciona igual porque el `ColorScheme` mapea `onSurfaceVariant → textSecondary`, pero es una fuente de color distinta a la que usan las pantallas que sí importan `app_theme.dart` explícitamente.

**Limitaciones conocidas:** el diálogo de confirmación de "Eliminar cuenta" dice "Esta acción no se puede deshacer" incluso cuando la cuenta tiene movimientos y en realidad **no se podrá eliminar** — el usuario confirma primero y recién después, en un segundo diálogo, se entera de que la operación falló. No hay forma de fusionar/transferir el saldo de una cuenta a otra antes de eliminarla. El modal de ajuste de saldo no muestra un ejemplo numérico de cómo se calculará la diferencia. No se puede personalizar la cuenta con una foto/ícono propio (a diferencia de las categorías, que sí tienen selector de ícono).

---

## 17. TransaccionNuevaScreen

**Archivo:** `lib/presentation/screens/placeholders/transaccion_nueva_screen.dart`
**Ruta de navegación:** `'/transacciones/nueva'` (arg. `transaccionId` opcional)
**Propósito:** registrar un gasto o ingreso nuevo, o editar/eliminar uno existente.
**Cómo se llega aquí:** botón "Gasto" del `AppBottomBar`; tap en cualquier movimiento (dashboard, "Todos los movimientos", movimientos de una cuenta) para editar.

**Elementos visibles:**
- `SegmentedButton` Gasto/Ingreso.
- `TextFormField` Monto — numérico, obligatorio (>0), prefijo dinámico con el símbolo de moneda de la cuenta elegida.
- `DropdownButtonFormField` Cuenta — obligatorio, muestra nombre + símbolo de moneda.
- `DropdownButtonFormField` Categoría — obligatorio, filtrado por el tipo (gasto/ingreso) elegido; último ítem "+ Crear categoría nueva" abre un `showModalBottomSheet` con `CategoriaFormulario` en modo rápido (`tipoFijo`, solo nombre + ícono).
- `TextFormField` Concepto — opcional.
- `DropdownButtonFormField` Método de pago — obligatorio, siempre con valor por defecto.
- `SwitchListTile` "Recurrente" (con subtítulo "Se repite todos los meses").
- Selector de fecha (`ListTile` + `showDatePicker`, rango 2000 a hoy+365 días).
- Botón "Guardar"/"Guardar cambios".
- (Solo en edición) ícono Eliminar en el `AppBar`.

**Estados que maneja:** cargando SÍ (tres niveles anidados: cuentas → categorías → transacción en modo edición). Vacío no tiene un estado "vacío" propio (es un formulario). Error SÍ en cada nivel de carga + `SnackBar` al guardar/eliminar. Éxito: SÍ desde la Fase 23.1 — `SnackBar` con texto específico según la acción ("Gasto guardado"/"Ingreso guardado"/"Movimiento actualizado") justo antes del `pop()`; la categoría rápida creada desde el dropdown también muestra su propio `SnackBar` ("Categoría creada", heredado de `CategoriaFormulario`).

**Sistema de diseño:** consistente, sin `AppCard` (formulario plano estándar).

**Limitaciones conocidas:** no se puede adjuntar/tomar una foto del comprobante desde la UI, **pese a que el dominio ya soporta `comprobanteUrl`** (`Transaccion.comprobanteUrl` existe en el modelo pero ningún campo de este formulario lo llena). No hay atajo para "duplicar" un movimiento parecido. El campo de monto no tiene ninguna calculadora integrada ni acepta pegar montos con separador de miles (solo dígitos y coma/punto decimal). Al crear una categoría rápida desde el dropdown, no hay botón "Cancelar" explícito en el bottom sheet — solo cerrarlo deslizando o tocando fuera. La fecha máxima seleccionable es hoy+365 días, lo que permite registrar "gastos futuros" sin ninguna advertencia de que es inusual.

---

## 18. MovimientosCuentaScreen

**Archivo:** `lib/presentation/screens/movimientos_cuenta_screen.dart`
**Ruta de navegación:** `'/cuentas/movimientos'` (arg. `cuentaId`)
**Propósito:** ver todos los movimientos de una cuenta específica.
**Cómo se llega aquí:** botón "Ver movimientos de esta cuenta" en `CuentaNuevaScreen` (modo edición).

**Elementos visibles:**
- Lista de movimientos (`FilaMovimientoTransaccion`, el mismo widget que usa el dashboard), ordenados por fecha descendente, con badge "Ajuste" para los generados por `AjustarSaldoCuenta`.
- Tap en un movimiento → `/transacciones/nueva` en modo edición.
- Datos: `transaccionesPorCuentaProvider`.

**Estados que maneja:** cargando SÍ. Vacío SÍ ("Todavía no hay movimientos registrados en esta cuenta."). Error SÍ (texto con el error crudo). Éxito no aplica.

**Sistema de diseño:** consistente.

**Limitaciones conocidas:** sin filtro por rango de fechas ni por tipo (gasto/ingreso). Sin búsqueda por texto/concepto. Sin totales resumidos en esta vista (solo la lista cruda de movimientos). Sin exportar a CSV/PDF.

---

## 19. TodosLosMovimientosScreen

**Archivo:** `lib/presentation/screens/todos_los_movimientos_screen.dart`
**Ruta de navegación:** `'/transacciones/todas'`
**Propósito:** ver todas las transacciones del usuario, sin filtrar por cuenta.
**Cómo se llega aquí:** "Ver todos" en la sección "Movimientos recientes" del dashboard.

**Elementos visibles:** igual que `MovimientosCuentaScreen` (reutiliza `ListaMovimientosTransaccion`), pero alimentada por `todasLasTransaccionesProvider` (`TransaccionRepository.obtenerTodas()`, sin filtrar).

**Estados que maneja:** cargando SÍ. Vacío SÍ ("Todavía no tienes movimientos registrados."). Error SÍ. Éxito no aplica.

**Sistema de diseño:** consistente.

**Limitaciones conocidas:** mismas que `MovimientosCuentaScreen` (sin filtro de fecha/tipo, sin búsqueda, sin totales, sin exportar). Además, al no filtrar por cuenta, una lista con muchos movimientos puede volverse larga sin paginación ni carga diferida — `obtenerTodas()` trae todo de una sola vez.

---

## 20. DeudaNuevaScreen

**Archivo:** `lib/presentation/screens/placeholders/deuda_nueva_screen.dart` (con `lib/presentation/screens/deuda_formulario.dart` embebido)
**Ruta de navegación:** `'/deudas/nueva'` (arg. `deudaId` opcional)
**Propósito:** registrar una deuda nueva, o editar/eliminar una existente.
**Cómo se llega aquí:** botón "Deuda" del `AppBottomBar`; "Editar deuda" en `DeudaDetalleScreen`.

**Elementos visibles:**
- (Solo edición) `ListTile` "Ver historial de pagos" → `/deudas/historial`.
- (Delegado a `DeudaFormulario`, ver Verificación): `TextFormField` Nombre de la deuda (obligatorio); `DropdownButtonFormField` Tipo de deuda; `DropdownButtonFormField` Tipo de acreedor; `TextFormField` Nombre del acreedor (obligatorio, con `hintText` dinámico según el tipo de acreedor); `DropdownButtonFormField` Moneda; `TextFormField` Monto total (numérico, obligatorio >0); selector de Fecha de inicio (`showDatePicker`); `SegmentedButton` Cuotas fijas / Pago libre.
  - Si **cuotas fijas**: `TextFormField` Número de cuotas (obligatorio >0), `TextFormField` Monto de cuota (obligatorio >0), `DropdownButtonFormField` Periodicidad (mensual/quincenal), bloque de solo lectura con "Interés total" y "Fecha de vencimiento estimada" calculados en vivo (`generarCronogramaCuotas`).
  - Si **pago libre**: `SwitchListTile` "¿Tiene interés?" → si se activa, `TextFormField` Tasa de interés (%) (obligatorio >0) + `DropdownButtonFormField` Tipo de tasa; `TextFormField` Pago mínimo (opcional).
- `TextFormField` Notas — opcional, multilínea.
- Botón "Guardar"/"Guardar cambios".
- (Solo edición) ícono Eliminar en el `AppBar` → `EliminarDeuda`.

**Estados que maneja:** cargando SÍ (en modo edición). Vacío parcial — "Esta deuda ya no existe." si el id no resuelve. Error SÍ (texto al cargar, `SnackBar` al guardar, diálogo al fallar eliminar). Éxito: SÍ desde la Fase 23.1 — `SnackBar` "Deuda registrada"/"Deuda actualizada" justo antes del `pop()`.

**Sistema de diseño:** casi consistente — el bloque "Interés total / Fecha de vencimiento estimada" (`deuda_formulario.dart:481-512`, dentro de `_construirCamposCuotasFijas`) usa `colorScheme.surfaceContainerHigh` + `BorderRadius.circular(14)` a mano en vez de `AppCard` — el mismo patrón de escape se repite en varias otras pantallas (ver Candidatos a nueva funcionalidad).

**Limitaciones conocidas:** eliminar una deuda con pagos falla (mensaje en diálogo) sin ofrecer ninguna alternativa — por ejemplo "eliminar la deuda y sus pagos" o "marcarla como cancelada" en vez de borrarla. No se puede adjuntar el contrato/comprobante de la deuda. El campo "Nombre del acreedor" no tiene autocompletado de acreedores usados antes. No hay forma de convertir una deuda de pago libre a cuotas fijas (o viceversa) sin perder los datos ya ingresados — cambiar el `SegmentedButton` solo oculta/muestra campos, no migra valores entre modos. "Interés total"/"Fecha de vencimiento estimada" muestran "—" sin explicar qué dato falta para poder calcularlos.

---

## 21. DeudaDetalleScreen

**Archivo:** `lib/presentation/screens/deuda_detalle_screen.dart`
**Ruta de navegación:** `'/deudas/detalle'` (arg. `deudaId`)
**Propósito:** vista central de una deuda — mini-dashboard, cronograma de cuotas o historial de pagos, y accesos rápidos a editar/pagar.
**Cómo se llega aquí:** tap en una deuda dentro de `DeudasActivasSection` del dashboard.

**Elementos visibles:**
- Mini-dashboard (`AppCard`): nombre, tipo + acreedor, banner "En mora" (color `colorGasto`/`colorDanger`) si aplica, monto total, interés total (si >0), barra de progreso de pago, texto "Pagado X de Y", próxima cuota/fecha o "Sin cuota fija".
- Botón "Editar deuda" → `/deudas/nueva` en modo edición.
- Botón "Ver historial" → `/deudas/historial`.
- Si **cuotas fijas**: cronograma de cuotas (`generarCronogramaCuotas`) — cada cuota pendiente es un `Dismissible` (swipe hacia la derecha) que abre `/deudas/pago` con precarga de número/monto esperado; las cuotas ya pagadas se muestran sin swipe, con ícono de check.
- Si **pago libre**: `ListaPagosDeuda` embebida (el mismo widget que usa `HistorialPagosDeudaScreen`).
- Datos: `deudaPorIdProvider`, `pagosPorDeudaProvider`.

**Estados que maneja:** cargando SÍ (deuda + cronograma). Vacío SÍ ("Esta deuda no tiene un cronograma de cuotas configurado." cuando aplica). Error SÍ. Éxito no aplica.

**Sistema de diseño:** el mini-dashboard usa `AppCard` correctamente, pero `_FilaCuota` (`deuda_detalle_screen.dart:296-301`) usa `colorScheme.surfaceContainerHigh` + `BorderRadius.circular(14)` en un `Container` a mano en vez de `AppCard` — mismo patrón de escape que se repite en varios lugares (ver Candidatos).

**Limitaciones conocidas:** el gesto de swipe para pagar una cuota no tiene ninguna pista visual permanente — solo aparece el fondo verde al empezar a deslizar; un usuario nuevo puede no descubrir que existe. No hay forma de eliminar un pago individual desde aquí (ni desde ningún otro lugar de la app, confirmado — ver limitación de `HistorialPagosDeudaScreen`). El banner de mora no tiene ninguna acción directa (por ejemplo "Registrar pago ahora" dentro del propio banner).

---

## 22. PagoDeudaNuevoScreen

**Archivo:** `lib/presentation/screens/pago_deuda_nuevo_screen.dart`
**Ruta de navegación:** `'/deudas/pago'` (arg. `deudaId: String` o `PagoDeudaRouteArgs`)
**Propósito:** registrar un abono a una deuda, incluyendo pagos retroactivos y desglose capital/interés.
**Cómo se llega aquí:** swipe en una cuota pendiente de `DeudaDetalleScreen` (con precarga de número/monto); ícono "Registrar pago" en `DeudasActivasSection` del dashboard (sin precarga).

**Elementos visibles:**
- `AppCard` resumen (nombre de la deuda, pagado/total, próxima cuota o "pago libre").
- `TextFormField` Monto pagado — numérico, obligatorio (>0), prefijo de moneda.
- `SwitchListTile` "Este pago ya ocurrió antes" (pago retroactivo — oculta el selector de cuenta y no descuenta ningún saldo).
- `DropdownButtonFormField` Cuenta de origen — obligatorio si no es retroactivo, filtrado por la moneda de la deuda; si no hay ninguna cuenta en esa moneda, se muestra un texto explicativo en su lugar.
- Selector de fecha de pago (rango 2000 a hoy, no permite fechas futuras).
- (Si la deuda tiene interés) `TextFormField` Monto a capital + `TextFormField` Monto a interés — opcionales, pero si se llenan deben sumar el monto pagado (error inline "Capital + interés debe sumar el monto pagado" si no cuadra).
- (Si estructura de cuotas fijas) `TextFormField` Número de cuota — opcional, texto libre.
- Botón "Guardar".
- Caso especial: si `deuda.estado == EstadoDeuda.pagada`, toda la pantalla muestra solo un texto "... ya está completamente pagada." sin formulario.

**Estados que maneja:** cargando SÍ. Vacío: el caso "deuda ya pagada" funciona como un estado especial sin formulario. Error SÍ (`SnackBar` + validación inline de desglose). Éxito: SÍ desde la Fase 23.1 — `SnackBar` "Pago registrado" justo antes del `pop()`.

**Sistema de diseño:** consistente, usa `AppCard`.

**Limitaciones conocidas:** si no hay ninguna cuenta en la moneda de la deuda, el único texto disponible dice "créala desde 'Mis cuentas' o marca este pago como ya ocurrido" — pero no es un enlace tocable, solo texto plano; no hay atajo directo a "Mis cuentas" ni a "Agregar cuenta". El campo "Número de cuota" es texto libre (no un selector de las cuotas pendientes reales del cronograma, salvo cuando llega precargado desde el swipe de `DeudaDetalleScreen`) — se puede escribir cualquier número sin validar que corresponda a una cuota real. No se puede adjuntar comprobante del pago.

---

## 23. HistorialPagosDeudaScreen

**Archivo:** `lib/presentation/screens/historial_pagos_deuda_screen.dart`
**Ruta de navegación:** `'/deudas/historial'` (arg. `deudaId`)
**Propósito:** ver todos los pagos registrados de una deuda.
**Cómo se llega aquí:** "Ver historial de pagos" en `DeudaNuevaScreen` (modo edición); "Ver historial" en `DeudaDetalleScreen`.

**Elementos visibles:**
- `AppCard` resumen (nombre de la deuda, pagado/total).
- Lista de pagos (`ListaPagosDeuda`): monto, fecha, desglose capital/interés si aplica, número de cuota si aplica, cuenta de origen (o "Pago retroactivo (sin cuenta asociada)" / "Cuenta eliminada" si `cuenta == null`).
- Datos: `deudaPorIdProvider`, `pagosPorDeudaProvider`, y por cada fila `cuentaPorIdProvider(cuentaId)`.

**Estados que maneja:** cargando SÍ. Vacío SÍ ("Todavía no registraste ningún pago para esta deuda."). Error SÍ. Éxito no aplica.

**Sistema de diseño:** la fila de pago (`_FilaPago`, `historial_pagos_deuda_screen.dart:163-169`) usa `colorScheme.surfaceContainerHigh` + `BorderRadius.circular(14)` en vez de `AppCard` — el mismo patrón de escape que `_FilaCuota` en `DeudaDetalleScreen` y `DeudaListaItem` en onboarding.

**Limitaciones conocidas:** no se puede editar ni eliminar un pago individual ya registrado desde aquí ni desde ningún otro lugar de la app — confirmado, no existe ningún caso de uso `EditarPagoDeuda`/`EliminarPagoDeuda` expuesto en ninguna pantalla. Si un pago tiene un error de captura (monto mal tecleado), la única forma de "corregirlo" sería eliminar la deuda entera. Sin filtro por rango de fechas ni exportar el historial.

---

## 24. MisCategoriasScreen

**Archivo:** `lib/presentation/screens/mis_categorias_screen.dart`
**Ruta de navegación:** `'/categorias'`
**Propósito:** catálogo de categorías — ver las predeterminadas (solo lectura) y administrar (editar/eliminar) las propias, separadas en Gastos/Ingresos.
**Cómo se llega aquí:** "Mis categorías" en `MiPerfilScreen`.

**Elementos visibles:**
- Botón "Nueva categoría" (`FilledButton.icon`) → `/categorias/nueva`.
- `AppCard` "Gastos" (`SectionLabel`) — categorías predeterminadas primero (ícono de candado, sin acción tocable), separador, luego categorías propias (tap → editar, ícono eliminar por fila).
- `AppCard` "Ingresos" — mismo patrón.
- Datos: `categoriasProvider`.

**Estados que maneja:** cargando SÍ. Vacío: no hay mensaje "vacío" explícito (las categorías predeterminadas siempre existen, así que la lista nunca está realmente vacía en la práctica). Error SÍ. Éxito: eliminar solo actualiza la lista, sin `SnackBar`/confirmación textual de éxito.

**Sistema de diseño:** consistente — ejemplo correcto de `AppCard` + `SectionLabel` + tokens (`borderCard` en el `Divider`, `textMuted`/`textSecondary`/`colorSuccess` usados apropiadamente).

**Limitaciones conocidas:** sin buscador ni forma de reordenar categorías manualmente. No se puede "ocultar"/archivar una categoría predeterminada que no se usa nunca (solo se puede ignorar visualmente). Eliminar una categoría con movimientos falla con un diálogo de error, sin ofrecer "reasignar los movimientos a otra categoría" como alternativa. No hay contador de cuántos movimientos usa cada categoría antes de intentar eliminarla — el usuario se entera recién al fallar.

---

## 25. CategoriaNuevaScreen

**Archivo:** `lib/presentation/screens/categoria_nueva_screen.dart` (con `lib/presentation/screens/categoria_formulario.dart` embebido)
**Ruta de navegación:** `'/categorias/nueva'` (arg. `categoriaId` opcional)
**Propósito:** crear o editar una categoría propia.
**Cómo se llega aquí:** "Nueva categoría" o tap en una categoría propia desde `MisCategoriasScreen`.

**Elementos visibles (delegados a `CategoriaFormulario`):**
- `TextFormField` Nombre — obligatorio.
- `SegmentedButton` Gasto/Ingreso — bloqueado (con texto explicativo) si la categoría en edición ya tiene movimientos asociados (`transaccionesPorCategoriaProvider`).
- Grid de íconos tocables (`_SelectorIcono`, catálogo fijo en `category_icons.dart`).
- Botón "Guardar"/"Guardar cambios".

**Estados que maneja:** cargando SÍ (en modo edición). Vacío parcial — "Esta categoría ya no existe." si el id no resuelve. Error SÍ. Éxito: SÍ desde la Fase 23.1 — `SnackBar` "Categoría creada"/"Categoría actualizada" justo antes del `pop()`.

**Sistema de diseño:** consistente — el grid de íconos usa los tokens (`colorSuccess`, `bgCard`, `borderCard`, `textSecondary`) correctamente.

**Limitaciones conocidas:** el catálogo de íconos es fijo y cerrado — no se puede subir un ícono/imagen propia, ni hay buscador dentro del grid si la lista de íconos crece. No hay selector de color por categoría (todas comparten los mismos tokens verdes). No se puede fusionar dos categorías propias en una.

---

## 26. ConsejosFinancierosScreen

**Archivo:** `lib/presentation/screens/consejos_financieros_screen.dart`
**Ruta de navegación:** `'/consejos'`
**Propósito:** conversar por chat con un asesor financiero (Gemini) que conoce el resumen agregado y anonimizado de deudas/ingresos/gastos del usuario. **Reescrita por completo en la Fase 30** — antes (Fase 17/24) era un botón único "Generar consejos" que devolvía una lista de 3-5 ideas sin memoria entre generaciones; ahora es un chat real, con historial que persiste en Supabase (`mensajes_consejos`) entre sesiones.
**Cómo se llega aquí:** botón "Consejos" del `AppBottomBar` (visible en el dashboard, y resaltado aquí mismo y en `MiPerfilScreen`).

**Elementos visibles:**
- Lista de burbujas de chat (`ListView`, scrolleable, auto-scroll al final tras cada envío): burbujas de usuario alineadas a la derecha (fondo `colorSuccess` translúcido), burbujas del asistente a la izquierda (fondo `bgCard` con borde `borderCard`, mismo tratamiento que `AppCard`).
- **Primer mensaje automático:** si el usuario no tiene ningún mensaje guardado, la pantalla arma su `ResumenParaConsejos` (`armarResumenParaConsejosProvider`) y lo manda sola como si el usuario lo hubiera escrito (`ChatConsejosRepository.enviarMensaje(esPrimerMensaje: true, resumen: ...)`) — sin ningún botón que tocar. Mientras tanto se ve el texto "Preparando tu resumen financiero..." y luego la burbuja "Escribiendo...".
- Burbuja "Escribiendo..." (izquierda, texto en cursiva `textSecondary`) mientras se espera la respuesta del asistente — no hay spinner de pantalla completa, ni para el primer mensaje ni para los de seguimiento.
- Burbuja de sistema centrada (ícono + texto, sin alinear a ningún lado) cuando falla un envío: fondo/ícono `colorWarning` con el mensaje fijo "Alcanzaste el límite de mensajes por hoy. Vuelve mañana." si es `LimiteDiarioConsejosError` (Fase 24, ahora cuenta mensajes en vez de "generaciones"); fondo/ícono `colorDanger` para cualquier otro error, con `mensajeDeError(error)`. Si falló el primer mensaje automático (historial todavía vacío), la burbuja incluye un botón "Reintentar" que vuelve a intentar armar el resumen y enviarlo.
- Campo de texto (`TextField`, multilínea hasta 4 líneas) + botón enviar (`IconButton.filled`, ícono `send`) al final, siempre visible — para mensajes de seguimiento libres. Se deshabilita mientras se está esperando una respuesta.
- `AppBottomBar` con "Consejos" resaltado (Fase 32: barra de 5 botones con efecto "glass" — ver el detalle completo en la entrada 14, DashboardScreen).
- Datos: `historialConsejosProvider` (lee `mensajes_consejos` del usuario actual directo contra Supabase, vía `ChatConsejosRepository.obtenerHistorial()`).

**Estados que maneja:** cargando SÍ (spinner de pantalla completa solo mientras se resuelve `historialConsejosProvider` por primera vez; de ahí en adelante, "Escribiendo..." dentro del chat, nunca un spinner que tape la conversación). Vacío SÍ ("Preparando tu resumen financiero..." antes de que el primer mensaje automático se dispare). Error SÍ, como burbuja de sistema dentro del chat (ver arriba) — ya no existe el bloque de error genérico que reemplazaba toda la pantalla. Éxito: la burbuja nueva del asistente en la lista ES la confirmación (igual que antes, no hace falta un mensaje adicional).

**Sistema de diseño:** consistente — burbujas con los tokens de `app_theme.dart` (`colorSuccess`/`bgCard`/`borderCard` para las burbujas normales, `colorWarning`/`colorDanger` para la de sistema), mismo criterio de "amarillo para un tope esperado, rojo para un error real" que usa `DeudasActivasSection` (Fase 19) para sus banners.

**Limitaciones conocidas:** no hay forma de borrar/editar un mensaje ya enviado, ni de "empezar de nuevo" la conversación desde la app (habría que borrar filas directo en Supabase). Los mensajes no se pueden copiar ni compartir. No hay indicador de "el asistente está pensando" más allá del texto "Escribiendo..." (sin animación de puntos). El campo de texto no muestra cuántos mensajes le quedan al usuario antes del límite diario (5/día, Fase 24) — se entera recién cuando lo alcanza. Si el usuario cierra la pantalla justo cuando se está armando el primer mensaje automático y vuelve a entrar, el guard `_yaIniciando` es por instancia de pantalla (no persiste), así que si el primer intento nunca llegó a guardar nada en `mensajes_consejos` (p. ej. la app se cerró a mitad de la llamada a la Edge Function), el siguiente ingreso lo vuelve a intentar solo — comportamiento correcto, pero no está cubierto por ningún test de extremo a extremo con la Edge Function real.

---

## 27. MiPerfilScreen

**Archivo:** `lib/presentation/screens/mi_perfil_screen.dart`
**Ruta de navegación:** `'/perfil'`
**Propósito:** administrar el perfil del usuario (avatar, nick de solo lectura, nombre, Instagram), elegir el tema de la app, acceder a categorías, cerrar sesión, y eliminar la cuenta de forma permanente. **Enriquecida en la Fase 31** — antes solo tenía el campo Nombre.
**Cómo se llega aquí:** botón "Perfil" del `AppBottomBar`.

**Elementos visibles:**
- **Fase 31** — Avatar actual (`AvatarCirculo`, 88px, círculo de color sólido por tipo + ícono blanco) centrado arriba de todo, tocable (con un pequeño ícono de lápiz superpuesto en la esquina) → abre `abrirSelectorAvatar` (bottom sheet con el grid de 12 avatares de `avataresDisponibles`, mismo patrón que el selector de íconos de categorías, Fase 20) → `PerfilRepository.guardarAvatarId`.
- **Fase 31** — Nick de solo lectura, centrado bajo el avatar (`@nick`, o "Sin nick" si por alguna razón no se guardó en el onboarding) + texto "El nick no se puede cambiar" (decisión explícita: así un futuro sistema social siempre encuentra al usuario por el mismo nick que usó desde el principio; no hay ningún campo editable para él en esta pantalla).
- `TextFormField` Nombre — sin validación de vacío, se puede guardar en blanco.
- **Fase 31** — `TextFormField` Instagram (opcional, texto libre tipo `@usuario`) → `PerfilRepository.guardarInstagram` (`null` si se deja vacío).
- Botón "Guardar" (`FilledButton`) — nunca se deshabilita por validación, siempre tocable; guarda Nombre e Instagram juntos.
- **Fase 31** — Sección "Apariencia": `SegmentedButton<TemaApp>` con 3 opciones (Claro/Oscuro/Sistema) → `PreferenciasRepository.guardarTema` + invalida `temaProvider`, que `FinanzasAutomaticasApp` (`app.dart`) observa para fijar `MaterialApp.themeMode` en tiempo real — cambiar la selección aquí recolorea toda la app al instante, sin reiniciar.
- `ListTile` "Mis categorías" → `/categorias`.
- **Fase 25** — `ListTile` "Automatización" → `/automatizacion` (`AutomatizacionScreen`, ver entrada más abajo).
- Botón "Cerrar sesión" (`OutlinedButton.icon`) — con diálogo de confirmación que aclara que no se borran datos.
- Sección "Zona de peligro" (título en `colorDanger`) + texto explicativo + botón "Eliminar mi cuenta" (`FilledButton.icon`, fondo `colorDanger`, ícono `delete_forever`) → diálogo `confirmarEliminarCuenta` (exige escribir literalmente "ELIMINAR" para habilitar el botón de confirmar) → `EliminarCuentaDeUsuario` + `PreferenciasRepository.limpiarTodo()`.
- `AppBottomBar` con "Perfil" resaltado (Fase 32: barra de 5 botones con efecto "glass" — ver el detalle completo en la entrada 14, DashboardScreen).
- Datos: `nombreUsuarioProvider` (`PreferenciasRepository`, 100% local) + `perfilProvider` (Fase 31, `PerfilRepository` → tabla `usuarios` de Supabase) + `temaProvider` (Fase 31, lectura síncrona de `PreferenciasRepository`, mismo patrón que `datosEnLaNubeProvider`).
- **Fase 24 — ya no tiene el campo "API key de Gemini"** (ni su `ListTile`/texto de ayuda de "Consejos financieros con IA"): la API key ahora es del distribuidor de la app y vive solo en el servidor (Edge Function `generar-consejos`), ningún usuario la ve ni la ingresa. `PreferenciasRepository.obtenerApiKeyGemini`/`guardarApiKeyGemini` siguen existiendo en el puerto por compatibilidad, pero esta pantalla ya no los llama.

**Estados que maneja:** cargando SÍ (mientras precargan el nombre y el perfil — dos providers anidados, Fase 23.2: mientras se ejecuta "Eliminar mi cuenta", un diálogo no descartable muestra la etapa actual en tiempo real en vez de solo el spinner del botón). Vacío no aplica. Error SÍ (texto genérico si falla cualquiera de los dos providers de precarga; `SnackBar` si falla guardar/cambiar avatar/cambiar tema/cerrar sesión; diálogo `mostrarErrorEliminar` si falla eliminar la cuenta). Éxito: `SnackBar` "Perfil actualizado" al guardar Nombre/Instagram — cambiar avatar o tema no muestra `SnackBar` propio (el cambio visual inmediato ya es la confirmación). "Cerrar sesión" y "Eliminar mi cuenta" siguen sin `SnackBar` de éxito propio (decisión explícita de la Fase 23.1: la navegación resultante, volver al login, ya es señal suficiente).

**Sistema de diseño:** consistente — "Zona de peligro" usa `colorDanger` correctamente, el botón de eliminar usa `colorSobreEstado` (Fase 31, reemplaza a `bgPage` como color de primer plano sobre `colorDanger` — `bgPage` cambia de valor según el tema ahora, `colorSobreEstado` es fijo a propósito para mantener contraste sobre los tres colores de estado en cualquier tema) dentro del sistema de tokens de la Fase 19/31.

**Limitaciones conocidas (la sección más relevante de este documento — flujo de eliminación de cuenta recién agregado, "Fase 22"):**
- ~~`EliminarCuentaDeUsuario.call` expone `onProgreso(etapa)` pero `MiPerfilScreen` lo invocaba sin pasarlo, mostrando solo un spinner genérico~~ — **resuelto en la Fase 23.2**: `_eliminarCuenta()` ahora conecta el callback a un `ValueNotifier<String>` y muestra un `AlertDialog` no descartable (`PopScope(canPop: false)`, `barrierDismissible: false`) con la etapa actual en tiempo real, mismo espíritu que `MigrarDatosScreen`. Sigue sin ser cancelable a mitad de camino — intencional, la operación es destructiva e idempotente por diseño.
- El campo Nombre no tiene validación de vacío — se puede guardar en blanco, lo que rompe el saludo "Hola, " (con coma y espacio colgantes) en el dashboard.
- ~~No hay validación de formato de la API key antes de guardarla~~ — ya no aplica desde la Fase 24: el campo se quitó, el usuario no ingresa ninguna API key.
- "Cerrar sesión" y "Eliminar mi cuenta" usan dos patrones de confirmación distintos (diálogo sí/no vs. escribir "ELIMINAR") — consistente con la gravedad relativa de cada acción, pero ninguno de los dos muestra un resumen con cifras concretas ("esto borrará N cuentas, N deudas, N transacciones") antes de confirmar, solo texto genérico.
- **Nuevo en la Fase 31:** el campo Instagram no valida el formato `@usuario` (acepta cualquier texto libre). Si el usuario nunca eligió un avatar (no debería pasar si el onboarding se completó, pero es posible en datos preexistentes migrados antes de la Fase 31), se ve el primer avatar del catálogo por defecto sin ninguna indicación de que es un valor "no elegido".

---

## 28. AutomatizacionScreen

**Archivo:** `lib/presentation/screens/automatizacion_screen.dart`
**Ruta de navegación:** `'/automatizacion'`
**Propósito:** entregarle al usuario el enlace (URL + `token_webhook`) que necesita configurar en un Atajo de iOS o una regla de reenvío de correo para que sus movimientos se registren solos vía la Edge Function `capturar-transaccion` (Fase 25 — infraestructura receptora de la Etapa 3; el Atajo y el Worker de correo en sí todavía no existen, ver `CONTEXTO.md`).
**Cómo se llega aquí:** `ListTile` "Automatización" en `MiPerfilScreen`.

**Elementos visibles:**
- `AppCard` explicativo ("Conecta capturas automáticas") con el texto de para qué sirve el enlace.
- `AppCard` "Tu enlace": `SelectableText` con la URL completa (`$supabaseUrl/functions/v1/capturar-transaccion?token=<token_webhook>`) + botón "Copiar" (`OutlinedButton.icon`, usa `Clipboard.setData`).
- `AppCard` de advertencia (ícono `warning_amber_rounded` + texto, ambos en `colorDanger`): "No compartas este enlace — cualquiera que lo tenga puede registrar movimientos en tu cuenta."
- Botón "Generar nuevo enlace" (`OutlinedButton.icon`) → `confirmarAccion` (mismo patrón que "Cerrar sesión" en `MiPerfilScreen`, diálogo sí/no) → `AutomatizacionRepository.regenerarTokenWebhook()`.
- Datos: `tokenWebhookProvider` (`AutomatizacionRepository`, siempre Supabase — el token de webhook no tiene equivalente en Drift, es un concepto que solo existe con datos en la nube).

**Estados que maneja:** cargando SÍ (spinner de pantalla completa mientras carga el token). Vacío no aplica (siempre hay un token, se genera solo al crear el usuario). Error SÍ (texto con el error crudo si falla cargar el token; `SnackBar` si falla regenerar). Éxito: `SnackBar` "Enlace copiado" al copiar y "Enlace regenerado" al regenerar — a diferencia de la mayoría de acciones destructivas/de ajustes de la app, aquí SÍ hay confirmación textual para ambas acciones.

**Sistema de diseño:** consistente — usa `AppCard` para las tres tarjetas y `colorDanger` para la advertencia, mismo patrón que "Zona de peligro" en `MiPerfilScreen`.

**Limitaciones conocidas:** no hay forma de ver si el enlace ya se usó alguna vez ni un historial de capturas automáticas recibidas (para eso hay que ir al dashboard/movimientos y reconocer la fuente `webhookAtajo` indirectamente, sin ningún badge visual — a diferencia del badge "Ajuste" que sí existe para `fuenteCaptura: ajuste`). No hay instrucciones paso a paso de cómo configurar el Atajo de iOS en sí (razonable por ahora: ese Atajo todavía no existe). El botón "Generar nuevo enlace" no advierte cuántas automatizaciones activas se van a romper (no hay forma de saberlo desde el cliente, de todas formas).

---

## Matriz resumen

| Pantalla | Carga | Vacío | Error | Diseño consistente |
|---|---|---|---|---|
| RootScreen | Sí | — | Sí | Sí |
| LoginScreen | Sí | — | Sí | Sí |
| CrearCuentaScreen | Sí | — | Sí | Sí |
| ConfigurarBloqueoScreen | Parcial (por botón) | — | Sí | Sí |
| DesbloqueoScreen | Sí | — | Sí | Sí |
| MigrarDatosScreen | Sí (con etapas) | — | Sí | Sí |
| OnboardingFlowScreen | — | — | — | Sí |
| OnboardingWelcomeStep | — | — | — | Sí |
| OnboardingNombreStep | — | — | — | Sí |
| OnboardingCuentasStep | Sí | Parcial (implícito) | Sí | Sí |
| OnboardingDeudasStep | Sí | Parcial (implícito) | Sí | Sí |
| OnboardingResumenStep | Sí | Sí (deudas) / Parcial (cuentas) | Sí (uno sin `mensajeDeError`) | Sí |
| DashboardScreen | Sí | Sí | Sí | Sí |
| MisCuentasScreen | Sí | Sí | Sí | Sí |
| CuentaNuevaScreen | Sí | Parcial ("ya no existe") | Sí | Casi (color directo en vez de token) |
| TransaccionNuevaScreen | Sí | Parcial | Sí | Sí |
| MovimientosCuentaScreen | Sí | Sí | Sí | Sí |
| TodosLosMovimientosScreen | Sí | Sí | Sí | Sí |
| DeudaNuevaScreen | Sí | Parcial | Sí | No (`Container` crudo en vez de `AppCard`) |
| DeudaDetalleScreen | Sí | Parcial (cronograma) | Sí | No (`_FilaCuota` cruda) |
| PagoDeudaNuevoScreen | Sí | Parcial (deuda pagada) | Sí | Sí |
| HistorialPagosDeudaScreen | Sí | Sí | Sí | No (`_FilaPago` cruda) |
| MisCategoriasScreen | Sí | Parcial (implícito) | Sí | Sí |
| CategoriaNuevaScreen | Sí | Parcial | Sí | Sí |
| ConsejosFinancierosScreen | Sí | Sí | Sí | Sí |
| MiPerfilScreen | Sí | — | Sí | Sí |
| AutomatizacionScreen | Sí | — | Sí | Sí |

---

## Candidatos a nueva funcionalidad

Ordenados de mayor a menor impacto para el usuario, agrupando patrones que se repiten en varias pantallas. No se repiten aquí los pendientes ya señalados por `INFORME_PROYECTO.md` §7 (selector de mes, manejo de errores de BD genérico, eliminación de cuenta — ya resuelta, campana/escudo decorativos) salvo con un ángulo específico de interfaz que ese informe no cubre.

1. ~~**Confirmación visual de guardado, ausente o inconsistente en casi todos los formularios.** La inmensa mayoría de las pantallas de creación/edición (transacción, deuda, cuenta, pago de deuda, categoría) solo hacen `Navigator.pop()` al guardar con éxito — sin `SnackBar`/toast.~~ — **resuelto en la Fase 23.1**: `TransaccionNuevaScreen`, `DeudaNuevaScreen`, `CuentaFormulario` (crear/editar y el modal "Ajustar saldo"), `PagoDeudaNuevoScreen` y `CategoriaFormulario` (incluye el modo rápido embebido en `TransaccionNuevaScreen`) ahora muestran un `SnackBar` con texto específico por acción ("Gasto guardado", "Deuda actualizada", "Saldo ajustado", "Pago registrado", "Categoría creada", etc.) justo antes de `pop()`/`onGuardadoExitoso()`. Decisión explícita para "Cerrar sesión" y "Eliminar cuenta" (el botón dentro de `CuentaFormulario`, no la cuenta de usuario): se dejaron sin `SnackBar` de éxito porque la navegación resultante (volver al login, volver a la lista) ya es señal suficiente de que la acción se completó.

2. ~~**Conectar el progreso por etapas que `EliminarCuentaDeUsuario` ya expone.** El caso de uso acepta `onProgreso(etapa)` con 6 mensajes descriptivos, pero `MiPerfilScreen` lo ignora y solo muestra un spinner genérico durante una operación destructiva e irreversible.~~ — **resuelto en la Fase 23.2**: `MiPerfilScreen._eliminarCuenta()` conecta ese callback a un diálogo de progreso no descartable (`PopScope(canPop: false)`, sin botón de cerrar) que muestra la etapa actual en tiempo real, mismo espíritu que `MigrarDatosScreen`. Deliberadamente no cancelable — la operación es destructiva e idempotente por diseño, el progreso es solo informativo.

3. **Falta de búsqueda/filtro en todas las listas de movimientos y catálogos.** `MisCuentasScreen`, `MisCategoriasScreen`, `MovimientosCuentaScreen`, `TodosLosMovimientosScreen` y `HistorialPagosDeudaScreen` no tienen buscador, filtro por fecha/tipo/moneda, ni orden alternativo. Es más urgente en `TodosLosMovimientosScreen`, que además carga todos los movimientos de una sola vez sin paginación — a medida que crece el historial del usuario, esa pantalla se volverá progresivamente más pesada de cargar y más difícil de recorrer.

4. **Gestión de un pago de deuda individual (editar/eliminar) no existe en ningún lugar.** Una vez registrado un `PagoDeuda`, la única forma de "deshacerlo" es eliminar la deuda entera (lo cual además falla si tiene pagos, según `DeudaNuevaScreen`). Un error de tecleo en un pago (monto, fecha, cuenta) queda sin remedio dentro de la app.

5. **Adjuntar comprobante fotográfico — el dominio ya lo soporta, la UI no lo usa.** `Transaccion.comprobanteUrl` existe en el modelo (documentado en `CONTEXTO.md` §2) pero ningún formulario de la app permite tomar/adjuntar una foto. Es candidato natural para una futura fase de captura automática, pero también tendría valor inmediato como registro manual de respaldo.

6. **Patrón de "fila embebida" que escapa del sistema de diseño, repetido en 4 archivos independientes.** `onboarding/deuda_lista_item.dart`, `deuda_formulario.dart` (bloque de interés/vencimiento estimado), `deuda_detalle_screen.dart` (`_FilaCuota`) e `historial_pagos_deuda_screen.dart` (`_FilaPago`) implementan cada uno, por separado, el mismo `Container` con `colorScheme.surfaceContainerHigh` + `BorderRadius.circular(14)` en vez de usar `AppCard`. No es solo una inconsistencia visual menor: al estar duplicado 4 veces, cualquier ajuste futuro al estilo de "fila de información" (por ejemplo alinearlo mejor con `AppCard`) exige tocar 4 archivos en vez de uno. Vale la pena extraer un widget compartido (`InfoRowCard` o similar) que envuelva `AppCard` con el layout común.

7. **Protección contra fuerza bruta en el bloqueo local.** `DesbloqueoScreen` no limita los intentos fallidos de PIN — no hay ningún retraso ni bloqueo temporal tras varios intentos incorrectos seguidos. Aunque el bloqueo local es una capa adicional (la sesión de Supabase sigue protegida aparte), es una brecha de seguridad percibida fácil de explotar si el dispositivo cae en manos de un tercero.

8. **Botones redundantes o sin retroalimentación clara.** `OnboardingDeudasStep` tiene dos botones ("Continuar" y "Omitir por ahora") que hacen exactamente lo mismo — sugiere revisar la copy/UX de ese paso. Y en varias pantallas donde falta una cuenta/categoría para continuar (p. ej. `PagoDeudaNuevoScreen` sin cuentas en la moneda de la deuda), el texto explicativo no es un enlace tocable hacia la acción que lo resolvería.

---

## Verificación

**Pantallas documentadas en detalle:** 27 (secciones 1 a 27 de este documento — se sumó `AutomatizacionScreen` en la Fase 25).

**Archivos `.dart` bajo `lib/presentation/screens/` (recursivo):** 41 al momento de esta actualización (Fase 25) — el conteo original de este documento (Fase de inventario inicial) fue 40 contra un enunciado que decía 39; ese desfase de entonces se dejó documentado tal cual en su momento, sin ajustar el número real. El archivo nuevo de la Fase 25 (`automatizacion_screen.dart`) explica el 40 → 41. Los 41 se reparten así: 27 documentados como pantallas reales (arriba) + 14 excluidos por ser widgets/formularios compartidos sin `Scaffold` ni ruta propia (mismos 14 de siempre, sin cambios — ver lista abajo). 27 + 14 = 41, cuadra con el recuento real.

**Los 14 archivos NO documentados como pantalla independiente, con el motivo exacto de cada uno:**

1. `lib/presentation/screens/dashboard/dashboard_fixtures.dart` — no es ni siquiera un widget, son constantes de datos de prueba (`cuentasDashboardFixture`, `resumenDashboardFixture`, `resumenDashboardVacioFixture`) usadas solo por `lib/main_dev.dart` para previsualizar el dashboard con datos falsos. Sin `Scaffold`, sin `build()`.
2. `lib/presentation/screens/dashboard/widgets/accesos_rapidos_section.dart` — fila de 2 botones ("Gasto/ingreso", "Nueva deuda"), embebida únicamente dentro de `DashboardEmptyState`. Sin `Scaffold` ni ruta propia.
3. `lib/presentation/screens/dashboard/widgets/cuentas_carrusel.dart` — la pila de tarjetas de cuenta (Fase 33: pila vertical con gesto de deslizar hacia arriba, antes un carrusel horizontal), embebida dentro del contenido de `DashboardScreen`. Sin `Scaffold` ni ruta propia; sus elementos se documentaron dentro de la entrada 14 (DashboardScreen).
4. `lib/presentation/screens/dashboard/widgets/dashboard_empty_state.dart` — estado vacío del dashboard, mostrado condicionalmente por `DashboardScreen` (`resumen.estaVacio`). Sin `Scaffold` ni ruta propia; documentado como parte del estado "vacío" de la entrada 14.
5. `lib/presentation/screens/dashboard/widgets/deudas_activas_section.dart` — sección acordeón embebida en `DashboardScreen`. Sin `Scaffold` ni ruta propia.
6. `lib/presentation/screens/dashboard/widgets/gasto_por_categoria_section.dart` — sección embebida en `DashboardScreen`. Sin `Scaffold` ni ruta propia.
7. `lib/presentation/screens/dashboard/widgets/ingresos_gastos_section.dart` — sección embebida en `DashboardScreen`. Sin `Scaffold` ni ruta propia.
8. `lib/presentation/screens/dashboard/widgets/movimientos_recientes_section.dart` — sección acordeón embebida en `DashboardScreen`. Sin `Scaffold` ni ruta propia.
9. `lib/presentation/screens/dashboard/widgets/saldo_total_card.dart` — tarjeta embebida en `DashboardScreen`. Sin `Scaffold` ni ruta propia.
10. `lib/presentation/screens/dashboard/widgets/wallet_account_card.dart` — tarjeta de cuenta reutilizada en al menos 5 lugares distintos (pila de cuentas del dashboard, `MisCuentasScreen`, `CuentaFormulario` en modo edición, `OnboardingCuentasStep`, `OnboardingResumenStep`). Nunca se instancia con su propio `Scaffold` ni ruta.
11. `lib/presentation/screens/onboarding/deuda_lista_item.dart` — fila compacta de una deuda, reutilizada en `OnboardingDeudasStep` y `OnboardingResumenStep`. Sin `Scaffold` ni ruta propia.
12. `lib/presentation/screens/cuenta_formulario.dart` — formulario de cuenta (crear/editar/ajustar saldo/eliminar), reutilizado por `CuentaNuevaScreen` (entrada 16) y `OnboardingCuentasStep` (entrada 11). Nunca se instancia con su propio `Scaffold`; sus campos y botones se documentaron dentro de esas dos entradas, no como pantalla aparte.
13. `lib/presentation/screens/deuda_formulario.dart` — formulario de deuda, reutilizado por `DeudaNuevaScreen` (entrada 20) y `OnboardingDeudasStep` (entrada 12). Mismo criterio que `cuenta_formulario.dart`.
14. `lib/presentation/screens/categoria_formulario.dart` — formulario de categoría, reutilizado por `CategoriaNuevaScreen` (entrada 25) y por el modo rápido embebido (bottom sheet) de `TransaccionNuevaScreen` (entrada 17). Mismo criterio.

Los 26 archivos restantes corresponden exactamente a las 26 pantallas documentadas en detalle arriba (incluyendo `RootScreen`, que aunque es principalmente un despachador reactivo sin UI propia persistente, sí tiene estados de carga/error reales y visibles que valía la pena catalogar, y los 5 pasos del onboarding + su contenedor, tal como pide el orden de pantallas del encargo).
