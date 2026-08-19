import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/perfil.dart';
import 'package:finanzas_automaticas/domain/repositories/perfil_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/onboarding/onboarding_nick_step.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakePerfilRepository implements PerfilRepository {
  _FakePerfilRepository({this.nicksTomados = const {}});

  final Set<String> nicksTomados;
  int llamadasNickDisponible = 0;

  @override
  Future<Perfil> obtenerPerfil() async => const Perfil();

  @override
  Future<bool> nickDisponible(String nick) async {
    llamadasNickDisponible++;
    return !nicksTomados.contains(nick);
  }

  @override
  Future<void> guardarNick(String nick) async {}

  @override
  Future<void> guardarAvatarId(String avatarId) async {}

  @override
  Future<void> guardarInstagram(String? instagram) async {}
}

Future<_FakePerfilRepository> _pumpNickStep(
  WidgetTester tester, {
  required TextEditingController controller,
  required VoidCallback onContinuar,
  Set<String> nicksTomados = const {},
}) async {
  final fake = _FakePerfilRepository(nicksTomados: nicksTomados);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [perfilRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: Scaffold(
          body: OnboardingNickStep(
            controller: controller,
            onAtras: () {},
            onContinuar: onContinuar,
          ),
        ),
      ),
    ),
  );
  return fake;
}

void main() {
  testWidgets(
    'Continuar sigue deshabilitado mientras se verifica la disponibilidad',
    (WidgetTester tester) async {
      final controller = TextEditingController();
      await _pumpNickStep(tester, controller: controller, onContinuar: () {});

      await tester.enterText(find.byType(TextFormField), 'jherson_v');
      await tester.pump();

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continuar'),
      );
      expect(boton.onPressed, isNull);
      expect(find.text('Verificando disponibilidad...'), findsOneWidget);
    },
  );

  testWidgets('un nick tomado muestra "Ya está en uso" y bloquea Continuar', (
    WidgetTester tester,
  ) async {
    var avanzo = false;
    final controller = TextEditingController();
    await _pumpNickStep(
      tester,
      controller: controller,
      onContinuar: () => avanzo = true,
      nicksTomados: {'jherson_v'},
    );

    await tester.enterText(find.byType(TextFormField), 'jherson_v');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Ya está en uso'), findsOneWidget);
    final boton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(boton.onPressed, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    expect(avanzo, isFalse);
  });

  testWidgets('un nick disponible muestra "Disponible" y habilita Continuar', (
    WidgetTester tester,
  ) async {
    var avanzo = false;
    final controller = TextEditingController();
    await _pumpNickStep(
      tester,
      controller: controller,
      onContinuar: () => avanzo = true,
    );

    await tester.enterText(find.byType(TextFormField), 'jherson_v');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Disponible'), findsOneWidget);
    final boton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(boton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    expect(avanzo, isTrue);
  });

  testWidgets(
    'un nick con formato inválido no llega a consultar al repositorio',
    (WidgetTester tester) async {
      final controller = TextEditingController();
      final fake = await _pumpNickStep(
        tester,
        controller: controller,
        onContinuar: () {},
      );

      await tester.enterText(find.byType(TextFormField), 'ab'); // muy corto
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Usa entre 3 y 20 letras, números o guion bajo, sin espacios.',
        ),
        findsOneWidget,
      );
      expect(fake.llamadasNickDisponible, 0);
    },
  );

  testWidgets(
    'escribir varias letras seguidas solo dispara UNA verificación (debounce)',
    (WidgetTester tester) async {
      final controller = TextEditingController();
      final fake = await _pumpNickStep(
        tester,
        controller: controller,
        onContinuar: () {},
      );

      for (final letra in 'jherson_v'.split('')) {
        await tester.enterText(
          find.byType(TextFormField),
          controller.text + letra,
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(fake.llamadasNickDisponible, 1);
    },
  );
}
