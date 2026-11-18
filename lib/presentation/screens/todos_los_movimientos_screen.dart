import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/categoria.dart';
import '../../domain/entities/cuenta.dart';
import '../../domain/entities/transaccion.dart';
import '../../domain/movimientos.dart';
import '../shared/app_bottom_bar.dart';
import '../shared/app_card.dart';
import '../shared/estilos.dart';
import '../shared/fila_movimiento.dart';
import '../shared/formatters.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Pestaña Movimientos (Fase 81, 02-movimientos.png): búsqueda, chips
/// Todo/Gastos/Ingresos, chip de mes, filtros por cuenta y categoría,
/// tarjeta "Gasto del mes" y lista agrupada por día con subtotal.
///
/// Toda la lógica (filtrar, agrupar, resumir) vive en
/// `domain/movimientos.dart` y tiene pruebas propias; esta pantalla solo
/// guarda el estado de los filtros y dibuja. Sigue usando
/// `TransaccionRepository.obtenerTodas()` (vía `todasLasTransaccionesProvider`).
class TodosLosMovimientosScreen extends ConsumerStatefulWidget {
  const TodosLosMovimientosScreen({super.key, this.ahora});

  /// Solo para pruebas: fija "hoy" (mes por defecto, Hoy/Ayer).
  final DateTime? ahora;

  @override
  ConsumerState<TodosLosMovimientosScreen> createState() =>
      _TodosLosMovimientosScreenState();
}

