// Edge Function: capturar-transaccion
//
// Por qué existe (Fase 25 — primera pieza de la Etapa 3, captura
// automática): recibe texto crudo desde fuera de la app (un Atajo de iOS
// disparado por una notificación de Apple Pay, o una regla de reenvío de
// correo para Yape/Plin) y lo convierte en una `Transaccion` real, sin que
// el usuario tenga que abrir la app ni tocar nada. Todavía no existe el
// Atajo de iOS ni el Worker que reenvía los correos — esta función es el
// "cerebro" receptor que ambos, cuando se construyan, van a llamar. Ver
// "Captura automática — Etapa 3 en progreso" en `CONTEXTO.md`.
//
// Autenticación: quien llama NO es la app logueada (no hay sesión de
// Supabase Auth ahí) — es un Atajo o un Worker externo. Por eso, a
// diferencia de `eliminar-cuenta`/`generar-consejos` (que verifican el JWT
// del header `Authorization`), esta función identifica al usuario por un
// token opaco de un solo campo (`token_webhook` en `usuarios`), que la app
// le muestra en "Mi perfil → Automatización" para que lo copie a su Atajo.
// El token viaja como query param en la URL que se le da al usuario
// (`?token=...`) o, si el llamador arma un body JSON, como campo `token`
// — se acepta cualquiera de las dos formas, la URL solo por comodidad de
// configuración en herramientas que no dejan armar un body a mano.
//
// Si el token no matchea ningún usuario, responde 401 sin decir si el
// problema es "token no existe" o cualquier otra cosa — no hay que darle
// pistas a quien intente adivinar tokens ajenos.
//
// Deploy (requiere Supabase CLI, no se puede hacer desde este entorno):
//   supabase functions deploy capturar-transaccion
// Usa el mismo secreto GEMINI_API_KEY que `generar-consejos` (Fase 24) —
// si ya lo configuraste ahí, no hace falta volver a hacerlo.

import { createClient } from 'jsr:@supabase/supabase-js@2';

// Fase 28: mismo modelo deprecado que `generar-consejos` — ver la nota
// ahí sobre el mensaje de error de Google que motivó el cambio.
const MODELO = 'gemini-3.6-flash';
// Fase 26: el `CHECK` real de `transacciones.moneda`/`cuentas.moneda`
// exige 'PEN'/'USD' en MAYÚSCULAS (confirmado consultando el esquema real
// vía `supabase db query --linked` contra `pg_constraint`) — no
// `Moneda.pen.name` en minúscula, que es lo que este archivo mandaba
// antes de esta fase y hacía fallar tanto el filtro de cuenta como el
// insert de la transacción.
const MONEDA_POR_DEFECTO = 'PEN';

type Fuente = 'webhook_atajo' | 'correo_ios';

interface BodyCaptura {
  token?: string;
  textoCrudo: string;
  fuente: Fuente;
}

interface ClasificacionGemini {
  tipo: 'ingreso' | 'gasto';
  monto: number;
  categoria_sugerida: string;
  concepto: string;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// Fase 26: el `CHECK` real de `transacciones.fuente_captura` usa
// snake_case ('notificacion_android', 'correo_ios', 'ocr_ios', 'ajuste';
// ver `lib/infrastructure/persistence/supabase/enum_mapeo_supabase.dart`
// para el mapeo completo del lado Dart) — nunca el nombre del enum de
// Dart tal cual (`webhookAtajo`, `correoIOS`), que es lo que esta función
// mandaba antes de esta fase. `'webhook_atajo'` específicamente todavía
// no está en ese `CHECK` en la base real — falta correr el `ALTER TABLE`
// documentado en el reporte de la Fase 26 antes de que una captura vía
// Atajo pueda insertarse con éxito.
function fuenteCapturaDominio(fuente: Fuente): string {
  return fuente === 'webhook_atajo' ? 'webhook_atajo' : 'correo_ios';
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Método no permitido' }, 405);
  }

