import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cuenta.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';
import 'wallet_account_card.dart';

/// Ancho:alto de cada tarjeta ≈ 1.6:1, como una tarjeta de crédito real
/// (mismo criterio que la Fase 18).
const double _relacionAspecto = 1.6;

/// Desplazamiento vertical de las tarjetas "fantasma" detrás de la frontal
/// (Fase 33) — la primera asoma 16px arriba, la segunda 32px.
const double _offset1 = 16;
const double _offset2 = 32;

/// Opacidad de cada tarjeta fantasma, decreciente con la profundidad.
const double _opacidad1 = 0.75;
const double _opacidad2 = 0.5;

/// Radio de esquina de `WalletAccountCard` (debe calzar con el de
/// `wallet_account_card.dart` para que el recorte cóncavo del botón
/// "Añadir cuenta" se vea integrado, no como un parche encima).
const double _radioTarjeta = 16;

/// Radio del botón "Añadir cuenta" (pill totalmente redondeada, así que
/// este radio es la mitad de su altura) — el recorte circular de la
/// esquina de la tarjeta usa este mismo radio a propósito (Fase 33.3).
const double _radioBotonAgregar = 20;

/// Cuánto se acerca el centro del recorte/botón a la esquina real de la
/// tarjeta — con esto el botón "sangra" apenas `_radioBotonAgregar -
/// _insetBotonAgregar` px fuera del borde, en vez de quedar pegado
/// exactamente en el pixel de la esquina.
const double _insetBotonAgregar = 12;
const double _sangriaBoton = _radioBotonAgregar - _insetBotonAgregar;

const Duration _duracionRotacion = Duration(milliseconds: 280);

/// Umbral de velocidad (px/s, negativo = hacia arriba) para que un swipe
/// rápido cuente como gesto válido aunque recorra poca distancia.
const double _umbralVelocidad = -300;

/// Umbral de distancia acumulada (px, negativo = hacia arriba) para que un
/// arrastre lento pero deliberado cuente como gesto válido.
const double _umbralDistancia = -40;

/// Pila vertical de tarjetas de cuenta (Fase 33 — tercer rediseño de este
/// componente: fila con peek en la Fase 8, carrusel horizontal con "página
/// de agregar" en la Fase 17/18, esta pila vertical con gesto de deslizar
/// hacia arriba). La tarjeta activa va al frente completa; hasta 2 cuentas
/// siguientes asoman detrás, desplazadas hacia arriba y con opacidad
/// reducida. Deslizar hacia arriba en la tarjeta frontal rota la pila
/// (la cuenta al frente pasa al final); el botón "Añadir cuenta" vive
/// integrado en un recorte cóncavo de la esquina inferior derecha de la
/// tarjeta frontal, nunca en las de atrás.
class CuentasCarrusel extends ConsumerStatefulWidget {
  const CuentasCarrusel({super.key});

  @override
  ConsumerState<CuentasCarrusel> createState() => _CuentasCarruselState();
}

