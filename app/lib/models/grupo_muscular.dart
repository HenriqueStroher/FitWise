import 'package:flutter/material.dart';

/// Grupos musculares da base de exercícios.
///
/// `codigo` é o valor gravado em `musculoPrimario` no Firestore — é por ele
/// que o ExercicioService filtra. A ordem desta lista é a ordem em que os
/// grupos aparecem no filtro e na tela inicial.
class GrupoMuscular {
  final String codigo;
  final String label;
  final IconData icone;

  const GrupoMuscular({
    required this.codigo,
    required this.label,
    required this.icone,
  });

  static const List<GrupoMuscular> todos = [
    GrupoMuscular(codigo: 'PEITO', label: 'Peito', icone: Icons.fitness_center),
    GrupoMuscular(codigo: 'COSTAS', label: 'Costas', icone: Icons.rowing),
    GrupoMuscular(codigo: 'OMBROS', label: 'Ombros', icone: Icons.accessibility_new),
    GrupoMuscular(codigo: 'BICEPS', label: 'Bíceps', icone: Icons.sports_mma),
    GrupoMuscular(codigo: 'TRICEPS', label: 'Tríceps', icone: Icons.sports_handball),
    GrupoMuscular(codigo: 'ABDOMEN', label: 'Abdômen', icone: Icons.self_improvement),
    GrupoMuscular(codigo: 'LOMBAR', label: 'Lombar', icone: Icons.accessibility),
    GrupoMuscular(codigo: 'QUADRICEPS', label: 'Quadríceps', icone: Icons.directions_run),
    GrupoMuscular(codigo: 'POSTERIOR', label: 'Posterior', icone: Icons.directions_walk),
    GrupoMuscular(codigo: 'GLUTEOS', label: 'Glúteos', icone: Icons.airline_seat_recline_normal),
    GrupoMuscular(codigo: 'PANTURRILHA', label: 'Panturrilha', icone: Icons.directions_bike),
  ];

  static const String codigoPadrao = 'PEITO';

  /// Rótulo em português de um código; devolve o próprio código se for
  /// desconhecido, para não esconder dado inesperado vindo do Firestore.
  static String labelDe(String codigo) {
    for (final grupo in todos) {
      if (grupo.codigo == codigo) return grupo.label;
    }
    return codigo;
  }
}
