import 'dart:async';

import 'package:flutter/material.dart';
import '../models/exercicio.dart';
import '../models/grupo_muscular.dart';
import '../models/rotulos.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import 'sugestoes_screen.dart';

class DetalheExercicioScreen extends StatelessWidget {
  final Exercicio exercicio;

  const DetalheExercicioScreen({super.key, required this.exercicio});

  void _abrirSugestoes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SugestoesScreen(exercicioOrigem: exercicio)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= 900;
    final hero = _HeroAnimado(exercicio: exercicio);
    final info = _Informacoes(
      exercicio: exercicio,
      botao: largo ? _BotaoVariacoes(onTap: () => _abrirSugestoes(context)) : null,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Conteudo(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const BotaoVoltar(),
                const SizedBox(height: 16),
                if (largo)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: hero),
                      const SizedBox(width: 48),
                      Expanded(flex: 6, child: info),
                    ],
                  )
                else ...[
                  hero,
                  const SizedBox(height: 24),
                  info,
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: largo
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppCores.fundo,
                border: Border(top: BorderSide(color: AppCores.linha)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: _BotaoVariacoes(onTap: () => _abrirSugestoes(context)),
                ),
              ),
            ),
    );
  }
}

/// Alterna os frames da ilustração para mostrar o movimento. Um toque pausa.
class _HeroAnimado extends StatefulWidget {
  final Exercicio exercicio;

  const _HeroAnimado({required this.exercicio});

  @override
  State<_HeroAnimado> createState() => _HeroAnimadoState();
}

class _HeroAnimadoState extends State<_HeroAnimado> {
  Timer? _timer;
  int _frameAtual = 0;
  bool _pausado = false;

  int get _totalFrames {
    final n = widget.exercicio.frames.length;
    return n == 0 ? 1 : n;
  }

  String _frame(int i) => 'assets/images/${widget.exercicio.slug}-${i + 1}.webp';

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Carrega todos os frames antes, para a troca não piscar
    for (var i = 0; i < _totalFrames; i++) {
      precacheImage(AssetImage(_frame(i)), context);
    }
  }

  void _iniciar() {
    if (_totalFrames < 2) return;
    _timer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      setState(() => _frameAtual = (_frameAtual + 1) % _totalFrames);
    });
  }

  void _alternar() {
    if (_totalFrames < 2) return;
    setState(() => _pausado = !_pausado);
    if (_pausado) {
      _timer?.cancel();
    } else {
      _iniciar();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _alternar,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AspectRatio(
          aspectRatio: 1.1,
          child: Stack(
            children: [
              Positioned.fill(
                child: Ilustracao(
                  caminho: _frame(_frameAtual),
                  respiro: const EdgeInsets.all(28),
                ),
              ),
              if (_totalFrames > 1)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      for (var i = 0; i < _totalFrames; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _frameAtual ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppCores.sobreDestaque
                                .withValues(alpha: i == _frameAtual ? 0.85 : 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              if (_pausado)
                const Positioned(
                  right: 14,
                  bottom: 12,
                  child: Icon(Icons.play_arrow_rounded, color: AppCores.sobreDestaque, size: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Informacoes extends StatelessWidget {
  final Exercicio exercicio;
  final Widget? botao;

  const _Informacoes({required this.exercicio, this.botao});

  @override
  Widget build(BuildContext context) {
    final ex = exercicio;
    final largura = MediaQuery.sizeOf(context).width;

    final sobretitulo = [
      GrupoMuscular.labelDe(ex.musculoPrimario),
      if (ex.tipo.isNotEmpty) Rotulos.tipo(ex.tipo),
    ].join('  ·  ').toUpperCase();

    final ficha = <(String, String)>[
      if (ex.equipamento.isNotEmpty) ('Equipamento', Rotulos.equipamentos(ex.equipamento)),
      if (ex.musculoSecundario.isNotEmpty)
        (
          switch (ex.musculoPrimario) {
            'ALONGAMENTO' => 'Alonga',
            'CORRIDA' => 'Músculos',
            _ => 'Secundários',
          },
          ex.musculoSecundario.map(Rotulos.musculo).join(', '),
        ),
      if (ex.planoMovimento.isNotEmpty) ('Plano', Rotulos.plano(ex.planoMovimento)),
      if (ex.vetorForca.isNotEmpty) ('Vetor de força', Rotulos.vetor(ex.vetorForca)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sobretitulo, style: AppTexto.rotulo.copyWith(color: AppCores.destaque)),
        const SizedBox(height: 10),
        Text(ex.nome, style: AppTexto.titulo(largura >= 720 ? 40 : 30)),
        if (ex.descricao.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(ex.descricao, style: AppTexto.corpo.copyWith(fontSize: 16)),
        ],
        if (botao != null) ...[
          const SizedBox(height: 28),
          botao!,
        ],
        if (ficha.isNotEmpty) ...[
          const SizedBox(height: 32),
          _Ficha(linhas: ficha),
        ],
        if (ex.steps.isNotEmpty) ...[
          const SizedBox(height: 40),
          _TituloSecao('Execução', '${ex.steps.length} passos'),
          const SizedBox(height: 18),
          for (var i = 0; i < ex.steps.length; i++) _Passo(numero: i + 1, texto: ex.steps[i]),
        ],
        if (ex.cuidados.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _TituloSecao('Cuidados', null),
          const SizedBox(height: 16),
          for (final c in ex.cuidados) _Cuidado(texto: c),
        ],
      ],
    );
  }
}

class _TituloSecao extends StatelessWidget {
  final String titulo;
  final String? detalhe;

  const _TituloSecao(this.titulo, this.detalhe);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(titulo, style: AppTexto.titulo(20)),
        const Spacer(),
        if (detalhe != null) Text(detalhe!, style: AppTexto.meta),
      ],
    );
  }
}

/// Tabela de características do exercício (equipamento, plano etc.).
class _Ficha extends StatelessWidget {
  final List<(String, String)> linhas;

  const _Ficha({required this.linhas});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppCores.linha)),
      ),
      child: Column(
        children: [
          for (final (rotulo, valor) in linhas)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppCores.linha)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 128,
                    child: Text(rotulo, style: AppTexto.meta.copyWith(fontSize: 14)),
                  ),
                  Expanded(
                    child: Text(valor,
                        style: AppTexto.item.copyWith(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Passo extends StatelessWidget {
  final int numero;
  final String texto;

  const _Passo({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              numero.toString().padLeft(2, '0'),
              style: AppTexto.numero.copyWith(fontSize: 15, color: AppCores.destaque, height: 1.55),
            ),
          ),
          Expanded(
            child: Text(texto, style: AppTexto.corpo.copyWith(color: AppCores.texto)),
          ),
        ],
      ),
    );
  }
}

class _Cuidado extends StatelessWidget {
  final String texto;

  const _Cuidado({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 11, right: 18),
            width: 18,
            height: 2,
            color: AppCores.textoApagado,
          ),
          Expanded(child: Text(texto, style: AppTexto.corpo)),
        ],
      ),
    );
  }
}

class _BotaoVariacoes extends StatelessWidget {
  final VoidCallback onTap;

  const _BotaoVariacoes({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressionavel(
      onTap: onTap,
      builder: (_, ativo) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: ativo ? const Color(0xFFE2FF7A) : AppCores.destaque,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Text(
              'Ver variações similares',
              style: AppTexto.item.copyWith(color: AppCores.sobreDestaque, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward, color: AppCores.sobreDestaque, size: 20),
          ],
        ),
      ),
    );
  }
}
