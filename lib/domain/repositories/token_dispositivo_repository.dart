/// Puerto sobre `public.tokens_dispositivo` (Fase 71, SQL en el reporte).
/// Sin adapter Drift — igual que `AutomatizacionRepository`/
/// `AmistadRepository`, un token de push de "este dispositivo" no tiene
/// significado en modo local, solo existe una vez que hay sesión en la
/// nube.
abstract class TokenDispositivoRepository {
  /// Guarda el token de push del usuario actual — si el dispositivo ya
  /// tenía uno guardado (columna `token` única), lo actualiza en vez de
  /// duplicarlo, incluso si mientras tanto cambió de cuenta.
  Future<void> guardarToken({required String token, required String plataforma});

  /// Elimina la fila de este token — se llama al cerrar sesión, para no
  /// seguir mandándole push a alguien que ya salió de esa cuenta en ese
  /// dispositivo.
  Future<void> eliminarToken(String token);
}
