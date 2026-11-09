import 'package:flutter/material.dart';
import '../../models/academia.dart';
import '../../services/academia_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comuns.dart';
import '../../widgets/treino_comuns.dart';

/// Painel do dono do software (contas em `admins/{uid}`): quantas academias,
/// donos, professores e alunos existem, os números de cada academia, as
/// contas que entraram por último e a inclusão de pessoas em qualquer papel.
///
/// Mostra só contagens, nomes e e-mails: as regras não deixam o admin ler o
/// treino de ninguém.
class PainelSoftwareScreen extends StatefulWidget {
  const PainelSoftwareScreen({super.key});

  @override
  State<PainelSoftwareScreen> createState() => _PainelSoftwareScreenState();
}

class _PainelSoftwareScreenState extends State<PainelSoftwareScreen> {
  final AcademiaService _service = AcademiaService();

  EstatisticasSoftware? _totais;
  List<ResumoAcademia> _academias = [];
  List<EntradaRecente> _entradas = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final r = await Future.wait([
        _service.estatisticas(),
        _service.resumoAcademias(),
        _service.entradasRecentes(),
      ]);
      if (!mounted) return;
      setState(() {
        _totais = r[0] as EstatisticasSoftware;
        _academias = r[1] as List<ResumoAcademia>;
        _entradas = r[2] as List<EntradaRecente>;
        _carregando = false;
        _erro = null;
      });
    } catch (e) {
      debugPrint('Painel do software: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar os números. Verifique sua conexão.';
      });
    }
  }

  Future<void> _adicionar() async {
    final feito = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoAdicionar(
        service: _service,
        academias: [for (final r in _academias) if (!r.academia.autonomo) r.academia],
      ),
    );
    if (feito == null) return;
    _carregar();
    if (mounted) avisar(context, feito);
  }

  /// "Dono · Academia X", "Professor autônomo", "Aluno · Academia X"...
  String _papelDe(Perfil p) {
    final academia = _academias.where((r) => r.academia.id == p.academiaId).firstOrNull?.academia;
    final onde = academia == null ? '' : '  ·  ${academia.nome}';
    return switch (p.papel) {
      Papel.usuario => 'Usuário comum',
      Papel.aluno => 'Aluno$onde',
      Papel.professor => 'Professor$onde',
      Papel.dono => academia?.autonomo ?? false ? 'Professor autônomo' : 'Dono$onde',
    };
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final t = _totais;
    String n(int? v) => _carregando || v == null ? '—' : '$v';

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
                    Text('DONO DO SOFTWARE', style: AppTexto.rotulo.copyWith(color: AppCores.destaque)),
                    const SizedBox(height: 8),
                    Text('PAINEL', style: AppTexto.display((largura * 0.085).clamp(30.0, 56.0))),
                    const SizedBox(height: 24),
                    if (_erro != null) ...[
                      Text(_erro!, style: AppTexto.item.copyWith(color: AppCores.textoSuave)),
                      const SizedBox(height: 12),
                      BotaoContorno(texto: 'Tentar de novo', icone: Icons.refresh, onTap: _carregar),
                    ] else ...[
                      GridView.count(
                        crossAxisCount: largura < 560 ? 2 : 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.6,
                        children: [
                          _Total(n(t?.academias), 'academias'),
                          _Total(n(t?.donos), 'donos'),
                          _Total(n(t?.professores), 'professores', nota: 'de academia, sem os donos'),
                          _Total(n(t?.autonomos), 'autônomos', nota: 'professores sem academia'),
                          _Total(n(t?.alunos), 'alunos'),
                          _Total(n(t?.usuarios), 'contas', nota: 'todas, com os usuários comuns'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _carregando || t == null
                            ? ' '
                            : '${t.usuarios - t.donos - t.autonomos - t.professores - t.alunos} '
                                'contas usam o app sem academia (usuários comuns).',
                        style: AppTexto.meta,
                      ),
                      const SizedBox(height: 24),
                      BotaoDestaque(texto: 'Adicionar pessoa', icone: Icons.person_add_alt_1_rounded, onTap: _adicionar),
                      const SizedBox(height: 36),
                      Text('ACADEMIAS E AUTÔNOMOS', style: AppTexto.rotulo),
                      const SizedBox(height: 12),
                      if (_carregando)
                        for (var i = 0; i < 2; i++) ...[const Esqueleto(altura: 64), const SizedBox(height: 10)]
                      else if (_academias.isEmpty)
                        Text('Nenhuma academia ainda.', style: AppTexto.corpo)
                      else
                        _Lista(children: [for (final a in _academias) _LinhaAcademia(resumo: a)]),
                      const SizedBox(height: 36),
                      Text('ENTRADAS RECENTES', style: AppTexto.rotulo),
                      const SizedBox(height: 6),
                      Text('As contas mais novas do app e o papel de cada uma hoje.', style: AppTexto.meta),
                      const SizedBox(height: 12),
                      if (_carregando)
                        for (var i = 0; i < 3; i++) ...[const Esqueleto(altura: 56), const SizedBox(height: 10)]
                      else
                        _Lista(children: [
                          for (final e in _entradas) _LinhaEntrada(entrada: e, papel: _papelDe(e.perfil)),
                        ]),
                    ],
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

class _Lista extends StatelessWidget {
  final List<Widget> children;

  const _Lista({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppCores.linha))),
      child: Column(children: children),
    );
  }
}

