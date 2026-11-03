import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/treino.dart';
import '../services/auth_service.dart';
import '../services/treino_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import '../widgets/treino_comuns.dart';
import 'historico_screen.dart';
import 'login_screen.dart';
import 'treino_dia_screen.dart';

/// Aba "Meus Treinos". É a única parte do app que exige login: sem usuário,
/// mostra a tela de entrada; com usuário, o painel da semana.
class MeusTreinosScreen extends StatefulWidget {
  const MeusTreinosScreen({super.key});

  @override
  State<MeusTreinosScreen> createState() => _MeusTreinosScreenState();
}

class _MeusTreinosScreenState extends State<MeusTreinosScreen> {
  final AuthService _auth = AuthService();
  late final Stream<User?> _usuario = _auth.usuario;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _usuario,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: AppCores.destaque),
          );
        }
        final usuario = snapshot.data;
        if (usuario == null) return const LoginScreen();
        // A chave recria o painel (e o serviço) se outro usuário entrar
        return _PainelSemana(key: ValueKey(usuario.uid), usuario: usuario, auth: _auth);
      },
    );
  }
}

class _PainelSemana extends StatefulWidget {
  final User usuario;
  final AuthService auth;

  const _PainelSemana({super.key, required this.usuario, required this.auth});

  @override
  State<_PainelSemana> createState() => _PainelSemanaState();
}

class _PainelSemanaState extends State<_PainelSemana> {
  late final TreinoService _service = TreinoService(uid: widget.usuario.uid);

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
        _erro = 'Não foi possível carregar seus treinos. Verifique sua conexão.';
      });
    }
  }

  Future<void> _abrirDia(int dia) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TreinoDiaScreen(dia: dia, service: _service)),
    );
    _carregar();
  }

  void _abrirHistorico() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoricoScreen(service: _service)),
    );
  }

  Future<void> _sair() async {
    final ok = await confirmar(
      context,
      titulo: 'Sair da conta?',
      mensagem: 'Seus treinos ficam salvos e voltam quando você entrar de novo.',
      acao: 'Sair',
    );
    if (ok) await widget.auth.sair();
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final hoje = DateTime.now().weekday;
    final nome = widget.usuario.displayName?.trim();
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (nome == null || nome.isEmpty ? widget.usuario.email ?? '' : 'Olá, $nome')
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTexto.rotulo.copyWith(color: AppCores.destaque),
                      ),
                    ),
                    Pressionavel(
                      onTap: _sair,
                      builder: (_, ativo) => Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              size: 16, color: ativo ? AppCores.texto : AppCores.textoSuave),
                          const SizedBox(width: 6),
                          Text('Sair',
                              style: AppTexto.meta
                                  .copyWith(color: ativo ? AppCores.texto : AppCores.textoSuave)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('MEUS TREINOS', style: AppTexto.display((largura * 0.085).clamp(30.0, 56.0))),
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
                    texto: 'Histórico de treinos',
                    icone: Icons.history_rounded,
                    onTap: _abrirHistorico,
                  ),
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
  final int planejados;
  final int registrados;
  final VoidCallback onTap;

  const _LinhaDia({
    required this.dia,
    required this.hoje,
    required this.planejados,
    required this.registrados,
    required this.onTap,
  });

  String get _meta {
    if (planejados == 0) return 'Descanso · toque para montar';
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
