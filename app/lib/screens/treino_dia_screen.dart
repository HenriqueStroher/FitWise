import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/treino.dart';
import '../services/treino_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import '../widgets/treino_comuns.dart';
import 'evolucao_exercicio_screen.dart';
import 'seletor_exercicio_screen.dart';

/// Treino de um dia da semana atual: monta a lista de exercícios (plano) e
/// registra as séries feitas nesta semana.
///
/// Mudanças na lista (adicionar, trocar, remover, reordenar) gravam o plano
/// do dia na hora. Séries gravam no documento da semana atual com um pequeno
/// atraso, para não escrever a cada tecla.
class TreinoDiaScreen extends StatefulWidget {
  final int dia;
  final TreinoService service;

  const TreinoDiaScreen({super.key, required this.dia, required this.service});

  @override
  State<TreinoDiaScreen> createState() => _TreinoDiaScreenState();
}

enum _Salvamento { salvo, pendente, salvando, erro }

class _TreinoDiaScreenState extends State<TreinoDiaScreen> {
  final DateTime _inicioSemana = SemanaTreino.inicioDe(DateTime.now());

  List<ExercicioTreino> _exercicios = [];

  /// Chave do exercício → última vez que ele foi registrado antes desta semana.
  Map<String, (SemanaTreino, ExercicioTreino)> _anteriores = {};

  bool _carregando = true;
  String? _erroCarga;
  _Salvamento _estado = _Salvamento.salvo;
  Timer? _atraso;

  TreinoService get _service => widget.service;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    // Grava o que ainda estava esperando o atraso
    if (_atraso?.isActive ?? false) {
      _atraso!.cancel();
      _service.salvarDiaDaSemana(_inicioSemana, widget.dia, _exercicios);
    }
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final resultados = await Future.wait([
        _service.buscarPlanoDoDia(widget.dia),
        _service.buscarSemana(_inicioSemana),
        _service.buscarHistorico(antesDe: _inicioSemana, limite: 12),
      ]);
      final plano = resultados[0] as List<ExercicioTreino>;
      final semana = resultados[1] as SemanaTreino?;
      final historico = resultados[2] as List<SemanaTreino>;

      // Junta o plano com as séries já registradas hoje nesta semana
      final registrados = {for (final e in semana?.dias[widget.dia] ?? <ExercicioTreino>[]) e.id: e};
      for (final e in plano) {
        e.series = registrados[e.id]?.series ?? [];
        _preparar(e);
      }

      // Histórico vem do mais recente para o mais antigo: o primeiro
      // encontrado para cada chave é a última vez
      final anteriores = <String, (SemanaTreino, ExercicioTreino)>{};
      for (final s in historico) {
        for (final ex in s.dias.values.expand((l) => l)) {
          if (ex.seriesPreenchidas.isEmpty) continue;
          anteriores.putIfAbsent(ex.chave, () => (s, ex));
        }
      }

