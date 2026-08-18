import 'package:flutter/material.dart';

/// El set completo de íconos reconocidos por [iconoParaCategoria] (Fase 6),
/// en el mismo orden — usado por el selector de ícono de
/// `categoria_formulario.dart` (Fase 20). No se agregan íconos nuevos: el
/// usuario elige entre los mismos que ya usan las categorías predeterminadas.
const categoriaIconNames = <String>[
  'restaurant',
  'directions_bus',
  'health_and_safety',
  'movie',
  'bolt',
  'school',
  'home',
  'payments',
  'work',
  'attach_money',
  'category',
  'tune',
];

IconData iconoParaCategoria(String iconName) {
  switch (iconName) {
    case 'restaurant':
      return Icons.restaurant;
    case 'directions_bus':
      return Icons.directions_bus;
    case 'health_and_safety':
      return Icons.health_and_safety;
    case 'movie':
      return Icons.movie;
    case 'bolt':
      return Icons.bolt;
    case 'school':
      return Icons.school;
    case 'home':
      return Icons.home;
    case 'payments':
      return Icons.payments;
    case 'work':
      return Icons.work;
    case 'attach_money':
      return Icons.attach_money;
    case 'tune':
      return Icons.tune;
    default:
      return Icons.category;
  }
}