class _TodosLosMovimientosScreenState
    extends ConsumerState<TodosLosMovimientosScreen> {
  final _busqueda = TextEditingController();

  /// Chip de tipo. Fase 85: [TipoTransaccion.transferenciaSalida] es el
  /// chip "Transferencias" (filtra las dos caras, ver [_soloTransferencias]).
  TipoTransaccion? _tipo;

  bool get _soloTransferencias => _tipo?.esTransferencia ?? false;

  /// Mes seleccionado (día 1); `null` = "Todo el tiempo".
  late DateTime? _mes = DateTime(_ahora.year, _ahora.month);
  String? _cuentaId;
  String? _categoriaId;

  DateTime get _ahora => widget.ahora ?? DateTime.now();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  bool get _hayFiltrosDeBusqueda =>
      _busqueda.text.trim().isNotEmpty ||
      _tipo != null ||
      _cuentaId != null ||
      _categoriaId != null;

  void _limpiarFiltros() {
    setState(() {
      _busqueda.clear();
      _tipo = null;
      _cuentaId = null;
      _categoriaId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transaccionesAsync = ref.watch(todasLasTransaccionesProvider);
    final categorias =
        ref.watch(categoriasProvider).valueOrNull ?? const <Categoria>[];
    final cuentas = ref.watch(cuentasProvider).valueOrNull ?? const <Cuenta>[];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        title: Semantics(
          header: true,
          child: Text(
            'Movimientos',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: transaccionesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('No se pudieron cargar los movimientos.\n$error'),
          ),
          data: (transacciones) =>
              _contenido(context, transacciones, categorias, cuentas),
        ),
      ),
      // Destino "Movimientos" de la barra (Fase 80).
      bottomNavigationBar: const AppBottomBar(actual: AppBottomTab.movimientos),
    );
  }

  Widget _contenido(
    BuildContext context,
    List<Transaccion> transacciones,
    List<Categoria> categorias,
    List<Cuenta> cuentas,
  ) {
    final todos = detallarMovimientos(transacciones, categorias, cuentas);
    if (todos.isEmpty) {
      return const _EstadoVacio(
        icono: Icons.receipt_long_outlined,
        titulo: 'Todavía no tienes movimientos registrados.',
      );
    }

    final (desde, hasta) = _mes == null ? (null, null) : rangoDelMes(_mes!);
    final filtrados = filtrarMovimientos(
      todos,
      texto: _busqueda.text,
      tipo: _soloTransferencias ? null : _tipo,
      soloTransferencias: _soloTransferencias,
      desde: desde,
      hasta: hasta,
      cuentaId: _cuentaId,
      categoriaId: _categoriaId,
    );
    // "Gasto del mes" resume el periodo (y cuenta/categoría), no la
    // búsqueda ni el chip de tipo: así no se vacía al elegir "Ingresos".
    final gasto = resumenGastoPorCategoria(
      filtrarMovimientos(
        todos,
        desde: desde,
        hasta: hasta,
        cuentaId: _cuentaId,
        categoriaId: _categoriaId,
      ),
    );
    final grupos = agruparPorDia(filtrados, ahora: _ahora);
    // Fase 85: títulos "Transferencia a …" / "Transferencia desde …".
    final pares = cuentasDeTransferencias(transacciones);
    final nombreCuenta = {for (final c in cuentas) c.id: c.nombre};

    final items = <_Item>[
      for (final r in gasto) _ItemGasto(r),
      for (final g in grupos) ...[
        _ItemDia(g),
        for (var i = 0; i < g.movimientos.length; i++)
          _ItemFila(
            g.movimientos[i],
            ultimoDelGrupo: i == g.movimientos.length - 1,
          ),
      ],
    ];
    final primerDia = items.indexWhere((i) => i is _ItemDia);
    final mesesConDatos = _mesesConDatos(todos);

    return Column(
      children: [
        _barraBusqueda(context, cuentas, categorias),
        _chips(context, mesesConDatos),
        Expanded(
          child: filtrados.isEmpty && gasto.isEmpty
              ? _vacioFiltrado()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length + (filtrados.isEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= items.length) return _vacioFiltrado();
                    final item = items[index];
                    return switch (item) {
                      _ItemGasto(:final resumen) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TarjetaGasto(
                          resumen: resumen,
                          titulo: _mes == null
                              ? 'Gasto total'
                              : 'Gasto del mes',
                        ),
                      ),
                      _ItemDia(:final grupo) => _EncabezadoDia(
                        grupo: grupo,
                        ahora: _ahora,
                        primero: index == primerDia,
                      ),
                      _ItemFila(:final movimiento, :final ultimoDelGrupo) =>
                        _FilaEnTarjeta(
                          ultima: index == items.length - 1,
                          conDivisor: !ultimoDelGrupo,
                          child: FilaMovimiento(
                            transaccionId: movimiento.transaccion.id,
                            concepto: movimiento.transaccion.concepto,
                            categoriaNombre: movimiento.categoriaNombre,
                            categoriaIcono: movimiento.categoriaIcono,
                            cuentaNombre: movimiento.cuentaNombre,
                            monto: movimiento.transaccion.monto,
                            moneda: movimiento.transaccion.moneda,
                            esIngreso:
                                movimiento.transaccion.tipo ==
                                TipoTransaccion.ingreso,
                            esAjuste:
                                movimiento.transaccion.fuenteCaptura ==
                                FuenteCaptura.ajuste,
                            transferenciaId:
                                movimiento.transaccion.transferenciaId,
                            tituloTransferencia:
                                movimiento.transaccion.esTransferencia
                                ? tituloTransferencia(
                                    movimiento.transaccion,
                                    pares,
                                    nombreCuenta,
                                  )
                                : null,
                            // Con una cuenta elegida se ve si sale o entra;
                            // en "todas" la transferencia no cambia el total.
                            signoTransferencia: _cuentaId == null
                                ? 0
                                : movimiento.transaccion.tipo ==
                                      TipoTransaccion.transferenciaSalida
                                ? -1
                                : 1,
                          ),
                        ),
                    };
                  },
                ),
        ),
      ],
    );
  }

  List<DateTime> _mesesConDatos(List<MovimientoDetallado> todos) {
    final meses = {
      for (final m in todos)
        DateTime(m.transaccion.fecha.year, m.transaccion.fecha.month),
      DateTime(_ahora.year, _ahora.month),
    }.toList()..sort((a, b) => b.compareTo(a));
    return meses;
  }

  Widget _vacioFiltrado() {
    if (_hayFiltrosDeBusqueda) {
      final texto = _busqueda.text.trim();
      return _EstadoVacio(
        icono: Icons.search_off,
        titulo: 'Sin resultados',
        detalle: texto.isEmpty
            ? 'Ningún movimiento coincide con los filtros.'
            : 'No encontramos movimientos para «$texto».',
        accion: 'Limpiar filtros',
        onAccion: _limpiarFiltros,
      );
    }
    return _EstadoVacio(
      icono: Icons.event_busy_outlined,
      titulo: 'No hay movimientos en ${formatearMes(_mes!, ahora: _ahora)}',
      accion: 'Ver todo el tiempo',
      onAccion: () => setState(() => _mes = null),
    );
  }

  Widget _barraBusqueda(
    BuildContext context,
    List<Cuenta> cuentas,
    List<Categoria> categorias,
  ) {
    final activos =
        (_cuentaId != null ? 1 : 0) + (_categoriaId != null ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Buscar movimientos',
              textField: true,
              child: TextField(
                controller: _busqueda,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar por concepto o categoría',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busqueda.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar búsqueda',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_busqueda.clear),
                        ),
                  filled: true,
                  fillColor: context.bgCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: context.borderCard),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: context.borderCard),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: activos == 0
                ? 'Filtros por cuenta y categoría'
                : 'Filtros por cuenta y categoría, $activos activos',
            excludeSemantics: true,
            child: Badge(
              isLabelVisible: activos > 0,
              label: Text('$activos'),
              backgroundColor: context.successText,
              child: Material(
                color: context.bgCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: context.borderCard),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _abrirFiltros(context, cuentas, categorias),
                  child: const SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(Icons.filter_list),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips(BuildContext context, List<DateTime> meses) {
    Widget chipTipo(String texto, TipoTransaccion? tipo) {
      final seleccionado = _tipo == tipo;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(texto),
          selected: seleccionado,
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          selectedColor: context.textPrimary,
          backgroundColor: context.bgCard,
          side: BorderSide(color: context.borderCard),
          shape: const StadiumBorder(),
          labelStyle: TextStyle(
            color: seleccionado ? context.bgPage : context.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          onSelected: (_) => setState(() => _tipo = tipo),
        ),
      );
    }

    final etiquetaMes = _mes == null
        ? 'Todo el tiempo'
        : formatearMes(_mes!, ahora: _ahora);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          chipTipo('Todo', null),
          chipTipo('Gastos', TipoTransaccion.gasto),
          chipTipo('Ingresos', TipoTransaccion.ingreso),
          chipTipo('Transferencias', TipoTransaccion.transferenciaSalida),
          Semantics(
            button: true,
            label: 'Periodo: $etiquetaMes. Cambiar mes',
            excludeSemantics: true,
            child: ActionChip(
              key: const Key('chip_mes'),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              labelPadding: const EdgeInsets.only(left: 2, right: 6),
              avatar: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(etiquetaMes),
              backgroundColor: context.bgCard,
              side: BorderSide(color: context.borderCard),
              shape: const StadiumBorder(),
              labelStyle: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              onPressed: () => _elegirMes(context, meses),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _elegirMes(BuildContext context, List<DateTime> meses) async {
    final opciones = <(String, DateTime?)>[
      for (final m in meses) (formatearMes(m, ahora: _ahora), m),
      ('Todo el tiempo', null),
    ];
    final elegido = await showModalBottomSheet<(DateTime?,)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (hoja) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (texto, mes) in opciones)
                ListTile(
                  minTileHeight: 52,
                  title: Text(texto),
                  trailing: mes == _mes ? const Icon(Icons.check) : null,
                  selected: mes == _mes,
                  onTap: () => Navigator.of(hoja).pop((mes,)),
                ),
            ],
          ),
        ),
      ),
    );
    if (elegido != null && mounted) setState(() => _mes = elegido.$1);
  }

  Future<void> _abrirFiltros(
    BuildContext context,
    List<Cuenta> cuentas,
    List<Categoria> categorias,
  ) async {
    var cuentaId = _cuentaId;
    var categoriaId = _categoriaId;
    final aplicar = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (hoja) => StatefulBuilder(
        builder: (hoja, setHoja) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              16 + MediaQuery.of(hoja).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filtros',
                  style: Theme.of(
                    hoja,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: cuentaId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todas las cuentas'),
                    ),
                    for (final c in cuentas)
                      DropdownMenuItem(value: c.id, child: Text(c.nombre)),
                  ],
                  onChanged: (v) => setHoja(() => cuentaId = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: categoriaId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todas las categorías'),
                    ),
                    for (final c in categorias)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          '${c.nombre} (${c.tipo == TipoCategoria.gasto ? 'gasto' : 'ingreso'})',
                        ),
                      ),
                  ],
                  onChanged: (v) => setHoja(() => categoriaId = v),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => setHoja(() {
                          cuentaId = null;
                          categoriaId = null;
                        }),
                        child: const Text('Limpiar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => Navigator.of(hoja).pop(true),
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (aplicar == true && mounted) {
      setState(() {
        _cuentaId = cuentaId;
        _categoriaId = categoriaId;
      });
    }
  }
}

