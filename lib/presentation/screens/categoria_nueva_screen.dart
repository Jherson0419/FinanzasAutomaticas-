import 'package:flutter/material.dart';

import 'categoria_formulario.dart';

class CategoriaNuevaScreen extends StatelessWidget {
  const CategoriaNuevaScreen({super.key, this.categoriaId});

  /// Si no es nulo, la pantalla abre en modo edición sobre esta categoría.
  final String? categoriaId;

  @override
  Widget build(BuildContext context) {
    final editando = categoriaId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar categoría' : 'Nueva categoría'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CategoriaFormulario(
              categoriaId: categoriaId,
              onGuardadoExitoso: (_) => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
