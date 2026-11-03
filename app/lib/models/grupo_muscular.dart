/// Grupos musculares da base de exercícios.
///
/// `codigo` é o valor gravado em `musculoPrimario` no Firestore — é por ele
/// que o ExercicioService filtra. A ordem desta lista é a ordem em que os
/// grupos aparecem no filtro e na tela inicial.
///
/// `capa` é o slug do exercício cuja ilustração representa o grupo nos cards
/// da tela inicial — no lugar de ícones, que o Material Icons não tem para
/// anatomia.
class GrupoMuscular {
  final String codigo;
  final String label;
  final String capa;

  const GrupoMuscular({required this.codigo, required this.label, required this.capa});

  String get imagemCapa => 'assets/images/$capa-1.webp';

  static const List<GrupoMuscular> todos = [
    GrupoMuscular(codigo: 'PEITO', label: 'Peito', capa: 'bench-press'),
    GrupoMuscular(codigo: 'COSTAS', label: 'Costas', capa: 'pull-ups'),
    GrupoMuscular(codigo: 'OMBROS', label: 'Ombros', capa: 'arnold-press'),
    GrupoMuscular(codigo: 'BICEPS', label: 'Bíceps', capa: 'biceps-curls-with-barbell'),
    GrupoMuscular(codigo: 'TRICEPS', label: 'Tríceps', capa: 'triceps-pushdown-with-rope-and-cable'),
    GrupoMuscular(codigo: 'ABDOMEN', label: 'Abdômen', capa: 'crunches'),
    GrupoMuscular(codigo: 'LOMBAR', label: 'Lombar', capa: 'barbell-dead-lifts'),
    GrupoMuscular(codigo: 'QUADRICEPS', label: 'Quadríceps', capa: 'barbell-squat'),
    GrupoMuscular(codigo: 'POSTERIOR', label: 'Posterior', capa: 'romanian-dead-lift'),
    GrupoMuscular(codigo: 'GLUTEOS', label: 'Glúteos', capa: 'bridging'),
    GrupoMuscular(codigo: 'PANTURRILHA', label: 'Panturrilha', capa: 'standing-calf-raises-using-machine'),
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
