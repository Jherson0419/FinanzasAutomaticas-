import 'package:flutter/material.dart';

import '../../domain/entities/deuda.dart';
import '../../domain/urgencia_deuda.dart';
import '../../domain/usecases/dto/resumen_dashboard.dart';
import '../theme/app_theme.dart';
import 'avatar_perfil_boton.dart';
import 'estilos.dart';
import 'formatters.dart';

/// Tono visual de un chip de urgencia. Nunca se comunica solo con color:
/// cada tono va con su ícono y su texto (Fase 80).
enum TonoUrgencia { peligro, aviso, neutro, ok }

/// Texto + ícono + tono del chip de urgencia de una deuda (Fase 80).
class EtiquetaUrgencia {
  final String texto;
  final IconData icono;
  final TonoUrgencia tono;

  const EtiquetaUrgencia(this.texto, this.icono, this.tono);
}

/// Hasta cuántos días antes se muestra "En N días" en vez de "Al día".
const _diasMostrarCuentaRegresiva = 7;

/// Etiqueta del chip a partir de la misma urgencia que ordena la lista
/// (`domain/urgencia_deuda.dart`), contando días de calendario:
/// - En mora o fecha ya pasada → "Vencida hace N días" / "En mora".
/// - Hoy / mañana / ≤ 7 días → "Vence hoy" / "Vence mañana" / "En N días".
/// - Más lejos → "Al día · 24 nov" (Fase 81); sin fecha → "Al día".
EtiquetaUrgencia etiquetaUrgencia(DeudaActivaResumen deuda, DateTime ahora) {
  final etiqueta = _etiquetaUrgenciaBase(deuda, ahora);
  // Fase 82: un préstamo que hice no está "al día" — está por cobrar.
  if (deuda.direccion == DireccionDeuda.meDeben &&
      etiqueta.tono == TonoUrgencia.ok) {
    final fecha = deuda.fechaVencimientoReal;
    return EtiquetaUrgencia(
      fecha == null
          ? 'Por cobrar'
          : 'Por cobrar · ${formatearDiaMesCorto(fecha, ahora: ahora)}',
      Icons.hourglass_empty,
      TonoUrgencia.neutro,
    );
  }
  return etiqueta;
}

EtiquetaUrgencia _etiquetaUrgenciaBase(
  DeudaActivaResumen deuda,
  DateTime ahora,
) {
  final fecha = deuda.fechaVencimientoReal;
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final dias = fecha == null
      ? null
      : DateTime(fecha.year, fecha.month, fecha.day).difference(hoy).inDays;

  if (deuda.enMora || (dias != null && dias < 0)) {
    final atraso = deuda.enMora
        ? (deuda.diasMora ?? (dias == null ? null : -dias))
        : -dias!;
    final texto = switch (atraso) {
      null || 0 => 'En mora',
      1 => 'Vencida ayer',
      _ => 'Vencida hace $atraso días',
    };
    return EtiquetaUrgencia(texto, Icons.error_outline, TonoUrgencia.peligro);
  }
  if (dias == null) {
    return const EtiquetaUrgencia(
      'Al día',
      Icons.check_circle_outline,
      TonoUrgencia.ok,
    );
  }
  final urgente = urgenciaDeuda(deuda, ahora) == UrgenciaDeuda.porVencer;
  final tono = urgente ? TonoUrgencia.aviso : TonoUrgencia.neutro;
  return switch (dias) {
    0 => const EtiquetaUrgencia(
      'Vence hoy',
      Icons.schedule,
      TonoUrgencia.aviso,
    ),
    1 => EtiquetaUrgencia('Vence mañana', Icons.schedule, tono),
    <= _diasMostrarCuentaRegresiva => EtiquetaUrgencia(
      'En $dias días',
      urgente ? Icons.schedule : Icons.event_outlined,
      tono,
    ),
    _ => EtiquetaUrgencia(
      'Al día · ${formatearDiaMesCorto(fecha!, ahora: ahora)}',
      Icons.check_circle_outline,
      TonoUrgencia.ok,
    ),
  };
}

/// Detalle de estructura de la fila completa (Fase 81, como en
/// 04-deudas.png): "Cuota S/ 210.00 · 3 de 12 pagadas" en cuotas fijas;
/// "Pago libre" si no. Fase 82: texto unificado — en el hub siempre se
/// cuentan las cuotas YA pagadas, con la palabra "pagadas".
String detalleEstructura(Deuda? deuda, DeudaActivaResumen resumen) {
  if (resumen.estructuraPago != EstructuraPago.cuotasFijas) {
    return 'Pago libre';
  }
  final total = deuda?.numeroCuotasTotal;
  final cuota = resumen.montoCuota;
  final montoCuota = cuota == null ? '' : formatearMonto(cuota, resumen.moneda);
  if (total == null) {
    return montoCuota.isEmpty ? 'Cuotas fijas' : 'Cuota $montoCuota';
  }
  final pagadas = (deuda?.numeroCuotasPagadas ?? 0).clamp(0, total);
  return montoCuota.isEmpty
      ? '$pagadas de $total pagadas'
      : 'Cuota $montoCuota · $pagadas de $total pagadas';
}

