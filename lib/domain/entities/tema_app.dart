/// Preferencia de tema de la app (Fase 31 — vuelve a ser elegible; la Fase
/// 19 la había fijado en oscuro permanente). Vive en el dominio como su
/// propio enum, no como `ThemeMode` de Flutter, para no importar Flutter
/// en `domain/` — `presentation/app.dart` lo traduce a `ThemeMode` en la
/// capa de UI.
enum TemaApp { claro, oscuro, sistema }
