/// Grupos musculares da base de exercícios.
///
/// `codigo` é o valor gravado em `musculoPrimario` no Firestore — é por ele
/// que o ExercicioService filtra. A ordem desta lista é a ordem em que os
/// grupos aparecem no filtro e na tela inicial.
///
/// Não há ícone por grupo: o Material Icons não tem símbolos anatômicos, e
/// as aproximações disponíveis confundiam mais do que ajudavam (um assento
/// de avião para glúteos, por exemplo). Os cards usam um ícone único.
class GrupoMuscular {
  final String codigo;
  final String label;

  const GrupoMuscular({required this.codigo, required this.label});

  static const List<GrupoMuscular> todos = [
    GrupoMuscular(codigo: 'PEITO', label: 'Peito'),
    GrupoMuscular(codigo: 'COSTAS', label: 'Costas'),
    GrupoMuscular(codigo: 'OMBROS', label: 'Ombros'),
    GrupoMuscular(codigo: 'BICEPS', label: 'Bíceps'),
    GrupoMuscular(codigo: 'TRICEPS', label: 'Tríceps'),
    GrupoMuscular(codigo: 'ABDOMEN', label: 'Abdômen'),
    GrupoMuscular(codigo: 'LOMBAR', label: 'Lombar'),
    GrupoMuscular(codigo: 'QUADRICEPS', label: 'Quadríceps'),
    GrupoMuscular(codigo: 'POSTERIOR', label: 'Posterior'),
    GrupoMuscular(codigo: 'GLUTEOS', label: 'Glúteos'),
    GrupoMuscular(codigo: 'PANTURRILHA', label: 'Panturrilha'),
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
