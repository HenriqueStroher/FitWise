import 'package:flutter/material.dart';
import '../navegacao.dart';
import '../theme/app_theme.dart';

/// Ilustração de exercício sobre um fundo colorido. As imagens são traço
/// preto em fundo quase branco; a matriz converte a claridade em
/// transparência (branco vira transparente, traço vira [tinta]), então o
/// fundo aparece sem a borda que o "quase branco" deixaria.
class Ilustracao extends StatelessWidget {
  final String caminho;
  final Color fundo;
  final Color tinta;
  final BoxFit ajuste;
  final EdgeInsets respiro;
  final Alignment alinhamento;

  const Ilustracao({
    super.key,
    required this.caminho,
    this.fundo = AppCores.papel,
    this.tinta = AppCores.sobreDestaque,
    this.ajuste = BoxFit.contain,
    this.respiro = EdgeInsets.zero,
    this.alinhamento = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: fundo,
      child: Padding(
        padding: respiro,
        child: ColorFiltered(
          colorFilter: _mascara(tinta),
          child: Image.asset(
            caminho,
            fit: ajuste,
            alignment: alinhamento,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

// Alpha = 1.25 * (1 - luminância) - 0.05: claridade acima de ~96% fica
// totalmente transparente; o resto escala até opaco.
ColorFilter _mascara(Color tinta) {
  const k = 1.25, corte = 0.05;
  return ColorFilter.matrix([
    0, 0, 0, 0, tinta.r * 255,
    0, 0, 0, 0, tinta.g * 255,
    0, 0, 0, 0, tinta.b * 255,
    -k * 0.2126, -k * 0.7152, -k * 0.0722, 0, (k - corte) * 255,
  ]);
}

/// Centraliza o conteúdo e limita a largura em telas grandes.
class Conteudo extends StatelessWidget {
  final Widget child;
  final double larguraMaxima;

  const Conteudo({
    super.key,
    required this.child,
    this.larguraMaxima = AppLayout.larguraMaxima,
  });

  @override
  Widget build(BuildContext context) {
    final margem = AppLayout.margem(MediaQuery.sizeOf(context).width);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: larguraMaxima + margem * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: margem),
          child: child,
        ),
      ),
    );
  }
}

/// Área tocável com retorno de hover (web) e de pressão (toque), no lugar
/// do splash padrão do Material.
class Pressionavel extends StatefulWidget {
  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool ativo) builder;

  const Pressionavel({super.key, required this.onTap, required this.builder});

  @override
  State<Pressionavel> createState() => _PressionavelState();
}

class _PressionavelState extends State<Pressionavel> {
  bool _hover = false;
  bool _pressionado = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressionado = true),
        onTapUp: (_) => setState(() => _pressionado = false),
        onTapCancel: () => setState(() => _pressionado = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressionado ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.builder(context, _hover || _pressionado),
        ),
      ),
    );
  }
}

/// Bloco cinza usado enquanto os dados carregam.
class Esqueleto extends StatelessWidget {
  final double? largura;
  final double altura;
  final double raio;

  const Esqueleto({super.key, this.largura, required this.altura, this.raio = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: largura,
      height: altura,
      decoration: BoxDecoration(
        color: AppCores.superficieAlta,
        borderRadius: BorderRadius.circular(raio),
      ),
    );
  }
}

/// Botão circular com ícone das telas internas (voltar, início, anterior...).
/// Sem [onTap], aparece apagado e não responde.
class BotaoCircular extends StatelessWidget {
  final IconData icone;
  final String dica;
  final VoidCallback? onTap;

  const BotaoCircular({super.key, required this.icone, required this.dica, this.onTap});

  Widget _circulo(bool ativo) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: ativo ? AppCores.superficieAlta : AppCores.superficie,
          shape: BoxShape.circle,
          border: Border.all(color: AppCores.linha),
        ),
        child: Icon(icone, color: AppCores.texto, size: 18),
      );

  @override
  Widget build(BuildContext context) {
    final toque = onTap;
    return Semantics(
      button: true,
      enabled: toque != null,
      label: dica,
      child: Tooltip(
        message: dica,
        child: toque == null
            ? Opacity(opacity: 0.3, child: _circulo(false))
            : Pressionavel(onTap: toque, builder: (_, ativo) => _circulo(ativo)),
      ),
    );
  }
}

/// Botão de voltar das telas internas.
class BotaoVoltar extends StatelessWidget {
  const BotaoVoltar({super.key});

  @override
  Widget build(BuildContext context) {
    return BotaoCircular(
      icone: Icons.arrow_back,
      dica: 'Voltar',
      onTap: () => Navigator.of(context).maybePop(),
    );
  }
}

/// Volta direto à tela inicial, fechando todas as telas abertas por cima.
/// Útil depois de encadear detalhe → variações → detalhe...
class BotaoInicio extends StatelessWidget {
  const BotaoInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return BotaoCircular(
      icone: Icons.home_outlined,
      dica: 'Início',
      onTap: () => Navegacao.irParaInicio(context),
    );
  }
}

/// Voltar e início lado a lado, para o topo das telas internas.
class BotoesTopo extends StatelessWidget {
  const BotoesTopo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [BotaoVoltar(), SizedBox(width: 8), BotaoInicio()],
    );
  }
}
