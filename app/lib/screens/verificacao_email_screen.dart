import 'dart:async';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import '../widgets/treino_comuns.dart';

/// Mostrada no lugar de "Meus Treinos" enquanto o e-mail da conta não foi
/// confirmado. Confere sozinha a cada poucos segundos, então basta abrir o
/// link (até em outro aparelho) que a tela avança.
class VerificacaoEmailScreen extends StatefulWidget {
  final AuthService auth;
  final String email;
  final VoidCallback onConfirmado;

  const VerificacaoEmailScreen({
    super.key,
    required this.auth,
    required this.email,
    required this.onConfirmado,
  });

  @override
  State<VerificacaoEmailScreen> createState() => _VerificacaoEmailScreenState();
}

class _VerificacaoEmailScreenState extends State<VerificacaoEmailScreen> {
  static const _esperaReenvio = 60;

  Timer? _conferencia;
  Timer? _contagem;
  int _segundosParaReenviar = 0;
  bool _conferindo = false;
  String? _mensagem;

  @override
  void initState() {
    super.initState();
    _conferencia = Timer.periodic(const Duration(seconds: 5), (_) => _conferir(silencioso: true));
  }

  @override
  void dispose() {
    _conferencia?.cancel();
    _contagem?.cancel();
    super.dispose();
  }

  Future<void> _conferir({bool silencioso = false}) async {
    if (_conferindo) return;
    if (!silencioso) setState(() => _conferindo = true);
    try {
      final ok = await widget.auth.confirmouEmail();
      if (!mounted) return;
      if (ok) {
        _conferencia?.cancel();
        widget.onConfirmado();
      } else if (!silencioso) {
        setState(() => _mensagem = 'Ainda não confirmado. Abra o link do e-mail e tente de novo.');
      }
    } catch (e) {
      debugPrint('Meus Treinos: $e');
      if (mounted && !silencioso) setState(() => _mensagem = AuthService.mensagemDeErro(e));
    } finally {
      if (mounted && !silencioso) setState(() => _conferindo = false);
    }
  }

  Future<void> _reenviar() async {
    if (_segundosParaReenviar > 0) return;
    try {
      await widget.auth.reenviarConfirmacao();
      if (!mounted) return;
      setState(() {
        _mensagem = null;
        _segundosParaReenviar = _esperaReenvio;
      });
      avisar(context, 'Enviamos um novo link para ${widget.email}.');
      _contagem?.cancel();
      _contagem = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _segundosParaReenviar--);
        if (_segundosParaReenviar <= 0) t.cancel();
      });
    } catch (e) {
      if (mounted) setState(() => _mensagem = AuthService.mensagemDeErro(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 36, bottom: 40),
      child: Conteudo(
        larguraMaxima: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('QUASE LÁ', style: AppTexto.rotulo.copyWith(color: AppCores.destaque)),
            const SizedBox(height: 10),
            Text('CONFIRME\nSEU E-MAIL', style: AppTexto.display((largura * 0.095).clamp(32.0, 56.0))),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                style: AppTexto.corpo,
                children: [
                  const TextSpan(text: 'Enviamos um link de confirmação para '),
                  TextSpan(text: widget.email, style: AppTexto.corpo.copyWith(color: AppCores.texto)),
                  const TextSpan(
                    text: '. Abra o link para liberar seus treinos. Se não encontrar, '
                        'confira a caixa de spam.',
                  ),
                ],
              ),
            ),
            if (_mensagem != null) ...[
              const SizedBox(height: 16),
              Text(_mensagem!, style: AppTexto.meta.copyWith(color: AppCores.erro)),
            ],
            const SizedBox(height: 28),
            BotaoDestaque(
              texto: 'Já confirmei',
              icone: Icons.check_rounded,
              carregando: _conferindo,
              onTap: _conferir,
            ),
            const SizedBox(height: 12),
            BotaoContorno(
              texto: _segundosParaReenviar > 0
                  ? 'Reenviar e-mail (${_segundosParaReenviar}s)'
                  : 'Reenviar e-mail',
              icone: Icons.mail_outline,
              onTap: _reenviar,
            ),
            const SizedBox(height: 18),
            Center(
              child: Pressionavel(
                onTap: widget.auth.sair,
                builder: (_, ativo) => Text(
                  'Usar outra conta',
                  style: AppTexto.meta.copyWith(
                    color: ativo ? AppCores.texto : AppCores.textoSuave,
                    decoration: TextDecoration.underline,
                    decorationColor: AppCores.textoApagado,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
