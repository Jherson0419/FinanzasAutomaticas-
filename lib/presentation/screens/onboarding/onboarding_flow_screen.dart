import 'package:flutter/material.dart';

import 'onboarding_cuentas_step.dart';
import 'onboarding_deudas_step.dart';
import 'onboarding_nombre_step.dart';
import 'onboarding_resumen_step.dart';
import 'onboarding_welcome_step.dart';

/// Wizard de onboarding: un solo contenedor con 5 pasos internos
/// controlados por estado local (sin rutas separadas). Se construye un solo
/// paso a la vez (en vez de `IndexedStack`/`PageView`) para que solo exista
/// un árbol de widgets activo por paso — evita, por ejemplo, tener varios
/// botones "Continuar" montados a la vez. El nombre ingresado sobrevive la
/// navegación entre pasos porque su controller vive aquí, no en el paso.
class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  static const _totalPasos = 5;

  int _paso = 0;
  final _nombreController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  void _irA(int paso) {
    setState(() => _paso = paso.clamp(0, _totalPasos - 1));
  }

  Widget _construirPaso() {
    switch (_paso) {
      case 0:
        return OnboardingWelcomeStep(onComenzar: () => _irA(1));
      case 1:
        return OnboardingNombreStep(
          controller: _nombreController,
          onAtras: () => _irA(0),
          onContinuar: () => _irA(2),
        );
      case 2:
        return OnboardingCuentasStep(
          onAtras: () => _irA(1),
          onContinuar: () => _irA(3),
        );
      case 3:
        return OnboardingDeudasStep(
          onAtras: () => _irA(2),
          onContinuar: () => _irA(4),
        );
      case 4:
      default:
        return OnboardingResumenStep(nombre: _nombreController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _IndicadorProgreso(
                pasoActual: _paso,
                totalPasos: _totalPasos,
              ),
            ),
            Expanded(child: _construirPaso()),
          ],
        ),
      ),
    );
  }
}

class _IndicadorProgreso extends StatelessWidget {
  const _IndicadorProgreso({
    required this.pasoActual,
    required this.totalPasos,
  });

  final int pasoActual;
  final int totalPasos;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < totalPasos; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i <= pasoActual
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
