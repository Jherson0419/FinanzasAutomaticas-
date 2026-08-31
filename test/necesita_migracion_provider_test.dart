import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/tema_app.dart';
import 'package:finanzas_automaticas/domain/repositories/preferencias_repository.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakePreferenciasRepository implements PreferenciasRepository {
  bool _datosEnLaNube = false;
  bool marcarDatosEnLaNubeLlamado = false;

  @override
  Future<bool> datosEnLaNube() async => _datosEnLaNube;
  @override
  Future<void> marcarDatosEnLaNube() async {
    marcarDatosEnLaNubeLlamado = true;
    _datosEnLaNube = true;
  }

  @override
  Future<String?> obtenerNombre() async => null;
  @override
  Future<void> guardarNombre(String nombre) async {}
  @override
  Future<bool> onboardingCompletado() async => false;
  @override
  Future<void> marcarOnboardingCompletado() async {}
  @override
  Future<TemaApp> obtenerTema() async => TemaApp.oscuro;
  @override
  Future<void> guardarTema(TemaApp tema) async {}
  @override
  Future<String?> obtenerApiKeyGemini() async => null;
  @override
  Future<void> guardarApiKeyGemini(String apiKey) async {}
  @override
  Future<bool> recordarSesion() async => true;
  @override
  Future<void> guardarRecordarSesion(bool recordar) async {}
  @override
  Future<DateTime?> ultimaGeneracionNotificacionesVencimiento() async => null;
  @override
  Future<void> guardarUltimaGeneracionNotificacionesVencimiento(
    DateTime fecha,
  ) async {}
  @override
  Future<void> limpiarTodo() async {}
}

void main() {
  test('una instalación nueva sin ninguna cuenta/deuda/transacción local marca '
      'datosEnLaNube sin mostrar la pantalla de migración', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final fakePreferencias = _FakePreferenciasRepository();

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        preferenciasRepositoryProvider.overrideWithValue(fakePreferencias),
      ],
    );
    addTearDown(container.dispose);

    final necesitaMigracion = await container.read(
      necesitaMigracionProvider.future,
    );

    expect(necesitaMigracion, isFalse);
    expect(fakePreferencias.marcarDatosEnLaNubeLlamado, isTrue);
  });

  test(
    'con al menos una cuenta local sin migrar, sí muestra la pantalla de migración',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await CuentaRepositoryDrift(db).crear(
        const Cuenta(
          id: 'cta-1',
          nombre: 'Efectivo',
          tipo: TipoCuenta.efectivo,
          moneda: Moneda.pen,
          saldoActual: 100,
        ),
      );
      final fakePreferencias = _FakePreferenciasRepository();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          preferenciasRepositoryProvider.overrideWithValue(fakePreferencias),
        ],
      );
      addTearDown(container.dispose);

      final necesitaMigracion = await container.read(
        necesitaMigracionProvider.future,
      );

      expect(necesitaMigracion, isTrue);
      expect(fakePreferencias.marcarDatosEnLaNubeLlamado, isFalse);
    },
  );

  test(
    'si datosEnLaNube ya es true, no toca Drift para nada (resuelve en base a la preferencia)',
    () async {
      final fakePreferencias = _FakePreferenciasRepository();
      await fakePreferencias.marcarDatosEnLaNube();
      fakePreferencias.marcarDatosEnLaNubeLlamado = false; // reset del espía

      final container = ProviderContainer(
        overrides: [
          // Sin `appDatabaseProvider` overrideado: si el provider intentara
          // tocar Drift, fallaría al construir un `AppDatabase` real.
          preferenciasRepositoryProvider.overrideWithValue(fakePreferencias),
        ],
      );
      addTearDown(container.dispose);

      final necesitaMigracion = await container.read(
        necesitaMigracionProvider.future,
      );

      expect(necesitaMigracion, isFalse);
    },
  );
}
