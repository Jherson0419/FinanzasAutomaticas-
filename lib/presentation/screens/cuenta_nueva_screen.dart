import 'package:flutter/material.dart';

import 'cuenta_formulario.dart';

class CuentaNuevaScreen extends StatelessWidget {
  const CuentaNuevaScreen({super.key, this.cuentaId});

  /// Si no es nulo, la pantalla abre en modo edición sobre esta cuenta.
  final String? cuentaId;

  @override
  Widget build(BuildContext context) {
    final editando = cuentaId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar cuenta' : 'Agregar cuenta'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CuentaFormulario(
              cuentaId: cuentaId,
              onGuardadoExitoso: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
