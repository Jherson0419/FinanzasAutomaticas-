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

  /// Monto usado de la línea de crédito (Fase 29): no es un campo propio —
  /// se deriva de `saldoActual`, que queda negativo en una cuenta de
  /// crédito a medida que se gasta (`aplicarEfectoTransaccion` ya lo maneja
  /// como cualquier otra cuenta, sin cambios).
  double get _usadoDeLinea =>
      cuenta.saldoActual < 0 ? cuenta.saldoActual.abs() : 0;

  /// `null` si la cuenta no tiene línea de crédito configurada (no debería
  /// pasar para `tipo == credito` una vez validado por
  /// `RegistrarCuenta`/`EditarCuenta`, pero se cubre por defensividad).
  double? get _progresoUso {
    final linea = cuenta.lineaCredito;
    if (linea == null || linea <= 0) return null;
    return (_usadoDeLinea / linea).clamp(0.0, 1.0);
  }

  /// Rojo/naranja desde ~80% de uso, verde por debajo — mismo criterio que
  /// pide la Fase 29.
  Color _colorUso(double progreso) =>
      progreso >= 0.8 ? colorDanger : colorSuccess;

  @override
  Widget build(BuildContext context) {
    final estilo = walletCardEstilos[cuenta.tipo]!;
    final colorBorde = Color.lerp(estilo.inicio, Colors.white, 0.3)!;
    final esCredito = cuenta.tipo == TipoCuenta.credito;
    final progresoUso = esCredito ? _progresoUso : null;

    if (compacto) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: estilo.degradado,
          border: Border.all(color: colorBorde, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              const Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(painter: _TexturaDiagonalPainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        esCredito && cuenta.lineaCredito != null
                            ? 'Usado ${formatearMonto(_usadoDeLinea, cuenta.moneda)} de '
                                  '${formatearMonto(cuenta.lineaCredito!, cuenta.moneda)}'
                            : formatearMonto(cuenta.saldoActual, cuenta.moneda),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: esCredito ? 12 : 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: width ?? 230,
      height: height ?? 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: estilo.degradado,
        border: Border.all(color: colorBorde, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            const Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(painter: _TexturaDiagonalPainter()),
              ),
            ),
            // Forma geométrica grande semi-transparente en la esquina
            // (Fase 31): el mismo ícono del tipo de cuenta, agrandado y
            // muy tenue, asomando por el borde inferior derecho.
            Positioned(
              right: -18,
              bottom: -18,
              child: ExcludeSemantics(
                child: Icon(
                  estilo.icono,
                  size: 96,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
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
                  if (esCredito && cuenta.lineaCredito != null) ...[
                    Text(
                      'Usado ${formatearMonto(_usadoDeLinea, cuenta.moneda)} de '
                      '${formatearMonto(cuenta.lineaCredito!, cuenta.moneda)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progresoUso,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        color: _colorUso(progresoUso ?? 0),
                      ),
                    ),
                  ] else
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Textura sutil de líneas diagonales sobre el degradado de la tarjeta
/// (Fase 31) — puramente decorativa (`ExcludeSemantics` en el `CustomPaint`
/// que la usa), a muy baja opacidad para no afectar la legibilidad del
/// texto ni el contraste. Mismo painter para las versiones compacta y
/// normal: se adapta al tamaño real vía `size` en `paint`.
class _TexturaDiagonalPainter extends CustomPainter {
  const _TexturaDiagonalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const espaciado = 14.0;
    final diagonal = size.width + size.height;
    for (double x = -size.height; x < diagonal; x += espaciado) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TexturaDiagonalPainter oldDelegate) => false;
}
