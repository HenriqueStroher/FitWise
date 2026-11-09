import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/academia.dart';
import '../../services/academia_service.dart';
import '../../services/sessao.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comuns.dart';
import '../../widgets/treino_comuns.dart';

/// Resposta ao link de convite (`?convite=CODIGO`), mostrada na aba Meus
/// Treinos depois do login. Aceitar liga o usuário à academia como aluno do
/// professor que mandou o link, ou como professor (convite do dono).
class ConviteScreen extends StatefulWidget {
  final String codigo;
  final Perfil perfil;

  const ConviteScreen({super.key, required this.codigo, required this.perfil});

  @override
  State<ConviteScreen> createState() => _ConviteScreenState();
}

class _ConviteScreenState extends State<ConviteScreen> {
  final AcademiaService _service = AcademiaService();

  Convite? _convite;
  String? _problema;
  bool _carregando = true;
  bool _aceitando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    String? problema;
    Convite? convite;
    try {
      convite = await _service.buscarConvite(widget.codigo);
      final p = widget.perfil;
      if (convite == null) {
        problema = 'Este convite não existe. Confira o link com quem mandou.';
      } else if (convite.expirado) {
        problema = 'Este convite expirou. Peça um link novo para ${convite.autorNome}.';
      } else if (p.academiaId == convite.academiaId &&
          ((convite.tipo == TipoConvite.aluno && p.professorUid == convite.autorUid) ||
              (convite.tipo == TipoConvite.professor && p.papel.ensina))) {
        // Já aceito antes (o link continua no endereço): segue sem perguntar
        _fechar();
        return;
      } else if (p.papel.ensina) {
        problema = 'Sua conta já é de ${p.papel == Papel.dono ? 'dono' : 'professor'} de uma academia. '
            'Para entrar por este convite, use outra conta.';
      }
    } catch (e) {
      debugPrint('Convite: $e');
      problema = 'Não foi possível abrir o convite. Verifique sua conexão.';
    }
    if (!mounted) return;
    setState(() {
      _convite = convite;
      _problema = problema;
      _carregando = false;
    });
  }

  void _fechar() => Sessao.convitePendente.value = null;

  Future<void> _aceitar() async {
    setState(() => _aceitando = true);
    try {
      await _service.aceitarConvite(widget.perfil.uid, _convite!);
      _fechar();
    } catch (e) {
      debugPrint('Convite: $e');
      if (!mounted) return;
      setState(() => _aceitando = false);
      avisar(context, 'Não foi possível aceitar o convite. Tente de novo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final c = _convite;
    final aluno = c?.tipo == TipoConvite.aluno;

    return ListView(
      padding: const EdgeInsets.only(top: 28, bottom: 40),
      children: [
        Conteudo(
          larguraMaxima: AppLayout.larguraLeitura,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('CONVITE', style: AppTexto.rotulo.copyWith(color: AppCores.destaque)),
              const SizedBox(height: 10),
              Text(
                _carregando ? '…' : ((c?.autonomo ?? false ? c?.autorNome : c?.academiaNome)?.toUpperCase() ?? 'CONVITE'),
                style: AppTexto.display((largura * 0.085).clamp(30.0, 56.0)),
              ),
              const SizedBox(height: 20),
              if (_carregando)
                const Esqueleto(altura: 120)
              else if (_problema != null) ...[
                Text(_problema!, style: AppTexto.corpo),
                const SizedBox(height: 20),
                BotaoContorno(texto: 'Continuar sem o convite', icone: Icons.close_rounded, onTap: _fechar),
              ] else ...[
                Text(
                  aluno
                      ? (c!.autonomo
                          ? '${c.autorNome} convidou você para ter o treino montado por '
                              '${c.autorNome.split(' ').first}.'
                          : '${c.autorNome} convidou você para treinar na ${c.academiaNome}, '
                              'com o treino montado por ${c.autorNome.split(' ').first}.')
                      : '${c!.autorNome} convidou você para ser professor da ${c.academiaNome}.',
                  style: AppTexto.item.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 16),
                for (final item in aluno
                    ? [
                        'Seu professor monta o seu treino de cada dia da semana.',
                        'Você registra as séries e cargas, como já faz hoje.',
                        'O professor acompanha o seu histórico de cargas para ajustar o treino.',
                        'Você pode sair quando quiser; o treino e o histórico ficam com você.',
                      ]
                    : [
                        'Você recebe um link para convidar os seus alunos.',
                        'Monta o treino de cada aluno e acompanha as cargas registradas.',
                        'O catálogo passa a mostrar só o que a academia tem.',
                      ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(Icons.check_rounded, size: 16, color: AppCores.destaque),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item, style: AppTexto.corpo)),
                      ],
                    ),
                  ),
                if (widget.perfil.papel == Papel.aluno) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Você já é aluno de outro professor. Ao aceitar, passa a ter o treino montado por '
                    '${c.autorNome}.',
                    style: AppTexto.meta,
                  ),
                ],
                const SizedBox(height: 24),
                BotaoDestaque(
                  texto: 'Aceitar convite',
                  icone: Icons.check_rounded,
                  carregando: _aceitando,
                  onTap: _aceitar,
                ),
                const SizedBox(height: 12),
                BotaoContorno(texto: 'Agora não', icone: Icons.close_rounded, onTap: _fechar),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Gera (ou reaproveita) o convite e mostra o link para copiar e mandar.
Future<void> mostrarConvite(BuildContext context, Perfil autor, Academia academia, TipoConvite tipo) async {
  final Convite convite;
  try {
    convite = await AcademiaService().conviteDe(autor, academia, tipo);
  } catch (e) {
    debugPrint('Convite: $e');
    if (context.mounted) avisar(context, 'Não foi possível gerar o convite. Verifique sua conexão.');
    return;
  }
  if (!context.mounted) return;
  final link = Sessao.linkDoConvite(convite.codigo);
  final validade = '${convite.expiraEm.day.toString().padLeft(2, '0')}/'
      '${convite.expiraEm.month.toString().padLeft(2, '0')}';

  await showDialog<void>(
    context: context,
    builder: (contexto) => AlertDialog(
      backgroundColor: AppCores.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(tipo == TipoConvite.aluno ? 'Convidar aluno' : 'Convidar professor', style: AppTexto.titulo(20)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tipo == TipoConvite.aluno
                  ? 'Quem abrir o link e entrar na conta passa a ter o treino montado por você, '
                      'e você acompanha as cargas registradas.'
                  : 'Quem abrir o link e entrar na conta passa a dar aula na ${academia.nome}, '
                      'com os próprios alunos.',
              style: AppTexto.corpo,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppCores.superficieAlta,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(link, style: AppTexto.item.copyWith(fontSize: 14)),
            ),
            const SizedBox(height: 10),
            Text('Código ${convite.codigo}  ·  vale para várias pessoas até $validade', style: AppTexto.meta),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto),
          child: Text('Fechar', style: AppTexto.item.copyWith(color: AppCores.textoSuave)),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: link));
            if (contexto.mounted) Navigator.pop(contexto);
            if (context.mounted) avisar(context, 'Link copiado.');
          },
          child: Text('Copiar link', style: AppTexto.item.copyWith(color: AppCores.destaque)),
        ),
      ],
    ),
  );
}
