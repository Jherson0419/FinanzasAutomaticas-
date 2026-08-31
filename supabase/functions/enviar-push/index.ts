// Edge Function: enviar-push
//
// Por qué existe (Fase 72 — cierra el circuito abierto en la Fase 71): la
// Fase 71 dejó el CLIENTE listo para recibir pushes (permiso, token
// guardado en `tokens_dispositivo`, manejo de mensajes entrantes) pero
// nada del lado del servidor los enviaba todavía. Esta función es ese
// emisor: la dispara un Database Webhook de Supabase (ver el reporte de
// esta fase para los pasos de configuración) en cada `INSERT` sobre
// `public.notificaciones` — la misma tabla que ya alimentan los triggers
// de las Fases 63/69/70/71 y `NotificacionesScreen` (Fase 63, sigue
// siendo la fuente de verdad dentro de la app; este push es solo un aviso
// adicional, ver `CONTEXTO.md`).
//
// Autenticación: a diferencia de `generar-consejos`/`eliminar-cuenta`
// (JWT del usuario logueado) esta función la llama el propio Webhook de
// Supabase, no la app — no hay "usuario que llama", el destinatario del
// push viene en el payload (`record.usuario_id`). El Webhook se configura
// con un header `Authorization: Bearer <SERVICE_ROLE_KEY>` (ver el
// reporte, bloque "Database Webhook") — el gateway de Edge Functions ya
// verifica ese JWT antes de que este código corra, así que no hace falta
// validar nada de autenticación acá adentro.
//
// Filtro de tipos "importantes": no todos los `tipo` de `notificaciones`
// justifican una interrupción con push — `gasto_tarjeta`/`ingreso_recibido`
// (Fase 69) se excluyen a propósito (son automáticos y frecuentes, un
// push por cada uno sería ruido) mientras que los que implican una
// acción social o una fecha límite sí lo justifican.
//
// Deploy (requiere Supabase CLI, no se puede hacer desde este entorno):
//   supabase functions deploy enviar-push
// Requiere el secreto FIREBASE_SERVICE_ACCOUNT (ver el reporte de esta
// fase, bloque "Secreto de la cuenta de servicio") — sin él, la función
// responde 500 en vez de intentar enviar nada.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const TIPOS_IMPORTANTES = new Set([
  'solicitud_recibida',
  'solicitud_aceptada',
  'deuda_vinculada',
  'deuda_pagada',
  'deuda_amigo_pagada',
  'pago_deuda_amigo',
  'cuota_por_vencer',
  'cuota_vencida',
]);

const SCOPE_FCM = 'https://www.googleapis.com/auth/firebase.messaging';

interface FilaNotificacion {
  id: string;
  usuario_id: string;
  tipo: string;
  mensaje: string;
  data: Record<string, unknown> | null;
  leida: boolean;
  created_at: string;
}

// Payload real de un Database Webhook de Supabase — `record` trae la fila
// completa recién insertada, con los mismos nombres de columna que el
// esquema real (verificados contra `notificacion_repository_supabase.dart`,
// Fase 63/70).
interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  schema: string;
  record: FilaNotificacion;
  old_record: FilaNotificacion | null;
}

// El JSON completo que Firebase Console entrega al generar la clave
// privada de una cuenta de servicio — solo se leen estos 3 campos, el
// resto del archivo (`type`, `token_uri`, etc.) no hace falta para armar
// el JWT de la Fase de autenticación de Google.
interface CuentaServicioFirebase {
  project_id: string;
  client_email: string;
  private_key: string;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Método no permitido' }, 405);
  }

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: 'Body inválido' }, 400);
  }

  // Nunca debería llegar así si el Webhook está configurado como pide el
  // reporte (solo `INSERT` en `notificaciones`) — pero si alguien lo
  // reconfigura después, responder 200 evita que Supabase reintente algo
  // que nunca va a cambiar de resultado.
  if (payload.type !== 'INSERT' || payload.table !== 'notificaciones') {
    return jsonResponse({ omitido: 'evento no manejado' }, 200);
  }

  const notificacion = payload.record;
  if (!TIPOS_IMPORTANTES.has(notificacion.tipo)) {
    return jsonResponse({ omitido: 'tipo no importante' }, 200);
  }

  const cuentaServicioJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!cuentaServicioJson) {
    return jsonResponse(
      { error: 'La función no tiene configurado FIREBASE_SERVICE_ACCOUNT' },
      500,
    );
  }

  let cuentaServicio: CuentaServicioFirebase;
  try {
    cuentaServicio = JSON.parse(cuentaServicioJson);
  } catch {
    return jsonResponse(
      { error: 'FIREBASE_SERVICE_ACCOUNT no es un JSON válido' },
      500,
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  // Cliente admin: el destinatario del push nunca es quien llama a esta
  // función (la llama el Webhook, no la app logueada de ese usuario) —
  // hace falta leer/borrar tokens de CUALQUIER usuario, sin pasar por RLS.
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: tokens, error: errorTokens } = await admin
    .from('tokens_dispositivo')
    .select('token')
    .eq('usuario_id', notificacion.usuario_id);

  if (errorTokens) {
    return jsonResponse({ error: errorTokens.message }, 500);
  }
  if (!tokens || tokens.length === 0) {
    return jsonResponse({ omitido: 'usuario sin tokens de push' }, 200);
  }

  let accessToken: string;
  try {
    accessToken = await obtenerAccessTokenFirebase(cuentaServicio);
  } catch (error) {
    return jsonResponse({ error: String(error) }, 502);
  }

  let enviados = 0;
  const tokensInvalidos: string[] = [];
  for (const fila of tokens) {
    const token = fila.token as string;
    const resultado = await enviarPushAToken(
      token,
      accessToken,
      cuentaServicio.project_id,
      notificacion,
    );
    if (resultado === 'enviado') enviados++;
    if (resultado === 'token_invalido') tokensInvalidos.push(token);
  }

  // Fase 72.4 — un token "muerto" (app desinstalada, token expirado o mal
  // formado) nunca se arregla solo con reintentar; se borra para no
  // seguir gastando envíos futuros en él en cada notificación siguiente.
  if (tokensInvalidos.length > 0) {
    await admin.from('tokens_dispositivo').delete().in('token', tokensInvalidos);
  }

  return jsonResponse(
    { enviados, tokensEliminados: tokensInvalidos.length },
    200,
  );
});

