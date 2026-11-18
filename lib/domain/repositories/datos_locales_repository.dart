/// Puerto del modo local (Fase 78) — operaciones sobre la totalidad de los
/// datos guardados solo en este dispositivo (Drift + `SharedPreferences`
/// propios del modo local). No tiene equivalente en la nube: en Supabase,
/// borrar todo es `EliminarCuentaDeUsuario`.
abstract class DatosLocalesRepository {
  /// Borra los datos financieros locales (cuentas, transacciones, deudas,
  /// pagos y categorías propias — las predeterminadas se conservan) y el
  /// perfil/notificaciones del modo local. Tras esto, el onboarding vuelve
  /// a aparecer porque ya no hay nick guardado.
  Future<void> borrarTodo();
}
