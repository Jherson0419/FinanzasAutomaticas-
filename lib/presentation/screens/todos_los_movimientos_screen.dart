import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'movimientos_cuenta_screen.dart';

/// Todas las transacciones registradas (`TransaccionRepository.obtenerTodas`),
/// ordenadas por fecha descendente, sin filtrar por cuenta. Enlazada desde
/// "Ver todos" en la sección de movimientos recientes del dashboard.
class TodosLosMovimientosScreen extends ConsumerWidget {
  const TodosLosMovimientosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaccionesAsync = ref.watch(todasLasTransaccionesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Todos los movimientos')),
      body: SafeArea(
        child: transaccionesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('No se pudieron cargar los movimientos.\n$error'),
          ),
          data: (transacciones) => ListaMovimientosTransaccion(
            transacciones: transacciones,
            mensajeVacio: 'Todavía no tienes movimientos registrados.',
          ),
        ),
      ),
    );
  }
}