/// Título de la deuda según su dirección (Fase 82): con una persona,
/// "Debes a Marco" (debo) o "Lucía te debe" (me deben); con una entidad o
/// comercio, el nombre de la deuda. Sin la entidad completa cargada, el
/// nombre de la deuda.
String tituloDeuda(Deuda? deuda, DeudaActivaResumen resumen) {
  if (deuda == null || deuda.tipoAcreedor != TipoAcreedor.personaNatural) {
    return resumen.nombreDeuda;
  }
  final quien = deuda.nombreAcreedor.trim();
  if (quien.isEmpty) return resumen.nombreDeuda;
  return deuda.meDeben ? '$quien te debe' : 'Debes a $quien';
}

/// La cuota que toca pagar ahora ("Cuota 4 de 12"), o `null` si
/// no es cuotas fijas. Usado en el título compacto de "Próximos pagos".
String? cuotaQueToca(Deuda? deuda, DeudaActivaResumen resumen) {
  if (resumen.estructuraPago != EstructuraPago.cuotasFijas) return null;
  final total = deuda?.numeroCuotasTotal;
  if (total == null) return null;
  final siguiente = ((deuda?.numeroCuotasPagadas ?? 0) + 1).clamp(1, total);
  return 'Cuota $siguiente de $total';
}

/// Chip de urgencia con ÍCONO + TEXTO (Fase 80): el color refuerza, nunca
/// es la única señal. Colores de texto/fondo accesibles por tema (≥ 4.5:1,
/// ver `test/contraste_tokens_test.dart`).
class ChipUrgencia extends StatelessWidget {
  const ChipUrgencia({super.key, required this.etiqueta});

  final EtiquetaUrgencia etiqueta;

  @override
  Widget build(BuildContext context) {
    final (texto, fondo) = switch (etiqueta.tono) {
      TonoUrgencia.peligro => (context.dangerText, context.dangerBg),
      TonoUrgencia.aviso => (context.warningText, context.warningBg),
      TonoUrgencia.ok => (context.successText, context.successBg),
      TonoUrgencia.neutro => (context.textPrimary, context.borderCard),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(etiqueta.icono, size: 14, color: texto),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              etiqueta.texto,
              style: TextStyle(
                color: texto,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ícono cuadrado de la deuda (Fase 81): iniciales del acreedor si es una
/// persona; si no, un ícono según el tipo de deuda. Decorativo: la fila ya
/// lleva el nombre, así que se excluye de la semántica.
class IconoDeuda extends StatelessWidget {
  const IconoDeuda({super.key, required this.deuda, this.tamano = 48});

  final Deuda? deuda;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final d = deuda;
    final esPersona = d?.tipoAcreedor == TipoAcreedor.personaNatural;
    final iniciales = esPersona ? inicialesDe(d!.nombreAcreedor) : null;
    final grafico = context.grafico;

    final (Color color, Color fondo, IconData icono) = switch (d?.tipoDeuda) {
      _ when iniciales != null => (
        context.warningText,
        context.warningBg,
        Icons.person_outline,
      ),
      TipoDeuda.tarjetaCredito => (
        grafico[1],
        grafico[1].withValues(alpha: 0.14),
        Icons.credit_card,
      ),
      TipoDeuda.compraCuotas => (
        grafico[1],
        grafico[1].withValues(alpha: 0.14),
        Icons.shopping_bag_outlined,
      ),
      TipoDeuda.deudaInformal => (
        context.warningText,
        context.warningBg,
        Icons.handshake_outlined,
      ),
      TipoDeuda.otro || null => (
        context.textSecondary,
        context.borderCard,
        Icons.receipt_long_outlined,
      ),
      _ => (
        context.successText,
        context.successBg,
        Icons.account_balance_outlined,
      ),
    };

    return ExcludeSemantics(
      child: Container(
        width: tamano,
        height: tamano,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(tamano * 0.3),
        ),
        child: iniciales != null
            ? Text(
                iniciales,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: tamano * 0.34,
                ),
              )
            : Icon(icono, color: color, size: tamano * 0.46),
      ),
    );
  }
}

/// Variante de [FilaDeuda].
enum VarianteFilaDeuda {
  /// Hub de Deudas (04-deudas.png): saldo pendiente, detalle de cuotas,
  /// barra de progreso y "Pagado / Total".
  completa,