// --- Elementos de la lista (ListView.builder perezoso) --------------------

sealed class _Item {}

class _ItemGasto extends _Item {
  _ItemGasto(this.resumen);
  final ResumenGastoCategorias resumen;
}

class _ItemDia extends _Item {
  _ItemDia(this.grupo);
  final GrupoDia grupo;
}

class _ItemFila extends _Item {
  _ItemFila(this.movimiento, {required this.ultimoDelGrupo});
  final MovimientoDetallado movimiento;
  final bool ultimoDelGrupo;
}

/// Fondo de tarjeta continuo para la lista agrupada (como un solo bloque
/// en 02-movimientos.png), redondeado arriba en el primer encabezado y
/// abajo en la última fila.
BoxDecoration _fondoLista(
  BuildContext context, {
  bool arriba = false,
  bool abajo = false,
}) => BoxDecoration(
  color: context.bgCard,
  borderRadius: BorderRadius.vertical(
    top: Radius.circular(arriba ? 20 : 0),
    bottom: Radius.circular(abajo ? 20 : 0),
  ),
);

class _EncabezadoDia extends StatelessWidget {
  const _EncabezadoDia({
    required this.grupo,
    required this.ahora,
    required this.primero,
  });

  final GrupoDia grupo;
  final DateTime ahora;
  final bool primero;

