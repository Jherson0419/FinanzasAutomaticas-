// Edge Function: generar-consejos
//
// Reescrita en la Fase 30: pasó de "un solo turno" (recibía un resumen,
// devolvía una lista de 3-5 consejos, sin memoria) a un chat real con
// historial persistente (`public.mensajes_consejos`). El modelo de API key
// (Fase 24 — vive solo aquí, como secreto de esta función, nunca en el
// dispositivo del usuario) y el límite diario (Fase 24, tabla
// `uso_consejos`) no cambiaron de fondo, solo qué representa el contador:
// antes eran "generaciones", ahora son mensajes enviados por el usuario
// (cada turno de ida y vuelta cuenta 1, sin importar si es el primer
// mensaje automático o uno de seguimiento escrito a mano).
//
// El cliente (`EdgeFunctionConsejosRepository`, en
// `lib/infrastructure/consejos/edge_function_consejos_repository.dart`)
// manda `{ mensaje, esPrimerMensaje, resumen? }`. Cuando `esPrimerMensaje`
// es `true`, `resumen` es obligatorio y el contenido real del primer
// mensaje de usuario lo arma esta función (agregado y anonimizado, mismo
// criterio de la Fase 24) — `mensaje` se ignora en ese caso.
//
// Mismo patrón de autenticación que `eliminar-cuenta` (Fase 22): el
// usuario se identifica por el JWT del header `Authorization`, nunca por un
// id que mande el body.
//
// Deploy (requiere Supabase CLI, no se puede hacer desde este entorno):
//   supabase functions deploy generar-consejos

import { createClient } from 'jsr:@supabase/supabase-js@2';

const LIMITE_DIARIO = 15;
// Fase 28: 'gemini-2.0-flash' quedó deprecado del lado de Google
// ("This model models/gemini-2.0-flash is no longer available. Please
// update your code to use models/gemini-3.6-flash").
const MODELO = 'gemini-3.6-flash';

// No visible en el chat — define el rol del asistente para TODA la
// conversación, en cada llamada (Gemini no recuerda `systemInstruction`
// entre llamadas, así que se manda siempre junto con el historial).
const INSTRUCCION_SISTEMA =
  'Eres un asesor financiero experto para un usuario en Perú. Tu prioridad ' +
  'es ayudarlo a pagar sus deudas lo más rápido posible, luego sugerirle ' +
  'formas simples de ahorrar, y por último ideas simples de inversión. ' +
  'Responde siempre en español, con un tono cercano y conversacional (como ' +
  'un asesor de confianza, no un documento formal), en mensajes breves y ' +
  'concretos. No uses markdown. No repitas datos que el usuario ya te dio ' +
  'salvo que ayude a tu respuesta. El monto usado de una tarjeta de ' +
  'crédito es una deuda, nunca sugieras usarlo como fuente de dinero para ' +
  'pagar otras deudas u otros gastos — solo se puede usar crédito ' +
  'disponible para nuevas compras, nunca para pagar deudas existentes.';

interface DeudaParaConsejos {
  tipoDeuda: string;
  montoTotal: number;
  montoPagado: number;
  interesTotal: number | null;
  moneda: string;
}

interface CategoriaMontoConsejo {
  categoriaNombre: string;
  monto: number;
  moneda: string;
}

// Fase 60: el monto usado de una tarjeta es una deuda propia, nunca dinero
// disponible — se reporta aparte de `saldoTotalPorMoneda` (que ya viene sin
// cuentas de crédito desde el cliente, ver `ArmarResumenParaConsejos`).
interface TarjetaCreditoParaConsejos {
  montoUsado: number;
  lineaTotal: number;
  creditoDisponible: number;
  moneda: string;
}

interface ResumenParaConsejos {
  deudasActivas: DeudaParaConsejos[];
  ingresosPorCategoriaMes: CategoriaMontoConsejo[];
  gastosPorCategoriaMes: CategoriaMontoConsejo[];
  saldoTotalPorMoneda: Record<string, number>;
  tarjetasCredito?: TarjetaCreditoParaConsejos[];
}

interface BodyPeticion {
  mensaje: string;
  esPrimerMensaje: boolean;
  resumen?: ResumenParaConsejos;
}

interface FilaMensaje {
  rol: 'usuario' | 'asistente';
  contenido: string;
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

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Falta el header Authorization' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const geminiApiKey = Deno.env.get('GEMINI_API_KEY');

