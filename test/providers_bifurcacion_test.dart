import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/preferencias_repository_shared_prefs.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('datosEnLaNubeProvider (Fase 21.5)', () {
    test('lee false cuando la preferencia nunca se marcó', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(datosEnLaNubeProvider), isFalse);
    });

    test('lee true cuando ya se marcó la migración como completada', () async {
      SharedPreferences.setMockInitialValues({
        PreferenciasRepositorySharedPrefs.claveDatosEnLaNube: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(datosEnLaNubeProvider), isTrue);
    });
  });

  group('Bifurcación de los 5 repositorios de datos financieros', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test(
      'con datosEnLaNube = false, los 5 providers resuelven a los adapters Drift',
      () {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            datosEnLaNubeProvider.overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);

        expect(
          container.read(cuentaRepositoryProvider),
          isA<CuentaRepositoryDrift>(),
        );
        expect(
          container.read(categoriaRepositoryProvider),
          isA<CategoriaRepositoryDrift>(),
        );
        expect(
          container.read(transaccionRepositoryProvider),
          isA<TransaccionRepositoryDrift>(),
        );
        expect(
          container.read(deudaRepositoryProvider),
          isA<DeudaRepositoryDrift>(),
        );
        expect(
          container.read(pagoDeudaRepositoryProvider),
          isA<PagoDeudaRepositoryDrift>(),
        );
      },
    );

    test(
      'con datosEnLaNube = true, los 5 providers intentan resolver al adapter '
      'Supabase (evidenciado por el AssertionError de Supabase.instance sin '
      'inicializar en este test — nunca caen de vuelta a Drift)',
      () {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            datosEnLaNubeProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        for (final leer in <Object? Function()>[
          () => container.read(cuentaRepositoryProvider),
          () => container.read(categoriaRepositoryProvider),
          () => container.read(transaccionRepositoryProvider),
          () => container.read(deudaRepositoryProvider),
          () => container.read(pagoDeudaRepositoryProvider),
        ]) {
          expect(leer, throwsA(isA<AssertionError>()));
        }
      },
    );
  });
}
