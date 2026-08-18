import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/categoria.dart';
import '../shared/category_icons.dart';
import '../shared/mensajes_error.dart';
import '../state/dashboard/dashboard_providers.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Formulario de categoría, reutilizado por [CategoriaNuevaScreen]
/// (crear/editar, según [categoriaId]) y por el modo rápido embebido en
/// `transaccion_nueva_screen.dart` (Fase 20.5, [tipoFijo] no nulo: solo
/// nombre + ícono, el tipo ya está implícito por el contexto del formulario
/// de transacción, así que el selector de tipo se oculta).
///
/// Las categorías predeterminadas nunca llegan a este formulario en modo
/// edición — `mis_categorias_screen.dart` no ofrece "Editar" para ellas, y
/// `EditarCategoria`/`EliminarCategoria` lo rechazarían de todos modos.
class CategoriaFormulario extends ConsumerStatefulWidget {
  const CategoriaFormulario({
    super.key,
    this.categoriaId,
    this.tipoFijo,
    required this.onGuardadoExitoso,
  });

  /// Si no es nulo, el formulario carga esa categoría y edita en vez de
  /// crear.
  final String? categoriaId;

  /// Modo rápido (Fase 20.5): fija el tipo y oculta su selector.
  final TipoCategoria? tipoFijo;

  /// Se invoca con la categoría creada/editada después de guardar con
  /// éxito — quien la use decide si navega, cierra un modal, o selecciona
  /// la categoría resultante en un dropdown.
  final ValueChanged<Categoria> onGuardadoExitoso;

  @override
  ConsumerState<CategoriaFormulario> createState() =>
      _CategoriaFormularioState();
}

class _CategoriaFormularioState extends ConsumerState<CategoriaFormulario> {
  final _nombreController = TextEditingController();

  TipoCategoria _tipo = TipoCategoria.gasto;
  String _iconName = categoriaIconNames.first;
  bool _guardando = false;
  bool _valoresPrecargados = false;

  bool get _editando => widget.categoriaId != null;

  @override
  void initState() {
    super.initState();
    if (widget.tipoFijo != null) _tipo = widget.tipoFijo!;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  bool get _esValido => _nombreController.text.trim().isNotEmpty;

  void _precargar(Categoria categoria) {
    if (_valoresPrecargados) return;
    _valoresPrecargados = true;
    _nombreController.text = categoria.nombre;
    _tipo = categoria.tipo;
    _iconName = categoria.iconName;
  }

  Future<void> _guardar() async {
    if (!_esValido) return;

    setState(() => _guardando = true);
    try {
      final Categoria resultado;
      if (_editando) {
        resultado = await ref.read(editarCategoriaProvider)(
          categoriaId: widget.categoriaId!,
          nombre: _nombreController.text.trim(),
          tipo: _tipo,
          iconName: _iconName,
        );
        ref.invalidate(categoriaPorIdProvider(widget.categoriaId!));
      } else {
        resultado = await ref.read(crearCategoriaProvider)(
          nombre: _nombreController.text.trim(),
          tipo: _tipo,
          iconName: _iconName,
        );
      }
      // `refresh` (no solo `invalidate`) y esperarlo importa: quien use
      // [onGuardadoExitoso] para preseleccionar la categoría recién creada
      // (modo rápido de `transaccion_nueva_screen.dart`) necesita que
      // `categoriasProvider` ya tenga el dato nuevo antes de que ese
      // callback dispare un `setState` — si no, el primer rebuild con la
      // lista todavía vieja borra la selección por no encontrarla.
      // ignore: unused_result — el valor no importa, solo que termine.
      await ref.refresh(categoriasProvider.future);
      ref.invalidate(resumenDashboardProvider);
      if (!mounted) return;
      widget.onGuardadoExitoso(resultado);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${mensajeDeError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoriaId != null) {
      final categoriaAsync = ref.watch(
        categoriaPorIdProvider(widget.categoriaId!),
      );
      return categoriaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('No se pudo cargar la categoría.\n$error')),
        data: (categoria) {
          if (categoria == null) {
            return const Center(child: Text('Esta categoría ya no existe.'));
          }
          _precargar(categoria);
          return _construirCampos(context);
        },
      );
    }
    return _construirCampos(context);
  }

  Widget _construirCampos(BuildContext context) {
    final theme = Theme.of(context);
    final tipoFijo = widget.tipoFijo != null;
    final tieneMovimientos = _editando
        ? (ref
                  .watch(transaccionesPorCategoriaProvider(widget.categoriaId!))
                  .valueOrNull
                  ?.isNotEmpty ??
              false)
        : false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (!tipoFijo) ...[
          const SizedBox(height: 16),
          SegmentedButton<TipoCategoria>(
            segments: const [
              ButtonSegment(
                value: TipoCategoria.gasto,
                label: Text('Gasto'),
                icon: Icon(Icons.remove_circle_outline),
              ),
              ButtonSegment(
                value: TipoCategoria.ingreso,
                label: Text('Ingreso'),
                icon: Icon(Icons.add_circle_outline),
              ),
            ],
            selected: {_tipo},
            onSelectionChanged: tieneMovimientos
                ? null
                : (seleccion) => setState(() => _tipo = seleccion.first),
          ),
          if (tieneMovimientos) ...[
            const SizedBox(height: 6),
            Text(
              'No se puede cambiar: esta categoría ya tiene movimientos.',
              style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
            ),
          ],
        ],
        const SizedBox(height: 20),
        Text('Ícono'.toUpperCase(), style: sectionLabelTextStyle),
        const SizedBox(height: 10),
        _SelectorIcono(
          seleccionado: _iconName,
          onSeleccionar: (nombre) => setState(() => _iconName = nombre),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: (_esValido && !_guardando) ? _guardar : null,
          child: _guardando
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Text(_editando ? 'Guardar cambios' : 'Guardar'),
        ),
      ],
    );
  }
}

/// Grid de íconos tocables (Fase 20.4) — nada de campo de texto libre.
class _SelectorIcono extends StatelessWidget {
  const _SelectorIcono({
    required this.seleccionado,
    required this.onSeleccionar,
  });

  final String seleccionado;
  final ValueChanged<String> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final nombre in categoriaIconNames)
          _IconoChip(
            nombre: nombre,
            seleccionado: nombre == seleccionado,
            onTap: () => onSeleccionar(nombre),
          ),
      ],
    );
  }
}

class _IconoChip extends StatelessWidget {
  const _IconoChip({
    required this.nombre,
    required this.seleccionado,
    required this.onTap,
  });

  final String nombre;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: seleccionado ? colorSuccess.withValues(alpha: 0.16) : bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado ? colorSuccess : borderCard,
            width: seleccionado ? 1.5 : 0.5,
          ),
        ),
        child: Icon(
          iconoParaCategoria(nombre),
          color: seleccionado ? colorSuccess : textSecondary,
          size: 22,
        ),
      ),
    );
  }
}