class _CuentasCarruselState extends ConsumerState<CuentasCarrusel>
    with SingleTickerProviderStateMixin {
  /// Orden actual de la pila, por id de cuenta — independiente del orden
  /// que devuelva el repositorio, para que rotar la pila no dependa de
  /// mutar datos, y para que un refresco del provider (p. ej. tras editar
  /// el saldo de una cuenta) no resetee qué tarjeta está al frente.
  List<String>? _ordenIds;

  /// Snapshot de las cuentas tomado al iniciar una rotación — se anima
  /// sobre esta copia congelada, no sobre `cuentasProvider` en vivo, para
  /// que la animación no se distorsione si el provider se refresca a
  /// mitad de camino.
  List<Cuenta>? _listaAnimando;

  double _arrastreAcumulado = 0;

  late final AnimationController _controller;
  late final CurvedAnimation _curva;

  @override
  void initState() {
    super.initState();
    // Inicializados aquí (no como `late final` perezosos) a propósito: si
    // nunca se dispara una rotación, un campo perezoso recién se crearía
    // en su primer acceso — que sin esto sería dentro de `dispose()`,
    // demasiado tarde para que `vsync` busque su contexto.
    _controller = AnimationController(duration: _duracionRotacion, vsync: this);
    _curva = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _curva.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Conserva el orden ya existente para las cuentas que siguen ahí, y
  /// agrega las nuevas al final — así una cuenta creada/eliminada en otra
  /// pantalla no reordena la pila entera.
  void _sincronizarOrden(List<Cuenta> cuentas) {
    final idsActuales = cuentas.map((c) => c.id).toSet();
    final ordenPrevio = _ordenIds ?? const [];
    final nuevoOrden = ordenPrevio.where(idsActuales.contains).toList();
    for (final cuenta in cuentas) {
      if (!nuevoOrden.contains(cuenta.id)) nuevoOrden.add(cuenta.id);
    }
    _ordenIds = nuevoOrden;
  }

  void _procesarFinArrastre(DragEndDetails details, List<Cuenta> ordenActual) {
    final distanciaSuficiente = _arrastreAcumulado < _umbralDistancia;
    final velocidadSuficiente =
        details.velocity.pixelsPerSecond.dy < _umbralVelocidad;
    _arrastreAcumulado = 0;

    if ((distanciaSuficiente || velocidadSuficiente) &&
        ordenActual.length > 1 &&
        !_controller.isAnimating) {
      _iniciarRotacion(ordenActual);
    }
  }

  void _iniciarRotacion(List<Cuenta> ordenActual) {
    setState(() => _listaAnimando = ordenActual);
    _controller.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        final ids = _ordenIds;
        if (ids != null && ids.isNotEmpty) {
          ids.add(ids.removeAt(0));
        }
        _listaAnimando = null;
      });
      _controller.value = 0;
    });
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
    if (cuentas.isEmpty) {
      _ordenIds = [];
      return _TarjetaVacia(
        onTap: () => Navigator.of(context).pushNamed('/cuentas/nueva'),
      );
    }

    _sincronizarOrden(cuentas);
    final orden = _ordenIds!;
    final ordenadas = orden
        .map((id) => cuentas.firstWhere((c) => c.id == id))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final alto = ancho / _relacionAspecto;
        final extra = ordenadas.length >= 3
            ? _offset2
            : (ordenadas.length == 2 ? _offset1 : 0.0);
        final alturaPila = alto + extra;
        final alturaTotal = alturaPila + _sangriaBoton;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: alturaTotal,
              child: _listaAnimando != null
                  ? _construirCapaAnimada(_listaAnimando!, ancho, alto, extra)
                  : _construirCapaEstatica(ordenadas, ancho, alto, extra),
            ),
            if (ordenadas.length > 1) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Desliza hacia arriba para ver la siguiente cuenta',
                  style: TextStyle(fontSize: 11.5, color: context.textMuted),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _construirCapaEstatica(
    List<Cuenta> ordenadas,
    double ancho,
    double alto,
    double extra,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => _arrastreAcumulado += d.delta.dy,
      onVerticalDragEnd: (d) => _procesarFinArrastre(d, ordenadas),
      onVerticalDragCancel: () => _arrastreAcumulado = 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (ordenadas.length >= 3)
            _capaFantasma(
              ordenadas[2],
              ancho,
              alto,
              top: extra - _offset2,
              opacidad: _opacidad2,
            ),
          if (ordenadas.length >= 2)
            _capaFantasma(
              ordenadas[1],
              ancho,
              alto,
              top: extra - _offset1,
              opacidad: _opacidad1,
            ),
          Positioned(
            top: extra,
            left: 0,
            right: 0,
            child: _TarjetaFrontalConBoton(
              cuenta: ordenadas[0],
              width: ancho,
              height: alto,
              onAgregar: () =>
                  Navigator.of(context).pushNamed('/cuentas/nueva'),
            ),
          ),
        ],
      ),
    );
  }

  /// Anima la rotación con un único `AnimationController`: la tarjeta
  /// saliente (índice 0 de la lista congelada) sube y se desvanece hacia
  /// la posición que le corresponda al terminar (el siguiente hueco visible
  /// si hay 2-3 cuentas en total, o completamente invisible si hay más),
  /// mientras el resto de la pila avanza un puesto hacia el frente.
  Widget _construirCapaAnimada(
    List<Cuenta> congelada,
    double ancho,
    double alto,
    double extra,
  ) {
    return AnimatedBuilder(
      animation: _curva,
      builder: (context, _) {
        final t = _curva.value;
        double topDe(int slot) => extra - _offset1 * slot;
        double opacidadDe(int slot) => (1 - 0.25 * slot).clamp(0.0, 1.0);
        double lerp(double a, double b) => a + (b - a) * t;

        final capas = <Widget>[];

        // Una 4ta cuenta (si existe) entra al hueco de la 2da fantasma.
        if (congelada.length > 3) {
          capas.add(
            _capaFantasma(
              congelada[3],
              ancho,
              alto,
              top: lerp(topDe(3), topDe(2)),
              opacidad: lerp(opacidadDe(3), opacidadDe(2)),
            ),
          );
        }
        // La 2da fantasma pasa a ser la 1ra.
        if (congelada.length > 2) {
          capas.add(
            _capaFantasma(
              congelada[2],
              ancho,
              alto,
              top: lerp(topDe(2), topDe(1)),
              opacidad: lerp(opacidadDe(2), opacidadDe(1)),
            ),
          );
        }
        // La 1ra fantasma pasa a ser la tarjeta frontal.
        capas.add(
          _capaFantasma(
            congelada[1],
            ancho,
            alto,
            top: lerp(topDe(1), topDe(0)),
            opacidad: lerp(opacidadDe(1), opacidadDe(0)),
          ),
        );
        // La tarjeta frontal sale: si sobran cuentas por mostrar cae en el
        // último hueco visible; si no, se desvanece por completo.
        final destinoSalida = (congelada.length - 1).clamp(0, 3);
        capas.add(
          _capaFantasma(
            congelada[0],
            ancho,
            alto,
            top: lerp(topDe(0), topDe(destinoSalida)),
            opacidad: lerp(opacidadDe(0), opacidadDe(destinoSalida)),
          ),
        );

        return Stack(clipBehavior: Clip.none, children: capas);
      },
    );
  }

  Widget _capaFantasma(
    Cuenta cuenta,
    double ancho,
    double alto, {
    required double top,
    required double opacidad,
  }) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Opacity(
            opacity: opacidad.clamp(0.0, 1.0),
            child: WalletAccountCard(cuenta: cuenta, width: ancho, height: alto),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta frontal: la única con el recorte cóncavo + botón "Añadir
/// cuenta" integrado en la esquina inferior derecha (Fase 33.3). El
/// `ClipPath` resta un círculo (mismo radio que el botón) del rectángulo
/// redondeado de `WalletAccountCard`; el botón se posiciona centrado sobre
/// ese mismo círculo, sangrando apenas un poco fuera del borde de la
/// tarjeta para leerse como si estuviera "encajado" en el recorte.
class _TarjetaFrontalConBoton extends StatelessWidget {
  const _TarjetaFrontalConBoton({
    required this.cuenta,
    required this.width,
    required this.height,
    required this.onAgregar,
  });

  final Cuenta cuenta;
  final double width;
  final double height;
  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipPath(
            clipper: const _RecorteEsquinaClipper(
              radioTarjeta: _radioTarjeta,
              radioRecorte: _radioBotonAgregar,
              inset: _insetBotonAgregar,
            ),
            child: WalletAccountCard(cuenta: cuenta, width: width, height: height),
          ),
          Positioned(
            right: -_sangriaBoton,
            bottom: -_sangriaBoton,
            child: _BotonAgregarCuenta(onTap: onAgregar),
          ),
        ],
      ),
    );
  }
}

