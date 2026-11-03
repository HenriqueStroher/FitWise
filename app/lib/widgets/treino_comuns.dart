import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'comuns.dart';

/// Componentes da área "Meus Treinos", no mesmo padrão visual do resto do
/// app (botão em destaque, campos com fundo de superfície, chips).

class BotaoDestaque extends StatelessWidget {
  final String texto;
  final VoidCallback? onTap;
  final IconData? icone;
  final bool carregando;

  const BotaoDestaque({
    super.key,
    required this.texto,
    required this.onTap,
    this.icone,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null && !carregando;
    return Pressionavel(
      onTap: habilitado ? onTap! : () {},
      builder: (_, ativo) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: !habilitado
              ? AppCores.destaque.withValues(alpha: 0.5)
              : (ativo ? const Color(0xFFE2FF7A) : AppCores.destaque),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                texto,
                style: AppTexto.item.copyWith(color: AppCores.sobreDestaque, fontWeight: FontWeight.w700),
              ),
            ),
            if (carregando)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppCores.sobreDestaque),
              )
            else
              Icon(icone ?? Icons.arrow_forward, color: AppCores.sobreDestaque, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Botão de linha (contorno), para ações secundárias.
class BotaoContorno extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;
  final IconData icone;
  final bool compacto;

  const BotaoContorno({
    super.key,
    required this.texto,
    required this.onTap,
    required this.icone,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressionavel(
      onTap: onTap,
      builder: (_, ativo) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: compacto ? 40 : 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: ativo ? AppCores.superficie : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ativo ? AppCores.textoApagado : AppCores.linha),
        ),
        child: Row(
          mainAxisSize: compacto ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icone, color: AppCores.destaque, size: 18),
            const SizedBox(width: 10),
            Text(texto, style: AppTexto.item.copyWith(fontSize: compacto ? 13 : 15)),
          ],
        ),
      ),
    );
  }
}

/// Chip de seleção, igual ao filtro de grupos da lista de exercícios.
class ChipOpcao extends StatelessWidget {
  final String texto;
  final bool selecionado;
  final VoidCallback onTap;

  const ChipOpcao({super.key, required this.texto, required this.selecionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressionavel(
      onTap: onTap,
      builder: (_, ativo) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selecionado ? AppCores.destaque : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selecionado ? AppCores.destaque : (ativo ? AppCores.textoApagado : AppCores.linha),
          ),
        ),
        child: Text(
          texto,
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
}

/// Decoração dos campos de texto, a mesma da busca de exercícios.
InputDecoration decoracaoCampo(String dica, {IconData? icone, Widget? sufixo}) {
  return InputDecoration(
    hintText: dica,
    hintStyle: AppTexto.item.copyWith(fontWeight: FontWeight.w400, color: AppCores.textoApagado),
    prefixIcon: icone == null ? null : Icon(icone, color: AppCores.textoApagado, size: 20),
    suffixIcon: sufixo,
    filled: true,
    fillColor: AppCores.superficie,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: icone == null ? 14 : 0),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppCores.textoApagado),
    ),
  );
}

/// Diálogo de confirmação para ações destrutivas. Devolve true se confirmado.
Future<bool> confirmar(BuildContext context,
    {required String titulo, required String mensagem, String acao = 'Remover'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      backgroundColor: AppCores.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(titulo, style: AppTexto.titulo(20)),
      content: Text(mensagem, style: AppTexto.corpo),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto, false),
          child: Text('Cancelar', style: AppTexto.item.copyWith(color: AppCores.textoSuave)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(contexto, true),
          child: Text(acao, style: AppTexto.item.copyWith(color: AppCores.destaque)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void avisar(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensagem, style: AppTexto.item.copyWith(fontSize: 14)),
      backgroundColor: AppCores.superficieAlta,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Número grande com legenda ao lado, como os totais da tela inicial.
class NumeroLegenda extends StatelessWidget {
  final String valor;
  final String legenda;

  const NumeroLegenda(this.valor, this.legenda, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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

/// Miniatura do exercício: ilustração do catálogo, ou um bloco com a
/// inicial quando o exercício tem nome livre.
class MiniaturaExercicio extends StatelessWidget {
  final String? slug;
  final String nome;
  final double tamanho;

  const MiniaturaExercicio({super.key, required this.slug, required this.nome, this.tamanho = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: tamanho,
        height: tamanho,
        child: slug != null && slug!.isNotEmpty
            ? Ilustracao(caminho: 'assets/images/$slug-1.webp', ajuste: BoxFit.cover)
            : ColoredBox(
                color: AppCores.superficieAlta,
                child: Center(
                  child: Text(
                    nome.isEmpty ? '?' : nome.characters.first.toUpperCase(),
                    style: AppTexto.display(tamanho * 0.4, cor: AppCores.textoSuave),
                  ),
                ),
              ),
      ),
    );
  }
}
