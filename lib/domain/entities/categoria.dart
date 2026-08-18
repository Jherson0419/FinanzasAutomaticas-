enum TipoCategoria { ingreso, gasto }

class Categoria {
  final String id;
  final String nombre;
  final TipoCategoria tipo;
  final String iconName;

  /// `true` para las categorías sembradas por la app (Fase 6) y las de
  /// "Ajuste de saldo" (Fase 16) — no se pueden editar ni eliminar (Fase
  /// 20). Por defecto `false`: toda categoría creada por el usuario.
  final bool esPredeterminada;

  const Categoria({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.iconName,
    this.esPredeterminada = false,
  });

  Categoria copyWith({String? nombre, TipoCategoria? tipo, String? iconName}) {
    return Categoria(
      id: id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      iconName: iconName ?? this.iconName,
      esPredeterminada: esPredeterminada,
    );
  }
}
