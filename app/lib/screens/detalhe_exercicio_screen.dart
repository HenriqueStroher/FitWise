import 'package:flutter/material.dart';
import '../models/exercicio.dart';
import '../models/grupo_muscular.dart';
import 'sugestoes_screen.dart';

class DetalheExercicioScreen extends StatefulWidget {
  final Exercicio exercicio;

  const DetalheExercicioScreen({super.key, required this.exercicio});

  @override
  State<DetalheExercicioScreen> createState() => _DetalheExercicioScreenState();
}

class _DetalheExercicioScreenState extends State<DetalheExercicioScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _frameAtual = 0;

  static const _bgPrimary = Color(0xFF111111);
  static const _bgCard    = Color(0xFF1C1C1C);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        final totalFrames = widget.exercicio.frames.length;
        if (totalFrames > 1) {
          setState(() {
            _frameAtual = (_animController.value * totalFrames).floor() % totalFrames;
          });
        }
      });
    _animController.repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _frameLocalPath(int index) {
    final slug = widget.exercicio.slug;
    return 'assets/images/$slug-${index + 1}.png';
  }

  String _capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercicio;

    return Scaffold(
      backgroundColor: _bgPrimary,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          ex.nome,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  _frameLocalPath(_frameAtual),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.fitness_center, color: Colors.black38, size: 60),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _secao('Sobre o exercício', ex.descricao),
            const SizedBox(height: 16),

            _chip('Músculo alvo', GrupoMuscular.labelDe(ex.musculoPrimario)),
            const SizedBox(height: 16),

            _secaoListaCapitalizada('Equipamento', ex.equipamento),
            const SizedBox(height: 16),

            _secaoLista('Como executar', ex.steps),
            const SizedBox(height: 16),

            _secaoListaIcone('Cuidados', ex.cuidados),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SugestoesScreen(exercicioOrigem: ex),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Sugerir Variação',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secao(String titulo, String conteudo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        Text(conteudo, style: const TextStyle(color: Colors.white60, height: 1.5)),
      ],
    );
  }

  Widget _chip(String label, String valor) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            valor,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _secaoListaCapitalizada(String titulo, List<String> itens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...itens.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  Expanded(
                    child: Text(
                      _capitalizar(item),
                      style: const TextStyle(color: Colors.white60, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _secaoLista(String titulo, List<String> itens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...itens.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  Expanded(
                      child: Text(item,
                          style: const TextStyle(color: Colors.white60, height: 1.4))),
                ],
              ),
            )),
      ],
    );
  }

  Widget _secaoListaIcone(String titulo, List<String> itens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white60, size: 18),
            const SizedBox(width: 6),
            Text(titulo,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 8),
        ...itens.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(item,
                          style: const TextStyle(color: Colors.white60, height: 1.4))),
                ],
              ),
            )),
      ],
    );
  }
}
