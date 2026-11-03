import 'package:flutter/material.dart';
import '../models/treino.dart';
import '../services/treino_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comuns.dart';
import '../widgets/treino_comuns.dart';

/// Um registro do exercício: em que semana e dia, e o que foi feito.
typedef _Registro = ({SemanaTreino semana, int dia, ExercicioTreino exercicio});

/// O número acompanhado na evolução, conforme o tipo de registro.
class _Metrica {
  final String titulo;
  final String legenda;
  final double? Function(ExercicioTreino) valor;
  final String Function(double) formatar;
  final String Function(double) compacto;

  /// Pace: quanto menor, melhor.
  final bool menorMelhor;

  const _Metrica({
    required this.titulo,
    required this.legenda,
    required this.valor,
    required this.formatar,
    required this.compacto,
    this.menorMelhor = false,
  });

  static _Metrica de(TipoRegistro registro) => switch (registro) {
        TipoRegistro.forca => _Metrica(
            titulo: 'CARGA MÁXIMA POR TREINO (KG)',
            legenda: 'carga máxima',
            valor: (e) => e.cargaMaxima,
            formatar: (v) => '${FormatoTreino.numero(v)} kg',
            compacto: FormatoTreino.numero,
          ),
        TipoRegistro.tempo => _Metrica(
            titulo: 'MAIOR TEMPO POR TREINO (SEG)',
            legenda: 'maior tempo',
            valor: (e) => e.tempoMaximo?.toDouble(),
            formatar: (v) => '${v.round()} s',
            compacto: (v) => '${v.round()}',
          ),
        TipoRegistro.distancia || TipoRegistro.intervalado => _Metrica(
            titulo: 'PACE MÉDIO POR TREINO (MIN/KM)',
            legenda: 'melhor pace',
            valor: (e) => e.paceMedio,
            formatar: FormatoTreino.pace,
            compacto: (v) => FormatoTreino.duracao(v.round()),
            menorMelhor: true,
          ),
      };

  double? melhor(Iterable<double> valores) {
    if (valores.isEmpty) return null;
    return valores.reduce((a, b) => (menorMelhor ? a < b : a > b) ? a : b);
  }
}

/// Evolução de um exercício ao longo das semanas: a métrica de cada registro
/// em gráfico (carga, pace ou tempo) e a lista completa, com a diferença
/// para o registro anterior.
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
    final registro = _registros.isEmpty ? TipoRegistro.forca : _registros.last.exercicio.registro;
    final metrica = _Metrica.de(registro);
    final valores = _registros.map((r) => metrica.valor(r.exercicio)).whereType<double>();
    final recorde = metrica.melhor(valores);
    final kmTotal = _registros.fold<double>(0, (t, r) => t + r.exercicio.distanciaTotal);

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
                  'Ainda não há registros deste exercício. Registre no treino do dia '
                  'e a evolução aparece aqui semana a semana.',
                  style: AppTexto.corpo,
                )
              else ...[
                Wrap(
                  spacing: 32,
                  runSpacing: 8,
                  children: [
                    NumeroLegenda(recorde == null ? '—' : metrica.formatar(recorde), metrica.legenda),
                    if (registro.corrida && kmTotal > 0)
                      NumeroLegenda(FormatoTreino.km(kmTotal), 'no total'),
                    NumeroLegenda('${_registros.length}', _registros.length == 1 ? 'registro' : 'registros'),
                  ],
                ),
                const SizedBox(height: 24),
                if (valores.length >= 2) ...[
                  _Grafico(registros: _registros, metrica: metrica),
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
                          metrica: metrica,
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

/// Barras com a métrica dos últimos registros (até 12). Para pace, a altura
/// é a velocidade, então a barra mais alta é sempre o melhor treino.
class _Grafico extends StatelessWidget {
  final List<_Registro> registros;
  final _Metrica metrica;

  const _Grafico({required this.registros, required this.metrica});

  @override
  Widget build(BuildContext context) {
    final ultimos = registros.length > 12 ? registros.sublist(registros.length - 12) : registros;
    double altura(double? v) => v == null || v <= 0 ? 0 : (metrica.menorMelhor ? 1 / v : v);
    final maior = ultimos.map((r) => altura(metrica.valor(r.exercicio))).fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: AppCores.superficie,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metrica.titulo, style: AppTexto.rotulo.copyWith(fontSize: 10)),
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
                        proporcao: maior <= 0 ? 0 : altura(metrica.valor(ultimos[i].exercicio)) / maior,
                        valor: metrica.valor(ultimos[i].exercicio) == null
                            ? '–'
                            : metrica.compacto(metrica.valor(ultimos[i].exercicio)!),
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
  final double proporcao;
  final String valor;
  final String rotulo;
  final bool destaque;

  const _Barra({required this.proporcao, required this.valor, required this.rotulo, required this.destaque});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            valor,
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
  final _Metrica metrica;

  const _LinhaRegistro({
    required this.registro,
    required this.anterior,
    required this.recorde,
    required this.metrica,
  });

  @override
  Widget build(BuildContext context) {
    final ex = registro.exercicio;
    final valor = metrica.valor(ex);
    final valorAnterior = anterior == null ? null : metrica.valor(anterior!.exercicio);
    final diferenca = (valor != null && valorAnterior != null) ? valor - valorAnterior : null;
    final melhorou = diferenca != null && (metrica.menorMelhor ? diferenca < 0 : diferenca > 0);
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
                Text(FormatoTreino.resumoExercicio(ex), style: AppTexto.meta),
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
                valor == null ? '–' : metrica.formatar(valor),
                style: AppTexto.titulo(18, peso: FontWeight.w700).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: valor != null && valor == recorde ? AppCores.destaque : AppCores.texto,
                ),
              ),
              // Pace com menos de meio segundo de diferença arredonda para 0:00
              if (diferenca != null && diferenca.abs() >= (metrica.menorMelhor ? 0.5 : 0.001)) ...[
                const SizedBox(height: 4),
                Text(
                  '${diferenca > 0 ? '+' : '−'}${metrica.formatar(diferenca.abs())}',
                  style: AppTexto.meta.copyWith(
                    fontSize: 12,
                    color: melhorou ? AppCores.destaque : AppCores.textoSuave,
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
