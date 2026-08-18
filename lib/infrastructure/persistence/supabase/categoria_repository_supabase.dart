import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/categoria.dart';
import '../../../domain/repositories/categoria_repository.dart';
import 'supabase_errores.dart';

/// Adapter de `CategoriaRepository` sobre la tabla `categorias` de
/// Supabase (Fase 21). Las categorías predeterminadas están sembradas
/// server-side (`schema_finanzas_v3.sql`) con `user_id IS NULL` —
/// compartidas por todos los usuarios vía RLS, nunca se vuelven a
/// insertar desde la app. Las lecturas traen predeterminadas + propias;
/// las escrituras (crear/actualizar/eliminar) siempre filtran por
/// `user_id` del usuario actual, así que nunca pueden tocar una
/// predeterminada aunque el caso de uso que las bloquea fallara.
class CategoriaRepositorySupabase implements CategoriaRepository {
  final SupabaseClient _client;

  CategoriaRepositorySupabase(this._client);

  String get _userId => _client.auth.currentUser!.id;

  String get _filtroPropiaOPredeterminada =>
      'user_id.eq.$_userId,user_id.is.null';

  @override
  Future<List<Categoria>> obtenerTodas() {
    return conManejoDeErroresSupabase('categorias.obtenerTodas', () async {
      final filas = await _client
          .from('categorias')
          .select()
          .or(_filtroPropiaOPredeterminada);
      return filas.map(aDominio).toList();
    });
  }

  @override
  Future<Categoria?> obtenerPorId(String id) {
    return conManejoDeErroresSupabase('categorias.obtenerPorId', () async {
      final fila = await _client
          .from('categorias')
          .select()
          .or(_filtroPropiaOPredeterminada)
          .eq('id', id)
          .maybeSingle();
      return fila == null ? null : aDominio(fila);
    });
  }

  @override
  Future<void> crear(Categoria categoria) {
    return conManejoDeErroresSupabase('categorias.crear', () async {
      await _client.from('categorias').insert(aFila(categoria));
    });
  }

  @override
  Future<void> actualizar(Categoria categoria) {
    return conManejoDeErroresSupabase('categorias.actualizar', () async {
      await _client
          .from('categorias')
          .update(aFila(categoria))
          .eq('user_id', _userId)
          .eq('id', categoria.id);
    });
  }

  @override
  Future<void> eliminar(String id) {
    return conManejoDeErroresSupabase('categorias.eliminar', () async {
      await _client
          .from('categorias')
          .delete()
          .eq('user_id', _userId)
          .eq('id', id);
    });
  }

  @visibleForTesting
  Map<String, dynamic> aFila(Categoria categoria) {
    return {
      'id': categoria.id,
      'user_id': _userId,
      'nombre': categoria.nombre,
      'tipo': categoria.tipo.name,
      'icon_name': categoria.iconName,
      'es_predeterminada': categoria.esPredeterminada,
    };
  }

  @visibleForTesting
  Categoria aDominio(Map<String, dynamic> fila) {
    return Categoria(
      id: fila['id'] as String,
      nombre: fila['nombre'] as String,
      tipo: TipoCategoria.values.byName(fila['tipo'] as String),
      iconName: fila['icon_name'] as String,
      esPredeterminada: fila['es_predeterminada'] as bool,
    );
  }
}
