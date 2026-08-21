import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/config/supabase_config.dart';

/// Fase 54: `authEmailRedirectUrl` (usado como `emailRedirectTo` al crear
/// una cuenta) solo funciona si su esquema está registrado tanto en
/// `Info.plist` (iOS) como en `AndroidManifest.xml` (Android) — un typo en
/// cualquiera de los 3 lugares rompe el deep link en silencio (el correo
/// de confirmación llega, pero tocarlo no vuelve a abrir la app). No hay
/// forma de probar el flujo real (necesita el SO abriendo el link), pero
/// sí que los 3 archivos estén de acuerdo en el mismo esquema.
void main() {
  final esquema = Uri.parse(authEmailRedirectUrl).scheme;

  test('authEmailRedirectUrl tiene un esquema custom no vacío', () {
    expect(esquema, isNotEmpty);
    expect(authEmailRedirectUrl, 'finzo://login-callback');
  });

  test('el esquema está registrado en ios/Runner/Info.plist', () {
    final contenido = File('ios/Runner/Info.plist').readAsStringSync();
    expect(contenido, contains('<string>$esquema</string>'));
    expect(contenido, contains('CFBundleURLSchemes'));
  });

  test(
    'el esquema está registrado en android/app/src/main/AndroidManifest.xml',
    () {
      final contenido = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(contenido, contains('android:scheme="$esquema"'));
    },
  );
}
