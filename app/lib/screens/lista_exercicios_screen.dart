import 'package:flutter/material.dart';
import '../models/exercicio.dart';
import '../models/grupo_muscular.dart';
import '../services/exercicio_service.dart';
import 'detalhe_exercicio_screen.dart';

class ListaExerciciosScreen extends StatefulWidget {
  const ListaExerciciosScreen({super.key});

  @override
  ListaExerciciosScreenState createState() => ListaExerciciosScreenState();
}

class ListaExerciciosScreenState extends State<ListaExerciciosScreen>
    with SingleTickerProviderStateMixin {
  final ExercicioService _service = ExercicioService();
  final TextEditingController _buscaController = TextEditingController();
  late AnimationController _animController;

  List<Exercicio> _exercicios = [];
  List<Exercicio> _exerciciosFiltrados = [];
  String _grupoSelecionado = GrupoMuscular.codigoPadrao;
  bool _carregando = true;

  // Uma chave por chip, para trazer o grupo selecionado para a área visível
  // quando a troca vem da tela inicial e não de um toque no próprio filtro.
  final Map<String, GlobalKey> _chavesGrupo = {
    for (final grupo in GrupoMuscular.todos) grupo.codigo: GlobalKey(),
  };

  static const _bgPrimary = Color(0xFF111111);
  static const _bgCard    = Color(0xFF1C1C1C);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _carregarExercicios();
  }

  @override
  void dispose() {
    _animController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  // Público para ser chamado pelo MainScreen
  void mudarGrupo(String grupo) {
    if (_grupoSelecionado == grupo) return;
    setState(() => _grupoSelecionado = grupo);
    _buscaController.clear();
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
    setState(() => _carregando = true);
    final lista = await _service.buscarPorGrupo(_grupoSelecionado);
    setState(() {
      _exercicios = lista;
      _exerciciosFiltrados = lista;
      _carregando = false;
    });
  }

  void _filtrarBusca(String texto) {
    setState(() {
      _exerciciosFiltrados = _exercicios
          .where((ex) => ex.nome.toLowerCase().contains(texto.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Column(
        children: [
          _buildFiltroGrupo(),
          _buildBusca(),
          Expanded(child: _buildLista()),
        ],
      ),
    );
  }

  Widget _buildFiltroGrupo() {
    return Container(
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
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
      ),
    );
  }

  Widget _botaoGrupo(GrupoMuscular grupo) {
    final selecionado = _grupoSelecionado == grupo.codigo;
    return GestureDetector(
      key: _chavesGrupo[grupo.codigo],
      onTap: () => mudarGrupo(grupo.codigo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado ? Colors.white : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          grupo.label,
          style: TextStyle(
            color: selecionado ? Colors.black : Colors.white54,
            fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildBusca() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _buscaController,
        onChanged: _filtrarBusca,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Buscar exercício...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
          filled: true,
          fillColor: _bgCard,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white24, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildLista() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    if (_exerciciosFiltrados.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text(
              'Nenhum exercício encontrado',
              style: TextStyle(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _exerciciosFiltrados.length,
      itemBuilder: (context, index) {
        return _cardExercicio(_exerciciosFiltrados[index]);
      },
    );
  }

  Widget _cardExercicio(Exercicio ex) {
    final imagePath = 'assets/images/${ex.slug}-1.webp';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalheExercicioScreen(exercicio: ex)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.fitness_center,
                    color: Colors.black54,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  ex.nome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
