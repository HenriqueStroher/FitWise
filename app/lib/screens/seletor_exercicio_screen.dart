import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import '../models/exercicio.dart';
import '../models/grupo_muscular.dart';
import '../models/treino.dart';
import '../services/exercicio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import '../widgets/treino_comuns.dart';

typedef EscolhaExercicio = ({String nome, String? slug, TipoRegistro registro});

/// Abre o seletor para trocar um exercício e devolve o escolhido (do
/// catálogo, com slug, ou um nome livre, sem slug). Nulo se o usuário voltar
/// sem escolher.
Future<EscolhaExercicio?> escolherExercicio(BuildContext context,
    {required String titulo, String? nomeAtual}) async {
  final escolhas = await Navigator.push<List<EscolhaExercicio>>(
    context,
    MaterialPageRoute(builder: (_) => SeletorExercicioScreen(titulo: titulo, nomeAtual: nomeAtual)),
  );
  return (escolhas == null || escolhas.isEmpty) ? null : escolhas.first;
}

/// Abre o seletor em modo de seleção múltipla e devolve os exercícios na
/// ordem em que foram marcados. [jaNoTreino] são as chaves dos exercícios
/// que o dia já tem, só para sinalizar na lista.
Future<List<EscolhaExercicio>?> escolherExercicios(BuildContext context,
    {required String titulo, Set<String> jaNoTreino = const {}}) {
  return Navigator.push<List<EscolhaExercicio>>(
    context,
    MaterialPageRoute(
      builder: (_) => SeletorExercicioScreen(titulo: titulo, multiplo: true, jaNoTreino: jaNoTreino),
    ),
  );
}

class SeletorExercicioScreen extends StatefulWidget {
  final String titulo;
  final String? nomeAtual;
  final bool multiplo;
  final Set<String> jaNoTreino;

  const SeletorExercicioScreen({
    super.key,
    required this.titulo,
    this.nomeAtual,
    this.multiplo = false,
    this.jaNoTreino = const {},
  });

  @override
  State<SeletorExercicioScreen> createState() => _SeletorExercicioScreenState();
}

class _SeletorExercicioScreenState extends State<SeletorExercicioScreen> {
  final ExercicioService _service = ExercicioService();
  late final TextEditingController _busca = TextEditingController(text: widget.nomeAtual ?? '');

  List<Exercicio> _catalogo = [];
  String? _grupo;
  bool _carregando = true;

  /// Chave → escolha, na ordem em que foram marcados (Map mantém a ordem
  /// de inserção).
  final Map<String, EscolhaExercicio> _selecionados = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final lista = await _service.buscarTodos();
      lista.sort((a, b) => a.nome.compareTo(b.nome));
      if (!mounted) return;
      setState(() {
        _catalogo = lista;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Meus Treinos: $e');
      // Sem catálogo ainda dá para usar um nome livre
      if (mounted) setState(() => _carregando = false);
    }
  }

  // Uma chave por chip, para centralizar o grupo tocado e revelar os
  // vizinhos, como no filtro da lista de exercícios
  final Map<String?, GlobalKey> _chavesGrupo = {
    null: GlobalKey(),
    for (final g in GrupoMuscular.todos) g.codigo: GlobalKey(),
  };

  void _mudarGrupo(String? grupo) {
    setState(() => _grupo = grupo);
    final contexto = _chavesGrupo[grupo]?.currentContext;
    if (contexto == null) return;
    Scrollable.ensureVisible(contexto, alignment: 0.5, duration: const Duration(milliseconds: 250));
  }

  List<Exercicio> get _filtrados {
    final texto = _busca.text.trim().toLowerCase();
    return _catalogo
        .where((ex) => _grupo == null || ex.musculoPrimario == _grupo)
        .where((ex) => texto.isEmpty || ex.nome.toLowerCase().contains(texto))
        .toList();
  }

  /// Nomes livres marcados: não aparecem na lista do catálogo, então ficam
  /// no topo para poderem ser desmarcados.
  List<MapEntry<String, EscolhaExercicio>> get _personalizadosMarcados =>
      _selecionados.entries.where((e) => e.value.slug == null).toList();

  void _tocar(String nome, String? slug, [TipoRegistro registro = TipoRegistro.forca]) {
    final escolha = (nome: nome.trim(), slug: slug, registro: registro);
    if (!widget.multiplo) {
      Navigator.pop<List<EscolhaExercicio>>(context, [escolha]);
      return;
    }
    final chave = ExercicioTreino.chaveDe(escolha.nome, slug);
    setState(() {
      if (_selecionados.remove(chave) == null) _selecionados[chave] = escolha;
    });
  }

  void _usarNomeDigitado() {
    final texto = _busca.text.trim();
    if (texto.isEmpty) return;
    final chave = ExercicioTreino.chaveDe(texto, null);
    // No modo múltiplo, digitar e confirmar sempre marca (não desmarca)
    if (widget.multiplo && _selecionados.containsKey(chave)) {
      setState(_busca.clear);
      return;
    }
    _tocar(texto, null);
    if (widget.multiplo) setState(_busca.clear);
  }

  void _confirmar() {
    Navigator.pop<List<EscolhaExercicio>>(context, _selecionados.values.toList());
  }

