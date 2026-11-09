import 'package:flutter/material.dart';
import '../models/exercicio.dart';
import '../models/grupo_muscular.dart';
import '../models/rotulos.dart';
import '../services/exercicio_service.dart';
import '../services/sessao.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import 'detalhe_exercicio_screen.dart';

class ListaExerciciosScreen extends StatefulWidget {
  const ListaExerciciosScreen({super.key});

  @override
  ListaExerciciosScreenState createState() => ListaExerciciosScreenState();
}

class ListaExerciciosScreenState extends State<ListaExerciciosScreen> {
  final ExercicioService _service = ExercicioService();
  final TextEditingController _buscaController = TextEditingController();
  final ScrollController _rolagem = ScrollController();

  List<Exercicio> _exercicios = [];
  List<Exercicio> _exerciciosFiltrados = [];
  String _grupoSelecionado = GrupoMuscular.codigoPadrao;
  bool _carregando = true;

  // Uma chave por chip, para trazer o grupo selecionado para a área visível
  // quando a troca vem da tela inicial e não de um toque no próprio filtro.
  final Map<String, GlobalKey> _chavesGrupo = {
    for (final grupo in GrupoMuscular.todos) grupo.codigo: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _carregarExercicios();
    // A lista muda quando a academia do usuário oculta exercícios
    Sessao.academia.addListener(_carregarExercicios);
  }