/// Rectángulo redondeado (mismo radio que `WalletAccountCard`) menos un
/// círculo en la esquina inferior derecha — el "mordisco" cóncavo donde se
/// asienta el botón "Añadir cuenta" (Fase 33.3).
class _RecorteEsquinaClipper extends CustomClipper<Path> {
  const _RecorteEsquinaClipper({
    required this.radioTarjeta,
    required this.radioRecorte,
    required this.inset,
  });

  final double radioTarjeta;
  final double radioRecorte;
  final double inset;

  @override
  Path getClip(Size size) {
    final base = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radioTarjeta),
        ),
      );
    final centro = Offset(size.width - inset, size.height - inset);
    final circulo = Path()
      ..addOval(Rect.fromCircle(center: centro, radius: radioRecorte));
    return Path.combine(PathOperation.difference, base, circulo);
  }

  @override
  bool shouldReclip(covariant _RecorteEsquinaClipper oldClipper) =>
      oldClipper.radioTarjeta != radioTarjeta ||
      oldClipper.radioRecorte != radioRecorte ||
      oldClipper.inset != inset;
}

/// Botón "Añadir cuenta" en forma de pill — fondo `bgPage` (Fase 31: el
/// mismo token que el fondo de la app en el tema activo, claro u oscuro)
/// para que visualmente "se hunda" en el recorte cóncavo de la tarjeta en
/// vez de leerse como un parche pegado encima.
class _BotonAgregarCuenta extends StatelessWidget {
  const _BotonAgregarCuenta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _radioBotonAgregar * 2,
      child: Material(
        color: context.bgPage,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radioBotonAgregar),
          side: BorderSide(color: context.borderCard),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radioBotonAgregar),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 16, color: colorSuccess),
                const SizedBox(width: 6),
                Text(
                  'Añadir cuenta',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado sin ninguna cuenta — prácticamente inalcanzable en la app real
/// (el onboarding obligatorio siempre deja al menos una), pero se conserva
/// como respaldo explícito: sin tarjeta frontal no hay dónde encajar el
/// recorte cóncavo, así que se muestra un prompt simple en su lugar.
class _TarjetaVacia extends StatelessWidget {
  const _TarjetaVacia({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final alto = ancho / _relacionAspecto;
        return SizedBox(
          width: ancho,
          height: alto,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(_radioTarjeta),
              child: CustomPaint(
                painter: _BordePunteado(
                  color: context.borderCard,
                  radio: _radioTarjeta,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: colorSuccess, size: 26),
                      const SizedBox(height: 6),
                      Text(
                        'Añadir cuenta',
                        style: TextStyle(
                          color: context.textSecondary,
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
      },
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
