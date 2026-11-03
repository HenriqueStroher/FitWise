import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_treino_ia/models/treino.dart';
import 'package:tcc_treino_ia/screens/treino_dia_screen.dart';
import 'package:tcc_treino_ia/services/treino_service.dart';
import 'package:tcc_treino_ia/theme/app_theme.dart';
import 'package:tcc_treino_ia/widgets/comuns.dart';

/// Serviço em memória, para testar a tela sem Firebase.
class _ServicoFalso implements TreinoService {
  final Map<int, List<ExercicioTreino>> plano;
  final List<String> gravacoes = [];

  _ServicoFalso(this.plano);

  @override
  String get uid => 'teste';

  @override
  Future<Map<int, List<ExercicioTreino>>> buscarPlano() async => plano;

  @override
  Future<List<ExercicioTreino>> buscarPlanoDoDia(int dia) async => plano[dia] ?? [];

  @override
  Future<void> salvarPlano(int dia, List<ExercicioTreino> exercicios) async {
    gravacoes.add('plano');
    plano[dia] = List.of(exercicios);
  }

  @override
  Future<SemanaTreino?> buscarSemana(DateTime inicio) async => null;

  @override
  Future<void> salvarDiaDaSemana(DateTime inicio, int dia, List<ExercicioTreino> exercicios) async =>
      gravacoes.add('semana');

  @override
  Future<List<SemanaTreino>> buscarHistorico({DateTime? antesDe, int? limite}) async => [];
}

Future<_ServicoFalso> _abrirTerca(WidgetTester tester,
    {List<ExercicioTreino>? exercicios, Size tela = const Size(1100, 1400)}) async {
  tester.view.physicalSize = tela;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final servico = _ServicoFalso({
    2: exercicios ??
        [
          ExercicioTreino(id: 'a', nome: 'Supino reto'),
          ExercicioTreino(id: 'b', nome: 'Crucifixo'),
        ],
  });

  await tester.pumpWidget(MaterialApp(
    theme: construirTema(),
    home: TreinoDiaScreen(dia: 2, service: servico),
  ));
  await tester.pumpAndSettle();
  return servico;
}

void main() {
  testWidgets('tiros cabem numa tela de celular pequena', (tester) async {
    await _abrirTerca(tester, tela: const Size(360, 1400), exercicios: [
      ExercicioTreino(id: 'c', nome: 'Corrida', registro: TipoRegistro.distancia),
      ExercicioTreino(id: 't', nome: 'Tiro (Intervalado)', registro: TipoRegistro.intervalado),
    ]);
    await tester.tap(find.text('Adicionar tiro'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), '0,4');
    await tester.enterText(find.byType(TextField).at(3), '1:40');
    await tester.pump();
    // Um estouro de layout (RenderFlex overflow) faria o teste falhar
    expect(find.text('4:10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('corrida, tiro e alongamento mostram os campos certos e calculam o pace', (tester) async {
    final servico = await _abrirTerca(tester, exercicios: [
      ExercicioTreino(id: 'c', nome: 'Corrida', registro: TipoRegistro.distancia),
      ExercicioTreino(id: 't', nome: 'Tiro (Intervalado)', registro: TipoRegistro.intervalado),
      ExercicioTreino(id: 'a', nome: 'Borboleta', registro: TipoRegistro.tempo),
    ]);

    // Corrida já abre com a linha de km e tempo, sem "Adicionar série"
    expect(find.text('KM'), findsOneWidget);
    expect(find.text('PACE'), findsOneWidget);
    expect(find.text('Adicionar tiro'), findsOneWidget);
    expect(find.text('Adicionar série'), findsOneWidget); // só o alongamento

    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), '5');
    await tester.enterText(campos.at(1), '25:30');
    await tester.pump();
    expect(find.text('5:06'), findsOneWidget);

    // Dois tiros: aparecem numerados, com pace e o total
    await tester.tap(find.text('Adicionar tiro'));
    await tester.pump();
    await tester.tap(find.text('Adicionar tiro'));
    await tester.pump();
    expect(find.text('TIRO'), findsOneWidget);
    final tiros = find.byType(TextField);
    await tester.enterText(tiros.at(2), '0,4');
    await tester.enterText(tiros.at(3), '1:40');
    await tester.enterText(tiros.at(4), '0,4');
    await tester.enterText(tiros.at(5), '1:32');
    await tester.pump();
    expect(find.text('4:10'), findsOneWidget);
    expect(find.text('3:50'), findsOneWidget);
    expect(find.textContaining('pace médio 4:00 /km'), findsOneWidget);

    // Alongamento: só segundos
    await tester.tap(find.text('Adicionar série'));
    await tester.pump();
    expect(find.text('TEMPO (SEG)'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(7));

    await tester.pump(const Duration(seconds: 1));
    expect(servico.gravacoes, contains('semana'));
  });

  testWidgets('limpar remove todos os exercícios do dia depois de confirmar', (tester) async {
    final servico = await _abrirTerca(tester);

    // Cancelar não apaga nada
    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Supino reto'), findsOneWidget);
    expect(servico.gravacoes, isEmpty);

    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar').last); // botão do diálogo
    await tester.pumpAndSettle();
    expect(find.text('Supino reto'), findsNothing);
    expect(find.text('Crucifixo'), findsNothing);
    expect(find.text('Nenhum exercício ainda'), findsOneWidget);
    expect(servico.plano[2], isEmpty);
    expect(servico.gravacoes, containsAll(['plano', 'semana']));
  });

  testWidgets('lista de exercícios e voltar aparecem com a barra inferior', (tester) async {
    final servico = await _abrirTerca(tester);

    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('Crucifixo'), findsOneWidget);
    expect(find.byType(BotaoVoltar), findsOneWidget);

    // A barra inferior fica só com a altura do botão
    final barra = tester.getRect(find.text('Adicionar exercício'));
    expect(barra.top, greaterThan(1250));

    // Adicionar série grava o registro da semana (depois do atraso)
    await tester.tap(find.text('Adicionar série').first);
    await tester.pump(const Duration(seconds: 1));
    expect(servico.gravacoes, contains('semana'));
    expect(find.text('01'), findsOneWidget);

    // A série nova começa vazia, mesmo depois de preencher a anterior
    final campos = find.byType(TextField);
    expect(tester.widget<TextField>(campos.at(0)).controller!.text, '');
    expect(tester.widget<TextField>(campos.at(1)).controller!.text, '');
    await tester.enterText(campos.at(0), '12');
    await tester.enterText(campos.at(1), '20');
    await tester.tap(find.text('Adicionar série').first);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('02'), findsOneWidget);
    final novos = find.byType(TextField);
    expect(tester.widget<TextField>(novos.at(2)).controller!.text, '');
    expect(tester.widget<TextField>(novos.at(3)).controller!.text, '');
  });
}
