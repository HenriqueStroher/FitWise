import 'package:flutter/widgets.dart';

/// Aba ativa da tela principal e o atalho de volta ao início.
///
/// Fica fora do MainScreen porque as telas empilhadas por cima dele (detalhe,
/// variações) precisam trocar a aba sem ter acesso ao estado dele.
class Navegacao {
  Navegacao._();

  static const abaInicio = 0;
  static const abaTreinos = 2;

  /// Índice da aba ativa: 0 Grupos, 1 Exercícios, 2 Meus Treinos.
  static final aba = ValueNotifier<int>(abaInicio);

  /// Fecha todas as telas empilhadas e mostra a aba Grupos.
  static void irParaInicio(BuildContext context) {
    Navigator.of(context).popUntil((rota) => rota.isFirst);
    aba.value = abaInicio;
  }
}
