import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/categoria_nueva_screen.dart';
import 'screens/consejos_financieros_screen.dart';
import 'screens/cuenta_nueva_screen.dart';
import 'screens/deuda_detalle_screen.dart';
import 'screens/historial_pagos_deuda_screen.dart';
import 'screens/mi_perfil_screen.dart';
import 'screens/mis_categorias_screen.dart';
import 'screens/mis_cuentas_screen.dart';
import 'screens/movimientos_cuenta_screen.dart';
import 'screens/pago_deuda_nuevo_screen.dart';
import 'screens/placeholders/deuda_nueva_screen.dart';
import 'screens/placeholders/transaccion_nueva_screen.dart';
import 'screens/root_screen.dart';
import 'screens/todos_los_movimientos_screen.dart';

class FinanzasAutomaticasApp extends StatelessWidget {
  const FinanzasAutomaticasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finanzas Automáticas',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: appTheme(),
      darkTheme: appTheme(),
      initialRoute: '/',
      routes: {
        '/': (context) => const RootScreen(),
        '/cuentas': (context) => const MisCuentasScreen(),
        '/categorias': (context) => const MisCategoriasScreen(),
        '/consejos': (context) => const ConsejosFinancierosScreen(),
        '/perfil': (context) => const MiPerfilScreen(),
        '/transacciones/todas': (context) => const TodosLosMovimientosScreen(),
      },
      // Estas rutas necesitan leer `settings.arguments` (un id opcional para
      // entrar en modo edición), algo que la tabla `routes` estática no
      // soporta: sus builders solo reciben `BuildContext`.
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/deudas/pago':
            final args = settings.arguments;
            if (args is PagoDeudaRouteArgs) {
              return MaterialPageRoute(
                builder: (context) => PagoDeudaNuevoScreen(
                  deudaId: args.deudaId,
                  numeroCuotaInicial: args.numeroCuotaInicial,
                  montoEsperadoInicial: args.montoEsperadoInicial,
                ),
              );
            }
            final deudaId = args as String;
            return MaterialPageRoute(
              builder: (context) => PagoDeudaNuevoScreen(deudaId: deudaId),
            );
          case '/deudas/detalle':
            final deudaId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) => DeudaDetalleScreen(deudaId: deudaId),
            );
          case '/deudas/historial':
            final deudaId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) => HistorialPagosDeudaScreen(deudaId: deudaId),
            );
          case '/transacciones/nueva':
            final transaccionId = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (context) =>
                  TransaccionNuevaScreen(transaccionId: transaccionId),
            );
          case '/deudas/nueva':
            final deudaId = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (context) => DeudaNuevaScreen(deudaId: deudaId),
            );
          case '/cuentas/nueva':
            final cuentaId = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (context) => CuentaNuevaScreen(cuentaId: cuentaId),
            );
          case '/categorias/nueva':
            final categoriaId = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (context) =>
                  CategoriaNuevaScreen(categoriaId: categoriaId),
            );
          case '/cuentas/movimientos':
            final cuentaId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) => MovimientosCuentaScreen(cuentaId: cuentaId),
            );
        }
        return null;
      },
    );
  }
}
