import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Salt fijo y simple — suficiente para este alcance (bloqueo local de la
/// app, no una credencial que proteja datos en un servidor). El PIN nunca
/// se guarda en texto plano, solo este hash.
const _salPin = 'finanzas_automaticas_pin_salt_v1';

/// Hash sha256 de un PIN, con salt. Usado tanto al guardar el PIN
/// (`ConfigurarBloqueoScreen`) como al verificarlo (`DesbloqueoScreen`) —
/// una única fuente de verdad para que ambos lados siempre coincidan.
String hashPin(String pin) {
  return sha256.convert(utf8.encode('$_salPin:$pin')).toString();
}