  let body: BodyCaptura;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Body inválido' }, 400);
  }

  const url = new URL(req.url);
  const token = url.searchParams.get('token') ?? body.token;
  if (!token || !body.textoCrudo || !body.fuente) {
    return jsonResponse(
      { error: 'Faltan campos: token, textoCrudo, fuente' },
      400,
    );
  }
  if (body.fuente !== 'webhook_atajo' && body.fuente !== 'correo_ios') {
    return jsonResponse({ error: 'fuente inválida' }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const geminiApiKey = Deno.env.get('GEMINI_API_KEY');

  // Único cliente de este archivo: siempre con la service role key. No hay
  // sesión de usuario que validar (ver nota de autenticación arriba) — el
  // "login" acá ES encontrar la fila de `usuarios` con este token.
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: usuario, error: errorUsuario } = await admin
    .from('usuarios')
    .select('id')
    .eq('token_webhook', token)
    .maybeSingle();

  if (errorUsuario) {
    return jsonResponse({ error: errorUsuario.message }, 500);
  }
  if (!usuario) {
    // Mismo status que "token con formato válido pero de nadie" — no se
    // distingue el motivo en la respuesta.
    return jsonResponse({ error: 'No autorizado' }, 401);
  }
  const userId = usuario.id as string;

  if (!geminiApiKey) {
    return jsonResponse(
      { error: 'La función no tiene configurado GEMINI_API_KEY' },
      500,
    );
  }

  let clasificacion: ClasificacionGemini;
  try {
    clasificacion = await clasificarConGemini(body.textoCrudo, geminiApiKey);
  } catch (error) {
    return jsonResponse({ error: String(error) }, 502);
  }

  // Categoría: por nombre sugerido por Gemini, dentro de las del usuario
  // (propias + predeterminadas); si no hay match, cae a la predeterminada
  // "Otros gastos"/"Otros ingresos" según el tipo — nunca falla por no
  // encontrar categoría, solo si ni siquiera esas dos predeterminadas
  // existen (no debería pasar, están sembradas server-side).
  const nombreFallback =
    clasificacion.tipo === 'gasto' ? 'Otros gastos' : 'Otros ingresos';
  const { data: categorias, error: errorCategorias } = await admin
    .from('categorias')
    .select('id, nombre, tipo, es_predeterminada, user_id')
    .eq('tipo', clasificacion.tipo)
    .or(`user_id.eq.${userId},user_id.is.null`);

  if (errorCategorias) {
    return jsonResponse({ error: errorCategorias.message }, 500);
  }

  const categoriaSugeridaLower = clasificacion.categoria_sugerida
    .trim()
    .toLowerCase();
  const categoria =
    (categorias ?? []).find(
      (c) => c.nombre.toLowerCase() === categoriaSugeridaLower,
    ) ??
    (categorias ?? []).find(
      (c) => c.es_predeterminada && c.nombre === nombreFallback,
    );

  if (!categoria) {
    return jsonResponse(
      { error: `No se encontró la categoría "${nombreFallback}"` },
      500,
    );
  }

  // Cuenta destino: simplificación temporal (ver comentario largo en el
  // reporte de la Fase 25) — de momento no hay forma de que el Atajo/correo
  // especifique con qué medio se pagó, así que se usa la primera cuenta
  // del usuario en la moneda por defecto (PEN). Si no tiene ninguna, se
  // corta acá con un error claro en vez de adivinar.
  const { data: cuenta, error: errorCuenta } = await admin
    .from('cuentas')
    .select('id, saldo_actual')
    .eq('user_id', userId)
    .eq('moneda', MONEDA_POR_DEFECTO)
    .limit(1)
    .maybeSingle();

  if (errorCuenta) {
    return jsonResponse({ error: errorCuenta.message }, 500);
  }
  if (!cuenta) {
    return jsonResponse(
      {
        error:
          `No tienes ninguna cuenta en ${MONEDA_POR_DEFECTO.toUpperCase()} ` +
          'para recibir esta captura automática.',
      },
      422,
    );
  }

  const nuevaTransaccion = {
    id: crypto.randomUUID(),
    user_id: userId,
    cuenta_id: cuenta.id,
    categoria_id: categoria.id,
    monto: clasificacion.monto,
    moneda: MONEDA_POR_DEFECTO,
    tipo: clasificacion.tipo,
    concepto: clasificacion.concepto,
    // No hay forma de saber el método real de pago solo del texto
    // capturado (ni Gemini lo devuelve, ver `ClasificacionGemini`) —
    // 'otro' es honesto en vez de adivinar 'tarjeta'/'yape' al voleo.
    metodo_pago: 'otro',
    es_recurrente: false,
    comprobante_url: null,
    fuente_captura: fuenteCapturaDominio(body.fuente),
    data_raw: body.textoCrudo,
    fecha: new Date().toISOString(),
  };

  const { error: errorInsert } = await admin
    .from('transacciones')
    .insert(nuevaTransaccion);

  if (errorInsert) {
    return jsonResponse({ error: errorInsert.message }, 500);
  }

  // `saldo_actual` es una caché derivada (ver `CONTEXTO.md` §3) que
  // normalmente actualiza `RegistrarGasto`/`RegistrarIngreso` del lado de
  // Dart — como esta función inserta directo por SQL sin pasar por esos
  // casos de uso, tiene que replicar esa misma actualización a mano. Si
  // falla, se borra la transacción recién creada en vez de dejarla
  // huérfana con el saldo desincronizado ("sin dejar la transacción a
  // medias", como pide el encargo de la Fase 25).
  const delta =
    clasificacion.tipo === 'ingreso' ? clasificacion.monto : -clasificacion.monto;
  const { error: errorSaldo } = await admin
    .from('cuentas')
    .update({ saldo_actual: (cuenta.saldo_actual as number) + delta })
    .eq('id', cuenta.id);

  if (errorSaldo) {
    await admin.from('transacciones').delete().eq('id', nuevaTransaccion.id);
    return jsonResponse(
      { error: 'No se pudo actualizar el saldo de la cuenta: ' + errorSaldo.message },
      500,
    );
  }

  return jsonResponse({ transaccion: nuevaTransaccion }, 200);
});