      if (!mounted) return;
      setState(() {
        _exercicios = plano;
        _anteriores = anteriores;
        _carregando = false;
        _erroCarga = null;
      });
    } catch (e) {
      debugPrint('Meus Treinos: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erroCarga = 'Não foi possível carregar o treino. Verifique sua conexão.';
      });
    }
  }

  // ─────────────────────────────────────────
  // GRAVAÇÃO
  // ─────────────────────────────────────────

  Future<void> _gravar(Future<void> Function() acao) async {
    setState(() => _estado = _Salvamento.salvando);
    try {
      await acao();
      if (mounted) setState(() => _estado = _Salvamento.salvo);
    } catch (e) {
      debugPrint('Meus Treinos: $e');
      if (!mounted) return;
      setState(() => _estado = _Salvamento.erro);
      avisar(context, 'Não foi possível salvar. Verifique sua conexão.');
    }
  }

  /// Lista mudou: grava plano e registro da semana juntos, sem atraso.
  void _estruturaAlterada() {
    _atraso?.cancel();
    _gravar(() => Future.wait([
          _service.salvarPlano(widget.dia, _exercicios),
          _service.salvarDiaDaSemana(_inicioSemana, widget.dia, _exercicios),
        ]));
  }

  /// Uma série mudou: grava o registro da semana depois de uma pausa.
  void _seriesAlteradas() {
    setState(() => _estado = _Salvamento.pendente);
    _atraso?.cancel();
    _atraso = Timer(const Duration(milliseconds: 700), () {
      _gravar(() => _service.salvarDiaDaSemana(_inicioSemana, widget.dia, _exercicios));
    });
  }

  // ─────────────────────────────────────────
  // AÇÕES
  // ─────────────────────────────────────────

  /// Corrida e longão sempre mostram a linha de km e tempo, mesmo vazia.
  /// Linha vazia não é gravada (ver ExercicioTreino.toRegistroMap).
  ExercicioTreino _preparar(ExercicioTreino e) {
    if (e.registro == TipoRegistro.distancia && e.series.isEmpty) e.series.add(SerieRegistro());
    return e;
  }

  Future<void> _adicionar() async {
    final escolhas = await escolherExercicios(
      context,
      titulo: 'Adicionar exercícios',
      jaNoTreino: {for (final e in _exercicios) e.chave},
    );
    if (escolhas == null || escolhas.isEmpty) return;
    setState(() {
      _exercicios.addAll([
        for (final e in escolhas)
          _preparar(ExercicioTreino(id: ExercicioTreino.novoId(), nome: e.nome, slug: e.slug, registro: e.registro)),
      ]);
    });
    _estruturaAlterada();
  }

  Future<void> _trocar(ExercicioTreino ex) async {
    final escolha = await escolherExercicio(context, titulo: 'Trocar exercício', nomeAtual: ex.nome);
    if (escolha == null) return;
    setState(() {
      // Outro tipo de registro (ex.: musculação → corrida) não aproveita as
      // séries anteriores
      if (ex.registro != escolha.registro) ex.series = [];
      ex.nome = escolha.nome;
      ex.slug = escolha.slug;
      ex.registro = escolha.registro;
      _preparar(ex);
    });
    _estruturaAlterada();
  }

  Future<void> _remover(ExercicioTreino ex) async {
    if (ex.seriesPreenchidas.isNotEmpty) {
      final ok = await confirmar(
        context,
        titulo: 'Remover ${ex.nome}?',
        mensagem: 'O exercício sai do treino de ${DiaSemana.nome(widget.dia).toLowerCase()} e as séries '
            'desta semana são apagadas. Semanas anteriores não são afetadas.',
      );
      if (!ok) return;
    }
    setState(() => _exercicios.remove(ex));
    _estruturaAlterada();
  }

  Future<void> _limparDia() async {
    final nomeDia = DiaSemana.nome(widget.dia).toLowerCase();
    final ok = await confirmar(
      context,
      titulo: 'Limpar o treino de $nomeDia?',
      mensagem: 'Todos os ${_exercicios.length} exercícios saem deste dia, junto com as séries '
          'registradas nesta semana. As semanas anteriores continuam no histórico.',
      acao: 'Limpar',
    );
    if (!ok) return;
    setState(_exercicios.clear);
    _estruturaAlterada();
  }

  void _reordenar(int de, int para) {
    setState(() => _exercicios.insert(para, _exercicios.removeAt(de)));
    _estruturaAlterada();
  }

  void _verEvolucao(ExercicioTreino ex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvolucaoExercicioScreen(chave: ex.chave, nome: ex.nome, slug: ex.slug, service: _service),
      ),
    );
  }

  // ─────────────────────────────────────────
  // INTERFACE
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Conteudo(
          larguraMaxima: AppLayout.larguraLeitura,
          child: _carregando
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCabecalho(),
                    const SizedBox(height: 8),
                    for (var i = 0; i < 3; i++) ...[
                      const Esqueleto(altura: 150),
                      const SizedBox(height: 14),
                    ],
                  ],
                )
              : _erroCarga != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCabecalho(),
                        Text(_erroCarga!, style: AppTexto.item.copyWith(color: AppCores.textoSuave)),
                        const SizedBox(height: 12),
                        BotaoContorno(texto: 'Tentar de novo', icone: Icons.refresh, onTap: () {
                          setState(() => _carregando = true);
                          _carregar();
                        }),
                      ],
                    )
                  : _buildLista(),
        ),
      ),
      bottomNavigationBar: _carregando || _erroCarga != null
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppCores.fundo,
                border: Border(top: BorderSide(color: AppCores.linha)),
              ),
              child: SafeArea(
                top: false,
                // A Column encolhe a barra à altura do botão: sozinho, o
                // Center do Conteudo ocuparia a tela toda e esconderia a lista
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Conteudo(
                      larguraMaxima: AppLayout.larguraLeitura,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: BotaoDestaque(texto: 'Adicionar exercício', icone: Icons.add, onTap: _adicionar),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLista() {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 24),
      header: _buildCabecalho(),
      footer: _exercicios.isEmpty ? _buildVazio() : null,
      itemCount: _exercicios.length,
      onReorderItem: _reordenar,
      proxyDecorator: (filho, _, _) => Material(color: Colors.transparent, child: filho),
      itemBuilder: (_, i) {
        final ex = _exercicios[i];
        return Padding(
          key: ValueKey(ex.id),
          padding: const EdgeInsets.only(bottom: 14),
          child: _CardExercicio(
            indice: i,
            exercicio: ex,
            anterior: _anteriores[ex.chave],
            onSeriesAlteradas: _seriesAlteradas,
            onTrocar: () => _trocar(ex),
            onRemover: () => _remover(ex),
            onEvolucao: () => _verEvolucao(ex),
          ),
        );
      },
    );
  }

  Widget _buildCabecalho() {
    final largura = MediaQuery.sizeOf(context).width;
    final data = DateTime(_inicioSemana.year, _inicioSemana.month, _inicioSemana.day + widget.dia - 1);
    final feitos = _exercicios.where((e) => e.seriesPreenchidas.isNotEmpty).length;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BotaoVoltar(),
              const Spacer(),
              _IndicadorSalvamento(estado: _estado),
            ],
          ),
          const SizedBox(height: 24),
          Text('TREINO  ·  ${FormatoTreino.dataCompleta(data)}',
              style: AppTexto.rotulo.copyWith(color: AppCores.destaque)),
          const SizedBox(height: 8),
          Text(DiaSemana.nome(widget.dia).toUpperCase(),
              style: AppTexto.display((largura * 0.08).clamp(28.0, 48.0))),
          if (_exercicios.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_exercicios.length} ${_exercicios.length == 1 ? 'exercício' : 'exercícios'}'
                    '  ·  $feitos registrado${feitos == 1 ? '' : 's'} nesta semana',
                    style: AppTexto.meta,
                  ),
                ),
                const SizedBox(width: 12),
                Pressionavel(
                  onTap: _limparDia,
                  builder: (_, ativo) => Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined,
                          size: 16, color: ativo ? AppCores.erro : AppCores.textoSuave),
                      const SizedBox(width: 6),
                      Text('Limpar',
                          style: AppTexto.meta.copyWith(color: ativo ? AppCores.erro : AppCores.textoSuave)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppCores.superficie,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nenhum exercício ainda', style: AppTexto.titulo(18)),
          const SizedBox(height: 8),
          Text(
            'Adicione exercícios do catálogo ou com um nome seu. Eles ficam salvos '
            'no treino de ${DiaSemana.nome(widget.dia).toLowerCase()} e aparecem toda semana '
            'para você registrar as séries.',
            style: AppTexto.corpo,
          ),
        ],
      ),
    );
  }
}

