import 'package:flutter/material.dart';

import '../../../../domain/entities/cuenta.dart';
import '../../../../domain/proxima_ocurrencia_mensual.dart';
import '../../../shared/app_card.dart';
import '../../../shared/formatters.dart';

enum _PestanaPago { pagoDelMes, pagoMinimo, deudaTotal }

/// Bloque de 3 pestañas debajo de `WalletAccountCard` en modo edición
/// (Fase 65, rediseño estilo Amex) — "Pago del mes" / "Pago mínimo" /
/// "Deuda total". El modelo actual no distingue ciclos de facturación
/// individuales, así que es una simplificación explícita: "Pago del mes" y
/// "Pago mínimo" muestran el mismo campo (`Cuenta.pagoMinimo`, opcional —
/// "No configurado" en vez de un S/ 0.00 engañoso si no está); "Deuda
/// total" muestra lo usado de la línea (`|saldoActual|` cuando es negativo,
/// 0 si no). Debajo del monto, la próxima fecha de pago ya calculada (Fase
/// 62, `proximaOcurrenciaMensual`) — igual sin importar la pestaña activa.
class TarjetaCreditoPagosSection extends StatefulWidget {
  const TarjetaCreditoPagosSection({super.key, required this.cuenta});

  final Cuenta cuenta;

  @override
  State<TarjetaCreditoPagosSection> createState() =>
      _TarjetaCreditoPagosSectionState();
}

class _TarjetaCreditoPagosSectionState
    extends State<TarjetaCreditoPagosSection> {
  _PestanaPago _pestana = _PestanaPago.pagoDelMes;

  double get _usadoDeLinea =>
      widget.cuenta.saldoActual < 0 ? widget.cuenta.saldoActual.abs() : 0;

  double? get _montoPestanaActual {
    switch (_pestana) {
      case _PestanaPago.pagoDelMes:
      case _PestanaPago.pagoMinimo:
        return widget.cuenta.pagoMinimo;
      case _PestanaPago.deudaTotal:
        return _usadoDeLinea;
    }
  }

  DateTime? get _proximaFechaPago {
    final fechaPago = widget.cuenta.fechaPago;
    if (fechaPago == null) return null;
    return proximaOcurrenciaMensual(fechaPago, DateTime.now());
  }

  Future<void> _verFechasDePago() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => _ModalFechasDePago(cuenta: widget.cuenta),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monto = _montoPestanaActual;
    final proximaFecha = _proximaFechaPago;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_PestanaPago>(
            segments: const [
              ButtonSegment(
                value: _PestanaPago.pagoDelMes,
                label: Text('Pago del mes'),
              ),
              ButtonSegment(
                value: _PestanaPago.pagoMinimo,
                label: Text('Pago mínimo'),
              ),
              ButtonSegment(
                value: _PestanaPago.deudaTotal,
                label: Text('Deuda total'),
              ),
            ],
            selected: {_pestana},
            onSelectionChanged: (seleccion) =>
                setState(() => _pestana = seleccion.first),
          ),
          const SizedBox(height: 16),
          Text(
            monto == null
                ? 'No configurado'
                : formatearMonto(monto, widget.cuenta.moneda),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            proximaFecha == null
                ? 'Sin fecha de pago configurada'
                : 'Vence el ${formatearDiaMes(proximaFecha)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _verFechasDePago,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Ver mis fechas de pago'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet de A.3: próxima fecha de corte Y de pago juntas — las que
/// A.1 quitó de `WalletAccountCard`.
class _ModalFechasDePago extends StatelessWidget {
  const _ModalFechasDePago({required this.cuenta});

  final Cuenta cuenta;

  String _textoFecha(DateTime? ancla) {
    if (ancla == null) return 'No configurado';
    return formatearDiaMes(proximaOcurrenciaMensual(ancla, DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tus fechas de pago',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Próximo corte'),
              trailing: Text(_textoFecha(cuenta.fechaCorte)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Próximo pago'),
              trailing: Text(_textoFecha(cuenta.fechaPago)),
            ),
          ],
        ),
      ),
    );
  }
}
