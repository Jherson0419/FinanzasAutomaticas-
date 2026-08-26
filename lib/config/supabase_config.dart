/// Credenciales del proyecto de Supabase usado solo para autenticación
/// (Fase 18) — los datos financieros siguen siendo 100% locales (Drift),
/// ver `CONTEXTO.md`.
///
/// ⚠️ Placeholders: reemplaza estos dos valores con los de tu proyecto de
/// Supabase (Project Settings → API) antes de compilar contra un backend
/// real. Con los valores de ejemplo, `Supabase.initialize` no podrá
/// autenticar a nadie.
const supabaseUrl = 'https://oyoxbvloqqiiasiaugzm.supabase.co';
const supabaseAnonKey = 'sb_publishable_QhGrHcVMjCCPol9U31k2lA_fQwMS3PQ';

/// Deep link al que Supabase redirige tras confirmar el correo de una
/// cuenta nueva (Fase 54) — registrado como esquema de URL custom en
/// `ios/Runner/Info.plist` (`CFBundleURLTypes`) y en el `<intent-filter>`
/// de `android/app/src/main/AndroidManifest.xml`. `supabase_flutter` ya
/// escucha deep links entrantes internamente (`SupabaseAuth`, usa
/// `app_links` bajo el capó) y resuelve la sesión sola en cuanto detecta
/// uno con estos parámetros — no hace falta un listener propio de
/// `app_links` en esta app, sería una segunda suscripción redundante al
/// mismo stream. También hay que agregar esta misma URL en el Dashboard
/// de Supabase → Authentication → URL Configuration → Redirect URLs,
/// si no la agrega ahí Supabase rechaza el redirect.
const authEmailRedirectUrl = 'finzo://login-callback';

/// Deep link para compartir el perfil y agregar amigos más rápido (Fase
/// 64): `finzo://agregar-amigo?nick=<nick>`, mismo esquema `finzo://` que
/// [authEmailRedirectUrl] pero otro host — registrado junto a
/// `login-callback` en el `<intent-filter>` de
/// `android/app/src/main/AndroidManifest.xml` (en iOS, `Info.plist` no
/// distingue hosts dentro de un mismo esquema, así que no hace falta una
/// entrada aparte ahí). A diferencia de `authEmailRedirectUrl`,
/// `supabase_flutter` NO reacciona a este link — su listener interno
/// (`SupabaseAuth`) solo procesa links con forma de callback de
/// autenticación e ignora cualquier otro — así que esta app sí necesita su
/// propia suscripción a `app_links` para este caso (ver `app.dart`,
/// `parsearNickDesdeLinkAgregarAmigo`).
String construirLinkAgregarAmigo(String nick) => 'finzo://agregar-amigo?nick=$nick';

/// Deep link al que Supabase redirige tras tocar el link de recuperación de
/// contraseña (Fase 65): mismo esquema `finzo://`, otro host, registrado
/// junto a `login-callback`/`agregar-amigo` en el `<intent-filter>` de
/// Android. A diferencia de `agregar-amigo`, este SÍ lo reconoce
/// `supabase_flutter` internamente (tiene forma de callback de
/// autenticación, igual que `login-callback`): al abrirlo, arma sola una
/// sesión de recuperación y emite `AuthChangeEvent.passwordRecovery` por
/// `onAuthStateChange` — no hace falta un listener de `app_links` propio
/// para este caso (ver `eventoRecuperacionContrasenaProvider`,
/// `presentation/state/providers.dart`).
const authResetPasswordRedirectUrl = 'finzo://reset-password';