class _IndicadorSalvamento extends StatelessWidget {
  final _Salvamento estado;

  const _IndicadorSalvamento({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (texto, cor, icone) = switch (estado) {
      _Salvamento.salvo => ('Salvo', AppCores.textoApagado, Icons.cloud_done_outlined),
      _Salvamento.pendente || _Salvamento.salvando =>
        ('Salvando…', AppCores.textoSuave, Icons.cloud_upload_outlined),
      _Salvamento.erro => ('Não salvo', AppCores.erro, Icons.cloud_off_outlined),
    };
    return Row(
      children: [
        Icon(icone, size: 16, color: cor),
        const SizedBox(width: 6),
        Text(texto, style: AppTexto.meta.copyWith(color: cor, fontSize: 12)),
      ],
    );
  }
}

// ─────────────────────────────────────────
// CARD DO EXERCÍCIO
// ─────────────────────────────────────────

// Larguras fixas das colunas da tabela de séries
const _larguraRotulo = 52.0;
const _larguraPace = 76.0;
const _larguraRemover = 40.0;

class _CardExercicio extends StatelessWidget {
  final int indice;
  final ExercicioTreino exercicio;
  final (SemanaTreino, ExercicioTreino)? anterior;
  final VoidCallback onSeriesAlteradas;
  final VoidCallback onTrocar;
  final VoidCallback onRemover;
  final VoidCallback onEvolucao;

