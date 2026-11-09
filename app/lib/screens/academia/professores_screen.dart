import 'package:flutter/material.dart';
import '../../models/academia.dart';
import '../../services/academia_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comuns.dart';
import '../../widgets/treino_comuns.dart';
import 'convite_screen.dart';

/// Professores da academia, vistos pelo dono: quantos alunos cada um tem,
/// o convite para professores novos e a remoção.
class ProfessoresScreen extends StatefulWidget {
  final Perfil dono;
  final Academia academia;

  const ProfessoresScreen({super.key, required this.dono, required this.academia});

  @override
  State<ProfessoresScreen> createState() => _ProfessoresScreenState();
}

class _ProfessoresScreenState extends State<ProfessoresScreen> {
  final AcademiaService _service = AcademiaService();

  /// O dono primeiro, depois os professores, com o total de alunos de cada.
  List<(Perfil, int)> _linhas = [];
  bool _carregando = true;
  String? _erro;

  String get _academiaId => widget.academia.id;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final professores = [widget.dono, ...await _service.professoresDa(_academiaId)];
      final alunos = await Future.wait(
        professores.map((p) => _service.contarAlunos(_academiaId, professorUid: p.uid)),
      );
      if (!mounted) return;
      setState(() {
        _linhas = [for (var i = 0; i < professores.length; i++) (professores[i], alunos[i])];
        _carregando = false;
        _erro = null;
      });
    } catch (e) {
      debugPrint('Professores: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar os professores. Verifique sua conexão.';
      });
    }
  }

  Future<void> _remover(Perfil professor, int alunos) async {
    final ok = await confirmar(
      context,
      titulo: 'Remover ${professor.exibicao}?',
      mensagem: alunos == 0
          ? 'A conta deixa de ser professor da ${widget.academia.nome} e volta a ser uma conta comum.'
          : 'A conta deixa de ser professor da ${widget.academia.nome}. '
              '${alunos == 1 ? 'O aluno passa' : 'Os $alunos alunos passam'} para você, '
              'com o treino que já estava montado.',
    );
    if (!ok) return;
    try {
      await _service.removerProfessor(professor, widget.academia);
      _carregar();
    } catch (e) {
      debugPrint('Professores: $e');
      if (mounted) avisar(context, 'Não foi possível remover. Verifique sua conexão.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final totalAlunos = _linhas.fold(0, (t, l) => t + l.$2);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppCores.destaque,
          backgroundColor: AppCores.superficie,
          onRefresh: _carregar,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Conteudo(
                larguraMaxima: AppLayout.larguraLeitura,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Align(alignment: Alignment.centerLeft, child: BotaoVoltar()),
                    const SizedBox(height: 24),
                    Text(widget.academia.nome.toUpperCase(), style: AppTexto.rotulo.copyWith(color: AppCores.destaque)),
                    const SizedBox(height: 8),
                    Text('PROFESSORES', style: AppTexto.display((largura * 0.085).clamp(30.0, 56.0))),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 32,
                      runSpacing: 8,
                      children: [
                        NumeroLegenda(_carregando ? '—' : '${_linhas.length}', 'professores'),
                        NumeroLegenda(_carregando ? '—' : '$totalAlunos', 'alunos'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    BotaoDestaque(
                      texto: 'Convidar professor',
                      icone: Icons.person_add_alt_1_rounded,
                      onTap: () => mostrarConvite(context, widget.dono, widget.academia, TipoConvite.professor),
                    ),
                    const SizedBox(height: 24),
                    if (_erro != null) ...[
                      Text(_erro!, style: AppTexto.item.copyWith(color: AppCores.textoSuave)),
                      const SizedBox(height: 12),
                      BotaoContorno(texto: 'Tentar de novo', icone: Icons.refresh, onTap: _carregar),
                    ] else if (_carregando)
                      for (var i = 0; i < 2; i++) ...[const Esqueleto(altura: 64), const SizedBox(height: 10)]
                    else
                      Container(
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppCores.linha))),
                        child: Column(
                          children: [
                            for (final (p, alunos) in _linhas)
                              _LinhaProfessor(
                                professor: p,
                                alunos: alunos,
                                voce: p.uid == widget.dono.uid,
                                onRemover: p.uid == widget.dono.uid ? null : () => _remover(p, alunos),
                              ),
                          ],
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

class _LinhaProfessor extends StatelessWidget {
  final Perfil professor;
  final int alunos;
  final bool voce;
  final VoidCallback? onRemover;

  const _LinhaProfessor({required this.professor, required this.alunos, required this.voce, this.onRemover});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppCores.linha))),
      child: Row(
        children: [
          MiniaturaExercicio(slug: null, nome: professor.exibicao, tamanho: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(voce ? '${professor.exibicao} (você)' : professor.exibicao,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTexto.item),
                const SizedBox(height: 4),
                Text('$alunos ${alunos == 1 ? 'aluno' : 'alunos'}  ·  ${professor.email}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTexto.meta),
              ],
            ),
          ),
          if (onRemover != null)
            IconButton(
              onPressed: onRemover,
              tooltip: 'Remover da academia',
              icon: const Icon(Icons.person_remove_outlined, color: AppCores.textoApagado, size: 20),
            ),
        ],
      ),
    );
  }
}