function base64UrlEncode(data: ArrayBuffer | string): string {
  const bytes =
    typeof data === 'string'
      ? new TextEncoder().encode(data)
      : new Uint8Array(data);
  let binario = '';
  for (const byte of bytes) binario += String.fromCharCode(byte);
  return btoa(binario).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemAClavePrivada(pem: string): ArrayBuffer {
  const base64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binario = atob(base64);
  const bytes = new Uint8Array(binario.length);
  for (let i = 0; i < binario.length; i++) bytes[i] = binario.charCodeAt(i);
  return bytes.buffer;
}

/// Flujo "JWT Bearer Token" de Google (RFC 7523) para autenticarse como la
/// cuenta de servicio sin ninguna librería externa (Deno trae Web Crypto
/// nativo, suficiente para firmar RS256): arma un JWT con la clave privada
/// del secreto `FIREBASE_SERVICE_ACCOUNT` y lo canjea por un access token
/// de OAuth2 con permiso de enviar mensajes de FCM. Válido 1 hora — como
/// esta función se invoca una vez por notificación importante (no hay
/// tráfico alto), pedir uno nuevo en cada invocación es más simple que
/// cachearlo entre invocaciones (que además, en Edge Functions, no
/// comparten memoria de forma confiable entre una y otra).
async function obtenerAccessTokenFirebase(
  cuentaServicio: CuentaServicioFirebase,
): Promise<string> {
  const ahora = Math.floor(Date.now() / 1000);
  const encabezado = base64UrlEncode(
    JSON.stringify({ alg: 'RS256', typ: 'JWT' }),
  );
  const claims = base64UrlEncode(
    JSON.stringify({
      iss: cuentaServicio.client_email,
      scope: SCOPE_FCM,
      aud: 'https://oauth2.googleapis.com/token',
      iat: ahora,
      exp: ahora + 3600,
    }),
  );
  const entrada = `${encabezado}.${claims}`;

  const clavePrivada = await crypto.subtle.importKey(
    'pkcs8',
    pemAClavePrivada(cuentaServicio.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const firma = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    clavePrivada,
    new TextEncoder().encode(entrada),
  );
  const jwt = `${entrada}.${base64UrlEncode(firma)}`;

  const respuesta = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!respuesta.ok) {
    const cuerpo = await respuesta.text();
    throw new Error(`Google OAuth respondió ${respuesta.status}: ${cuerpo}`);
  }

  const json = await respuesta.json();
  if (!json.access_token) {
    throw new Error('Google OAuth no devolvió access_token');
  }
  return json.access_token as string;
}

type ResultadoEnvio = 'enviado' | 'token_invalido' | 'error';

/// Manda un mensaje a UN token vía la API HTTP v1 de FCM. `data` viaja
/// junto a `notification` para que el cliente (`MensajePush.data`, Fase
/// 71) tenga de dónde leer `tipo`/`notificacion_id` el día que valga la
/// pena enrutar a una pantalla más específica que `NotificacionesScreen`
/// — hoy el cliente no lo usa todavía, pero mandarlo ya no cuesta nada.
async function enviarPushAToken(
  token: string,
  accessToken: string,
  projectId: string,
  notificacion: FilaNotificacion,
): Promise<ResultadoEnvio> {
  const respuesta = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: 'Finzo', body: notificacion.mensaje },
          data: {
            tipo: notificacion.tipo,
            notificacion_id: notificacion.id,
          },
        },
      }),
    },
  );

  if (respuesta.ok) return 'enviado';

  const cuerpoError = await respuesta.json().catch(() => null);
  const detalle = cuerpoError?.error?.details?.find(
    (d: { errorCode?: string }) => d.errorCode,
  );
  const codigoError: string | undefined =
    detalle?.errorCode ?? cuerpoError?.error?.status;

  if (codigoError === 'UNREGISTERED' || codigoError === 'INVALID_ARGUMENT') {
    return 'token_invalido';
  }

  console.error(`FCM respondió ${respuesta.status} para un token:`, cuerpoError);
  return 'error';
}
