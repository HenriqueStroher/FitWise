import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_treino_ia/models/exercicio.dart';
import 'package:tcc_treino_ia/navegacao.dart';
import 'package:tcc_treino_ia/screens/detalhe_exercicio_screen.dart';

Exercicio _ex(String slug, String nome) => Exercicio(
      id: slug,
      slug: slug,
      nome: nome,
      descricao: '',
      musculoPrimario: 'PEITO',
      tipo: '',
      musculoSecundario: const [],
      equipamento: const [],
      frames: const ['1', '2'],
      steps: const [],
      cuidados: const [],
      vetorForca: '',
      planoMovimento: '',
      ativacaoMuscular: 0,
      escoreRiscoLesao: 0,
    );

// Slugs reais: a tela pré-carrega as imagens em assets/images
final _lista = [
  _ex('bench-press', 'Supino A'),
  _ex('bench-press-dumbbell', 'Supino B'),
  _ex('incline-bench-press', 'Supino C'),
];

/// Abre o detalhe por cima de uma tela base, como no app.
Future<void> _abrir(WidgetTester tester, Exercicio ex, List<Exercicio> sequencia) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetalheExercicioScreen(exercicio: ex, sequencia: sequencia)),
          ),
          child: const Text('base'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('base'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('anterior e próximo percorrem a lista na mesma tela', (tester) async {
    await _abrir(tester, _lista[0], _lista);
    expect(find.text('Supino A'), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);

    // Na primeira posição, "anterior" não faz nada
    await tester.tap(find.byTooltip('Exercício anterior'));
    await tester.pump();
    expect(find.text('1 de 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Próximo exercício'));
    await tester.pump();
    expect(find.text('Supino B'), findsOneWidget);
    expect(find.text('2 de 3'), findsOneWidget);

    // A troca não empilha telas: voltar leva direto à base
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('base'), findsOneWidget);
  });

  testWidgets('setas do teclado também trocam de exercício', (tester) async {
    await _abrir(tester, _lista[1], _lista);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Supino C'), findsOneWidget);
    // Na última posição, a seta para a direita não passa do fim
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('3 de 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('Supino B'), findsOneWidget);
  });

  testWidgets('sem lista de origem, o navegador não aparece', (tester) async {
    await _abrir(tester, _lista[0], const []);
    expect(find.byTooltip('Próximo exercício'), findsNothing);
    expect(find.textContaining(' de '), findsNothing);
  });

  testWidgets('início fecha as telas empilhadas e volta à aba Grupos', (tester) async {
    Navegacao.aba.value = 1;
    await _abrir(tester, _lista[0], _lista);
    await tester.tap(find.byTooltip('Início'));
    await tester.pumpAndSettle();
    expect(find.text('base'), findsOneWidget);
    expect(Navegacao.aba.value, Navegacao.abaInicio);
  });
}
