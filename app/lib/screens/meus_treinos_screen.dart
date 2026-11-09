import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/academia.dart';
import '../models/treino.dart';
import '../services/academia_service.dart';
import '../services/auth_service.dart';
import '../services/sessao.dart';
import '../services/treino_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import '../widgets/treino_comuns.dart';
import 'academia/convite_screen.dart';
import 'academia/painel_professor_screen.dart';
import 'academia/painel_software_screen.dart';
import 'historico_screen.dart';
import 'login_screen.dart';
import 'treino_dia_screen.dart';
import 'verificacao_email_screen.dart';

/// Aba "Meus Treinos". É a única parte do app que exige login: sem usuário,
/// mostra a tela de entrada; com usuário, o painel da semana.
///
/// Com o modo academia ligado (Sessao.habilitada), o que aparece depende do
/// papel: professor e dono veem os alunos, o aluno vê o treino montado pelo
/// professor e o usuário comum segue como sempre.
class MeusTreinosScreen extends StatefulWidget {
  const MeusTreinosScreen({super.key});

  @override
  State<MeusTreinosScreen> createState() => _MeusTreinosScreenState();
}

class _MeusTreinosScreenState extends State<MeusTreinosScreen> {
  final AuthService _auth = AuthService();
  late final Stream<User?> _usuario = _auth.usuario;

  static const _carregando = Center(
    child: CircularProgressIndicator(strokeWidth: 2, color: AppCores.destaque),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _usuario,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _carregando;
        if (snapshot.data == null) return const LoginScreen();
        // currentUser reflete o reload() feito ao conferir a confirmação,
        // mesmo que o stream ainda não tenha emitido
        final usuario = _auth.usuarioAtual ?? snapshot.data!;
        if (!usuario.emailVerified) {
          return VerificacaoEmailScreen(
            key: ValueKey(usuario.uid),
            auth: _auth,
            email: usuario.email ?? '',
            onConfirmado: () => setState(() {}),
          );
        }
        if (!Sessao.habilitada) return _painelProprio(usuario, null);

        return ListenableBuilder(
          listenable: Listenable.merge([Sessao.perfil, Sessao.convitePendente]),
          builder: (context, _) {
            final perfil = Sessao.perfil.value;
            if (perfil == null || perfil.uid != usuario.uid) return _carregando;

            final convite = Sessao.convitePendente.value;
            if (convite != null) {
              return ConviteScreen(key: ValueKey(convite), codigo: convite, perfil: perfil);
            }
            if (perfil.papel.ensina) {
              return PainelProfessorScreen(
                key: ValueKey('${perfil.uid}-${perfil.papel.name}-${perfil.academiaId}'),
                perfil: perfil,
                topo: SaudacaoSair(usuario: usuario, auth: _auth),
              );
            }
            return _painelProprio(usuario, perfil);
          },
        );
      },
    );
  }

  /// Painel da semana do próprio usuário: comum (monta o treino) ou aluno
  /// (registra o treino montado pelo professor).
  Widget _painelProprio(User usuario, Perfil? perfil) {
    final aluno = perfil?.papel == Papel.aluno;
    return PainelSemana(
      // A chave recria o painel (e o serviço) se outro usuário entrar ou se
      // o papel mudar (entrou ou saiu da academia)
      key: ValueKey('${usuario.uid}-${perfil?.papel.name}-${perfil?.professorUid}'),
      service: TreinoService(uid: usuario.uid),
      topo: SaudacaoSair(usuario: usuario, auth: _auth),
      titulo: 'MEUS TREINOS',
      modo: aluno ? ModoTreino.registro : ModoTreino.completo,
      cabecalho: aluno ? _VinculoAluno(perfil: perfil!) : null,
      rodape: [
        if (perfil?.admin ?? false) const BotaoPainelSoftware(),
        if (aluno) _BotaoSairDaAcademia(perfil: perfil!),
      ],
    );
  }
}

/// Saudação com o nome e o botão de sair, no topo dos painéis.
class SaudacaoSair extends StatelessWidget {
  final User usuario;
  final AuthService auth;

  const SaudacaoSair({super.key, required this.usuario, required this.auth});