  const _CardExercicio({
    required this.indice,
    required this.exercicio,
    required this.anterior,
    required this.onSeriesAlteradas,
    required this.onTrocar,
    required this.onRemover,
    required this.onEvolucao,
  });

  List<SerieRegistro> get _series => exercicio.series;
  TipoRegistro get _registro => exercicio.registro;

  /// Corrida e longão têm uma linha só, sem adicionar nem remover.
  bool get _unica => _registro == TipoRegistro.distancia;

  void _adicionarSerie() {
    // Começa vazia (os campos mostram "–"); a referência da última vez fica
    // no subtítulo do card
    _series.add(SerieRegistro());
    onSeriesAlteradas();
  }

  void _repetirUltimaVez() {
    _series
      ..clear()
      ..addAll(anterior!.$2.seriesPreenchidas.map((s) => s.copia()));
    onSeriesAlteradas();
  }

  void _removerSerie(SerieRegistro s) {
    _series.remove(s);
    onSeriesAlteradas();
  }

  Widget _cabecalhoTabela() {
    Text rotulo(String t, {TextAlign alinhamento = TextAlign.center}) =>
        Text(t, textAlign: alinhamento, style: AppTexto.rotulo.copyWith(fontSize: 10));

    final colunas = switch (_registro) {
      TipoRegistro.forca => [
          SizedBox(width: _larguraRotulo, child: rotulo('SÉRIE', alinhamento: TextAlign.start)),
          Expanded(child: rotulo('REPS')),
          const SizedBox(width: 10),
          Expanded(child: rotulo('CARGA (KG)')),
          const SizedBox(width: _larguraRemover),
        ],
      TipoRegistro.tempo => [
          SizedBox(width: _larguraRotulo, child: rotulo('SÉRIE', alinhamento: TextAlign.start)),
          Expanded(child: rotulo('TEMPO (SEG)')),
          const SizedBox(width: _larguraRemover),
        ],
      TipoRegistro.distancia || TipoRegistro.intervalado => [
          if (!_unica) SizedBox(width: _larguraRotulo, child: rotulo('TIRO', alinhamento: TextAlign.start)),
          Expanded(child: rotulo('KM')),
          const SizedBox(width: 10),
          Expanded(child: rotulo('TEMPO')),
          SizedBox(width: _larguraPace, child: rotulo('PACE')),
          if (!_unica) const SizedBox(width: _larguraRemover),
        ],
    };
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(children: colunas),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pace = exercicio.paceMedio;
    final botoes = [
      if (!_unica)
        BotaoContorno(
          texto: _registro == TipoRegistro.intervalado ? 'Adicionar tiro' : 'Adicionar série',
          icone: Icons.add,
          compacto: true,
          onTap: _adicionarSerie,
        ),
      if (exercicio.seriesPreenchidas.isEmpty && anterior != null)
        BotaoContorno(
          texto: 'Repetir última vez',
          icone: Icons.replay_rounded,
          compacto: true,
          onTap: _repetirUltimaVez,
        ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      decoration: BoxDecoration(
        color: AppCores.superficie,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppCores.linha),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MiniaturaExercicio(slug: exercicio.slug, nome: exercicio.nome),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercicio.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTexto.item),
                    const SizedBox(height: 4),
                    Text(
                      anterior == null
                          ? 'Primeira vez registrando'
                          : 'Última vez (${FormatoTreino.data(anterior!.$1.inicio)}): '
                              '${FormatoTreino.resumoExercicio(anterior!.$2)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTexto.meta.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: indice,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator_rounded, color: AppCores.textoApagado, size: 22),
                  ),
                ),
              ),
              _MenuExercicio(onTrocar: onTrocar, onEvolucao: onEvolucao, onRemover: onRemover),
            ],
          ),
          const SizedBox(height: 14),
          if (_series.isNotEmpty) ...[
            _cabecalhoTabela(),
            const SizedBox(height: 8),
            for (var i = 0; i < _series.length; i++)
              _LinhaSerie(
                key: ObjectKey(_series[i]),
                registro: _registro,
                numero: _unica ? null : i + 1,
                serie: _series[i],
                onAlterada: onSeriesAlteradas,
                onRemover: _unica ? null : () => _removerSerie(_series[i]),
              ),
            if (_registro == TipoRegistro.intervalado && pace != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8, right: 8),
                child: Text(
                  'Total ${FormatoTreino.km(exercicio.distanciaTotal)}  ·  pace médio ${FormatoTreino.pace(pace)}',
                  style: AppTexto.meta.copyWith(fontSize: 12, color: AppCores.texto),
                ),
              ),
            const SizedBox(height: 4),
          ],
          if (botoes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: botoes),
            ),
        ],
      ),
    );
  }
}

