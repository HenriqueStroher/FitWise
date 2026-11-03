import 'package:flutter/material.dart';
import '../models/exercicio.dart';
import '../models/grupo_muscular.dart';
import '../services/recomendacao_service.dart';
import '../services/exercicio_service.dart';
import 'detalhe_exercicio_screen.dart';

class SugestoesScreen extends StatefulWidget {
  final Exercicio exercicioOrigem;

  const SugestoesScreen({super.key, required this.exercicioOrigem});

  @override
  State<SugestoesScreen> createState() => _SugestoesScreenState();
}

class _SugestoesScreenState extends State<SugestoesScreen> {
  final RecomendacaoService _recomendacao = RecomendacaoService();
  final ExercicioService _exercicioService = ExercicioService();

  List<MapEntry<Exercicio, double>> _sugestoes = [];
  bool _carregando = true;

  static const _bgPrimary = Color(0xFF111111);
  static const _bgCard    = Color(0xFF1C1C1C);

  @override
  void initState() {
    super.initState();
    _gerarSugestoes();
  }

  Future<void> _gerarSugestoes() async {
    final catalogo = await _exercicioService
        .buscarPorGrupo(widget.exercicioOrigem.musculoPrimario);

    final sugestoes = _recomendacao.sugerirVariacoes(
      widget.exercicioOrigem,
      catalogo,
    );

    setState(() {
      _sugestoes = sugestoes;
      _carregando = false;
    });
  }

  Color _corScore(double score) {
    if (score >= 0.90) return const Color(0xFF4ADE80); // verde
    if (score >= 0.75) return const Color(0xFFFBBF24); // amarelo
    return const Color(0xFFEF4444);                    // vermelho
  }

  String _labelScore(double score) {
    if (score >= 0.90) return 'Alta compatibilidade';
    if (score >= 0.75) return 'Boa compatibilidade';
    return 'Compatibilidade moderada';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Sugestões de Variação',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: Colors.white54))
          : Column(
              children: [
                _cardOrigem(),
                Expanded(child: _buildLista()),
              ],
            ),
    );
  }

  Widget _cardOrigem() {
    final ex = widget.exercicioOrigem;
    final imagePath = 'assets/images/${ex.slug}-1.png';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.fitness_center, color: Colors.black54, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Base de comparação',
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  ex.nome,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              GrupoMuscular.labelDe(ex.musculoPrimario),
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (_sugestoes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text('Nenhuma variação encontrada',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
            SizedBox(height: 6),
            Text('Tente outro exercício como base',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _sugestoes.length,
      itemBuilder: (context, index) {
        final entry = _sugestoes[index];
        return _cardSugestao(entry.key, entry.value);
      },
    );
  }

  Widget _cardSugestao(Exercicio ex, double score) {
    final imagePath = 'assets/images/${ex.slug}-1.png';
    final cor = _corScore(score);
    final label = _labelScore(score);

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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: score,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(cor),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
