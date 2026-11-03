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

Future<_ServicoFalso> _abrirTerca(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1100, 925);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final servico = _ServicoFalso({
    2: [
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
    expect(barra.top, greaterThan(800));

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
