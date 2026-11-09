import 'package:flutter/material.dart';
import '../models/treino.dart';
import '../services/treino_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import '../widgets/treino_comuns.dart';
import 'evolucao_exercicio_screen.dart';

/// Todas as semanas registradas, da mais recente para a mais antiga.
class HistoricoScreen extends StatefulWidget {
  final TreinoService service;

  /// Linha acima do título; o professor vê o nome do aluno.
  final String rotulo;

  const HistoricoScreen({super.key, required this.service, this.rotulo = 'MEUS TREINOS'});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final String _semanaAtual = SemanaTreino.idDe(SemanaTreino.inicioDe(DateTime.now()));

  List<SemanaTreino> _semanas = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final semanas = await widget.service.buscarHistorico();
      if (!mounted) return;
      setState(() {
        _semanas = semanas;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Meus Treinos: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar o histórico. Verifique sua conexão.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Conteudo(
          larguraMaxima: AppLayout.larguraLeitura,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: BotaoVoltar()),
              const SizedBox(height: 24),
              Text(widget.rotulo, style: AppTexto.rotulo.copyWith(color: AppCores.destaque)),
              const SizedBox(height: 8),
              Text('HISTÓRICO', style: AppTexto.display((largura * 0.085).clamp(30.0, 56.0))),
              const SizedBox(height: 12),
              Text(
                _carregando
                    ? ''
                    : '${_semanas.length} ${_semanas.length == 1 ? 'semana registrada' : 'semanas registradas'}',
                style: AppTexto.meta,
              ),
              const SizedBox(height: 24),
              if (_carregando)
                for (var i = 0; i < 4; i++) ...[
                  const Esqueleto(altura: 72),
                  const SizedBox(height: 10),
                ]
              else if (_erro != null)
                Text(_erro!, style: AppTexto.item.copyWith(color: AppCores.textoSuave))
              else if (_semanas.isEmpty)
                Text(
                  'Nenhuma semana registrada ainda. Registre suas séries no treino do dia '
                  'e elas aparecem aqui, organizadas por semana.',
                  style: AppTexto.corpo,
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppCores.linha)),
                  ),
                  child: Column(
                    children: [
                      for (final s in _semanas)
                        _LinhaSemana(
                          semana: s,
                          atual: s.id == _semanaAtual,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SemanaScreen(semana: s, service: widget.service),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaSemana extends StatelessWidget {
  final SemanaTreino semana;
  final bool atual;
  final VoidCallback onTap;

  const _LinhaSemana({required this.semana, required this.atual, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dias = semana.diasTreinados;
    final meta = [
      '${dias.length} ${dias.length == 1 ? 'dia' : 'dias'}',
      '${semana.totalSeries} séries',
      if (semana.volume > 0) '${FormatoTreino.milhar(semana.volume)} kg de volume',
      if (semana.distancia > 0) '${FormatoTreino.km(semana.distancia)} corridos',
    ].join('  ·  ');

    return Pressionavel(
      onTap: onTap,
      builder: (_, ativo) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: ativo ? AppCores.superficie : Colors.transparent,
          border: const Border(bottom: BorderSide(color: AppCores.linha)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text('Semana ${FormatoTreino.periodo(semana)}', style: AppTexto.item),
                      ),
                      if (atual) ...[
                        const SizedBox(width: 8),
                        Text('ATUAL', style: AppTexto.rotulo.copyWith(fontSize: 10, color: AppCores.destaque)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(meta, style: AppTexto.meta),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var d = 1; d <= 7; d++)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 28,
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: dias.contains(d) ? AppCores.destaque : AppCores.superficieAlta,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            DiaSemana.curto(d)[0],
                            style: AppTexto.rotulo.copyWith(
                              fontSize: 10,
                              letterSpacing: 0,
                              color: dias.contains(d) ? AppCores.sobreDestaque : AppCores.textoApagado,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ativo ? AppCores.texto : AppCores.textoApagado),
          ],
        ),
      ),
    );
  }
}

/// Uma semana do histórico, somente leitura: dias treinados, exercícios e
/// cada série com repetições e carga.
class SemanaScreen extends StatelessWidget {
  final SemanaTreino semana;
  final TreinoService service;

  const SemanaScreen({super.key, required this.semana, required this.service});

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Conteudo(
          larguraMaxima: AppLayout.larguraLeitura,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: BotaoVoltar()),
              const SizedBox(height: 24),
              Text('SEMANA', style: AppTexto.rotulo.copyWith(color: AppCores.destaque)),
              const SizedBox(height: 8),
              Text(
                '${FormatoTreino.data(semana.inicio)} – ${FormatoTreino.data(semana.fim)}',
                style: AppTexto.display((largura * 0.085).clamp(30.0, 52.0)),
              ),
              const SizedBox(height: 8),
              Text('${semana.inicio.year}', style: AppTexto.meta),
              const SizedBox(height: 18),
              Wrap(
                spacing: 32,
                runSpacing: 8,
                children: [
                  NumeroLegenda('${semana.diasTreinados.length}', 'dias treinados'),
                  NumeroLegenda('${semana.totalSeries}', 'séries'),
                  if (semana.volume > 0) NumeroLegenda(FormatoTreino.milhar(semana.volume), 'kg de volume'),
                  if (semana.distancia > 0)
                    NumeroLegenda(FormatoTreino.numero(double.parse(semana.distancia.toStringAsFixed(1))), 'km corridos'),
                ],
              ),
              for (final dia in semana.diasTreinados) ...[
                const SizedBox(height: 36),
                _CabecalhoDia(semana: semana, dia: dia),
                const SizedBox(height: 12),
                for (final ex in semana.dias[dia]!.where((e) => e.seriesPreenchidas.isNotEmpty))
                  _ExercicioRegistrado(
                    exercicio: ex,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EvolucaoExercicioScreen(
                          chave: ex.chave,
                          nome: ex.nome,
                          slug: ex.slug,
                          service: service,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CabecalhoDia extends StatelessWidget {
  final SemanaTreino semana;
  final int dia;

  const _CabecalhoDia({required this.semana, required this.dia});

  @override
  Widget build(BuildContext context) {
    final data = DateTime(semana.inicio.year, semana.inicio.month, semana.inicio.day + dia - 1);
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppCores.linha)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(DiaSemana.nome(dia), style: AppTexto.titulo(20)),
          const Spacer(),
          Text(FormatoTreino.dataCompleta(data), style: AppTexto.meta),
        ],
      ),
    );
  }
}

/// Exercício de um dia do histórico com a tabela de séries.
class _ExercicioRegistrado extends StatelessWidget {
  final ExercicioTreino exercicio;
  final VoidCallback onTap;

  const _ExercicioRegistrado({required this.exercicio, required this.onTap});

  /// Uma série no formato do tipo de registro: "Série 1 · 12 repetições ·
  /// 20 kg", "Tiro 1 · 0,4 km · 1:40 · 4:10 /km", "Série 1 · 30 s".
  Widget _linha(int i, SerieRegistro s) {
    final destaque = AppTexto.titulo(15, peso: FontWeight.w700)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final meio = AppTexto.item.copyWith(fontSize: 14, fontWeight: FontWeight.w500);

    final (rotulo, centro, direita) = switch (exercicio.registro) {
      TipoRegistro.forca => (
          'Série ${i + 1}',
          '${s.reps ?? '–'} repetições',
          s.carga == null ? '– kg' : '${FormatoTreino.numero(s.carga!)} kg',
        ),
      TipoRegistro.tempo => ('Série ${i + 1}', '', s.tempo == null ? '– s' : '${s.tempo} s'),
      TipoRegistro.distancia || TipoRegistro.intervalado => (
          exercicio.registro == TipoRegistro.intervalado ? 'Tiro ${i + 1}' : 'Corrida',
          [
            s.distancia == null ? '– km' : FormatoTreino.km(s.distancia!),
            s.tempo == null ? '–' : FormatoTreino.duracao(s.tempo!),
          ].join('  ·  '),
          s.pace == null ? '–' : FormatoTreino.pace(s.pace!),
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(rotulo, style: AppTexto.meta)),
          Expanded(child: Text(centro, style: meio)),
          Text(direita, style: destaque),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final series = exercicio.seriesPreenchidas;
    final contagem = switch (exercicio.registro) {
      TipoRegistro.intervalado => '${series.length} ${series.length == 1 ? 'tiro' : 'tiros'}',
      TipoRegistro.distancia => '',
      _ => '${series.length} ${series.length == 1 ? 'série' : 'séries'}',
    };
    return Pressionavel(
      onTap: onTap,
      builder: (_, ativo) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppCores.superficie,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ativo ? AppCores.textoApagado : AppCores.linha),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MiniaturaExercicio(slug: exercicio.slug, nome: exercicio.nome, tamanho: 40),
                const SizedBox(width: 12),
                Expanded(child: Text(exercicio.nome, style: AppTexto.item)),
                Text(contagem, style: AppTexto.meta),
                const SizedBox(width: 6),
                const Icon(Icons.show_chart_rounded, color: AppCores.textoApagado, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < series.length; i++)
              _linha(i, series[i]),
            if (exercicio.registro == TipoRegistro.intervalado && exercicio.paceMedio != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Total ${FormatoTreino.km(exercicio.distanciaTotal)}  ·  '
                  'pace médio ${FormatoTreino.pace(exercicio.paceMedio!)}',
                  style: AppTexto.meta.copyWith(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
