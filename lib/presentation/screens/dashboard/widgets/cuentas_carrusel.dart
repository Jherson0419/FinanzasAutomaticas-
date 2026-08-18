import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cuenta.dart';
import '../../../state/providers.dart';
import 'wallet_account_card.dart';

/// Carrusel de tarjetas wallet a tamaño real: cada tarjeta ocupa casi todo
/// el ancho disponible (con el borde de la tarjeta vecina asomando a los
/// lados), con proporción cercana a una tarjeta de crédito real. La
/// tarjeta "+" de agregar cuenta es siempre la última página.
class CuentasCarrusel extends ConsumerStatefulWidget {
  const CuentasCarrusel({super.key});

  @override
  ConsumerState<CuentasCarrusel> createState() => _CuentasCarruselState();
}

class _CuentasCarruselState extends ConsumerState<CuentasCarrusel> {
  /// Cada página ocupa el 85% del ancho — deja ~7.5% de cada lado para que
  /// se asome el borde de la tarjeta anterior/siguiente.
  static const _viewportFraction = 0.85;

  /// Ancho:alto ≈ 1.6:1, como una tarjeta de crédito real.
  static const _relacionAspecto = 1.6;

  late final PageController _controller = PageController(
    viewportFraction: _viewportFraction,
  );
  int _paginaActual = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cuentasAsync = ref.watch(cuentasProvider);

    return cuentasAsync.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No se pudieron cargar las cuentas.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
      data: (cuentas) => _construir(cuentas),
    );
  }

  Widget _construir(List<Cuenta> cuentas) {
    final totalPaginas = cuentas.length + 1; // + tarjeta "agregar"
    if (_paginaActual > totalPaginas - 1) {
      _paginaActual = totalPaginas - 1;
    }
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoTarjeta = constraints.maxWidth * _viewportFraction;
        final altoTarjeta = anchoTarjeta / _relacionAspecto;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: altoTarjeta,
              child: PageView.builder(
                controller: _controller,
                itemCount: totalPaginas,
                onPageChanged: (index) => setState(() => _paginaActual = index),
                itemBuilder: (context, index) {
                  final esAgregar = index == cuentas.length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: esAgregar
                        ? _AgregarCuentaCard(
                            width: anchoTarjeta,
                            height: altoTarjeta,
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/cuentas/nueva'),
                          )
                        : WalletAccountCard(
                            cuenta: cuentas[index],
                            width: anchoTarjeta,
                            height: altoTarjeta,
                          ),
                  );
                },
              ),
            ),
            if (totalPaginas > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < totalPaginas; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _paginaActual ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _paginaActual
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AgregarCuentaCard extends StatelessWidget {
  final VoidCallback onTap;
  final double width;
  final double height;

  const _AgregarCuentaCard({
    required this.onTap,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: _BordePunteado(color: colorScheme.outline, radio: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: colorScheme.primary, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    'Agregar cuenta',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BordePunteado extends CustomPainter {
  final Color color;
  final double radio;

  const _BordePunteado({required this.color, required this.radio});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radio),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashWidth = 6.0;
    const gapWidth = 4.0;
    for (final metric in path.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metric.length) {
        final siguiente = distancia + dashWidth;
        canvas.drawPath(
          metric.extractPath(distancia, siguiente.clamp(0, metric.length)),
          paint,
        );
        distancia = siguiente + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordePunteado oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radio != radio;
}