  // Cliente "de usuario": valida el JWT, sabe a quién pertenece, y respeta
  // RLS — suficiente para leer `mensajes_consejos` (hay política de SELECT
  // para el dueño de la fila).
  const clienteUsuario = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: errorUsuario,
  } = await clienteUsuario.auth.getUser();

  if (errorUsuario || !user) {
    return jsonResponse({ error: 'Sesión inválida' }, 401);
  }

  let body: BodyPeticion;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Body inválido' }, 400);
  }

  if (body.esPrimerMensaje && !body.resumen) {
    return jsonResponse(
      { error: 'Falta "resumen" para el primer mensaje' },
      400,
    );
  }
  if (!body.esPrimerMensaje && (!body.mensaje || !body.mensaje.trim())) {
    return jsonResponse({ error: 'Falta "mensaje"' }, 400);
  }

  // Cliente admin: la única parte de este archivo con permiso para
  // escribir `uso_consejos` y `mensajes_consejos` — ninguna de las dos
  // tiene política de INSERT/UPDATE para el cliente.
  const clienteAdmin = createClient(supabaseUrl, serviceRoleKey);
  // Fecha en formato YYYY-MM-DD, asumiendo que la base de datos usa UTC
  // (default de Supabase) para `CURRENT_DATE` — mismo criterio en ambos
  // lados para que la fila de hoy siempre calce.
  const hoy = new Date().toISOString().slice(0, 10);

  const { data: filaExistente, error: errorLectura } = await clienteAdmin
    .from('uso_consejos')
    .select('conteo')
    .eq('user_id', user.id)
    .eq('fecha', hoy)
    .maybeSingle();

  if (errorLectura) {
    return jsonResponse({ error: errorLectura.message }, 500);
  }

  const conteoActual = filaExistente?.conteo ?? 0;
  if (conteoActual >= LIMITE_DIARIO) {
    return jsonResponse({ error: 'limite_diario_alcanzado' }, 429);
  }

  const { error: errorEscrituraConteo } = filaExistente
    ? await clienteAdmin
        .from('uso_consejos')
        .update({ conteo: conteoActual + 1 })
        .eq('user_id', user.id)
        .eq('fecha', hoy)
    : await clienteAdmin
        .from('uso_consejos')
        .insert({ user_id: user.id, fecha: hoy, conteo: 1 });

  if (errorEscrituraConteo) {
    return jsonResponse({ error: errorEscrituraConteo.message }, 500);
  }

  if (!geminiApiKey) {
    return jsonResponse(
      { error: 'La función no tiene configurado GEMINI_API_KEY' },
      500,
    );
  }

  // Historial existente, ordenado por fecha — con el cliente "de usuario"
  // (RLS ya lo limita al dueño), no con el admin.
  const { data: historialRows, error: errorHistorial } = await clienteUsuario
    .from('mensajes_consejos')
    .select('rol, contenido')
    .eq('user_id', user.id)
    .order('created_at', { ascending: true });

  if (errorHistorial) {
    return jsonResponse({ error: errorHistorial.message }, 500);
  }

  const contenidoUsuario = body.esPrimerMensaje
    ? construirPrimerMensaje(body.resumen!)
    : body.mensaje.trim();

  let respuestaTexto: string;
  try {
    respuestaTexto = await generarRespuestaConGemini(
      (historialRows ?? []) as FilaMensaje[],
      contenidoUsuario,
      geminiApiKey,
    );
  } catch (error) {
    // Nada se escribe en `mensajes_consejos` si Gemini falla — así nunca
    // queda un mensaje de usuario huérfano sin su respuesta.
    return jsonResponse({ error: String(error) }, 502);
  }

  // Los dos mensajes (usuario + asistente) se guardan juntos, en un solo
  // INSERT: o quedan los dos, o ninguno.
  const { error: errorGuardado } = await clienteAdmin
    .from('mensajes_consejos')
    .insert([
      { user_id: user.id, rol: 'usuario', contenido: contenidoUsuario },
      { user_id: user.id, rol: 'asistente', contenido: respuestaTexto },
    ]);

  if (errorGuardado) {
    return jsonResponse({ error: errorGuardado.message }, 500);
  }

  return jsonResponse({ respuesta: respuestaTexto }, 200);
});