  @override
  void dispose() {
    Sessao.academia.removeListener(_carregarExercicios);
    _buscaController.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  // Público para ser chamado pelo MainScreen
  void mudarGrupo(String grupo) {
    if (_grupoSelecionado == grupo) return;
    setState(() => _grupoSelecionado = grupo);
    _buscaController.clear();
    if (_rolagem.hasClients) _rolagem.jumpTo(0);
    _revelarGrupoSelecionado();
    _carregarExercicios();
  }

  void _revelarGrupoSelecionado() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contexto = _chavesGrupo[_grupoSelecionado]?.currentContext;
      if (contexto == null) return;
      Scrollable.ensureVisible(
        contexto,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
      );
    });
  }

  Future<void> _carregarExercicios() async {
    final grupo = _grupoSelecionado;
    setState(() => _carregando = true);
    final lista = await _service.buscarPorGrupo(grupo);
    // Descarta a resposta se o usuário já trocou de grupo nesse meio-tempo
    if (!mounted || grupo != _grupoSelecionado) return;
    _exercicios = lista;
    _carregando = false;
    _filtrarBusca(_buscaController.text);
  }

  void _filtrarBusca(String texto) {
    setState(() {
      _exerciciosFiltrados = _exercicios
          .where((ex) => ex.nome.toLowerCase().contains(texto.toLowerCase()))
          .toList();
    });
  }

  void _limparBusca() {
    _buscaController.clear();
    _filtrarBusca('');
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final recuo = AppLayout.recuo(largura);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(recuo, 28, recuo, 20),
          child: _buildTitulo(largura),
        ),
        _buildFiltroGrupo(recuo),
        Padding(
          padding: EdgeInsets.fromLTRB(recuo, 14, recuo, 6),
          child: _buildBusca(),
        ),
        Expanded(child: _buildLista(largura, recuo)),
      ],
    );
  }

  Widget _buildTitulo(double largura) {
    final total = _exercicios.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            GrupoMuscular.labelDe(_grupoSelecionado).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTexto.display((largura * 0.085).clamp(30.0, 56.0)),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            _carregando ? '' : '$total ${total == 1 ? 'exercício' : 'exercícios'}',
            style: AppTexto.meta,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltroGrupo(double recuo) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: recuo),
        children: [
          for (final grupo in GrupoMuscular.todos)
            Padding(
              padding: EdgeInsets.only(
                right: grupo == GrupoMuscular.todos.last ? 0 : 8,
              ),
              child: _botaoGrupo(grupo),
            ),
        ],
      ),
    );
  }

  Widget _botaoGrupo(GrupoMuscular grupo) {
    final selecionado = _grupoSelecionado == grupo.codigo;
    return Pressionavel(
      key: _chavesGrupo[grupo.codigo],
      onTap: () => mudarGrupo(grupo.codigo),
      builder: (_, ativo) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selecionado ? AppCores.destaque : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selecionado
                ? AppCores.destaque
                : (ativo ? AppCores.textoApagado : AppCores.linha),
          ),
        ),
        child: Text(
          grupo.label,
          style: AppTexto.item.copyWith(
            fontSize: 13,
            color: selecionado
                ? AppCores.sobreDestaque
                : (ativo ? AppCores.texto : AppCores.textoSuave),
          ),
        ),
      ),
    );
  }

  Widget _buildBusca() {
    return TextField(
      controller: _buscaController,
      onChanged: _filtrarBusca,
      style: AppTexto.item.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Buscar em ${GrupoMuscular.labelDe(_grupoSelecionado)}',
        hintStyle: AppTexto.item.copyWith(
            fontWeight: FontWeight.w400, color: AppCores.textoApagado),
        prefixIcon: const Icon(Icons.search, color: AppCores.textoApagado, size: 20),
        suffixIcon: _buscaController.text.isEmpty
            ? null
            : IconButton(
                onPressed: _limparBusca,
                icon: const Icon(Icons.close, color: AppCores.textoSuave, size: 18),
              ),
        filled: true,
        fillColor: AppCores.superficie,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppCores.textoApagado),
        ),
      ),
    );
  }

  Widget _buildLista(double largura, double recuo) {
    final duasColunas = largura >= 860;
    final padding = EdgeInsets.fromLTRB(recuo, 8, recuo, 32);

    if (_carregando) {
      return ListView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (_, _) => const _LinhaEsqueleto(),
      );
    }

    if (_exerciciosFiltrados.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(recuo, 40, recuo, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nada encontrado para "${_buscaController.text}".',
                style: AppTexto.item.copyWith(color: AppCores.textoSuave)),
            const SizedBox(height: 12),
            Pressionavel(
              onTap: _limparBusca,
              builder: (_, ativo) => Text(
                'Limpar busca',
                style: AppTexto.item.copyWith(
                  color: AppCores.destaque,
                  decoration: ativo ? TextDecoration.underline : null,
                  decorationColor: AppCores.destaque,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (duasColunas) {
      return GridView.builder(
        controller: _rolagem,
        padding: padding,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 28,
          mainAxisExtent: 97,
        ),
        itemCount: _exerciciosFiltrados.length,
        itemBuilder: (_, i) =>
            LinhaExercicio(exercicio: _exerciciosFiltrados[i], sequencia: _exerciciosFiltrados),
      );
    }

    return ListView.builder(
      controller: _rolagem,
      padding: padding,
      itemCount: _exerciciosFiltrados.length,
      itemBuilder: (_, i) =>
          LinhaExercicio(exercicio: _exerciciosFiltrados[i], sequencia: _exerciciosFiltrados),
    );
  }
}

/// Linha de exercício usada na lista e nas sugestões: miniatura, nome e
/// metadados. [trailing] ocupa a ponta direita (ex.: % de similaridade).
/// [sequencia] é a lista em que a linha está, para o detalhe poder passar
/// para o anterior e o próximo.
class LinhaExercicio extends StatelessWidget {
  final Exercicio exercicio;
  final List<Exercicio> sequencia;
  final Widget? trailing;

  const LinhaExercicio({
    super.key,
    required this.exercicio,
    this.sequencia = const [],
    this.trailing,
  });

  String get _meta {
    final partes = [
      if (exercicio.tipo.isNotEmpty) Rotulos.tipo(exercicio.tipo),
      if (exercicio.equipamento.isNotEmpty) Rotulos.equipamentos(exercicio.equipamento),
    ];
    return partes.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    return Pressionavel(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          // Cópia: a lista filtrada muda se a busca mudar com o detalhe aberto
          builder: (_) => DetalheExercicioScreen(exercicio: exercicio, sequencia: List.of(sequencia)),
        ),
      ),
      builder: (_, ativo) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppCores.linha)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Ilustracao(
                  caminho: 'assets/images/${exercicio.slug}-1.webp',
                  fundo: ativo ? AppCores.destaque : AppCores.papel,
                  ajuste: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(exercicio.nome,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTexto.item),
                  if (_meta.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(_meta,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTexto.meta),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _LinhaEsqueleto extends StatelessWidget {
  const _LinhaEsqueleto();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppCores.linha)),
      ),
      child: const Row(
        children: [
          Esqueleto(largura: 72, altura: 72, raio: 4),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Esqueleto(largura: 180, altura: 14),
                SizedBox(height: 10),
                Esqueleto(largura: 110, altura: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
