// Modelos do modo academia (em teste): academias, papéis e convites.
//
// Quem não pertence a nenhuma academia é um usuário comum e usa o app como
// sempre usou. Os campos de vínculo (papel, academiaId, professorUid) ficam
// no próprio documento `usuarios/{uid}`; as regras do Firestore controlam
// quem pode mudá-los.

import 'exercicio.dart';

enum Papel {
  /// Sem academia: monta e registra o próprio treino.
  usuario,

  /// Vinculado a um professor, que monta o plano; só registra as séries.
  aluno,

  /// Monta o treino dos próprios alunos.
  professor,

  /// Professor que também administra a academia (professores e
  /// equipamentos). É quem contrata o app.
  dono;

  static Papel de(String? codigo) =>
      values.firstWhere((p) => p.name == codigo, orElse: () => usuario);

  /// Professor ou dono: tem alunos e monta treinos.
  bool get ensina => this == professor || this == dono;
}

/// Dados de `usuarios/{uid}` que o app precisa para decidir o que mostrar.
class Perfil {
  final String uid;
  final String nome;
  final String email;
  final Papel papel;
  final String? academiaId;
  final String? professorUid;

  /// Dono do software (existe `admins/{uid}`): vê o painel com os números de
  /// todas as academias.
  final bool admin;

  const Perfil({
    required this.uid,
    this.nome = '',
    this.email = '',
    this.papel = Papel.usuario,
    this.academiaId,
    this.professorUid,
    this.admin = false,
  });

  factory Perfil.fromMap(String uid, Map<String, dynamic>? m, {bool admin = false}) {
    final dados = m ?? const {};
    // Um papel de academia sem academia não vale: trata como usuário comum
    final academiaId = dados['academiaId'] as String?;
    return Perfil(
      uid: uid,
      nome: dados['nome'] as String? ?? '',
      email: dados['email'] as String? ?? '',
      papel: academiaId == null ? Papel.usuario : Papel.de(dados['papel'] as String?),
      academiaId: academiaId,
      professorUid: dados['professorUid'] as String?,
      admin: admin,
    );
  }

  /// Nome para exibir; o e-mail quando o nome não foi preenchido.
  String get exibicao => nome.trim().isEmpty ? email : nome.trim();

  String get primeiroNome => exibicao.split(' ').first;
}

/// Uma academia cliente e o que ela tem de equipamento.
///
/// O professor autônomo (personal) também tem uma "academia" própria, com
/// [autonomo] verdadeiro: ele é o dono, e os alunos dele ficam ligados a ela.
/// Assim os dois casos usam as mesmas regras e telas; só a interface muda
/// (sem professores nem equipamentos para administrar).
class Academia {
  final String id;
  final String nome;
  final String donoUid;
  final bool autonomo;

  /// Equipamentos que a academia não tem (códigos de Exercicio.equipamento).
  /// Todo exercício que usa um deles fica oculto.
  final Set<String> equipamentosIndisponiveis;

  /// Exercícios ocultos um a um (slugs), para o que o equipamento não
  /// resolve: "Máquina" cobre leg press, hack, extensora...
  final Set<String> exerciciosOcultos;

  const Academia({
    required this.id,
    required this.nome,
    required this.donoUid,
    this.autonomo = false,
    this.equipamentosIndisponiveis = const {},
    this.exerciciosOcultos = const {},
  });

  factory Academia.fromMap(String id, Map<String, dynamic> m) => Academia(
        id: id,
        nome: m['nome'] as String? ?? '',
        donoUid: m['donoUid'] as String? ?? '',
        autonomo: m['tipo'] == tipoAutonomo,
        equipamentosIndisponiveis: {...List<String>.from(m['equipamentosIndisponiveis'] ?? const [])},
        exerciciosOcultos: {...List<String>.from(m['exerciciosOcultos'] ?? const [])},
      );

  /// Valores do campo `tipo` no Firestore.
  static const tipoAcademia = 'academia';
  static const tipoAutonomo = 'autonomo';

  /// Equipamentos que nunca entram na lista do dono: toda academia tem.
  static const equipamentosSempreDisponiveis = {'peso_corporal', 'parede'};

  /// O exercício aparece se não foi ocultado e a academia tem todos os
  /// equipamentos dele. Guardar o que está oculto (e não o que está
  /// disponível) faz os exercícios novos do catálogo aparecerem sozinhos.
  bool visivel(Exercicio ex) => !ocultoPorExercicio(ex) && equipamentoQueFalta(ex) == null;

  bool ocultoPorExercicio(Exercicio ex) => exerciciosOcultos.contains(ex.slug);

  /// O primeiro equipamento do exercício que a academia não tem, ou nulo.
  String? equipamentoQueFalta(Exercicio ex) {
    for (final eq in ex.equipamento) {
      if (equipamentosIndisponiveis.contains(eq)) return eq;
    }
    return null;
  }
}

enum TipoConvite {
  /// Gerado por um professor: quem aceita vira aluno dele.
  aluno,

  /// Gerado pelo dono: quem aceita vira professor da academia.
  professor;

  static TipoConvite de(String? codigo) =>
      values.firstWhere((t) => t.name == codigo, orElse: () => aluno);
}

/// Convite em `convites/{codigo}`. O link leva o código (`?convite=...`).
/// Vale para várias pessoas até expirar, para poder ser mandado num grupo.
class Convite {
  final String codigo;
  final TipoConvite tipo;
  final String academiaId;
  final String academiaNome;

  /// Quem gerou: o professor (convite de aluno) ou o dono (de professor).
  final String autorUid;
  final String autorNome;
  final DateTime expiraEm;

  /// Convite de um professor autônomo (sem academia de verdade).
  final bool autonomo;

  const Convite({
    required this.codigo,
    required this.tipo,
    required this.academiaId,
    required this.academiaNome,
    required this.autorUid,
    required this.autorNome,
    required this.expiraEm,
    this.autonomo = false,
  });

  bool get expirado => DateTime.now().isAfter(expiraEm);

  /// Alfabeto sem caracteres que se confundem (0/O, 1/I/L).
  static const alfabeto = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
}
