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
  Future<String> subirFotoAvatar(
    List<int> bytes, {
    required String extension,
  }) async => 'https://storage.example.com/avatares/prueba.$extension';

  @override
  Future<void> guardarInstagram(String? instagram) async {}

  @override
  Future<void> guardarNombreCompleto(String? nombreCompleto) async {}

  @override
  Future<void> guardarCelular(String? celular) async {}

  @override
  Future<void> guardarOtraRedSocial(String? otraRedSocial) async {}
}

Future<_FakePerfilRepository> _pumpNickStep(
  WidgetTester tester, {
  required TextEditingController controller,
  required VoidCallback onContinuar,
  Set<String> nicksTomados = const {},
  String nombre = '',
}) async {
  final fake = _FakePerfilRepository(nicksTomados: nicksTomados);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [perfilRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: Scaffold(
          body: OnboardingNickStep(
            controller: controller,
            nombre: nombre,
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

  testWidgets(
    'Fase 56: sin nombre, no genera ninguna sugerencia de nick',
    (WidgetTester tester) async {
      final controller = TextEditingController();
      await _pumpNickStep(tester, controller: controller, onContinuar: () {});
      await tester.pumpAndSettle();

      expect(find.text('Sugerencias:'), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
    },
  );

  testWidgets(
    'Fase 56: con nombre, genera 3 sugerencias de nick disponibles como chips',
    (WidgetTester tester) async {
      final controller = TextEditingController();
      await _pumpNickStep(
        tester,
        controller: controller,
        onContinuar: () {},
        nombre: 'Jherson',
      );
      await tester.pumpAndSettle();

      expect(find.text('Sugerencias:'), findsOneWidget);
      expect(find.byType(ActionChip), findsNWidgets(3));
    },
  );

  testWidgets(
    'Fase 56: las sugerencias ya tomadas no se muestran como chip',
    (WidgetTester tester) async {
      final controller = TextEditingController();
      // Con esta semilla fija en `generarSugerenciasNick` (no controlable
      // desde el widget), lo verificable sin acoplarse a los valores
      // exactos es: ninguna sugerencia mostrada aparece en `nicksTomados`.
      // Se simula "todo tomado" para confirmar que en ese caso no se
      // muestra ningún chip en absoluto.
      await _pumpNickStep(
        tester,
        controller: controller,
        onContinuar: () {},
        nombre: 'Jherson',
        nicksTomados: {
          for (var n = 10; n < 1000; n++) ...{
            'jherson$n',
            'jherson_$n',
          },
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Sugerencias:'), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
    },
  );

  testWidgets(
    'Fase 56: tocar una sugerencia autocompleta el campo y dispara su '
    'verificación',
    (WidgetTester tester) async {
      final controller = TextEditingController();
      await _pumpNickStep(
        tester,
        controller: controller,
        onContinuar: () {},
        nombre: 'Jherson',
      );
      await tester.pumpAndSettle();

      final chip = tester.widget<ActionChip>(find.byType(ActionChip).first);
      final textoChip = (chip.label as Text).data!; // "@jhersonNN"
      final sugerencia = textoChip.substring(1); // sin el "@"

      await tester.tap(find.byType(ActionChip).first);
      await tester.pumpAndSettle();

      expect(controller.text, sugerencia);
      expect(find.text('Disponible'), findsOneWidget);
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continuar'),
      );
      expect(boton.onPressed, isNotNull);
    },
  );
}
