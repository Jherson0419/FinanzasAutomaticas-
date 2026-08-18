import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/pin_hash.dart';

void main() {
  test('el mismo PIN siempre produce el mismo hash', () {
    expect(hashPin('1234'), hashPin('1234'));
  });

  test('PINs distintos producen hashes distintos', () {
    expect(hashPin('1234'), isNot(equals(hashPin('4321'))));
  });

  test('el hash nunca es el PIN en texto plano', () {
    expect(hashPin('1234'), isNot(equals('1234')));
  });
}
