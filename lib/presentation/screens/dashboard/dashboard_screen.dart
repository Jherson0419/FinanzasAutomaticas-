import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/usecases/dto/resumen_dashboard.dart';
import '../../shared/app_bottom_bar.dart';
import '../../shared/avatar_perfil_boton.dart';
import '../../shared/formatters.dart';
import '../../state/dashboard/dashboard_providers.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../shared/notificaciones_recordatorios.dart';
import '../consejero_screen.dart';
import '../mi_avance_screen.dart';
import 'widgets/alertas_tarjetas_credito_banner.dart';
import 'widgets/dashboard_empty_state.dart';
import 'widgets/movimientos_recientes_section.dart';
import 'widgets/proximos_pagos_section.dart';
import 'widgets/saldo_hero_card.dart';
import 'widgets/tus_deudas_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fase 25.5: cuando `capturar-transaccion` (Atajo de iOS, correo)
    // inserta una fila nueva, este listener la ve por Supabase Realtime y
    // refresca el dashboard solo — sin que el usuario tenga que salir y
    // volver a entrar. La transición inicial (`AsyncLoading` → primer
    // `AsyncData`) es solo el snapshot con el que arranca el stream, mismo
    // dato que `resumenDashboardProvider` ya cargó por su cuenta — no
    // cuenta como "cambio real". Solo se invalida en una transición de
    // `AsyncData` a `AsyncData` (un evento después del primero).
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      transaccionesEnVivoProvider,
      (previous, next) {
        if (previous is AsyncData && next is AsyncData) {
          ref.invalidate(resumenDashboardProvider);
          ref.invalidate(cuentasProvider);
        }
      },
    );

    final resumenAsync = ref.watch(resumenDashboardProvider);
    final nombreAsync = ref.watch(nombreUsuarioProvider);
    // Fase 63: conteo de notificaciones no leídas para el badge de la
    // campana — `valueOrNull` deja el badge sin número mientras el stream
    // de Realtime todavía no emitió su primer snapshot, en vez de mostrar
    // un "0" que después salta a un número distinto.
    final conteoNoLeidas =
        ref.watch(notificacionesNoLeidasProvider).valueOrNull?.length ?? 0;
    final theme = Theme.of(context);
    final saludo = nombreAsync.maybeWhen(
      data: (nombre) =>
          (nombre == null || nombre.trim().isEmpty) ? 'Hola' : 'Hola, $nombre',
      orElse: () => 'Hola',
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        // Fase 80: el avatar abre "Mi perfil" (ya no está en la barra
        // inferior). Fase 81: saludo + fecha en español debajo, y la
        // campana en un botón circular, como en 01-inicio.png.
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Center(child: AvatarPerfilBoton()),
        ),
        leadingWidth: 16 + AvatarPerfilBoton.tamano + 4,
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              saludo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              formatearFechaLarga(DateTime.now()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.bgCard,
                border: Border.all(color: context.borderCard),
              ),
              child: IconButton(
                tooltip: 'Notificaciones',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () =>
                    Navigator.of(context).pushNamed('/notificaciones'),
                icon: Badge(
                  label: Text('$conteoNoLeidas'),
                  isLabelVisible: conteoNoLeidas > 0,
                  backgroundColor: context.dangerText,
                  child: const Icon(Icons.notifications_none),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: resumenAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo cargar el dashboard.\n$error',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          data: (resumen) => resumen.estaVacio
              ? const DashboardEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: _DashboardContent(resumen: resumen),
                ),
        ),
      ),
      bottomNavigationBar: const AppBottomBar(actual: AppBottomTab.inicio),
    );
  }
}

/// Inicio (Fase 81, 01-inicio.png), de arriba abajo: héroe de saldo,
/// alertas de tarjetas, "Tus deudas", "Próximos pagos" y "Movimientos
/// recientes". Lo que salió del Inicio y a dónde fue:
/// - `CuentasCarrusel` → Mis cuentas (ya muestra cada `WalletAccountCard`
///   en lista vertical), enlazada desde "N cuentas ›" y desde Mi perfil.
/// - `SaldoTotalCard` + `IngresosGastosSection` → `SaldoHeroCard`.
/// - `GastoPorCategoriaSection` → "Gasto del mes" en Movimientos.
/// - `DeudasActivasSection` y `TeDebenSection` → `TusDeudasCard` +
///   `ProximosPagosSection` aquí, y el detalle completo en el hub Deudas.
class _DashboardContent extends StatelessWidget {
  final ResumenDashboard resumen;

  const _DashboardContent({required this.resumen});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaldoHeroCard(
          saldoTotalPorMoneda: resumen.saldoTotalPorMoneda,
          ingresosMesPorMoneda: resumen.ingresosMesPorMoneda,
          gastosMesPorMoneda: resumen.gastosMesPorMoneda,
          cantidadCuentas: resumen.saldosPorCuenta.length,
        ),
        const SizedBox(height: 12),
        const AlertasTarjetasCreditoBanner(),
        // Fase 86: una línea con el consejo más importante (si lo hay).
        const ConsejoDestacadoLinea(),
        // Fase 87: un logro por celebrar (uno a la vez), la oferta única de
        // recordatorios y la sincronización (invisible) de los programados.
        const CelebracionHito(),
        const OfrecimientoRecordatorios(),
        const SincronizadorRecordatorios(),
        const SizedBox(height: 12),
        TusDeudasCard(
          deudasActivas: resumen.deudasActivas,
          totalAdeudadoPorMoneda: resumen.totalAdeudadoPorMoneda,
          totalTeDebenPorMoneda: resumen.totalTeDebenPorMoneda,
        ),
        const SizedBox(height: 16),
        ProximosPagosSection(deudasActivas: resumen.deudasActivas),
        if (resumen.deudasActivas.isNotEmpty) const SizedBox(height: 16),
        MovimientosRecientesSection(
          movimientosRecientes: resumen.movimientosRecientes,
        ),
      ],
    );
  }
}
