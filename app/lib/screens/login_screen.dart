import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import '../widgets/treino_comuns.dart';

/// Entrada e cadastro, mostrados no lugar de "Meus Treinos" enquanto não há
/// usuário logado. Ao logar, o StreamBuilder de MeusTreinosScreen troca a
/// tela sozinho — aqui não há navegação.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();

  bool _cadastro = false;
  bool _enviando = false;
  bool _senhaVisivel = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  void _alternarModo(bool cadastro) {
    if (_cadastro == cadastro) return;
    setState(() {
      _cadastro = cadastro;
      _erro = null;
    });
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      if (_cadastro) {
        await _auth.cadastrar(_nome.text, _email.text, _senha.text);
      } else {
        await _auth.entrar(_email.text, _senha.text);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = AuthService.mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _recuperarSenha() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _erro = 'Digite seu e-mail acima para receber o link de redefinição.');
      return;
    }
    try {
      await _auth.recuperarSenha(email);
      if (!mounted) return;
      setState(() => _erro = null);
      avisar(context, 'Enviamos um link de redefinição para $email.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = AuthService.mensagemDeErro(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 36, bottom: 40),
      child: Conteudo(
        larguraMaxima: 440,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ÁREA PESSOAL', style: AppTexto.rotulo.copyWith(color: AppCores.destaque)),
              const SizedBox(height: 10),
              Text('MEUS\nTREINOS', style: AppTexto.display((largura * 0.095).clamp(32.0, 56.0))),
              const SizedBox(height: 16),
              Text(
                'Entre na sua conta para montar seus treinos, registrar séries e cargas '
                'e acompanhar sua evolução semana a semana. O catálogo de exercícios '
                'continua livre, sem login.',
                style: AppTexto.corpo,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  ChipOpcao(texto: 'Entrar', selecionado: !_cadastro, onTap: () => _alternarModo(false)),
                  const SizedBox(width: 8),
                  ChipOpcao(texto: 'Criar conta', selecionado: _cadastro, onTap: () => _alternarModo(true)),
                ],
              ),
              const SizedBox(height: 20),
              if (_cadastro) ...[
                _campo(
                  controller: _nome,
                  dica: 'Nome',
                  icone: Icons.person_outline,
                  validar: (v) => (v ?? '').trim().isEmpty ? 'Informe seu nome.' : null,
                  autofill: AutofillHints.name,
                ),
                const SizedBox(height: 12),
              ],
              _campo(
                controller: _email,
                dica: 'E-mail',
                icone: Icons.mail_outline,
                teclado: TextInputType.emailAddress,
                autofill: AutofillHints.email,
                validar: (v) => (v ?? '').contains('@') ? null : 'Informe um e-mail válido.',
              ),
              const SizedBox(height: 12),
              _campo(
                controller: _senha,
                dica: 'Senha',
                icone: Icons.lock_outline,
                oculto: !_senhaVisivel,
                autofill: _cadastro ? AutofillHints.newPassword : AutofillHints.password,
                sufixo: IconButton(
                  onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                  icon: Icon(_senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppCores.textoApagado, size: 18),
                ),
                validar: (v) => (v ?? '').length < 6 ? 'A senha precisa ter pelo menos 6 caracteres.' : null,
                aoEnviar: _cadastro ? null : _enviar,
              ),
              if (_cadastro) ...[
                const SizedBox(height: 12),
                _campo(
                  controller: _confirmacao,
                  dica: 'Confirmar senha',
                  icone: Icons.lock_outline,
                  oculto: !_senhaVisivel,
                  validar: (v) => v != _senha.text ? 'As senhas não conferem.' : null,
                  aoEnviar: _enviar,
                ),
              ],
              if (_erro != null) ...[
                const SizedBox(height: 16),
                Text(_erro!, style: AppTexto.meta.copyWith(color: AppCores.erro)),
              ],
              const SizedBox(height: 24),
              BotaoDestaque(
                texto: _cadastro ? 'Criar conta' : 'Entrar',
                onTap: _enviar,
                carregando: _enviando,
              ),
              if (!_cadastro) ...[
                const SizedBox(height: 18),
                Center(
                  child: Pressionavel(
                    onTap: _recuperarSenha,
                    builder: (_, ativo) => Text(
                      'Esqueci minha senha',
                      style: AppTexto.meta.copyWith(
                        color: ativo ? AppCores.texto : AppCores.textoSuave,
                        decoration: TextDecoration.underline,
                        decorationColor: AppCores.textoApagado,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String dica,
    required IconData icone,
    required String? Function(String?) validar,
    TextInputType? teclado,
    bool oculto = false,
    Widget? sufixo,
    String? autofill,
    VoidCallback? aoEnviar,
  }) {
    return TextFormField(
      controller: controller,
      validator: validar,
      keyboardType: teclado,
      obscureText: oculto,
      autofillHints: autofill == null ? null : [autofill],
      textInputAction: aoEnviar == null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: aoEnviar == null ? null : (_) => aoEnviar(),
      style: AppTexto.item.copyWith(fontWeight: FontWeight.w500),
      decoration: decoracaoCampo(dica, icone: icone, sufixo: sufixo).copyWith(
        errorStyle: AppTexto.meta.copyWith(color: AppCores.erro, fontSize: 12),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppCores.erro),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppCores.erro),
        ),
      ),
    );
  }
}
