import 'package:flutter/material.dart';
import '../models/grupo_muscular.dart';
import '../services/exercicio_service.dart';

class HomeScreen extends StatefulWidget {
  final void Function(String grupo) onNavegar;

  const HomeScreen({super.key, required this.onNavegar});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ExercicioService _service = ExercicioService();

  Map<String, int> _contagem = {};
  bool _carregandoContagem = true;

  static const _bgPrimary = Color(0xFF111111);
  static const _bgCard    = Color(0xFF1C1C1C);

  @override
  void initState() {
    super.initState();
    _carregarContagem();
  }

  Future<void> _carregarContagem() async {
    final contagem = await _service.contarPorGrupo();
    if (!mounted) return;
    setState(() {
      _contagem = contagem;
      _carregandoContagem = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCabecalho(),
            const SizedBox(height: 32),
            _buildComoUsar(),
            const SizedBox(height: 24),
            _buildRecursos(),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecalho() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.fitness_center, color: Colors.black, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FitWise',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Seu guia de musculação',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Bem-vindo ao FitWise!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Um aplicativo educativo desenvolvido para orientar praticantes de musculação no aprendizado e execução correta dos exercícios.',
          style: TextStyle(color: Colors.white54, fontSize: 15, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildComoUsar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Como usar',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _passo('1', 'Filtre por grupo muscular',
              'Deslize o filtro no topo da seção "Exercícios" para percorrer os grupos musculares.'),
          _passo('2', 'Busque um exercício',
              'Digite o nome na barra de busca para encontrar rapidamente o que procura.'),
          _passo('3', 'Explore os detalhes',
              'Toque em qualquer exercício para ver instruções completas de execução, equipamentos e cuidados.'),
          _passo('4', 'Descubra variações',
              'Use o botão "Sugerir Variação" para ver exercícios similares recomendados pela IA.'),
        ],
      ),
    );
  }

  Widget _passo(String numero, String titulo, String descricao) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                numero,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(descricao,
                    style: const TextStyle(color: Colors.white38, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecursos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'O que você encontra aqui',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _buildGradeGrupos(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _cardInfo(Icons.menu_book_rounded, 'Conteúdo\nEducativo', 'Detalhado')),
            const SizedBox(width: 10),
            Expanded(child: _cardInfo(Icons.lightbulb_outline, 'IA de\nVariações', 'Inteligente')),
          ],
        ),
      ],
    );
  }

  // Grade de dois cards por linha com todos os grupos musculares
  Widget _buildGradeGrupos() {
    const grupos = GrupoMuscular.todos;
    final linhas = <Widget>[];

    for (var i = 0; i < grupos.length; i += 2) {
      final direita = i + 1 < grupos.length ? grupos[i + 1] : null;

      linhas.add(Padding(
        padding: EdgeInsets.only(bottom: i + 2 < grupos.length ? 10 : 0),
        child: Row(
          children: [
            Expanded(child: _cardGrupo(grupos[i])),
            const SizedBox(width: 10),
            // Mantém a largura das colunas quando a última linha tem um só card
            Expanded(
              child: direita == null ? const SizedBox.shrink() : _cardGrupo(direita),
            ),
          ],
        ),
      ));
    }

    return Column(children: linhas);
  }

  // Card clicável de grupo muscular
  Widget _cardGrupo(GrupoMuscular grupo) {
    final total = _contagem[grupo.codigo] ?? 0;
    final subtitulo = _carregandoContagem
        ? '...'
        : '$total ${total == 1 ? 'exercício' : 'exercícios'}';

    return GestureDetector(
      onTap: () => widget.onNavegar(grupo.codigo),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(grupo.icone, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(grupo.label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(subtitulo,
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  // Card informativo (sem clique)
  Widget _cardInfo(IconData icone, String titulo, String subtitulo) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icone, color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitulo,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
