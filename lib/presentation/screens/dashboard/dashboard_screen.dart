import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/usecases/dto/resumen_dashboard.dart';
import '../../shared/app_bottom_bar.dart';
import '../../state/dashboard/dashboard_providers.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import 'widgets/alertas_tarjetas_credito_banner.dart';
import 'widgets/cuentas_carrusel.dart';
import 'widgets/dashboard_empty_state.dart';
import 'widgets/deudas_activas_section.dart';
import 'widgets/gasto_por_categoria_section.dart';
import 'widgets/ingresos_gastos_section.dart';
import 'widgets/movimientos_recientes_section.dart';
import 'widgets/saldo_total_card.dart';

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
    final theme = Theme.of(context);
    final saludo = nombreAsync.maybeWhen(
      data: (nombre) =>
          (nombre == null || nombre.trim().isEmpty) ? 'Hola' : 'Hola, $nombre',
      orElse: () => 'Hola',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          saludo,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Mis cuentas',
            onPressed: () => Navigator.of(context).pushNamed('/cuentas'),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.gpp_good_outlined, color: colorSuccess),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
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
                  padding: const EdgeInsets.all(16),
                  child: _DashboardContent(resumen: resumen),
                ),
        ),
      ),
      bottomNavigationBar: const AppBottomBar(actual: AppBottomTab.dashboard),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final ResumenDashboard resumen;

  const _DashboardContent({required this.resumen});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CuentasCarrusel(),
        const SizedBox(height: 16),
        const AlertasTarjetasCreditoBanner(),
        const SizedBox(height: 16),
        SaldoTotalCard(saldoTotalPorMoneda: resumen.saldoTotalPorMoneda),
        const SizedBox(height: 16),
        IngresosGastosSection(
          ingresosMesPorMoneda: resumen.ingresosMesPorMoneda,
          gastosMesPorMoneda: resumen.gastosMesPorMoneda,
        ),
        const SizedBox(height: 16),
        GastoPorCategoriaSection(
          gastoPorCategoriaMes: resumen.gastoPorCategoriaMes,
        ),
        const SizedBox(height: 16),
        DeudasActivasSection(
          deudasActivas: resumen.deudasActivas,
          deudasEnMoraCount: resumen.deudasEnMoraCount,
          deudasPorVencerEstaSemanaCount:
              resumen.deudasPorVencerEstaSemanaCount,
          totalAdeudadoPorMoneda: resumen.totalAdeudadoPorMoneda,
        ),
        const SizedBox(height: 16),
        MovimientosRecientesSection(
          movimientosRecientes: resumen.movimientosRecientes,
        ),
      ],
    );
  }
}