  /// "Próximos pagos" del Inicio (01-inicio.png): monto que toca pagar
  /// (cuota o saldo en pago libre) y fecha, sin barra.
  compacta,
}

/// Fila de una deuda activa (Fase 80, extraída a `shared/` en la Fase 81
/// para reutilizarla en el hub de Deudas y en "Próximos pagos" del Inicio
/// sin duplicar lógica). Tocarla abre el detalle de la deuda.
class FilaDeuda extends StatelessWidget {
  const FilaDeuda({
    super.key,
    required this.resumen,
    required this.deuda,
    required this.ahora,
    this.variante = VarianteFilaDeuda.completa,
  });

  /// Datos ya calculados por `ObtenerResumenDashboard` (saldo, total a
  /// pagar, fecha real de vencimiento).
  final DeudaActivaResumen resumen;

  /// La entidad completa, solo para tipo/acreedor/cuotas; puede faltar
  /// (p. ej. mientras carga) y la fila igual se dibuja.
  final Deuda? deuda;
  final DateTime ahora;
  final VarianteFilaDeuda variante;

  @override
  Widget build(BuildContext context) {
    final etiqueta = etiquetaUrgencia(resumen, ahora);
    final esCompacta = variante == VarianteFilaDeuda.compacta;
    final saldo = formatearMonto(resumen.saldoPendiente, resumen.moneda);

    final String montoDerecha;
    final String? subDerecha;
    final String titulo;
    final nombre = tituloDeuda(deuda, resumen);
    final cobro = resumen.direccion == DireccionDeuda.meDeben;
    final pagadoTexto = cobro ? 'Cobrado' : 'Pagado';
    if (esCompacta) {
      final cuota = cuotaQueToca(deuda, resumen);
      titulo = cuota == null ? nombre : '$nombre · $cuota';
      final esCuotas =
          resumen.estructuraPago == EstructuraPago.cuotasFijas &&
          resumen.montoCuota != null;
      montoDerecha = esCuotas
          ? formatearMonto(resumen.montoCuota!, resumen.moneda)
          : saldo;
      final fecha = resumen.fechaVencimientoReal;
      subDerecha = fecha == null
          ? null
          : formatearDiaMesCorto(fecha, ahora: ahora);
    } else {
      titulo = nombre;
      montoDerecha = saldo;
      subDerecha = detalleEstructura(deuda, resumen);
    }

    final semantica = esCompacta
        ? '$titulo. Monto a pagar $montoDerecha. ${etiqueta.texto}.'
              '${subDerecha == null ? '' : ' Fecha $subDerecha.'}'
        : '$titulo. ${cobro ? 'Por cobrar' : 'Saldo pendiente'} $saldo. '
              '${etiqueta.texto}. $subDerecha. '
              '$pagadoTexto ${formatearMonto(resumen.montoPagado, resumen.moneda)} '
              'de ${formatearMonto(resumen.totalAPagar, resumen.moneda)}.';

    return Semantics(
      button: true,
      label: semantica,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(
          context,
        ).pushNamed('/deudas/detalle', arguments: resumen.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: esCompacta
              ? _cabecera(context, titulo, etiqueta, montoDerecha, subDerecha)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _cabecera(
                      context,
                      titulo,
                      etiqueta,
                      montoDerecha,
                      subDerecha,
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: resumen.progreso,
                        minHeight: 6,
                        backgroundColor: context.borderCard,
                        color: context.brandAction,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _textoPie(
                          context,
                          '$pagadoTexto ${formatearMonto(resumen.montoPagado, resumen.moneda)}',
                        ),
                        _textoPie(
                          context,
                          'Total ${formatearMonto(resumen.totalAPagar, resumen.moneda)}',
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _textoPie(BuildContext context, String texto) => Text(
    texto,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: context.textSecondary,
      fontFeatures: cifrasTabulares,
    ),
  );

  Widget _cabecera(
    BuildContext context,
    String titulo,
    EtiquetaUrgencia etiqueta,
    String montoDerecha,
    String? subDerecha,
  ) {
    final theme = Theme.of(context);
    final esCompacta = variante == VarianteFilaDeuda.compacta;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconoDeuda(deuda: deuda, tamano: esCompacta ? 44 : 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              ChipUrgencia(etiqueta: etiqueta),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                montoDerecha,
                textAlign: TextAlign.end,
                style: estiloMonto(
                  theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (subDerecha != null) ...[
                const SizedBox(height: 2),
                Text(
                  subDerecha,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                    fontFeatures: cifrasTabulares,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