class _Total extends StatelessWidget {
  final String valor;
  final String legenda;
  final String? nota;

  const _Total(this.valor, this.legenda, {this.nota});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppCores.superficie,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppCores.linha),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(valor, style: AppTexto.display(28)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(legenda, style: AppTexto.item.copyWith(fontSize: 14)),
              if (nota != null)
                Text(nota!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTexto.meta.copyWith(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinhaAcademia extends StatelessWidget {
  final ResumoAcademia resumo;

  const _LinhaAcademia({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final a = resumo.academia;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppCores.linha))),
      child: Row(
        children: [
          Icon(a.autonomo ? Icons.sports_rounded : Icons.storefront_outlined, color: AppCores.textoSuave, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.nome, style: AppTexto.item),
                const SizedBox(height: 4),
                Text(a.autonomo ? 'Professor autônomo' : 'Dono: ${resumo.donoNome}', style: AppTexto.meta),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!a.autonomo) ...[
                Text('${resumo.professores} prof.', style: AppTexto.meta.copyWith(color: AppCores.texto)),
                const SizedBox(height: 4),
              ],
              Text('${resumo.alunos} ${resumo.alunos == 1 ? 'aluno' : 'alunos'}',
                  style: AppTexto.meta.copyWith(color: AppCores.destaque)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinhaEntrada extends StatelessWidget {
  final EntradaRecente entrada;
  final String papel;

  const _LinhaEntrada({required this.entrada, required this.papel});

  @override
  Widget build(BuildContext context) {
    final p = entrada.perfil;
    final d = entrada.criadoEm;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppCores.linha))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.exibicao, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTexto.item),
                const SizedBox(height: 4),
                Text('$papel  ·  ${p.email}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTexto.meta),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
            style: AppTexto.numero.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

enum _TipoInclusao {
  dono('Dono de academia'),
  autonomo('Professor autônomo'),
  professor('Professor de academia'),
  aluno('Aluno');

  final String rotulo;
  const _TipoInclusao(this.rotulo);
}

/// Coloca uma conta que já existe em qualquer papel. Devolve (ao fechar) a
/// mensagem de sucesso.
class _DialogoAdicionar extends StatefulWidget {
  final AcademiaService service;

  /// Academias de verdade (sem os autônomos), para o professor de academia.
  final List<Academia> academias;

  const _DialogoAdicionar({required this.service, required this.academias});

  @override
  State<_DialogoAdicionar> createState() => _DialogoAdicionarState();
}

class _DialogoAdicionarState extends State<_DialogoAdicionar> {
  final _email = TextEditingController();
  final _extra = TextEditingController();
  _TipoInclusao _tipo = _TipoInclusao.dono;
  Academia? _academia;
  String? _erro;
  bool _salvando = false;

  @override
  void dispose() {
    _email.dispose();
    _extra.dispose();
    super.dispose();
  }

  String get _explicacao => switch (_tipo) {
        _TipoInclusao.dono =>
          'Cria a academia e dá à conta o acesso de dono: convida professores, escolhe os equipamentos '
              'e também dá aula.',
        _TipoInclusao.autonomo =>
          'Personal sem academia: convida os próprios alunos e monta o treino deles. Vê o catálogo completo.',
        _TipoInclusao.professor => 'Coloca a conta como professor de uma academia que já existe.',
        _TipoInclusao.aluno => 'Liga a conta a um professor, que passa a montar o treino dela.',
      };

  Future<void> _salvar() async {
    final email = _email.text.trim();
    final extra = _extra.text.trim();
    String? faltando;
    if (email.isEmpty) faltando = 'Preencha o e-mail da pessoa.';
    if (_tipo == _TipoInclusao.dono && extra.isEmpty) faltando = 'Preencha o nome da academia.';
    if (_tipo == _TipoInclusao.professor && _academia == null) faltando = 'Escolha a academia.';
    if (_tipo == _TipoInclusao.aluno && extra.isEmpty) faltando = 'Preencha o e-mail do professor.';
    if (faltando != null) {
      setState(() => _erro = faltando);
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final erro = switch (_tipo) {
        _TipoInclusao.dono => await widget.service.criarAcademia(extra, email),
        _TipoInclusao.autonomo => await widget.service.criarAcademia(extra, email, autonomo: true),
        _TipoInclusao.professor => await widget.service.adicionarProfessor(email, _academia!),
        _TipoInclusao.aluno => await widget.service.adicionarAluno(email, extra),
      };
      if (!mounted) return;
      if (erro == null) {
        Navigator.pop(context, '${_tipo.rotulo} adicionado: $email');
        return;
      }
      setState(() => _erro = erro);
    } catch (e) {
      debugPrint('Painel do software: $e');
      if (mounted) setState(() => _erro = 'Não foi possível salvar. Verifique sua conexão.');
    }
    if (mounted) setState(() => _salvando = false);
  }

  @override
  Widget build(BuildContext context) {
    final campoExtra = switch (_tipo) {
      _TipoInclusao.dono => 'Nome da academia',
      _TipoInclusao.autonomo => 'Nome de exibição (opcional; padrão: o nome da pessoa)',
      _TipoInclusao.aluno => 'E-mail do professor',
      _TipoInclusao.professor => null,
    };

    return AlertDialog(
      backgroundColor: AppCores.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text('Adicionar pessoa', style: AppTexto.titulo(20)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _TipoInclusao.values)
                    IntrinsicWidth(
                      child: ChipOpcao(
                        texto: t.rotulo,
                        selecionado: t == _tipo,
                        onTap: () => setState(() {
                          _tipo = t;
                          _erro = null;
                          _extra.clear();
                        }),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(_explicacao, style: AppTexto.meta),
              const SizedBox(height: 4),
              Text('A pessoa precisa ter se cadastrado no app antes.',
                  style: AppTexto.meta.copyWith(color: AppCores.textoApagado)),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                style: AppTexto.item,
                keyboardType: TextInputType.emailAddress,
                decoration: decoracaoCampo(_tipo == _TipoInclusao.aluno ? 'E-mail do aluno' : 'E-mail da pessoa'),
              ),
              const SizedBox(height: 10),
              if (campoExtra != null)
                TextField(
                  controller: _extra,
                  style: AppTexto.item,
                  keyboardType: _tipo == _TipoInclusao.aluno ? TextInputType.emailAddress : TextInputType.text,
                  decoration: decoracaoCampo(campoExtra),
                  onSubmitted: (_) => _salvar(),
                )
              else if (widget.academias.isEmpty)
                Text('Nenhuma academia criada ainda.', style: AppTexto.meta)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in widget.academias)
                      IntrinsicWidth(
                        child: ChipOpcao(
                          texto: a.nome,
                          selecionado: a.id == _academia?.id,
                          onTap: () => setState(() => _academia = a),
                        ),
                      ),
                  ],
                ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(_erro!, style: AppTexto.meta.copyWith(color: AppCores.erro)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: AppTexto.item.copyWith(color: AppCores.textoSuave)),
        ),
        TextButton(
          onPressed: _salvando ? null : _salvar,
          child: Text(_salvando ? 'Salvando…' : 'Adicionar', style: AppTexto.item.copyWith(color: AppCores.destaque)),
        ),
      ],
    );
  }
}
