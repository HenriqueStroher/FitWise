import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_treino_ia/models/treino.dart';

void main() {
  group('SemanaTreino', () {
    test('a semana começa na segunda-feira', () {
      // 03/11/2026 é uma terça; 08/11/2026 é domingo
      expect(SemanaTreino.inicioDe(DateTime(2026, 11, 3)), DateTime(2026, 11, 2));
      expect(SemanaTreino.inicioDe(DateTime(2026, 11, 2, 23, 59)), DateTime(2026, 11, 2));
      expect(SemanaTreino.inicioDe(DateTime(2026, 11, 8, 22)), DateTime(2026, 11, 2));
      expect(SemanaTreino.inicioDe(DateTime(2026, 11, 9)), DateTime(2026, 11, 9));
    });

    test('semana que atravessa a virada do ano', () {
      final inicio = SemanaTreino.inicioDe(DateTime(2027, 1, 1));
      expect(inicio, DateTime(2026, 12, 28));
      expect(SemanaTreino(inicio: inicio, dias: {}).fim, DateTime(2027, 1, 3));
    });

    test('id ordena cronologicamente e volta para a mesma data', () {
      final ids = [DateTime(2026, 9, 28), DateTime(2026, 11, 2), DateTime(2026, 10, 5)]
          .map(SemanaTreino.idDe)
          .toList()
        ..sort();
      expect(ids, ['2026-09-28', '2026-10-05', '2026-11-02']);
      expect(SemanaTreino.fromFirestore('2026-11-02', {}).inicio, DateTime(2026, 11, 2));
    });

    test('lê dias do Firestore e ignora exercícios sem séries', () {
      final s = SemanaTreino.fromFirestore('2026-11-02', {
        'dias': {
          '1': [
            {
              'id': 'a',
              'nome': 'Supino reto',
              'slug': 'bench-press',
              'series': [
                {'reps': 12, 'carga': 20},
                {'reps': 10, 'carga': 25},
                {'reps': 8, 'carga': 30.5},
              ],
            },
          ],
          '3': [],
        },
      });
      expect(s.diasTreinados, [1]);
      expect(s.totalSeries, 3);
      expect(s.volume, 12 * 20 + 10 * 25 + 8 * 30.5);
      expect(s.dias[1]!.first.cargaMaxima, 30.5);
    });
  });

  group('ExercicioTreino', () {
    test('a chave identifica o exercício entre semanas', () {
      final a = ExercicioTreino(id: '1', nome: 'Supino reto', slug: 'bench-press');
      final b = ExercicioTreino(id: '2', nome: 'Outro nome', slug: 'bench-press');
      final c = ExercicioTreino(id: '3', nome: '  Remada Cavalinho ');
      final d = ExercicioTreino(id: '4', nome: 'remada cavalinho');
      expect(a.chave, b.chave);
      expect(c.chave, d.chave);
      expect(a.chave, isNot(c.chave));
    });

    test('ids não se repetem mesmo criados no mesmo instante', () {
      final ids = {for (var i = 0; i < 50; i++) ExercicioTreino.novoId()};
      expect(ids.length, 50);
    });

    test('registro grava só as séries preenchidas', () {
      final ex = ExercicioTreino(id: '1', nome: 'Rosca', series: [
        SerieRegistro(reps: 10, carga: 12),
        SerieRegistro(),
      ]);
      expect(ex.toRegistroMap()['series'], [
        {'reps': 10, 'carga': 12.0},
      ]);
      expect(ex.toPlanoMap().containsKey('series'), isFalse);
    });
  });

  group('Corrida e alongamento', () {
    test('tempo: leitura e formatação', () {
      expect(FormatoTreino.lerDuracao('25:30'), 1530);
      expect(FormatoTreino.lerDuracao('1:05:30'), 3930);
      expect(FormatoTreino.lerDuracao('25'), 1500); // só número = minutos
      expect(FormatoTreino.lerDuracao(''), isNull);
      expect(FormatoTreino.lerDuracao('25:'), isNull);
      expect(FormatoTreino.duracao(1530), '25:30');
      expect(FormatoTreino.duracao(3930), '1:05:30');
      expect(FormatoTreino.duracao(65), '1:05');
    });

    test('pace da corrida', () {
      final corrida = ExercicioTreino(
        id: 'c',
        nome: 'Corrida',
        slug: 'corrida',
        registro: TipoRegistro.distancia,
        series: [SerieRegistro(distancia: 5, tempo: 1530)],
      );
      expect(corrida.paceMedio, 306); // 25:30 em 5 km = 5:06 /km
      expect(FormatoTreino.pace(corrida.paceMedio!), '5:06 /km');
      expect(FormatoTreino.resumoExercicio(corrida), '5 km  ·  25:30  ·  5:06 /km');
    });

    test('tiros: pace médio ponderado pela distância', () {
      final tiro = ExercicioTreino(
        id: 't',
        nome: 'Tiro',
        registro: TipoRegistro.intervalado,
        series: [
          SerieRegistro(distancia: 0.4, tempo: 100), // 4:10 /km
          SerieRegistro(distancia: 0.4, tempo: 92), // 3:50 /km
          SerieRegistro(distancia: 1, tempo: 270), // 4:30 /km
          SerieRegistro(), // vazia não conta
        ],
      );
      expect(tiro.series[0].pace, 250);
      expect(tiro.distanciaTotal, closeTo(1.8, 1e-9));
      expect(tiro.paceMedio, closeTo(462 / 1.8, 1e-9));
      expect(FormatoTreino.resumoExercicio(tiro), '3 tiros  ·  1,8 km  ·  4:17 /km');
    });

    test('alongamento registra segundos', () {
      final al = ExercicioTreino(
        id: 'a',
        nome: 'Borboleta',
        registro: TipoRegistro.tempo,
        series: [SerieRegistro(tempo: 30), SerieRegistro(tempo: 45)],
      );
      expect(al.tempoMaximo, 45);
      expect(FormatoTreino.resumoExercicio(al), '30 s  ·  45 s');
      expect(al.toRegistroMap()['series'], [
        {'tempo': 30},
        {'tempo': 45},
      ]);
    });

    test('tipo de registro vai e volta do Firestore', () {
      final ex = ExercicioTreino(id: 'x', nome: 'Tiro', slug: 'tiro', registro: TipoRegistro.intervalado);
      expect(ExercicioTreino.fromMap(ex.toPlanoMap()).registro, TipoRegistro.intervalado);
      // Dados antigos, gravados antes dos novos tipos, continuam como força
      expect(ExercicioTreino.fromMap({'id': 'y', 'nome': 'Supino'}).registro, TipoRegistro.forca);
      expect(TipoRegistro.de('qualquer'), TipoRegistro.forca);
    });

    test('semana soma os km corridos', () {
      final s = SemanaTreino.fromFirestore('2026-11-02', {
        'dias': {
          '2': [
            {'id': 'a', 'nome': 'Corrida', 'registro': 'distancia', 'series': [{'distancia': 5, 'tempo': 1500}]},
            {'id': 'b', 'nome': 'Supino', 'series': [{'reps': 10, 'carga': 20}]},
          ],
          '4': [
            {'id': 'c', 'nome': 'Tiro', 'registro': 'intervalado', 'series': [{'distancia': 0.4, 'tempo': 100}, {'distancia': 0.4, 'tempo': 98}]},
          ],
        },
      });
      expect(s.distancia, closeTo(5.8, 1e-9));
      expect(s.volume, 200);
    });
  });

  group('FormatoTreino', () {
    test('números', () {
      expect(FormatoTreino.numero(20), '20');
      expect(FormatoTreino.numero(22.5), '22,5');
      expect(FormatoTreino.numero(1.25), '1,25');
      expect(FormatoTreino.lerNumero('22,5'), 22.5);
      expect(FormatoTreino.lerNumero(''), isNull);
      expect(FormatoTreino.milhar(12340), '12.340');
      expect(FormatoTreino.milhar(999), '999');
      expect(FormatoTreino.milhar(1000000), '1.000.000');
    });

    test('período e resumo', () {
      final s = SemanaTreino(inicio: DateTime(2026, 11, 2), dias: {});
      expect(FormatoTreino.periodo(s), '02/11/2026 até 08/11/2026');
      expect(
        FormatoTreino.resumo([SerieRegistro(reps: 12, carga: 20), SerieRegistro(reps: 10)]),
        '12×20  ·  10×–',
      );
    });
  });
}
