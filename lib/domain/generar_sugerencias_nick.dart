import 'dart:math';

/// Genera hasta 3 variaciones de nick a partir del nombre que el usuario ya
/// escribió en el paso anterior del onboarding (Fase 56) — normaliza a
/// minúsculas sin espacios/acentos/símbolos y agrega sufijos numéricos o un
/// guion bajo, para que sea probable que al menos una esté disponible
/// (`OnboardingNickStep` verifica cada una contra `nickDisponible` y solo
/// muestra las que de verdad lo están). Función pura, sin red — [random] es
/// inyectable para que los tests sean determinísticos; por defecto usa
/// `Random()` real.
///
/// Devuelve una lista vacía si [nombre] queda vacío tras normalizar (nada
/// de qué partir).
List<String> generarSugerenciasNick(String nombre, {Random? random}) {
  final base = _normalizar(nombre);
  if (base.isEmpty) return const [];

  final rng = random ?? Random();
  final candidatas = <String>{
    '$base${rng.nextInt(90) + 10}', // ej. jherson23
    '${base}_${rng.nextInt(90) + 10}', // ej. jherson_47
    '$base${rng.nextInt(900) + 100}', // ej. jherson871
  };

  return candidatas.map(_limitarA20).toList();
}

/// Solo la primera palabra (sin apellido separado en el formulario),
/// minúsculas, sin tildes/eñe, y solo `[a-z0-9]` — mismo alfabeto que exige
/// el formato de nick (`^[a-zA-Z0-9_]{3,20}$` en `OnboardingNickStep`).
String _normalizar(String nombre) {
  final primeraPalabra = nombre.trim().split(RegExp(r'\s+')).first;
  final sinAcentos = _quitarAcentos(primeraPalabra.toLowerCase());
  return sinAcentos.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

const _conAcento = 'áéíóúüñ';
const _sinAcento = 'aeiouun';

String _quitarAcentos(String texto) {
  var resultado = texto;
  for (var i = 0; i < _conAcento.length; i++) {
    resultado = resultado.replaceAll(_conAcento[i], _sinAcento[i]);
  }
  return resultado;
}

String _limitarA20(String nick) => nick.length > 20 ? nick.substring(0, 20) : nick;
