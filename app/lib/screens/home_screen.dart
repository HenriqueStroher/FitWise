import 'package:flutter/material.dart';
import '../models/grupo_muscular.dart';
import '../services/exercicio_service.dart';
import '../services/sessao.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';

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

  @override
  void initState() {
    super.initState();
    _carregarContagem();
    // A contagem muda quando a academia do usuário oculta exercícios
    Sessao.academia.addListener(_carregarContagem);
  }

  @override
  void dispose() {
    Sessao.academia.removeListener(_carregarContagem);
    super.dispose();
  }

  Future<void> _carregarContagem() async {
    final contagem = await _service.contarPorGrupo();
    if (!mounted) return;
    setState(() {
      _contagem = contagem;
      _carregandoContagem = false;
    });
  }

  int get _total => _contagem.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final recuo = AppLayout.recuo(largura);
    final colunas = largura < 560 ? 2 : (largura < 900 ? 3 : 4);
    final espaco = largura < 560 ? 10.0 : 14.0;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(recuo, 36, recuo, 32),
          sliver: SliverToBoxAdapter(child: _buildCabecalho(largura)),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: recuo),
          sliver: SliverGrid.builder(
            itemCount: GrupoMuscular.todos.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colunas,
              mainAxisSpacing: espaco,
              crossAxisSpacing: espaco,
              childAspectRatio: colunas >= 4 ? 0.95 : 0.8,
            ),
            itemBuilder: (_, i) => _CardGrupo(
              grupo: GrupoMuscular.todos[i],
              indice: i + 1,
              total: _carregandoContagem ? null : (_contagem[GrupoMuscular.todos[i].codigo] ?? 0),
              onTap: () => widget.onNavegar(GrupoMuscular.todos[i].codigo),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(recuo, 40, recuo, 32),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Ilustrações: Everkinetic',
              style: AppTexto.meta.copyWith(color: AppCores.textoApagado, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCabecalho(double largura) {
    final tamanho = (largura * 0.095).clamp(32.0, 76.0);
    final titulo = Text('EXERCÍCIOS\nPOR GRUPO\nMUSCULAR', style: AppTexto.display(tamanho));
    final numeros = [
      _numero(_carregandoContagem ? '—' : '$_total', 'exercícios'),
      _numero('${GrupoMuscular.todos.length}', 'grupos'),
    ];

    // Em telas largas os números vão para a direita do título
    if (largura >= 900) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          titulo,
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [numeros[0], const SizedBox(height: 6), numeros[1]],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titulo,
        const SizedBox(height: 28),
        Row(children: [numeros[0], const SizedBox(width: 32), numeros[1]]),
      ],
    );
  }

  Widget _numero(String valor, String legenda) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(valor,
            style: AppTexto.titulo(22, peso: FontWeight.w700)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(width: 6),
        Text(legenda, style: AppTexto.meta),
      ],
    );
  }
}

class _CardGrupo extends StatelessWidget {
  final GrupoMuscular grupo;
  final int indice;
  final int? total;
  final VoidCallback onTap;

  const _CardGrupo({
    required this.grupo,
    required this.indice,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const tinta = AppCores.sobreDestaque;
    final apagado = tinta.withValues(alpha: 0.5);

    return Pressionavel(
      onTap: onTap,
      builder: (_, ativo) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: ativo ? AppCores.destaque : AppCores.papel),
          duration: const Duration(milliseconds: 180),
          builder: (_, cor, _) => Stack(
            children: [
              Positioned.fill(
                child: Ilustracao(
                  caminho: grupo.imagemCapa,
                  fundo: cor!,
                  respiro: const EdgeInsets.fromLTRB(6, 26, 6, 58),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Text(indice.toString().padLeft(2, '0'),
                    style: AppTexto.numero.copyWith(color: apagado)),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        grupo.label.toUpperCase(),
                        maxLines: 1,
                        style: AppTexto.display(16, cor: tinta).copyWith(letterSpacing: 0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total == null ? ' ' : '$total ${total == 1 ? 'exercício' : 'exercícios'}',
                      style: AppTexto.meta.copyWith(color: apagado, fontSize: 12),
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
