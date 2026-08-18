import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/categoria.dart';
import '../../domain/entities/transaccion.dart';
import '../shared/category_icons.dart';
import '../shared/dashboard_colors.dart';
import '../shared/formatters.dart';
import '../state/providers.dart';

/// Todos los movimientos de una cuenta (sin el límite de 8 de
/// `MovimientosRecientesSection`), con el mismo estilo visual que esa
/// sección del dashboard.
class MovimientosCuentaScreen extends ConsumerWidget {
  const MovimientosCuentaScreen({super.key, required this.cuentaId});

  final String cuentaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaccionesAsync = ref.watch(
      transaccionesPorCuentaProvider(cuentaId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos de la cuenta')),
      body: SafeArea(
        child: transaccionesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('No se pudieron cargar los movimientos.\n$error'),
          ),
          data: (transacciones) => ListaMovimientosTransaccion(
            transacciones: transacciones,
            mensajeVacio:
                'Todavía no hay movimientos registrados en esta cuenta.',
          ),
        ),
      ),
    );
  }
}

/// Lista de movimientos (ordenados por fecha descendente) con el mismo
/// estilo visual en toda la app — usada por `MovimientosCuentaScreen`,
/// `todos_los_movimientos_screen.dart` y `MovimientosRecientesSection`.
class ListaMovimientosTransaccion extends ConsumerWidget {
  const ListaMovimientosTransaccion({
    super.key,
    required this.transacciones,
    required this.mensajeVacio,
  });

  final List<Transaccion> transacciones;
  final String mensajeVacio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (transacciones.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            mensajeVacio,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final ordenadas = [...transacciones]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final categoriasAsync = ref.watch(categoriasProvider);

    return categoriasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('No se pudieron cargar las categorías.\n$error')),
      data: (categorias) {
        final categoriasPorId = {
          for (final categoria in categorias) categoria.id: categoria,
        };
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final transaccion in ordenadas)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: FilaMovimientoTransaccion(
                  transaccion: transaccion,
                  categoria: categoriasPorId[transaccion.categoriaId],
                ),
              ),
          ],
        );
      },
    );
  }
}

class FilaMovimientoTransaccion extends StatelessWidget {
  const FilaMovimientoTransaccion({
    super.key,
    required this.transaccion,
    required this.categoria,
  });

  final Transaccion transaccion;
  final Categoria? categoria;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final esAjuste = transaccion.fuenteCaptura == FuenteCaptura.ajuste;

    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).pushNamed('/transacciones/nueva', arguments: transaccion.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurfaceVariant,
              child: Icon(
                esAjuste
                    ? Icons.tune
                    : iconoParaCategoria(categoria?.iconName ?? 'category'),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          transaccion.concepto.isEmpty
                              ? (categoria?.nombre ?? 'Sin categoría')
                              : transaccion.concepto,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (esAjuste) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Ajuste',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    formatearFecha(transaccion.fecha),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${transaccion.tipo == TipoTransaccion.ingreso ? '+' : '-'} ${formatearMonto(transaccion.monto, transaccion.moneda)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: transaccion.tipo == TipoTransaccion.ingreso
                    ? colorIngreso(context)
                    : colorGasto(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