  /// Posição (1, 2, 3...) do exercício na seleção, ou nulo se não marcado.
  int? _ordem(String chave) {
    var i = 0;
    for (final k in _selecionados.keys) {
      i++;
      if (k == chave) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final texto = _busca.text.trim();
    final filtrados = _filtrados;
    final total = _selecionados.length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Conteudo(
          larguraMaxima: AppLayout.larguraLeitura,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: BotaoVoltar()),
              const SizedBox(height: 24),
              Text(widget.titulo, style: AppTexto.titulo(28)),
              if (widget.multiplo) ...[
                const SizedBox(height: 6),
                Text('Toque para marcar quantos quiser', style: AppTexto.meta),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _busca,
                autofocus: widget.nomeAtual == null,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _usarNomeDigitado(),
                style: AppTexto.item.copyWith(fontWeight: FontWeight.w500),
                decoration: decoracaoCampo(
                  'Buscar ou digitar um nome',
                  icone: Icons.search,
                  sufixo: texto.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(_busca.clear),
                          icon: const Icon(Icons.close, color: AppCores.textoSuave, size: 18),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                // Na web o Flutter só arrasta listas com toque; aqui o mouse
                // também arrasta, para alcançar os grupos fora da tela
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ChipOpcao(
                        key: _chavesGrupo[null],
                        texto: 'Todos',
                        selecionado: _grupo == null,
                        onTap: () => _mudarGrupo(null),
                      ),
                      for (final g in GrupoMuscular.todos)
                        Padding(
                          key: _chavesGrupo[g.codigo],
                          padding: const EdgeInsets.only(left: 8),
                          child: ChipOpcao(
                            texto: g.label,
                            selecionado: _grupo == g.codigo,
                            onTap: () => _mudarGrupo(g.codigo),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    if (texto.isNotEmpty)
                      _Opcao(
                        titulo: 'Usar "$texto"',
                        subtitulo: 'Exercício com nome personalizado',
                        miniatura: MiniaturaExercicio(slug: null, nome: texto),
                        ordem: widget.multiplo ? _ordem(ExercicioTreino.chaveDe(texto, null)) : null,
                        onTap: _usarNomeDigitado,
                      ),
                    if (widget.multiplo)
                      for (final e in _personalizadosMarcados)
                        if (e.key != ExercicioTreino.chaveDe(texto, null))
                          _Opcao(
                            titulo: e.value.nome,
                            subtitulo: 'Nome personalizado',
                            miniatura: MiniaturaExercicio(slug: null, nome: e.value.nome),
                            ordem: _ordem(e.key),
                            onTap: () => _tocar(e.value.nome, null),
                          ),
                    if (_carregando)
                      for (var i = 0; i < 5; i++)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Esqueleto(largura: 48, altura: 48, raio: 4),
                              SizedBox(width: 14),
                              Expanded(child: Esqueleto(altura: 14)),
                            ],
                          ),
                        )
                    else if (filtrados.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          texto.isEmpty
                              ? 'Nenhum exercício neste grupo.'
                              : 'Nenhum exercício do catálogo com esse nome.',
                          style: AppTexto.item.copyWith(color: AppCores.textoSuave),
                        ),
                      )
                    else
                      for (final ex in filtrados)
                        _Opcao(
                          titulo: ex.nome,
                          subtitulo: [
                            GrupoMuscular.labelDe(ex.musculoPrimario),
                            if (widget.jaNoTreino.contains(ExercicioTreino.chaveDe(ex.nome, ex.slug)))
                              'já está no treino',
                          ].join('  ·  '),
                          miniatura: MiniaturaExercicio(slug: ex.slug, nome: ex.nome),
                          ordem: widget.multiplo ? _ordem(ExercicioTreino.chaveDe(ex.nome, ex.slug)) : null,
                          onTap: () => _tocar(ex.nome, ex.slug, TipoRegistro.de(ex.registro)),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: !widget.multiplo || total == 0
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppCores.fundo,
                border: Border(top: BorderSide(color: AppCores.linha)),
              ),
              child: SafeArea(
                top: false,
                // A Column encolhe a barra à altura do botão: sozinho, o
                // Center do Conteudo ocuparia a tela toda
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Conteudo(
                      larguraMaxima: AppLayout.larguraLeitura,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Pressionavel(
                              onTap: () => setState(_selecionados.clear),
                              builder: (_, ativo) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                                child: Text(
                                  'Limpar',
                                  style: AppTexto.item.copyWith(
                                    fontSize: 14,
                                    color: ativo ? AppCores.texto : AppCores.textoSuave,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: BotaoDestaque(
                                texto: 'Adicionar $total ${total == 1 ? 'exercício' : 'exercícios'}',
                                icone: Icons.check_rounded,
                                onTap: _confirmar,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Opcao extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget miniatura;

  /// Posição na seleção múltipla; nulo quando não está marcado (ou no modo
  /// de escolha única).
  final int? ordem;
  final VoidCallback onTap;

  const _Opcao({
    required this.titulo,
    required this.subtitulo,
    required this.miniatura,
    required this.onTap,
    this.ordem,
  });

  @override
  Widget build(BuildContext context) {
    final marcado = ordem != null;
    return Pressionavel(
      onTap: onTap,
      builder: (_, ativo) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppCores.linha)),
        ),
        child: Row(
          children: [
            miniatura,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTexto.item),
                  const SizedBox(height: 3),
                  Text(subtitulo, style: AppTexto.meta.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: marcado ? AppCores.destaque : Colors.transparent,
                border: Border.all(
                  color: marcado ? AppCores.destaque : (ativo ? AppCores.textoSuave : AppCores.linha),
                  width: 1.5,
                ),
              ),
              child: marcado
                  ? Text('$ordem',
                      style: AppTexto.numero.copyWith(fontSize: 12, color: AppCores.sobreDestaque))
                  : Icon(Icons.add_rounded, size: 16, color: ativo ? AppCores.destaque : AppCores.textoApagado),
            ),
          ],
        ),
      ),
    );
  }
}
