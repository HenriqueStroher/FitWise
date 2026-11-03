class Exercicio {
  final String id;
  final String slug;
  final String nome;
  final String descricao;
  final String musculoPrimario;
  final String tipo;
  final List<String> musculoSecundario;
  final List<String> equipamento;
  final List<String> frames;
  final List<String> steps;
  final List<String> cuidados;
  final String vetorForca;
  final String planoMovimento;
  final double ativacaoMuscular;
  final double escoreRiscoLesao;

  Exercicio({
    required this.id,
    required this.slug,
    required this.nome,
    required this.descricao,
    required this.musculoPrimario,
    required this.tipo,
    required this.musculoSecundario,
    required this.equipamento,
    required this.frames,
    required this.steps,
    required this.cuidados,
    required this.vetorForca,
    required this.planoMovimento,
    required this.ativacaoMuscular,
    required this.escoreRiscoLesao,
  });

  factory Exercicio.fromFirestore(Map<String, dynamic> data) {
    return Exercicio(
      id: data['id'] ?? '',
      slug: data['slug'] ?? '',
      nome: data['nome'] ?? '',
      descricao: data['descricao'] ?? '',
      musculoPrimario: data['musculoPrimario'] ?? '',
      tipo: data['tipo'] ?? '',
      musculoSecundario: List<String>.from(data['musculoSecundario'] ?? []),
      equipamento: List<String>.from(data['equipamento'] ?? []),
      frames: List<String>.from(data['frames'] ?? []),
      steps: List<String>.from(data['steps'] ?? []),
      cuidados: List<String>.from(data['cuidados'] ?? []),
      vetorForca: data['vetorForca'] ?? '',
      planoMovimento: data['planoMovimento'] ?? '',
      ativacaoMuscular: (data['ativacaoMuscular'] ?? 0.0).toDouble(),
      escoreRiscoLesao: (data['escoreRiscoLesao'] ?? 0.0).toDouble(),
    );
  }
}