class _MenuExercicio extends StatelessWidget {
  final VoidCallback onTrocar;
  final VoidCallback onEvolucao;
  final VoidCallback onRemover;

  const _MenuExercicio({required this.onTrocar, required this.onEvolucao, required this.onRemover});

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<VoidCallback> item(String texto, IconData icone, VoidCallback acao, {Color? cor}) {
      return PopupMenuItem(
        value: acao,
        child: Row(
          children: [
            Icon(icone, size: 18, color: cor ?? AppCores.textoSuave),
            const SizedBox(width: 12),
            Text(texto, style: AppTexto.item.copyWith(fontSize: 14, color: cor)),
          ],
        ),
      );
    }

    return PopupMenuButton<VoidCallback>(
      tooltip: 'Opções',
      color: AppCores.superficieAlta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      icon: const Icon(Icons.more_vert_rounded, color: AppCores.textoSuave, size: 20),
      onSelected: (acao) => acao(),
      itemBuilder: (_) => [
        item('Trocar / editar exercício', Icons.edit_outlined, onTrocar),
        item('Ver evolução', Icons.show_chart_rounded, onEvolucao),
        item('Remover do treino', Icons.delete_outline_rounded, onRemover, cor: AppCores.erro),
      ],
    );
  }
}

/// Uma linha da tabela. Edita o [SerieRegistro] direto e avisa o card a cada
/// mudança. Os campos dependem do tipo de registro: reps e carga (força),
/// km e tempo com o pace calculado (corrida) ou só segundos (alongamento).
/// Os controladores vivem aqui para o cursor não pular quando a tela
/// reconstrói.
class _LinhaSerie extends StatefulWidget {
  final TipoRegistro registro;

  /// Número da série; nulo na corrida de linha única.
  final int? numero;
  final SerieRegistro serie;
  final VoidCallback onAlterada;
  final VoidCallback? onRemover;

  const _LinhaSerie({
    super.key,
    required this.registro,
    required this.numero,
    required this.serie,
    required this.onAlterada,
    required this.onRemover,
  });

  @override
  State<_LinhaSerie> createState() => _LinhaSerieState();
}

class _LinhaSerieState extends State<_LinhaSerie> {
  late final TextEditingController _primeiro;
  late final TextEditingController _segundo;

  SerieRegistro get _s => widget.serie;