/// Primer mensaje de usuario de una conversación nueva, armado a partir del
/// resumen agregado y anonimizado — mismo criterio de qué NO incluir que
/// `ResumenParaConsejos` ya tenía desde la Fase 24 (sin nombres de
/// acreedores ni de cuentas). Fraseado en primera persona porque es lo que
/// se guarda y se muestra como si el usuario lo hubiera escrito.
function construirPrimerMensaje(resumen: ResumenParaConsejos): string {
  const lineas: string[] = [
    'Hola, estas son mis deudas activas:',
  ];

  if (resumen.deudasActivas.length === 0) {
    lineas.push('- Ninguna');
  } else {
    for (const deuda of resumen.deudasActivas) {
      const pendiente = deuda.montoTotal - deuda.montoPagado;
      const interesTexto =
        deuda.interesTotal != null && deuda.interesTotal > 0
          ? `, interés total: ${deuda.interesTotal.toFixed(2)}`
          : '';
      lineas.push(
        `- Tipo: ${deuda.tipoDeuda}, pendiente: ${pendiente.toFixed(2)} ` +
          `${deuda.moneda.toUpperCase()}${interesTexto}`,
      );
    }
  }

  lineas.push('', 'Mis ingresos del mes por categoría:');
  escribirCategorias(lineas, resumen.ingresosPorCategoriaMes);
  lineas.push('', 'Mis gastos del mes por categoría:');
  escribirCategorias(lineas, resumen.gastosPorCategoriaMes);
  lineas.push('', 'Mi saldo total disponible (sin tarjetas de crédito):');

  const monedas = Object.keys(resumen.saldoTotalPorMoneda);
  if (monedas.length === 0) {
    lineas.push('- Ninguno');
  } else {
    for (const moneda of monedas) {
      lineas.push(
        `- ${resumen.saldoTotalPorMoneda[moneda].toFixed(2)} ` +
          `${moneda.toUpperCase()}`,
      );
    }
  }

  lineas.push('', 'Mis tarjetas de crédito (esto NO es dinero disponible, es deuda):');
  const tarjetas = resumen.tarjetasCredito ?? [];
  if (tarjetas.length === 0) {
    lineas.push('- Ninguna');
  } else {
    for (const tarjeta of tarjetas) {
      lineas.push(
        `- Usado: ${tarjeta.montoUsado.toFixed(2)} ${tarjeta.moneda.toUpperCase()} ` +
          `(deuda) de una línea de ${tarjeta.lineaTotal.toFixed(2)} ` +
          `${tarjeta.moneda.toUpperCase()}, crédito disponible: ` +
          `${tarjeta.creditoDisponible.toFixed(2)} ${tarjeta.moneda.toUpperCase()}`,
      );
    }
  }

  lineas.push(
    '',
    '¿Qué me recomiendas para pagar mis deudas más rápido y mejorar mis ' +
      'finanzas?',
  );

  return lineas.join('\n');
}

function escribirCategorias(
  lineas: string[],
  categorias: CategoriaMontoConsejo[],
): void {
  if (categorias.length === 0) {
    lineas.push('- Ninguno');
    return;
  }
  for (const c of categorias) {
    lineas.push(
      `- ${c.categoriaNombre}: ${c.monto.toFixed(2)} ${c.moneda.toUpperCase()}`,
    );
  }
}

/// Llama a Gemini en modo multi-turno: `contents` alterna `user`/`model`
/// con todo el historial ya guardado, más el mensaje nuevo al final;
/// `systemInstruction` define el rol del asistente sin aparecer como un
/// mensaje más del chat.
async function generarRespuestaConGemini(
  historial: FilaMensaje[],
  mensajeNuevo: string,
  apiKey: string,
): Promise<string> {
  const uri =
    `https://generativelanguage.googleapis.com/v1beta/models/${MODELO}:generateContent` +
    `?key=${apiKey}`;

  const contents = [
    ...historial.map((fila) => ({
      role: fila.rol === 'usuario' ? 'user' : 'model',
      parts: [{ text: fila.contenido }],
    })),
    { role: 'user', parts: [{ text: mensajeNuevo }] },
  ];

  const respuesta = await fetch(uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: INSTRUCCION_SISTEMA }] },
      contents,
    }),
  });

  if (!respuesta.ok) {
    const cuerpo = await respuesta.text();
    throw new Error(`Gemini respondió ${respuesta.status}: ${cuerpo}`);
  }

  const json = await respuesta.json();
  const texto: string | undefined =
    json?.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!texto || texto.trim().length === 0) {
    throw new Error('Gemini no devolvió ninguna respuesta');
  }

  return texto.trim();
}
