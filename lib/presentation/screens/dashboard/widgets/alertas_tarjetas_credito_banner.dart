import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/usecases/dto/alerta_tarjeta_credito.dart';
import '../../../state/dashboard/dashboard_providers.dart';
import '../../../theme/app_theme.dart';

/// Banner de corte/pago próximo de tarjetas de crédito (Fase 29) — mismo
/// estilo que el banner de deudas por vencer (`DeudasActivasSection`), pero
/// autocontenido: observa su propio provider en vez de recibir los datos
/// por parámetro, igual que `CuentasCarrusel`.
class AlertasTarjetasCreditoBanner extends ConsumerWidget {
  const AlertasTarjetasCreditoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertasAsync = ref.watch(alertasTarjetasCreditoProvider);
    final alertas = alertasAsync.valueOrNull ?? const [];
    if (alertas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final alerta in alertas) ...[
          _Banner(texto: _textoAlerta(alerta)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _textoAlerta(AlertaTarjetaCredito alerta) {
    final evento = alerta.tipo == TipoAlertaTarjeta.corte
        ? 'el corte'
        : 'el pago';
    return '${alerta.nombreCuenta}: $evento es ${_textoDias(alerta.diasRestantes)}';
  }

  String _textoDias(int dias) {
    if (dias <= 0) return 'hoy';
    if (dias == 1) return 'mañana';
    return 'en $dias días';
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.credit_card, color: colorWarning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorWarning),
            ),
          ),
        ],
      ),
    );
  }
}