  Future<void> _sair(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Sair da conta?',
      mensagem: 'Seus treinos ficam salvos e voltam quando você entrar de novo.',
      acao: 'Sair',
    );
    if (ok) await auth.sair();
  }

  @override
  Widget build(BuildContext context) {
    final nome = usuario.displayName?.trim();
    return Row(
      children: [
        Expanded(
          child: Text(
            (nome == null || nome.isEmpty ? usuario.email ?? '' : 'Olá, $nome').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTexto.rotulo.copyWith(color: AppCores.destaque),
          ),
        ),
        Pressionavel(
          onTap: () => _sair(context),
          builder: (_, ativo) => Row(
            children: [
              Icon(Icons.logout_rounded, size: 16, color: ativo ? AppCores.texto : AppCores.textoSuave),
              const SizedBox(width: 6),
              Text('Sair', style: AppTexto.meta.copyWith(color: ativo ? AppCores.texto : AppCores.textoSuave)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Atalho para o painel do dono do software.
class BotaoPainelSoftware extends StatelessWidget {
  const BotaoPainelSoftware({super.key});

  @override
  Widget build(BuildContext context) {
    return BotaoContorno(
      texto: 'Painel do software',
      icone: Icons.insights_rounded,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PainelSoftwareScreen())),
    );
  }
}

/// "Academia X · professor Y", abaixo do título do aluno.
class _VinculoAluno extends StatefulWidget {
  final Perfil perfil;

  const _VinculoAluno({required this.perfil});

  @override
  State<_VinculoAluno> createState() => _VinculoAlunoState();
}

class _VinculoAlunoState extends State<_VinculoAluno> {
  String? _professor;

  @override
  void initState() {
    super.initState();
    final uid = widget.perfil.professorUid;
    if (uid == null) return;
    AcademiaService().buscarPerfil(uid).then((p) {
      if (mounted) setState(() => _professor = p?.exibicao);
    }).catchError((Object e) {
      debugPrint('Meus Treinos: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Academia?>(
      valueListenable: Sessao.academia,
      builder: (context, academia, _) => Row(
        children: [
          Icon(academia?.autonomo ?? false ? Icons.sports_rounded : Icons.storefront_outlined,
              size: 16, color: AppCores.textoSuave),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                // O autônomo não tem academia: aparece só o professor
                if (!(academia?.autonomo ?? false)) academia?.nome ?? 'Academia',
                if (_professor != null) 'treino de $_professor',
              ].join('  ·  '),
              style: AppTexto.meta.copyWith(color: AppCores.texto),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoSairDaAcademia extends StatelessWidget {
  final Perfil perfil;

  const _BotaoSairDaAcademia({required this.perfil});

  Future<void> _sair(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Sair da academia?',
      mensagem: 'Seu professor deixa de ver e montar seu treino. O treino atual e o histórico '
          'continuam com você, e você passa a montar o treino sozinho.',
      acao: 'Sair',
    );
    if (!ok) return;
    try {
      await AcademiaService().desvincular(perfil.uid);
    } catch (e) {
      debugPrint('Meus Treinos: $e');
      if (context.mounted) avisar(context, 'Não foi possível sair. Verifique sua conexão.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BotaoContorno(texto: 'Sair da academia', icone: Icons.logout_rounded, onTap: () => _sair(context));
  }
}

/// Painel de uma semana de treino: os sete dias, o que foi planejado e o que
/// já foi registrado. Serve ao próprio usuário e ao professor que abre um
/// aluno ([modo] diz o que cada um pode fazer ao abrir o dia).
class PainelSemana extends StatefulWidget {
  final TreinoService service;

  /// Linha acima do título: saudação e sair, ou voltar.
  final Widget topo;
  final String titulo;

  /// Linha opcional logo abaixo do título (ex.: academia do aluno).
  final Widget? cabecalho;
  final ModoTreino modo;

  /// Nome do aluno, quando é o professor quem vê o painel.
  final String? nomeAluno;

  /// Botões extras abaixo do histórico.
  final List<Widget> rodape;

  const PainelSemana({
    super.key,
    required this.service,
    required this.topo,
    required this.titulo,
    this.cabecalho,
    this.modo = ModoTreino.completo,
    this.nomeAluno,
    this.rodape = const [],
  });

  @override
  State<PainelSemana> createState() => _PainelSemanaState();
}

class _PainelSemanaState extends State<PainelSemana> {
  TreinoService get _service => widget.service;

  Map<int, List<ExercicioTreino>> _plano = {};
  SemanaTreino? _semana;
  late DateTime _inicioSemana;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    _inicioSemana = SemanaTreino.inicioDe(DateTime.now());
    try {
      final resultados = await Future.wait([
        _service.buscarPlano(),
        _service.buscarSemana(_inicioSemana),
      ]);
      if (!mounted) return;
      setState(() {
        _plano = resultados[0] as Map<int, List<ExercicioTreino>>;
        _semana = resultados[1] as SemanaTreino?;
        _carregando = false;
        _erro = null;
      });
    } catch (e) {
      debugPrint('Meus Treinos: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar os treinos. Verifique sua conexão.';
      });
    }
  }

  Future<void> _abrirDia(int dia) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TreinoDiaScreen(dia: dia, service: _service, modo: widget.modo, nomeAluno: widget.nomeAluno),
      ),
    );
    _carregar();
  }

  void _abrirHistorico() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoricoScreen(
          service: _service,
          rotulo: widget.nomeAluno == null ? 'MEUS TREINOS' : widget.nomeAluno!.toUpperCase(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final hoje = DateTime.now().weekday;
    final treinados = _semana?.diasTreinados ?? const <int>[];

    return RefreshIndicator(
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
                Text(widget.titulo, style: AppTexto.display((largura * 0.085).clamp(30.0, 56.0))),
                if (widget.cabecalho != null) ...[
                  const SizedBox(height: 14),
                  widget.cabecalho!,
                ],
                const SizedBox(height: 14),
                Text(
                  'Semana ${FormatoTreino.data(_inicioSemana)} até '
                  '${FormatoTreino.dataCompleta(DateTime(_inicioSemana.year, _inicioSemana.month, _inicioSemana.day + 6))}',
                  style: AppTexto.meta,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 32,
                  runSpacing: 8,
                  children: [
                    NumeroLegenda(_carregando ? '—' : '${treinados.length}/7', 'dias treinados'),
                    NumeroLegenda(_carregando ? '—' : '${_semana?.totalSeries ?? 0}', 'séries'),
                  ],
                ),
                const SizedBox(height: 28),
                if (_erro != null) ...[
                  Text(_erro!, style: AppTexto.item.copyWith(color: AppCores.textoSuave)),
                  const SizedBox(height: 12),
                  BotaoContorno(texto: 'Tentar de novo', icone: Icons.refresh, onTap: _carregar),
                ] else ...[
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppCores.linha)),
                    ),
                    child: Column(
                      children: [
                        for (var dia = 1; dia <= 7; dia++)
                          _carregando
                              ? const _LinhaDiaEsqueleto()
                              : _LinhaDia(
                                  dia: dia,
                                  hoje: dia == hoje,
                                  montavel: widget.modo.editaEstrutura,
                                  planejados: (_plano[dia] ?? []).length,
                                  registrados: (_semana?.dias[dia] ?? [])
                                      .where((e) => e.seriesPreenchidas.isNotEmpty)
                                      .length,
                                  onTap: () => _abrirDia(dia),
                                ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  BotaoContorno(
                    texto: widget.nomeAluno == null ? 'Histórico de treinos' : 'Histórico de cargas',
                    icone: Icons.history_rounded,
                    onTap: _abrirHistorico,
                  ),
                  for (final botao in widget.rodape) ...[
                    const SizedBox(height: 12),
                    botao,
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaDia extends StatelessWidget {
  final int dia;
  final bool hoje;

  /// Quem vê o painel pode montar o dia (o aluno não pode).
  final bool montavel;
  final int planejados;
  final int registrados;
  final VoidCallback onTap;

  const _LinhaDia({
    required this.dia,
    required this.hoje,
    required this.montavel,
    required this.planejados,
    required this.registrados,
    required this.onTap,
  });

  String get _meta {
    if (planejados == 0) return montavel ? 'Descanso · toque para montar' : 'Descanso';
    final ex = '$planejados ${planejados == 1 ? 'exercício' : 'exercícios'}';
    if (registrados == 0) return ex;
    return '$ex  ·  $registrados registrado${registrados == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final feito = registrados > 0;
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
            SizedBox(
              width: 52,
              child: Text(
                DiaSemana.curto(dia).toUpperCase(),
                style: AppTexto.numero.copyWith(
                  fontSize: 14,
                  color: hoje ? AppCores.destaque : AppCores.textoApagado,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(DiaSemana.nome(dia), style: AppTexto.item)),
                      if (hoje) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppCores.destaque,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('HOJE',
                              style: AppTexto.rotulo.copyWith(
                                  fontSize: 9, color: AppCores.sobreDestaque, letterSpacing: 1)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_meta, style: AppTexto.meta),
                ],
              ),
            ),
            if (feito)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.check_circle_rounded, color: AppCores.destaque, size: 20),
              ),
            Icon(Icons.chevron_right_rounded,
                color: ativo ? AppCores.texto : AppCores.textoApagado, size: 22),
          ],
        ),
      ),
    );
  }
}

class _LinhaDiaEsqueleto extends StatelessWidget {
  const _LinhaDiaEsqueleto();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppCores.linha)),
      ),
      child: const Row(
        children: [
          Esqueleto(largura: 30, altura: 12),
          SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Esqueleto(largura: 130, altura: 14),
                SizedBox(height: 8),
                Esqueleto(largura: 90, altura: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
