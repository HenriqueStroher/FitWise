import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_treino_ia/models/academia.dart';
import 'package:tcc_treino_ia/models/exercicio.dart';
import 'package:tcc_treino_ia/services/recomendacao_service.dart';

Exercicio _ex(String slug, List<String> equipamento, {String vetor = 'horizontal', String plano = 'transversal'}) =>
    Exercicio(
      id: slug,
      slug: slug,
      nome: slug,
      descricao: '',
      musculoPrimario: 'PEITO',
      tipo: '',
      musculoSecundario: const [],
      equipamento: equipamento,
      frames: const [],
      steps: const [],
      cuidados: const [],
      vetorForca: vetor,
      planoMovimento: plano,
      ativacaoMuscular: 0,
      escoreRiscoLesao: 0,
    );

void main() {
  group('Academia.visivel', () {
    const academia = Academia(
      id: 'a',
      nome: 'Teste',
      donoUid: 'd',
      equipamentosIndisponiveis: {'smith'},
      exerciciosOcultos: {'hack'},
    );

    test('esconde o exercício que usa um equipamento que a academia não tem', () {
      final smith = _ex('supino-smith', ['smith', 'banco_reto']);
      expect(academia.visivel(smith), isFalse);
      expect(academia.equipamentoQueFalta(smith), 'smith');
    });

    test('esconde o exercício ocultado um a um, mesmo com o equipamento disponível', () {
      final hack = _ex('hack', ['maquina']);
      final legPress = _ex('leg-press', ['maquina']);
      expect(academia.visivel(hack), isFalse);
      expect(academia.equipamentoQueFalta(hack), isNull);
      expect(academia.visivel(legPress), isTrue);
    });

    test('exercício novo no catálogo aparece sem o dono precisar liberar', () {
      expect(academia.visivel(_ex('novo', ['haltere'])), isTrue);
      expect(academia.visivel(_ex('sem-equipamento', const [])), isTrue);
    });

    test('a recomendação, com o catálogo filtrado, só sugere o que a academia tem', () {
      final origem = _ex('supino-barra', ['barra', 'banco_reto']);
      final catalogo = [
        origem,
        _ex('supino-smith', ['smith', 'banco_reto']),
        _ex('supino-maquina', ['maquina_supino']),
      ];
      final todas = RecomendacaoService().sugerirVariacoes(origem, catalogo).map((e) => e.key.slug);
      final daAcademia = RecomendacaoService()
          .sugerirVariacoes(origem, catalogo.where(academia.visivel).toList())
          .map((e) => e.key.slug);
      expect(todas, contains('supino-maquina'));
      expect(daAcademia, isNot(contains('supino-smith')));
      expect(daAcademia, contains('supino-maquina'));
    });
  });

  group('Academia', () {
    test('lê o tipo: academia de verdade ou professor autônomo', () {
      expect(Academia.fromMap('a', {'nome': 'Ponto Fit', 'tipo': 'academia'}).autonomo, isFalse);
      expect(Academia.fromMap('p', {'nome': 'Júlia', 'tipo': 'autonomo'}).autonomo, isTrue);
      // Sem o campo (documentos antigos), é academia
      expect(Academia.fromMap('x', {'nome': 'X'}).autonomo, isFalse);
    });
  });

  group('Perfil', () {
    test('sem academia é usuário comum, mesmo com um papel gravado', () {
      final p = Perfil.fromMap('u', {'nome': 'Ana', 'papel': 'professor'});
      expect(p.papel, Papel.usuario);
    });

    test('lê papel, academia e professor', () {
      final p = Perfil.fromMap('u', {
        'nome': 'Bruna Lima',
        'email': 'b@x.com',
        'papel': 'aluno',
        'academiaId': 'a',
        'professorUid': 'p',
      });
      expect(p.papel, Papel.aluno);
      expect(p.professorUid, 'p');
      expect(p.primeiroNome, 'Bruna');
      expect(p.papel.ensina, isFalse);
    });

    test('dono também dá aula', () {
      expect(Papel.dono.ensina, isTrue);
      expect(Papel.professor.ensina, isTrue);
    });

    test('sem nome, mostra o e-mail', () {
      expect(Perfil.fromMap('u', {'email': 'x@y.com'}).exibicao, 'x@y.com');
    });
  });
}
