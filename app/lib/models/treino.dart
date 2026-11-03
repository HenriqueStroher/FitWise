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

/// Como um exercício é anotado no treino do dia. Vem do catálogo
/// (Exercicio.registro); exercícios com nome livre são de força.
enum TipoRegistro {
  /// Séries de repetições e carga (musculação).
  forca,

  /// Uma corrida só, com distância e tempo (corrida, longão).
  distancia,

  /// Vários tiros, cada um com distância e tempo.
  intervalado,

  /// Séries com tempo em segundos (alongamentos).
  tempo;

  static TipoRegistro de(String? codigo) =>
      values.firstWhere((t) => t.name == codigo, orElse: () => forca);

  bool get corrida => this == distancia || this == intervalado;
}

/// Uma série. Cada tipo de registro usa só alguns campos: força usa [reps]
/// e [carga]; corrida usa [distancia] (km) e [tempo] (segundos); alongamento
/// usa só [tempo].
class SerieRegistro {
  int? reps;
  double? carga;
  double? distancia;
  int? tempo;

  SerieRegistro({this.reps, this.carga, this.distancia, this.tempo});

  SerieRegistro copia() => SerieRegistro(reps: reps, carga: carga, distancia: distancia, tempo: tempo);

  bool get preenchida => reps != null || carga != null || distancia != null || tempo != null;

  /// Carga × repetições; série sem um dos dois não conta.
  double get volume => (reps ?? 0) * (carga ?? 0);

  /// Segundos por km, quando há distância e tempo.
  double? get pace =>
      (distancia != null && distancia! > 0 && tempo != null && tempo! > 0) ? tempo! / distancia! : null;

  factory SerieRegistro.fromMap(Map<String, dynamic> m) => SerieRegistro(
        reps: (m['reps'] as num?)?.toInt(),
        carga: (m['carga'] as num?)?.toDouble(),
        distancia: (m['distancia'] as num?)?.toDouble(),
        tempo: (m['tempo'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        if (reps != null) 'reps': reps,
        if (carga != null) 'carga': carga,
        if (distancia != null) 'distancia': distancia,
        if (tempo != null) 'tempo': tempo,
      };
}

/// Um exercício dentro de um dia. No plano, [series] fica vazio; no registro
/// semanal, guarda o que foi feito.
class ExercicioTreino {
  final String id;
  String nome;

  /// Slug do catálogo, quando o exercício veio de lá (habilita a ilustração).
  /// Nulo para exercícios com nome livre.
  String? slug;
  TipoRegistro registro;
  List<SerieRegistro> series;

  ExercicioTreino({
    required this.id,
    required this.nome,
    this.slug,
    this.registro = TipoRegistro.forca,
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

  /// Soma dos km das séries (corrida).
  double get distanciaTotal => series.fold(0, (t, s) => t + (s.distancia ?? 0));

  /// Maior tempo de uma série, em segundos (alongamento).
  int? get tempoMaximo {
    final tempos = series.map((s) => s.tempo).whereType<int>();
    return tempos.isEmpty ? null : tempos.reduce((a, b) => a > b ? a : b);
  }

  /// Pace médio ponderado (tempo total ÷ distância total) das séries com
  /// distância e tempo. Segundos por km.
  double? get paceMedio {
    final validas = series.where((s) => s.pace != null);
    final km = validas.fold<double>(0, (t, s) => t + s.distancia!);
    final seg = validas.fold<int>(0, (t, s) => t + s.tempo!);
    return km > 0 ? seg / km : null;
  }

  factory ExercicioTreino.fromMap(Map<String, dynamic> m) => ExercicioTreino(
        id: m['id'] ?? '',
        nome: m['nome'] ?? '',
        slug: m['slug'],
        registro: TipoRegistro.de(m['registro']),
        series: [
          for (final s in (m['series'] as List? ?? []))
            SerieRegistro.fromMap(Map<String, dynamic>.from(s)),
        ],
      );

  Map<String, dynamic> toPlanoMap() => {
        'id': id,
        'nome': nome,
        'slug': slug,
        if (registro != TipoRegistro.forca) 'registro': registro.name,
      };

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

  /// Km corridos na semana.
  double get distancia => dias.values
      .expand((l) => l)
      .where((e) => e.registro.corrida)
      .fold(0, (t, e) => t + e.distanciaTotal);

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

  /// 1530 → "25:30", 3930 → "1:05:30".
  static String duracao(int segundos) {
    final h = segundos ~/ 3600, m = (segundos % 3600) ~/ 60, s = segundos % 60;
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  }

  /// Lê "25:30" (min:seg), "1:05:30" (h:min:seg) ou "25" (minutos).
  static int? lerDuracao(String texto) {
    final partes = texto.trim().split(':');
    if (partes.any((p) => p.isEmpty) || partes.length > 3) return null;
    final n = partes.map(int.tryParse).toList();
    if (n.contains(null)) return null;
    final v = n.cast<int>();
    return switch (v.length) {
      1 => v[0] * 60,
      2 => v[0] * 60 + v[1],
      _ => v[0] * 3600 + v[1] * 60 + v[2],
    };
  }

  /// Segundos por km → "5:06 /km".
  static String pace(double segPorKm) => '${duracao(segPorKm.round())} /km';

  static String km(double v) => '${numero(double.parse(v.toStringAsFixed(2)))} km';

  /// Resumo de um exercício conforme o tipo de registro, para a referência
  /// "Última vez" e o histórico.
  static String resumoExercicio(ExercicioTreino ex) {
    final series = ex.seriesPreenchidas;
    switch (ex.registro) {
      case TipoRegistro.forca:
        return resumo(series);
      case TipoRegistro.tempo:
        return series.map((s) => s.tempo == null ? '–' : '${s.tempo} s').join('  ·  ');
      case TipoRegistro.distancia:
      case TipoRegistro.intervalado:
        final pace = ex.paceMedio;
        return [
          if (ex.registro == TipoRegistro.intervalado)
            '${series.length} ${series.length == 1 ? 'tiro' : 'tiros'}',
          if (ex.distanciaTotal > 0) km(ex.distanciaTotal),
          if (ex.registro == TipoRegistro.distancia && series.isNotEmpty && series.first.tempo != null)
            duracao(series.first.tempo!),
          if (pace != null) FormatoTreino.pace(pace),
        ].join('  ·  ');
    }
  }
}