  @override
  void initState() {
    super.initState();
    String num(double? v) => v == null ? '' : FormatoTreino.numero(v);
    switch (widget.registro) {
      case TipoRegistro.forca:
        _primeiro = TextEditingController(text: _s.reps?.toString() ?? '');
        _segundo = TextEditingController(text: num(_s.carga));
      case TipoRegistro.tempo:
        _primeiro = TextEditingController(text: _s.tempo?.toString() ?? '');
        _segundo = TextEditingController();
      case TipoRegistro.distancia:
      case TipoRegistro.intervalado:
        _primeiro = TextEditingController(text: num(_s.distancia));
        _segundo = TextEditingController(text: _s.tempo == null ? '' : FormatoTreino.duracao(_s.tempo!));
    }
  }

  @override
  void dispose() {
    _primeiro.dispose();
    _segundo.dispose();
    super.dispose();
  }

  void _alterar(VoidCallback mudanca) {
    mudanca();
    // Reconstrói esta linha para o pace acompanhar a digitação
    if (widget.registro.corrida) setState(() {});
    widget.onAlterada();
  }

  Widget _campo(
    TextEditingController c, {
    required RegExp permitido,
    required int tamanho,
    required ValueChanged<String> aoMudar,
    bool decimal = false,
    bool duracao = false,
    String dica = '–',
  }) {
    return TextField(
      controller: c,
      onChanged: aoMudar,
      // Seleciona tudo ao tocar, para trocar o valor sem apagar antes
      onTap: () => c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length),
      keyboardType: duracao ? TextInputType.datetime : TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(permitido),
        LengthLimitingTextInputFormatter(tamanho),
      ],
      textAlign: TextAlign.center,
      style: AppTexto.titulo(17, peso: FontWeight.w700)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      decoration: decoracaoCampo(dica).copyWith(
        fillColor: AppCores.superficieAlta,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inteiro = RegExp(r'[0-9]');
    final decimal = RegExp(r'[0-9.,]');

    final campos = switch (widget.registro) {
      TipoRegistro.forca => [
          Expanded(
            child: _campo(_primeiro, permitido: inteiro, tamanho: 3, aoMudar: (t) {
              _alterar(() => _s.reps = int.tryParse(t));
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _campo(_segundo, permitido: decimal, tamanho: 6, decimal: true, aoMudar: (t) {
              _alterar(() => _s.carga = FormatoTreino.lerNumero(t));
            }),
          ),
        ],
      TipoRegistro.tempo => [
          Expanded(
            child: _campo(_primeiro, permitido: inteiro, tamanho: 4, aoMudar: (t) {
              _alterar(() => _s.tempo = int.tryParse(t));
            }),
          ),
        ],
      TipoRegistro.distancia || TipoRegistro.intervalado => [
          Expanded(
            child: _campo(_primeiro, permitido: decimal, tamanho: 6, decimal: true, aoMudar: (t) {
              _alterar(() => _s.distancia = FormatoTreino.lerNumero(t));
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _campo(_segundo,
                permitido: RegExp(r'[0-9:]'), tamanho: 8, duracao: true, dica: 'mm:ss', aoMudar: (t) {
              _alterar(() => _s.tempo = FormatoTreino.lerDuracao(t));
            }),
          ),
          SizedBox(
            width: _larguraPace,
            child: Text(
              _s.pace == null ? '–' : FormatoTreino.duracao(_s.pace!.round()),
              textAlign: TextAlign.center,
              style: AppTexto.numero.copyWith(
                fontSize: 15,
                color: _s.pace == null ? AppCores.textoApagado : AppCores.texto,
              ),
            ),
          ),
        ],
    };

    return Padding(
      padding: EdgeInsets.only(bottom: 8, right: widget.onRemover == null ? 8 : 0),
      child: Row(
        children: [
          if (widget.numero != null)
            SizedBox(
              width: _larguraRotulo,
              child: Text(
                widget.numero.toString().padLeft(2, '0'),
                style: AppTexto.numero.copyWith(fontSize: 15, color: AppCores.destaque),
              ),
            ),
          ...campos,
          if (widget.onRemover != null)
            IconButton(
              onPressed: widget.onRemover,
              tooltip: widget.registro == TipoRegistro.intervalado ? 'Remover tiro' : 'Remover série',
              icon: const Icon(Icons.close_rounded, color: AppCores.textoApagado, size: 18),
            ),
        ],
      ),
    );
  }
}
