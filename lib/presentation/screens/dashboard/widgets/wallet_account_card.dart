import 'package:flutter/material.dart';

import '../../../../domain/entities/cuenta.dart';
import '../../../shared/enum_labels.dart';
import '../../../shared/formatters.dart';
import '../../../shared/wallet_card_colors.dart';
import '../../../theme/app_theme.dart';

class WalletAccountCard extends StatelessWidget {
  final Cuenta cuenta;

  /// Versión reducida (fila de ancho completo) usada en listas, como el
  /// paso de cuentas del onboarding o el resumen final. La versión normal
  /// (230×140 por defecto) es la de "Mis cuentas" y el formulario de cuenta;
  /// el carrusel del dashboard pasa [width]/[height] explícitos para llenar
  /// casi todo el ancho de cada página del `PageView`.
  final bool compacto;

  /// Tamaño de la versión no compacta. `null` usa el tamaño por defecto
  /// (230×140).
  final double? width;
  final double? height;

  const WalletAccountCard({
    super.key,
    required this.cuenta,
    this.compacto = false,
    this.width,
    this.height,
  });

  /// Etiqueta del tipo de cuenta en mayúsculas, con el mismo tratamiento
  /// tipográfico que `sectionLabelTextStyle` (Fase 19.1) pero recoloreado a
  /// blanco translúcido: aquí el texto va sobre un degradado, no sobre
  /// `bgCard`.
  TextStyle _estiloTipoLabel(double fontSize) =>
      sectionLabelTextStyle.copyWith(color: Colors.white70, fontSize: fontSize);

  @override
  Widget build(BuildContext context) {
    final estilo = walletCardEstilos[cuenta.tipo]!;
    final colorBorde = Color.lerp(estilo.inicio, Colors.white, 0.3)!;

    if (compacto) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: estilo.degradado,
          border: Border.all(color: colorBorde, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(estilo.icono, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cuenta.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    labelTipoCuenta(cuenta.tipo).toUpperCase(),
                    style: _estiloTipoLabel(10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatearMonto(cuenta.saldoActual, cuenta.moneda),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: width ?? 230,
      height: height ?? 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: estilo.degradado,
        border: Border.all(color: colorBorde, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  cuenta.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(estilo.icono, color: Colors.white70, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            formatearMonto(cuenta.saldoActual, cuenta.moneda),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            labelTipoCuenta(cuenta.tipo).toUpperCase(),
            style: _estiloTipoLabel(11),
          ),
        ],
      ),
    );
  }
}