async function clasificarConGemini(
  textoCrudo: string,
  apiKey: string,
): Promise<ClasificacionGemini> {
  const uri =
    `https://generativelanguage.googleapis.com/v1beta/models/${MODELO}:generateContent` +
    `?key=${apiKey}`;

  const prompt =
    'Clasifica el siguiente texto de una notificación o correo de un ' +
    'medio de pago peruano (Apple Pay, Yape, Plin, etc.) como una única ' +
    'transacción financiera. Responde SOLO con un objeto JSON, sin texto ' +
    'adicional, con exactamente estas claves: "tipo" ("ingreso" o ' +
    '"gasto"), "monto" (número positivo, sin símbolo de moneda), ' +
    '"categoria_sugerida" (una palabra o frase corta como "Comida", ' +
    '"Transporte", "Sueldo", etc.), "concepto" (una descripción breve, ' +
    'sin datos sensibles como números de tarjeta o cuenta).\n\n' +
    `Texto:\n${textoCrudo}`;

  const respuesta = await fetch(uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: 'application/json' },
    }),
  });

  if (!respuesta.ok) {
    const cuerpo = await respuesta.text();
    throw new Error(`Gemini respondió ${respuesta.status}: ${cuerpo}`);
  }

  const json = await respuesta.json();
  const texto: string | undefined =
    json?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!texto) {
    throw new Error('Gemini no devolvió ninguna clasificación');
  }

  let parseado: unknown;
  try {
    parseado = JSON.parse(texto);
  } catch {
    throw new Error('Gemini devolvió un JSON inválido');
  }

  if (
    typeof parseado !== 'object' ||
    parseado === null ||
    !('tipo' in parseado) ||
    !('monto' in parseado) ||
    !('categoria_sugerida' in parseado) ||
    !('concepto' in parseado)
  ) {
    throw new Error('La clasificación de Gemini no tiene el formato esperado');
  }

  const clasificacion = parseado as ClasificacionGemini;
  if (clasificacion.tipo !== 'ingreso' && clasificacion.tipo !== 'gasto') {
    throw new Error('Gemini devolvió un "tipo" inválido');
  }
  if (typeof clasificacion.monto !== 'number' || clasificacion.monto <= 0) {
    throw new Error('Gemini devolvió un "monto" inválido');
  }

  return clasificacion;
}
