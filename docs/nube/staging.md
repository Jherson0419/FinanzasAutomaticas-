# Staging: un Supabase de pruebas para Finzo

Objetivo: probar la app en modo nube (Fases 78–87) contra un proyecto de
Supabase **que no es producción**, antes de tocar producción (Fase 89).

> Nada de esto se ejecutó desde el repositorio. Todos los pasos los hace
> el dueño del proyecto, con sus credenciales.

## 1. Crear el proyecto de pruebas

1. En <https://supabase.com/dashboard> → **New project**. Nombre sugerido:
   `finzo-staging`. Misma región que producción.
2. Guarda la contraseña de la base de datos en tu gestor de contraseñas
   (no en el repo).
3. Project Settings → **API**: copia la **Project URL** y la
   **publishable key** (`sb_publishable_…`). Son las que usará la app.
4. Authentication → URL Configuration → **Redirect URLs**: agrega
   `finzo://login-callback` y `finzo://reset-password` (los mismos que
   producción, ver `lib/config/supabase_config.dart`).

## 2. Obtener el esquema base

**El repositorio NO contiene el esquema base** (no hay ningún
`CREATE TABLE`; el archivo `schema_finanzas_v3.sql` que mencionan
`CONTEXTO.md`/`INFORME_PROYECTO.md` no está versionado). Solo están las
migraciones pendientes de las Fases 82–85 y las Edge Functions.

Hay que sacarlo de producción **en solo lectura** (es una lectura, no
cambia nada):

**Opción A — Supabase CLI (necesita Docker Desktop corriendo):**

```bash
supabase login
supabase link --project-ref <ref-de-produccion>
supabase db dump --linked -f supabase/esquema_base.sql            # esquema
supabase db dump --linked --role-only -f supabase/roles.sql        # roles (opcional)
```

`supabase db dump` usa `pg_dump` dentro de un contenedor: sin Docker
falla.

**Opción B — sin Docker, con `pg_dump` (PostgreSQL 15+ instalado):**

```bash
pg_dump "postgresql://postgres:<CONTRASEÑA>@db.<ref>.supabase.co:5432/postgres" \
  --schema-only --schema=public --no-owner --no-privileges \
  -f supabase/esquema_base.sql
```

Revisa el archivo antes de versionarlo: no debe llevar datos ni
contraseñas (`--schema-only` no exporta filas).

**Lo que el volcado NO trae** y hay que repetir a mano en staging:

- Buckets de Storage (p. ej. el de avatares de la Fase 56) y sus políticas.
- La publicación de Realtime para `transacciones` y `notificaciones`
  (Database → Replication).
- Ajustes de Auth (proveedor de Google, plantillas de correo, Redirect URLs).
- Secretos de las Edge Functions (`supabase secrets list` en producción
  para ver los NOMBRES; los valores se cargan con `supabase secrets set`).

## 3. Aplicar el SQL en orden

Con el SQL Editor de **staging** (o `psql` contra staging):

1. `supabase/esquema_base.sql` (el volcado del paso 2).
2. Las migraciones pendientes, en el orden de
   [`supabase/migraciones_pendientes/LEEME_orden.md`](../../supabase/migraciones_pendientes/LEEME_orden.md):
   `fase82` → `fase83` → `fase84` → `fase84b` → `fase85` → `fase89`
   (la 89 reescribe los triggers; antes de correrla, respalda las
   funciones originales en `supabase/respaldo/`).
3. Las consultas de verificación de cada archivo (están al final de cada
   uno y resumidas en el LEEME).
4. Las pruebas manuales de [`checklist_staging.md`](checklist_staging.md).

Todos los archivos se pueden repetir: si algo falla a mitad, corrige y
vuelve a correr el mismo archivo.

## 4. Ejecutar la app contra staging

La URL y la clave se inyectan al compilar (Fase 88); **no hace falta
tocar ningún entry point**.

1. Crea `config/staging.json` (está en `.gitignore`, nunca se sube):

   ```json
   {
     "SUPABASE_URL": "https://<ref-staging>.supabase.co",
     "SUPABASE_ANON_KEY": "sb_publishable_<clave de staging>",
     "FINZO_ENTORNO": "staging"
   }
   ```

2. Ejecuta:

   ```bash
   flutter run --dart-define-from-file=config/staging.json
   ```

   Sin ese archivo (o sin `--dart-define`), la app usa los valores de
   siempre, es decir, **producción**. Siempre declara `FINZO_ENTORNO`: si
   pasas URL/clave sin él, `configuracionSupabaseIncoherente` queda en
   `true` (útil para detectar el error).

3. Para probar la migración local → nube: entra en modo local
   (`lib/main_local.dart`), carga los datos de ejemplo, y luego usa
   "Migrar mis datos a la nube" en la app compilada contra staging.

## 5. Antes de pasar a producción (Fase 89)

- [ ] Todas las migraciones aplicadas y verificadas en staging.
- [ ] Revisados los triggers listados en el LEEME (sección "Triggers").
- [ ] Migración local → nube probada con los datos de ejemplo.
- [ ] `generar-consejos` desplegada en staging y probada (ver
      [`despliegue.md`](despliegue.md)).
