import 'package:flutter/material.dart';
import '../models/exercicio.dart';
import '../services/recomendacao_service.dart';
import '../services/exercicio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import 'lista_exercicios_screen.dart';

class SugestoesScreen extends StatefulWidget {
  final Exercicio exercicioOrigem;

  const SugestoesScreen({super.key, required this.exercicioOrigem});

  @override
  State<SugestoesScreen> createState() => _SugestoesScreenState();
}

class _SugestoesScreenState extends State<SugestoesScreen> {
  final RecomendacaoService _recomendacao = RecomendacaoService();
  final ExercicioService _exercicioService = ExercicioService();

  List<MapEntry<Exercicio, double>> _sugestoes = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _gerarSugestoes();
  }

  Future<void> _gerarSugestoes() async {
    final catalogo = await _exercicioService
        .buscarPorGrupo(widget.exercicioOrigem.musculoPrimario);

    final sugestoes = _recomendacao.sugerirVariacoes(
      widget.exercicioOrigem,
      catalogo,
    );

    if (!mounted) return;
    setState(() {
      _sugestoes = sugestoes;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: SafeArea(
        child: Conteudo(
          larguraMaxima: AppLayout.larguraLeitura,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: BotaoVoltar()),
              const SizedBox(height: 28),
              Text('VARIAÇÕES DE', style: AppTexto.rotulo),
              const SizedBox(height: 8),
              Text(widget.exercicioOrigem.nome,
                  style: AppTexto.titulo(largura >= 720 ? 36 : 28)),
              const SizedBox(height: 10),
              Text(
                _carregando
                    ? ''
                    : '${_sugestoes.length} ${_sugestoes.length == 1 ? 'opção' : 'opções'}  ·  ordenadas por similaridade',
                style: AppTexto.meta,
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildLista()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLista() {
    if (_carregando) {
      return Column(
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Esqueleto(largura: 72, altura: 72, raio: 4),
                  SizedBox(width: 16),
                  Expanded(child: Esqueleto(altura: 14)),
                  SizedBox(width: 40),
                  Esqueleto(largura: 44, altura: 20),
                ],
              ),
            ),
        ],
      );
    }

    if (_sugestoes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(
          'Nenhum exercício do mesmo grupo é parecido o bastante com este.',
          style: AppTexto.item.copyWith(color: AppCores.textoSuave),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: _sugestoes.length,
      itemBuilder: (context, index) {
        final entry = _sugestoes[index];
        return LinhaExercicio(
          exercicio: entry.key,
          trailing: _Similaridade(score: entry.value),
        );
      },
    );
  }
}

class _Similaridade extends StatelessWidget {
  final double score;

  const _Similaridade({required this.score});

  @override
  Widget build(BuildContext context) {
    final cor = score >= 0.90
        ? AppCores.destaque
        : (score >= 0.75 ? AppCores.texto : AppCores.textoSuave);

    return SizedBox(
      width: 52,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${(score * 100).round()}%',
            style: AppTexto.titulo(18, cor: cor, peso: FontWeight.w700)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: score,
                backgroundColor: AppCores.linha,
                valueColor: AlwaysStoppedAnimation<Color>(cor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
