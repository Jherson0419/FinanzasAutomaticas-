import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/categoria.dart';
import '../shared/app_card.dart';
import '../shared/category_icons.dart';
import '../shared/dialogos_eliminar.dart';
import '../shared/section_label.dart';
import '../state/dashboard/dashboard_providers.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Catálogo de categorías (Fase 20): predeterminadas (solo lectura) y
/// propias del usuario (editables/eliminables), separadas en Gastos/
/// Ingresos.
class MisCategoriasScreen extends ConsumerWidget {
  const MisCategoriasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriasAsync = ref.watch(categoriasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis categorías')),
      body: SafeArea(
        child: categoriasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('No se pudieron cargar las categorías.\n$error'),
          ),
          data: (categorias) {
            final gastos =
                categorias.where((c) => c.tipo == TipoCategoria.gasto).toList()
                  ..sort(_comparar);
            final ingresos =
                categorias
                    .where((c) => c.tipo == TipoCategoria.ingreso)
                    .toList()
                  ..sort(_comparar);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/categorias/nueva'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva categoría'),
                ),
                const SizedBox(height: 20),
                _SeccionCategorias(
                  icono: Icons.remove_circle_outline,
                  titulo: 'Gastos',
                  categorias: gastos,
                ),
                const SizedBox(height: 16),
                _SeccionCategorias(
                  icono: Icons.add_circle_outline,
                  titulo: 'Ingresos',
                  categorias: ingresos,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

int _comparar(Categoria a, Categoria b) {
  if (a.esPredeterminada != b.esPredeterminada) {
    return a.esPredeterminada ? -1 : 1;
  }
  return a.nombre.compareTo(b.nombre);
}

class _SeccionCategorias extends StatelessWidget {
  const _SeccionCategorias({
    required this.icono,
    required this.titulo,
    required this.categorias,
  });

  final IconData icono;
  final String titulo;
  final List<Categoria> categorias;

  @override
  Widget build(BuildContext context) {
    final predeterminadas = categorias
        .where((c) => c.esPredeterminada)
        .toList();
    final propias = categorias.where((c) => !c.esPredeterminada).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(icon: icono, label: titulo),
          const SizedBox(height: 12),
          for (final categoria in predeterminadas)
            _FilaCategoria(categoria: categoria),
          if (propias.isNotEmpty) ...[
            Divider(height: 24, color: context.borderCard),
            for (final categoria in propias)
              _FilaCategoria(categoria: categoria),
          ],
        ],
      ),
    );
  }
}

class _FilaCategoria extends ConsumerWidget {
  const _FilaCategoria({required this.categoria});

  final Categoria categoria;

  Future<void> _eliminar(BuildContext context, WidgetRef ref) async {
    final confirmado = await confirmarEliminar(
      context,
      titulo: 'Eliminar categoría',
      mensaje:
          '¿Eliminar "${categoria.nombre}"? Esta acción no se puede deshacer.',
    );
    if (!confirmado) return;
    if (!context.mounted) return;

    try {
      await ref.read(eliminarCategoriaProvider)(categoriaId: categoria.id);
      ref.invalidate(categoriasProvider);
      ref.invalidate(resumenDashboardProvider);
    } catch (error) {
      if (!context.mounted) return;
      await mostrarErrorEliminar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (categoria.esPredeterminada) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              iconoParaCategoria(categoria.iconName),
              color: context.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(categoria.nombre, style: theme.textTheme.bodyMedium),
            ),
            Icon(Icons.lock_outline, color: context.textMuted, size: 16),
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(
        context,
      ).pushNamed('/categorias/nueva', arguments: categoria.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              iconoParaCategoria(categoria.iconName),
              color: colorSuccess,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(categoria.nombre, style: theme.textTheme.bodyMedium),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _eliminar(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