  @override
  Widget build(BuildContext context) {
    final etiqueta = switch (grupo.tipoDia) {
      TipoDia.hoy => 'Hoy',
      TipoDia.ayer => 'Ayer',
      TipoDia.otro => formatearDiaMesCorto(grupo.dia, ahora: ahora),
    };
    final subtotal = grupo.subtotalNeto.entries
        .map(
          (e) => formatearMontoConSigno(e.value, e.key, positivo: e.value >= 0),
        )
        .join(' · ');
    final estilo = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: context.textSecondary,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
    );
    return Semantics(
      header: true,
      label: '$etiqueta, neto del día $subtotal',
      excludeSemantics: true,
      child: Container(
        decoration: _fondoLista(context, arriba: primero),
        padding: EdgeInsets.fromLTRB(20, primero ? 18 : 14, 20, 4),
        child: Column(
          children: [
            if (!primero) ...[
              Divider(height: 1, color: context.borderCard),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Expanded(child: Text(etiqueta.toUpperCase(), style: estilo)),
                Text(subtotal, style: estiloMonto(estilo)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaEnTarjeta extends StatelessWidget {
  const _FilaEnTarjeta({
    required this.child,
    required this.ultima,
    required this.conDivisor,
  });

  final Widget child;
  final bool ultima;
  final bool conDivisor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _fondoLista(context, abajo: ultima),
      padding: EdgeInsets.fromLTRB(20, 0, 20, ultima ? 8 : 0),
      child: Column(
        children: [
          child,
          if (conDivisor) Divider(height: 1, color: context.borderCard),
        ],
      ),
    );
  }
}

/// "Gasto del mes" (Fase 81): total, barra segmentada top 3 + Otros y
/// leyenda con nombre y porcentaje — el color nunca va solo.
class _TarjetaGasto extends StatelessWidget {
  const _TarjetaGasto({required this.resumen, required this.titulo});

  final ResumenGastoCategorias resumen;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paleta = context.grafico;
    Color colorDe(int i, PorcionGasto p) =>
        p.esOtros ? paleta.last : paleta[i.clamp(0, paleta.length - 2)];
    final total = formatearMonto(resumen.total, resumen.moneda);
    final descripcion = resumen.porciones
        .map((p) => '${p.nombre} ${p.porcentajeEntero}%')
        .join(', ');

    return Semantics(
      container: true,
      label: '$titulo: $total. $descripcion.',
      excludeSemantics: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(
                  titulo,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  total,
                  style: estiloMonto(
                    theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (var i = 0; i < resumen.porciones.length; i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      Expanded(
                        flex: (resumen.porciones[i].porcentaje * 10)
                            .round()
                            .clamp(1, 1000),
                        child: ColoredBox(
                          color: colorDe(i, resumen.porciones[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                for (var i = 0; i < resumen.porciones.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colorDe(i, resumen.porciones[i]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${resumen.porciones[i].nombre} '
                        '${resumen.porciones[i].porcentajeEntero}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontFeatures: cifrasTabulares,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({
    required this.icono,
    required this.titulo,
    this.detalle,
    this.accion,
    this.onAccion,
  });

  final IconData icono;
  final String titulo;
  final String? detalle;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: context.textSecondary),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (detalle != null) ...[
              const SizedBox(height: 6),
              Text(
                detalle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
            if (accion != null) ...[
              const SizedBox(height: 12),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: context.successText,
                ),
                onPressed: onAccion,
                child: Text(accion!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
