import 'package:flutter/material.dart';
import '../../models/academia.dart';
import '../../services/academia_service.dart';
import '../../services/sessao.dart';
import '../../services/treino_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comuns.dart';
import '../../widgets/treino_comuns.dart';
import '../meus_treinos_screen.dart';
import '../treino_dia_screen.dart';
import 'convite_screen.dart';
import 'equipamentos_screen.dart';
import 'professores_screen.dart';

/// Aba Meus Treinos de professores e donos: a lista de alunos, o convite e,
/// para o dono, a administração da academia.
class PainelProfessorScreen extends StatefulWidget {
  final Perfil perfil;

  /// Saudação e sair.
  final Widget topo;

  const PainelProfessorScreen({super.key, required this.perfil, required this.topo});

  @override
  State<PainelProfessorScreen> createState() => _PainelProfessorScreenState();
}

class _PainelProfessorScreenState extends State<PainelProfessorScreen> {
  final AcademiaService _service = AcademiaService();

  List<Perfil> _alunos = [];

  /// Aluno → dias com série registrada nesta semana.
  Map<String, int> _dias = {};
  bool _carregando = true;
  String? _erro;

  Perfil get _eu => widget.perfil;
  bool get _dono => _eu.papel == Papel.dono;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final alunos = await _service.alunosDe(_eu.academiaId!, _eu.uid);
      final dias = await Future.wait(alunos.map((a) => _service.diasTreinadosNaSemana(a.uid)));
      if (!mounted) return;
      setState(() {
        _alunos = alunos;
        _dias = {for (var i = 0; i < alunos.length; i++) alunos[i].uid: dias[i]};
        _carregando = false;
        _erro = null;
      });
    } catch (e) {
      debugPrint('Professor: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar seus alunos. Verifique sua conexão.';
      });
    }
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    _carregar();
  }

  void _convidar(Academia academia) => mostrarConvite(context, _eu, academia, TipoConvite.aluno);

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final treinaram = _dias.values.where((d) => d > 0).length;

    return ValueListenableBuilder<Academia?>(
      valueListenable: Sessao.academia,
      builder: (context, academia, _) => RefreshIndicator(
        color: AppCores.destaque,
        backgroundColor: AppCores.superficie,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.only(top: 28, bottom: 40),
          children: [
            Conteudo(
              larguraMaxima: AppLayout.larguraLeitura,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.topo,
                  const SizedBox(height: 10),
                  Text('MEUS ALUNOS', style: AppTexto.display((largura * 0.085).clamp(30.0, 56.0))),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(academia?.autonomo ?? false ? Icons.sports_rounded : Icons.storefront_outlined,
                          size: 16, color: AppCores.textoSuave),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          academia?.autonomo ?? false
                              ? 'Professor autônomo'
                              : '${academia?.nome ?? 'Academia'}  ·  ${_dono ? 'dono e professor' : 'professor'}',
                          style: AppTexto.meta.copyWith(color: AppCores.texto),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 32,
                    runSpacing: 8,
                    children: [
                      NumeroLegenda(_carregando ? '—' : '${_alunos.length}', _alunos.length == 1 ? 'aluno' : 'alunos'),
                      NumeroLegenda(_carregando ? '—' : '$treinaram', 'treinaram nesta semana'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  BotaoDestaque(
                    texto: 'Convidar aluno',
                    icone: Icons.person_add_alt_1_rounded,
                    onTap: academia == null ? null : () => _convidar(academia),
                  ),
                  const SizedBox(height: 24),
                  if (_erro != null) ...[
                    Text(_erro!, style: AppTexto.item.copyWith(color: AppCores.textoSuave)),
                    const SizedBox(height: 12),
                    BotaoContorno(texto: 'Tentar de novo', icone: Icons.refresh, onTap: _carregar),
                  ] else if (_carregando)
                    for (var i = 0; i < 3; i++) ...[const Esqueleto(altura: 64), const SizedBox(height: 10)]
                  else if (_alunos.isEmpty)
                    _Vazio(onConvidar: academia == null ? null : () => _convidar(academia))
                  else
                    Container(
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppCores.linha))),
                      child: Column(
                        children: [
                          for (final a in _alunos)
                            _LinhaAluno(
                              aluno: a,
                              dias: _dias[a.uid] ?? 0,
                              onTap: () => _abrir(AlunoScreen(aluno: a)),
                            ),
                        ],
                      ),
                    ),
                  // O autônomo não tem professores nem equipamentos para administrar
                  if (_dono && academia != null && !academia.autonomo) ...[
                    const SizedBox(height: 36),
                    Text('ACADEMIA', style: AppTexto.rotulo),
                    const SizedBox(height: 12),
                    BotaoContorno(
                      texto: 'Professores',
                      icone: Icons.groups_outlined,
                      onTap: () => _abrir(ProfessoresScreen(dono: _eu, academia: academia)),
                    ),
                    const SizedBox(height: 12),
                    BotaoContorno(
                      texto: 'Equipamentos e exercícios',
                      icone: Icons.fitness_center_rounded,
                      onTap: () => _abrir(EquipamentosScreen(academia: academia)),
                    ),
                  ],
                  const SizedBox(height: 36),
                  Text('VOCÊ', style: AppTexto.rotulo),
                  const SizedBox(height: 12),
                  BotaoContorno(
                    texto: 'Meu treino',
                    icone: Icons.event_note_rounded,
                    onTap: () => _abrir(_MeuTreinoScreen(perfil: _eu)),
                  ),
                  if (_eu.admin) ...[
                    const SizedBox(height: 12),
                    const BotaoPainelSoftware(),
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

class _LinhaAluno extends StatelessWidget {
  final Perfil aluno;
  final int dias;
  final VoidCallback onTap;

  const _LinhaAluno({required this.aluno, required this.dias, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressionavel(
      onTap: onTap,
      builder: (_, ativo) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: ativo ? AppCores.superficie : Colors.transparent,
          border: const Border(bottom: BorderSide(color: AppCores.linha)),
        ),
        child: Row(
          children: [
            MiniaturaExercicio(slug: null, nome: aluno.exibicao, tamanho: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(aluno.exibicao, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTexto.item),
                  const SizedBox(height: 4),
                  Text(aluno.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTexto.meta),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$dias/7',
              style: AppTexto.numero.copyWith(
                fontSize: 15,
                color: dias > 0 ? AppCores.destaque : AppCores.textoApagado,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: ativo ? AppCores.texto : AppCores.textoApagado, size: 22),
          ],
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  final VoidCallback? onConvidar;

  const _Vazio({required this.onConvidar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppCores.superficie, borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nenhum aluno ainda', style: AppTexto.titulo(18)),
          const SizedBox(height: 8),
          Text(
            'Toque em "Convidar aluno" e mande o link. Quem entrar por ele aparece aqui, e você '
            'monta o treino de cada dia da semana.',
            style: AppTexto.corpo,
          ),
        ],
      ),
    );
  }
}

/// Um aluno visto pelo professor: a semana dele, para montar os dias, e o
/// histórico de cargas.
class AlunoScreen extends StatelessWidget {
  final Perfil aluno;

  const AlunoScreen({super.key, required this.aluno});

  Future<void> _desvincular(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Desvincular ${aluno.exibicao}?',
      mensagem: 'Você deixa de ver e montar o treino. O aluno continua com o treino atual e o '
          'histórico, e passa a montar o treino sozinho.',
      acao: 'Desvincular',
    );
    if (!ok) return;
    try {
      await AcademiaService().desvincular(aluno.uid);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Professor: $e');
      if (context.mounted) avisar(context, 'Não foi possível desvincular. Verifique sua conexão.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PainelSemana(
          service: TreinoService(uid: aluno.uid),
          topo: Row(
            children: [
              const BotaoVoltar(),
              const Spacer(),
              Pressionavel(
                onTap: () => _desvincular(context),
                builder: (_, ativo) => Row(
                  children: [
                    Icon(Icons.person_remove_outlined, size: 16, color: ativo ? AppCores.erro : AppCores.textoSuave),
                    const SizedBox(width: 6),
                    Text('Desvincular',
                        style: AppTexto.meta.copyWith(color: ativo ? AppCores.erro : AppCores.textoSuave)),
                  ],
                ),
              ),
            ],
          ),
          titulo: aluno.exibicao.toUpperCase(),
          cabecalho: Text(aluno.email, style: AppTexto.meta.copyWith(color: AppCores.texto)),
          modo: ModoTreino.plano,
          nomeAluno: aluno.primeiroNome,
        ),
      ),
    );
  }
}

/// O treino pessoal do professor, que monta e registra como um usuário comum.
class _MeuTreinoScreen extends StatelessWidget {
  final Perfil perfil;

  const _MeuTreinoScreen({required this.perfil});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PainelSemana(
          service: TreinoService(uid: perfil.uid),
          topo: const Align(alignment: Alignment.centerLeft, child: BotaoVoltar()),
          titulo: 'MEU TREINO',
        ),
      ),
    );
  }
}
