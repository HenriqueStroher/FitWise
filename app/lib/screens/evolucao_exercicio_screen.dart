import 'package:flutter/material.dart';
import '../models/treino.dart';
import '../services/treino_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import '../widgets/treino_comuns.dart';

/// Um registro do exercício: em que semana e dia, e o que foi feito.
typedef _Registro = ({SemanaTreino semana, int dia, ExercicioTreino exercicio});

/// Evolução de um exercício ao longo das semanas: carga máxima de cada
/// registro em gráfico e a lista completa, com a diferença para o anterior.
class EvolucaoExercicioScreen extends StatefulWidget {
  final String chave;
  final String nome;
  final String? slug;
  final TreinoService service;

  const EvolucaoExercicioScreen({
    super.key,
    required this.chave,
    required this.nome,
    required this.slug,
    required this.service,
  });

  @override
  State<EvolucaoExercicioScreen> createState() => _EvolucaoExercicioScreenState();
}

class _EvolucaoExercicioScreenState extends State<EvolucaoExercicioScreen> {
  /// Do mais antigo para o mais recente.
  List<_Registro> _registros = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final semanas = await widget.service.buscarHistorico();
      final registros = <_Registro>[
        for (final s in semanas.reversed)
          for (var d = 1; d <= 7; d++)
            for (final ex in s.dias[d] ?? <ExercicioTreino>[])
              if (ex.chave == widget.chave && ex.seriesPreenchidas.isNotEmpty)
                (semana: s, dia: d, exercicio: ex),
      ];
      if (!mounted) return;
      setState(() {
        _registros = registros;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Meus Treinos: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar a evolução. Verifique sua conexão.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final cargas = _registros.map((r) => r.exercicio.cargaMaxima).whereType<double>();
    final recorde = cargas.isEmpty ? null : cargas.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Conteudo(
          larguraMaxima: AppLayout.larguraLeitura,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: BotaoVoltar()),
              const SizedBox(height: 24),
              Row(
                children: [
                  MiniaturaExercicio(slug: widget.slug, nome: widget.nome, tamanho: 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EVOLUÇÃO', style: AppTexto.rotulo.copyWith(color: AppCores.destaque)),
                        const SizedBox(height: 6),
                        Text(widget.nome, style: AppTexto.titulo(largura >= 720 ? 32 : 24)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_carregando)
                const Esqueleto(altura: 180)
              else if (_erro != null)
                Text(_erro!, style: AppTexto.item.copyWith(color: AppCores.textoSuave))
              else if (_registros.isEmpty)
                Text(
                  'Ainda não há séries registradas deste exercício. Registre no treino do dia '
                  'e a evolução aparece aqui semana a semana.',
                  style: AppTexto.corpo,
                )
              else ...[
                Wrap(
                  spacing: 32,
                  runSpacing: 8,
                  children: [
                    NumeroLegenda(recorde == null ? '—' : '${FormatoTreino.numero(recorde)} kg', 'carga máxima'),
                    NumeroLegenda('${_registros.length}', _registros.length == 1 ? 'registro' : 'registros'),
                  ],
                ),
                const SizedBox(height: 24),
                if (cargas.length >= 2) ...[
                  _GraficoCargas(registros: _registros),
                  const SizedBox(height: 32),
                ],
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppCores.linha)),
                  ),
                  child: Column(
                    children: [
                      for (var i = _registros.length - 1; i >= 0; i--)
                        _LinhaRegistro(
                          registro: _registros[i],
                          anterior: i > 0 ? _registros[i - 1] : null,
                          recorde: recorde,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Barras com a carga máxima dos últimos registros (até 12).
class _GraficoCargas extends StatelessWidget {
  final List<_Registro> registros;

  const _GraficoCargas({required this.registros});

  @override
  Widget build(BuildContext context) {
    final ultimos = registros.length > 12 ? registros.sublist(registros.length - 12) : registros;
    final maior = ultimos
        .map((r) => r.exercicio.cargaMaxima ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: AppCores.superficie,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CARGA MÁXIMA POR TREINO (KG)', style: AppTexto.rotulo.copyWith(fontSize: 10)),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < ultimos.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _Barra(
                        valor: ultimos[i].exercicio.cargaMaxima ?? 0,
                        maior: maior,
                        rotulo: FormatoTreino.data(DateTime(
                          ultimos[i].semana.inicio.year,
                          ultimos[i].semana.inicio.month,
                          ultimos[i].semana.inicio.day + ultimos[i].dia - 1,
                        )),
                        destaque: i == ultimos.length - 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  final double valor;
  final double maior;
  final String rotulo;
  final bool destaque;

  const _Barra({required this.valor, required this.maior, required this.rotulo, required this.destaque});

  @override
  Widget build(BuildContext context) {
    final proporcao = maior <= 0 ? 0.0 : valor / maior;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            FormatoTreino.numero(valor),
            style: AppTexto.numero.copyWith(
              fontSize: 11,
              color: destaque ? AppCores.destaque : AppCores.textoSuave,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: FractionallySizedBox(
            heightFactor: proporcao.clamp(0.03, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: destaque ? AppCores.destaque : AppCores.textoApagado,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(rotulo, style: AppTexto.meta.copyWith(fontSize: 10, color: AppCores.textoApagado)),
        ),
      ],
    );
  }
}

class _LinhaRegistro extends StatelessWidget {
  final _Registro registro;
  final _Registro? anterior;
  final double? recorde;

  const _LinhaRegistro({required this.registro, required this.anterior, required this.recorde});

  @override
  Widget build(BuildContext context) {
    final ex = registro.exercicio;
    final carga = ex.cargaMaxima;
    final cargaAnterior = anterior?.exercicio.cargaMaxima;
    final diferenca = (carga != null && cargaAnterior != null) ? carga - cargaAnterior : null;
    final inicio = registro.semana.inicio;
    final data = DateTime(inicio.year, inicio.month, inicio.day + registro.dia - 1);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppCores.linha)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DiaSemana.nome(registro.dia)}, ${FormatoTreino.dataCompleta(data)}',
                  style: AppTexto.item.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text('Semana ${FormatoTreino.periodo(registro.semana)}',
                    style: AppTexto.meta.copyWith(fontSize: 12, color: AppCores.textoApagado)),
                const SizedBox(height: 6),
                Text(FormatoTreino.resumo(ex.seriesPreenchidas), style: AppTexto.meta),
                if (ex.volume > 0) ...[
                  const SizedBox(height: 3),
                  Text('Volume ${FormatoTreino.milhar(ex.volume)} kg',
                      style: AppTexto.meta.copyWith(fontSize: 12, color: AppCores.textoApagado)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                carga == null ? '–' : '${FormatoTreino.numero(carga)} kg',
                style: AppTexto.titulo(18, peso: FontWeight.w700).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: carga != null && carga == recorde ? AppCores.destaque : AppCores.texto,
                ),
              ),
              if (diferenca != null && diferenca != 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${diferenca > 0 ? '+' : '−'}${FormatoTreino.numero(diferenca.abs())} kg',
                  style: AppTexto.meta.copyWith(
                    fontSize: 12,
                    color: diferenca > 0 ? AppCores.destaque : AppCores.textoSuave,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
