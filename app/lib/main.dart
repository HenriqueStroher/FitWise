import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'navegacao.dart';
import 'screens/home_screen.dart';
import 'screens/lista_exercicios_screen.dart';
import 'screens/meus_treinos_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/comuns.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Com --dart-define=EMULADOR=true, o Firestore é o emulador local (porta
  // 8080, ver firebase.json): dá para testar uma base nova sem publicá-la.
  // O login continua sendo o de produção.
  if (const bool.fromEnvironment('EMULADOR')) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitWise',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ListaExerciciosScreenState> _listaKey = GlobalKey<ListaExerciciosScreenState>();
  // A aba fica em Navegacao para que o botão de início das telas internas
  // também possa trocá-la
  int get _aba => Navegacao.aba.value;

  @override
  void initState() {
    super.initState();
    Navegacao.aba.addListener(_aoMudarAba);
  }

  @override
  void dispose() {
    Navegacao.aba.removeListener(_aoMudarAba);
    super.dispose();
  }

  void _aoMudarAba() => setState(() {});

  static const _abas = ['Grupos', 'Exercícios', 'Meus Treinos'];

  void _navegarParaGrupo(String grupo) {
    Navegacao.aba.value = 1;
    _listaKey.currentState?.mudarGrupo(grupo);
  }

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopo(largo),
            Expanded(
              child: IndexedStack(
                index: _aba,
                children: [
                  HomeScreen(onNavegar: _navegarParaGrupo),
                  ListaExerciciosScreen(key: _listaKey),
                  const MeusTreinosScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: largo ? null : _buildBarraInferior(),
    );
  }

  Widget _buildTopo(bool largo) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppCores.linha)),
      ),
      child: Conteudo(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const _Marca(),
              const Spacer(),
              if (largo)
                for (var i = 0; i < _abas.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: _abaTopo(i),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _abaTopo(int i) {
    final ativa = _aba == i;
    return Pressionavel(
      onTap: () => Navegacao.aba.value = i,
      builder: (_, hover) => Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: ativa ? AppCores.destaque : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          _abas[i],
          style: AppTexto.item.copyWith(
            fontSize: 14,
            color: ativa || hover ? AppCores.texto : AppCores.textoSuave,
          ),
        ),
      ),
    );
  }

  Widget _buildBarraInferior() {
    const icones = [
      Icons.grid_view_rounded,
      Icons.format_list_bulleted_rounded,
      Icons.fitness_center_rounded,
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppCores.fundo,
        border: Border(top: BorderSide(color: AppCores.linha)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _abas.length; i++)
                Expanded(
                  child: Pressionavel(
                    onTap: () => Navegacao.aba.value = i,
                    builder: (_, _) {
                      final ativa = _aba == i;
                      final cor = ativa ? AppCores.texto : AppCores.textoApagado;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icones[i], color: cor, size: 22),
                          const SizedBox(height: 4),
                          Text(_abas[i],
                              style: AppTexto.meta.copyWith(
                                  fontSize: 11,
                                  color: cor,
                                  fontWeight: ativa ? FontWeight.w600 : FontWeight.w500)),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          color: AppCores.destaque,
        ),
        const SizedBox(width: 10),
        Text('FITWISE', style: AppTexto.display(15).copyWith(letterSpacing: 1.2, height: 1)),
      ],
    );
  }
}
