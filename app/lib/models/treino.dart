// Modelos da área "Meus Treinos".
//
// O treino tem duas partes guardadas separadamente no Firestore:
// - o plano de cada dia da semana: quais exercícios e em que ordem;
// - os registros semanais: o que foi feito (séries, reps e cargas) em cada
//   dia de uma semana específica. Cada semana é um documento próprio, então
//   registrar a semana atual nunca altera as anteriores.

class DiaSemana {
  /// 1 = segunda ... 7 = domingo (mesma convenção de DateTime.weekday).
  static const nomes = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  static const curtos = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  static String nome(int dia) => nomes[dia - 1];
  static String curto(int dia) => curtos[dia - 1];
}

class SerieRegistro {
  int? reps;
  double? carga;

  SerieRegistro({this.reps, this.carga});

  SerieRegistro copia() => SerieRegistro(reps: reps, carga: carga);

  bool get preenchida => reps != null || carga != null;

  /// Carga × repetições; série sem um dos dois não conta.
  double get volume => (reps ?? 0) * (carga ?? 0);

  factory SerieRegistro.fromMap(Map<String, dynamic> m) => SerieRegistro(
        reps: (m['reps'] as num?)?.toInt(),
        carga: (m['carga'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {'reps': reps, 'carga': carga};
}

/// Um exercício dentro de um dia. No plano, [series] fica vazio; no registro
/// semanal, guarda o que foi feito.
class ExercicioTreino {
  final String id;
  String nome;

  /// Slug do catálogo, quando o exercício veio de lá (habilita a ilustração).
  /// Nulo para exercícios com nome livre.
  String? slug;
  List<SerieRegistro> series;

  ExercicioTreino({
    required this.id,
    required this.nome,
    this.slug,
    List<SerieRegistro>? series,
  }) : series = series ?? [];

  /// Identifica "o mesmo exercício" entre semanas diferentes, para mostrar a
  /// referência da última vez e a evolução. Não usa o [id], que muda se o
  /// exercício for removido e adicionado de novo.
  String get chave => chaveDe(nome, slug);

  static String chaveDe(String nome, String? slug) =>
      (slug != null && slug.isNotEmpty) ? 'slug:$slug' : 'nome:${nome.trim().toLowerCase()}';

  List<SerieRegistro> get seriesPreenchidas => series.where((s) => s.preenchida).toList();

  double get volume => series.fold(0, (t, s) => t + s.volume);

  double? get cargaMaxima {
    final cargas = series.map((s) => s.carga).whereType<double>();
    return cargas.isEmpty ? null : cargas.reduce((a, b) => a > b ? a : b);
  }

  factory ExercicioTreino.fromMap(Map<String, dynamic> m) => ExercicioTreino(
        id: m['id'] ?? '',
        nome: m['nome'] ?? '',
        slug: m['slug'],
        series: [
          for (final s in (m['series'] as List? ?? []))
            SerieRegistro.fromMap(Map<String, dynamic>.from(s)),
        ],
      );

  Map<String, dynamic> toPlanoMap() => {'id': id, 'nome': nome, 'slug': slug};

  Map<String, dynamic> toRegistroMap() => {
        ...toPlanoMap(),
        'series': [for (final s in seriesPreenchidas) s.toMap()],
      };

  /// Id único mesmo para vários exercícios criados no mesmo instante (na
  /// web o relógio só tem precisão de milissegundos).
  static String novoId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(_contador++).toRadixString(36)}';
  static int _contador = 0;
}

/// Registro de uma semana (segunda a domingo).
class SemanaTreino {
  final DateTime inicio;

  /// Dia da semana (1–7) → exercícios realizados naquele dia.
  final Map<int, List<ExercicioTreino>> dias;

  SemanaTreino({required this.inicio, required this.dias});

  DateTime get fim => DateTime(inicio.year, inicio.month, inicio.day + 6);

  String get id => idDe(inicio);

  /// Dias com pelo menos uma série registrada, em ordem.
  List<int> get diasTreinados => [
        for (var d = 1; d <= 7; d++)
          if ((dias[d] ?? []).any((e) => e.seriesPreenchidas.isNotEmpty)) d,
      ];

  int get totalSeries =>
      dias.values.expand((l) => l).fold(0, (t, e) => t + e.seriesPreenchidas.length);

  double get volume => dias.values.expand((l) => l).fold(0, (t, e) => t + e.volume);

  /// Segunda-feira da semana que contém [data].
  static DateTime inicioDe(DateTime data) =>
      DateTime(data.year, data.month, data.day - (data.weekday - 1));

  /// Id do documento: a segunda-feira em AAAA-MM-DD, que também ordena as
  /// semanas cronologicamente.
  static String idDe(DateTime inicio) =>
      '${inicio.year.toString().padLeft(4, '0')}-'
      '${inicio.month.toString().padLeft(2, '0')}-'
      '${inicio.day.toString().padLeft(2, '0')}';

  factory SemanaTreino.fromFirestore(String id, Map<String, dynamic> data) {
    final p = id.split('-').map(int.parse).toList();
    final brutos = Map<String, dynamic>.from(data['dias'] ?? {});
    return SemanaTreino(
      inicio: DateTime(p[0], p[1], p[2]),
      dias: {
        for (final e in brutos.entries)
          int.parse(e.key): [
            for (final ex in (e.value as List? ?? []))
              ExercicioTreino.fromMap(Map<String, dynamic>.from(ex)),
          ],
      },
    );
  }
}

/// Formatação compartilhada pelas telas de treino.
class FormatoTreino {
  static String data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static String dataCompleta(DateTime d) => '${data(d)}/${d.year}';

  static String periodo(SemanaTreino s) =>
      '${dataCompleta(s.inicio)} até ${dataCompleta(s.fim)}';

  /// 20 → "20", 22.5 → "22,5".
  static String numero(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');
  }

  /// 12340 → "12.340".
  static String milhar(double v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String serie(SerieRegistro s) {
    final reps = s.reps?.toString() ?? '–';
    final carga = s.carga == null ? '–' : numero(s.carga!);
    return '$reps × $carga kg';
  }

  /// "12×20 · 10×25 · 8×30" — resumo compacto de uma lista de séries.
  static String resumo(List<SerieRegistro> series) => series
      .map((s) => '${s.reps ?? '–'}×${s.carga == null ? '–' : numero(s.carga!)}')
      .join('  ·  ');

  static double? lerNumero(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));
}
