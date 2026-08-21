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
