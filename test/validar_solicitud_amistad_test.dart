import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/validar_solicitud_amistad.dart';

void main() {
  test('no lanza nada si los dos ids son distintos', () {
    expect(
      () => validarSolicitudAmistad(
        miUsuarioId: 'user-1',
        paraUsuarioId: 'user-2',
      ),
      returnsNormally,
    );
  });

  test('lanza ArgumentError si el usuario intenta enviarse una solicitud a sí mismo', () {
    expect(
      () => validarSolicitudAmistad(
        miUsuarioId: 'user-1',
        paraUsuarioId: 'user-1',
      ),
      throwsArgumentError,
    );
  });
}
