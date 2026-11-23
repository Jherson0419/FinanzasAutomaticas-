import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/config/supabase_config.dart';

/// Fase 88 — sin `--dart-define`, la configuración es la de siempre
/// (producción): los builds publicados no cambian.
void main() {
  test('sin --dart-define: valores de siempre y entorno producción', () {
    expect(supabaseUrl, 'https://oyoxbvloqqiiasiaugzm.supabase.co');
    expect(supabaseAnonKey, startsWith('sb_publishable_'));
    expect(entornoSupabase, 'produccion');
    expect(configuracionSupabaseIncoherente, isFalse);
  });
}
