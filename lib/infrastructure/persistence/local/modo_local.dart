/// Constantes compartidas por los adaptadores del modo local (Fase 78).
///
/// Todas las claves de `SharedPreferences` que escribe el modo local llevan
/// este prefijo: el modo local y la app de producción comparten
/// almacenamiento si se instalan con el mismo bundle id, y así "Borrar todos
/// los datos locales" puede limpiar exactamente lo suyo sin tocar las
/// preferencias de producción (`datos_en_la_nube`, `tema_app`,
/// `recordar_sesion`…).
const prefijoModoLocal = 'modo_local.';

/// Mensaje único para toda operación que solo existe con la nube.
const mensajeDisponibleConLaNube = 'Disponible con la nube';

/// Error que lanzan los adaptadores locales ante operaciones de nube.
UnsupportedError noDisponibleEnModoLocal([String? detalle]) => UnsupportedError(
  detalle == null
      ? 'No disponible en modo local. $mensajeDisponibleConLaNube.'
      : '$detalle — No disponible en modo local. '
            '$mensajeDisponibleConLaNube.',
);
