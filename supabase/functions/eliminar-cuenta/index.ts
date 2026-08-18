// Edge Function: eliminar-cuenta
//
// Por qué existe (Fase 22, requisito de Apple — Guideline 5.1.1(v)):
// el SDK `supabase_flutter` no expone ninguna forma de que un usuario
// borre su propia cuenta de autenticación desde el cliente — borrar un
// usuario de Supabase Auth requiere la Admin API (`auth.admin.deleteUser`),
// que solo funciona con la service role key. Esa key nunca debe viajar al
// dispositivo del usuario (le daría acceso admin a toda la base de datos),
// así que el borrado tiene que correr server-side. Esta función es ese
// servidor: un Edge Function con la service role key como variable de
// entorno, invocado por la app ya autenticada (`SupabaseAuthRepository.
// eliminarCuenta`, en `lib/infrastructure/auth/supabase_auth_repository.dart`).
//
// Seguridad: la función nunca acepta un id de usuario en el body. El único
// usuario que se puede borrar es el dueño del JWT que llega en el header
// `Authorization` — se valida ese JWT contra Supabase Auth antes de tocar
// la Admin API, así que un usuario nunca puede borrar la cuenta de otro
// aunque intente mandar un id distinto.
//
// Nota de orden: la app llama a esta función DESPUÉS de borrar todos los
// datos financieros del usuario (`EliminarCuentaDeUsuario`, en
// `lib/domain/usecases/eliminar_cuenta_de_usuario.dart`) — mientras la
// cuenta de auth siga viva, RLS sigue autorizando esos borrados.
//
// Deploy (requiere Supabase CLI, no se puede hacer desde este entorno):
//   supabase functions deploy eliminar-cuenta
// La service role key ya está disponible automáticamente como
// SUPABASE_SERVICE_ROLE_KEY en el entorno de Edge Functions — no hace
// falta configurarla a mano.

import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Método no permitido' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: 'Falta el header Authorization' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Cliente "de usuario": solo sirve para validar el JWT que mandó la app
  // y saber a quién pertenece. Nunca usa la service role key.
  const clienteUsuario = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: errorUsuario,
  } = await clienteUsuario.auth.getUser();

  if (errorUsuario || !user) {
    return new Response(JSON.stringify({ error: 'Sesión inválida' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Cliente admin: la única parte de este archivo con permiso para borrar
  // usuarios. Solo se usa con el id que acabamos de validar arriba, nunca
  // con un id que mande el cuerpo de la petición.
  const clienteAdmin = createClient(supabaseUrl, serviceRoleKey);
  const { error: errorBorrado } = await clienteAdmin.auth.admin.deleteUser(
    user.id,
  );

  if (errorBorrado) {
    return new Response(JSON.stringify({ error: errorBorrado.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
