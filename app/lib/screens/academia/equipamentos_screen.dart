import 'package:flutter/material.dart';
import '../../models/academia.dart';
import '../../models/exercicio.dart';
import '../../models/grupo_muscular.dart';
import '../../models/rotulos.dart';
import '../../services/academia_service.dart';
import '../../services/exercicio_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comuns.dart';
import '../../widgets/treino_comuns.dart';

/// O dono diz o que a academia tem. Em duas etapas: primeiro os
/// equipamentos (sem Smith, some tudo que usa Smith), depois exercício por
/// exercício, para o que o equipamento não separa (as "Máquinas" incluem
/// leg press, hack, extensora...). Cada toque grava na hora; professores e
/// alunos passam a ver o catálogo filtrado, e a recomendação de trocas só
/// sugere o que existe na academia.
class EquipamentosScreen extends StatefulWidget {
  final Academia academia;

  const EquipamentosScreen({super.key, required this.academia});

  @override
  State<EquipamentosScreen> createState() => _EquipamentosScreenState();
}

class _EquipamentosScreenState extends State<EquipamentosScreen> {
  final AcademiaService _service = AcademiaService();

  late final Set<String> _indisponiveis = {...widget.academia.equipamentosIndisponiveis};
  late final Set<String> _ocultos = {...widget.academia.exerciciosOcultos};

  List<Exercicio> _catalogo = [];
  List<String> _equipamentos = [];
  String _grupo = GrupoMuscular.codigoPadrao;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final todos = await ExercicioService().buscarTodos(incluirOcultos: true);
      todos.sort((a, b) => a.nome.compareTo(b.nome));
      final equipamentos = {
        for (final ex in todos) ...ex.equipamento,
      }.difference(Academia.equipamentosSempreDisponiveis).toList()
        ..sort((a, b) => Rotulos.equipamento(a).compareTo(Rotulos.equipamento(b)));
      if (!mounted) return;
      setState(() {
        _catalogo = todos;
        _equipamentos = equipamentos;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Equipamentos: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// A academia com as escolhas atuais, para usar as mesmas regras do filtro.
  Academia get _atual => Academia(
        id: widget.academia.id,
        nome: widget.academia.nome,
        donoUid: widget.academia.donoUid,
        equipamentosIndisponiveis: _indisponiveis,
        exerciciosOcultos: _ocultos,
      );

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await _service.salvarDisponibilidade(
        widget.academia.id,
        equipamentosIndisponiveis: _indisponiveis,
        exerciciosOcultos: _ocultos,
      );
    } catch (e) {
      debugPrint('Equipamentos: $e');
      if (mounted) avisar(context, 'Não foi possível salvar. Verifique sua conexão.');
    }
    if (mounted) setState(() => _salvando = false);
  }

  void _alternarEquipamento(String eq) {
    setState(() => _indisponiveis.contains(eq) ? _indisponiveis.remove(eq) : _indisponiveis.add(eq));
    _salvar();
  }

  void _alternarExercicio(Exercicio ex) {
    setState(() => _ocultos.contains(ex.slug) ? _ocultos.remove(ex.slug) : _ocultos.add(ex.slug));
    _salvar();
  }

  int _usos(String eq) => _catalogo.where((ex) => ex.equipamento.contains(eq)).length;

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final academia = _atual;
    final visiveis = _catalogo.where(academia.visivel).length;
    final doGrupo = _catalogo.where((ex) => ex.musculoPrimario == _grupo).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            Conteudo(
              larguraMaxima: AppLayout.larguraLeitura,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const BotaoVoltar(),
                      const Spacer(),
                      Text(_salvando ? 'Salvando…' : 'Salvo',
                          style: AppTexto.meta.copyWith(fontSize: 12, color: AppCores.textoApagado)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(widget.academia.nome.toUpperCase(), style: AppTexto.rotulo.copyWith(color: AppCores.destaque)),
                  const SizedBox(height: 8),
                  Text('EQUIPAMENTOS', style: AppTexto.display((largura * 0.085).clamp(30.0, 56.0))),
                  const SizedBox(height: 14),
                  Text(
                    'Professores e alunos só veem os exercícios que a academia consegue fazer. '
                    'As sugestões de troca também passam a considerar só esses.',
                    style: AppTexto.corpo,
                  ),
                  const SizedBox(height: 18),
                  NumeroLegenda(_carregando ? '—' : '$visiveis de ${_catalogo.length}', 'exercícios aparecem'),
                  const SizedBox(height: 32),
                  if (_carregando)
                    const Esqueleto(altura: 200)
                  else ...[
                    Text('1. O QUE A ACADEMIA TEM', style: AppTexto.rotulo),
                    const SizedBox(height: 6),
                    Text('Desmarque o que não existe. Some tudo que usa esse equipamento.', style: AppTexto.meta),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // O chip ocupa a largura que recebe; no Wrap, só a do texto
                        for (final eq in _equipamentos)
                          IntrinsicWidth(
                            child: ChipOpcao(
                              texto: '${Rotulos.equipamento(eq)} (${_usos(eq)})',
                              selecionado: !_indisponiveis.contains(eq),
                              onTap: () => _alternarEquipamento(eq),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text('2. EXERCÍCIO POR EXERCÍCIO', style: AppTexto.rotulo),
                    const SizedBox(height: 6),
                    Text(
                      'Para o que o equipamento não separa: por exemplo, a academia tem leg press, mas não tem hack.',
                      style: AppTexto.meta,
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final g in GrupoMuscular.todos) ...[
                            ChipOpcao(texto: g.label, selecionado: g.codigo == _grupo, onTap: () => setState(() => _grupo = g.codigo)),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final ex in doGrupo)
                      _LinhaExercicio(
                        exercicio: ex,
                        falta: academia.equipamentoQueFalta(ex),
                        visivel: academia.visivel(ex),
                        onTap: () => _alternarExercicio(ex),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaExercicio extends StatelessWidget {
  final Exercicio exercicio;

  /// Equipamento que a academia não tem; com ele, o exercício fica oculto
  /// independentemente do botão.
  final String? falta;
  final bool visivel;
  final VoidCallback onTap;

  const _LinhaExercicio({required this.exercicio, required this.falta, required this.visivel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bloqueado = falta != null;
    return Opacity(
      opacity: visivel ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppCores.linha))),
        child: Row(
          children: [
            MiniaturaExercicio(slug: exercicio.slug, nome: exercicio.nome, tamanho: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercicio.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTexto.item),
                  const SizedBox(height: 4),
                  Text(
                    bloqueado
                        ? 'Oculto: sem ${Rotulos.equipamento(falta!)} na academia'
                        : (exercicio.equipamento.isEmpty ? 'Sem equipamento' : Rotulos.equipamentos(exercicio.equipamento)),
                    style: AppTexto.meta.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: visivel,
              onChanged: bloqueado ? null : (_) => onTap(),
              activeThumbColor: AppCores.sobreDestaque,
              activeTrackColor: AppCores.destaque,
            ),
          ],
        ),
      ),
    );
  }
}
