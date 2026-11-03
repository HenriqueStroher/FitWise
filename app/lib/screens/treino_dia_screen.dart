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

  Future<void> _adicionar() async {
    final escolhas = await escolherExercicios(
      context,
      titulo: 'Adicionar exercícios',
      jaNoTreino: {for (final e in _exercicios) e.chave},
    );
    if (escolhas == null || escolhas.isEmpty) return;
    setState(() {
      _exercicios.addAll([
        for (final e in escolhas) ExercicioTreino(id: ExercicioTreino.novoId(), nome: e.nome, slug: e.slug),
      ]);
    });
    _estruturaAlterada();
  }

  Future<void> _trocar(ExercicioTreino ex) async {
    final escolha = await escolherExercicio(context, titulo: 'Trocar exercício', nomeAtual: ex.nome);
    if (escolha == null) return;
    setState(() {
      ex.nome = escolha.nome;
      ex.slug = escolha.slug;
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

  @override
  Widget build(BuildContext context) {
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
                              '${FormatoTreino.resumo(anterior!.$2.seriesPreenchidas)}',
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
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  SizedBox(width: 52, child: Text('SÉRIE', style: AppTexto.rotulo.copyWith(fontSize: 10))),
                  Expanded(child: Text('REPS', textAlign: TextAlign.center, style: AppTexto.rotulo.copyWith(fontSize: 10))),
                  const SizedBox(width: 10),
                  Expanded(child: Text('CARGA (KG)', textAlign: TextAlign.center, style: AppTexto.rotulo.copyWith(fontSize: 10))),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _series.length; i++)
              _LinhaSerie(
                key: ObjectKey(_series[i]),
                numero: i + 1,
                serie: _series[i],
                onAlterada: onSeriesAlteradas,
                onRemover: () => _removerSerie(_series[i]),
              ),
            const SizedBox(height: 4),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BotaoContorno(texto: 'Adicionar série', icone: Icons.add, compacto: true, onTap: _adicionarSerie),
                if (_series.isEmpty && anterior != null)
                  BotaoContorno(
                    texto: 'Repetir última vez',
                    icone: Icons.replay_rounded,
                    compacto: true,
                    onTap: _repetirUltimaVez,
                  ),
              ],
            ),
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

/// Uma série: repetições e carga. Edita o [SerieRegistro] direto e avisa o
/// card a cada mudança. Os controladores vivem aqui para o cursor não pular
/// quando a tela reconstrói.
class _LinhaSerie extends StatefulWidget {
  final int numero;
  final SerieRegistro serie;
  final VoidCallback onAlterada;
  final VoidCallback onRemover;

  const _LinhaSerie({
    super.key,
    required this.numero,
    required this.serie,
    required this.onAlterada,
    required this.onRemover,
  });

  @override
  State<_LinhaSerie> createState() => _LinhaSerieState();
}

class _LinhaSerieState extends State<_LinhaSerie> {
  late final TextEditingController _reps =
      TextEditingController(text: widget.serie.reps?.toString() ?? '');
  late final TextEditingController _carga = TextEditingController(
      text: widget.serie.carga == null ? '' : FormatoTreino.numero(widget.serie.carga!));

  @override
  void dispose() {
    _reps.dispose();
    _carga.dispose();
    super.dispose();
  }

  Widget _campo(TextEditingController c, {required bool decimal, required ValueChanged<String> aoMudar}) {
    return TextField(
      controller: c,
      onChanged: aoMudar,
      // Seleciona tudo ao tocar, para trocar o valor sem apagar antes
      onTap: () => c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]')),
        LengthLimitingTextInputFormatter(decimal ? 6 : 3),
      ],
      textAlign: TextAlign.center,
      style: AppTexto.titulo(17, peso: FontWeight.w700)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      decoration: decoracaoCampo('–').copyWith(
        fillColor: AppCores.superficieAlta,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              widget.numero.toString().padLeft(2, '0'),
              style: AppTexto.numero.copyWith(fontSize: 15, color: AppCores.destaque),
            ),
          ),
          Expanded(
            child: _campo(_reps, decimal: false, aoMudar: (t) {
              widget.serie.reps = int.tryParse(t);
              widget.onAlterada();
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _campo(_carga, decimal: true, aoMudar: (t) {
              widget.serie.carga = FormatoTreino.lerNumero(t);
              widget.onAlterada();
            }),
          ),
          IconButton(
            onPressed: widget.onRemover,
            tooltip: 'Remover série',
            icon: const Icon(Icons.close_rounded, color: AppCores.textoApagado, size: 18),
          ),
        ],
      ),
    );
  }
}
