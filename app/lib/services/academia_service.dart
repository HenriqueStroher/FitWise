import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/academia.dart';
import '../models/treino.dart';

/// Totais do painel do dono do software. [academias] e [donos] não contam
/// os professores autônomos, que ficam em [autonomos].
typedef EstatisticasSoftware = ({
  int academias,
  int donos,
  int autonomos,
  int professores,
  int alunos,
  int usuarios,
});

/// Uma conta na lista de entradas recentes do painel do software.
typedef EntradaRecente = ({Perfil perfil, DateTime? criadoEm});

/// Uma linha da lista de academias do painel do software.
typedef ResumoAcademia = ({Academia academia, String donoNome, int professores, int alunos});

/// Leitura e gravação do modo academia (em teste).
///
/// Estrutura no Firestore:
/// - `usuarios/{uid}`: os campos `papel`, `academiaId` e `professorUid`
///   ligam a pessoa à academia (ver Perfil).
/// - `academias/{id}`: nome, dono e os equipamentos/exercícios ocultos.
/// - `convites/{codigo}`: links de convite de aluno e de professor.
/// - `admins/{uid}`: donos do software. Criado só pelo console.
///
/// O que cada papel pode ler e gravar está em firestore.rules.
class AcademiaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usuarios => _db.collection('usuarios');
  CollectionReference<Map<String, dynamic>> get _academias => _db.collection('academias');
  CollectionReference<Map<String, dynamic>> get _convites => _db.collection('convites');

  /// Campos que ligam o usuário a uma academia; apagá-los o torna comum.
  static const camposVinculo = ['papel', 'academiaId', 'professorUid', 'convite'];

  static const validadeConvite = Duration(days: 7);

  // ─────────────────────────────────────────
  // PERFIS
  // ─────────────────────────────────────────

  Future<Perfil?> buscarPerfil(String uid) async {
    final doc = await _usuarios.doc(uid).get();
    return doc.exists ? Perfil.fromMap(uid, doc.data()) : null;
  }

  Future<Academia?> buscarAcademia(String id) async {
    final doc = await _academias.doc(id).get();
    return doc.exists ? Academia.fromMap(doc.id, doc.data()!) : null;
  }

  List<Perfil> _perfis(QuerySnapshot<Map<String, dynamic>> s) =>
      [for (final d in s.docs) Perfil.fromMap(d.id, d.data())]
        ..sort((a, b) => a.exibicao.toLowerCase().compareTo(b.exibicao.toLowerCase()));

  /// Alunos de um professor. O filtro por academia é exigido pelas regras.
  Future<List<Perfil>> alunosDe(String academiaId, String professorUid) async {
    final s = await _usuarios
        .where('academiaId', isEqualTo: academiaId)
        .where('professorUid', isEqualTo: professorUid)
        .get();
    return _perfis(s);
  }

  /// Professores da academia, sem o dono (visto pelo dono).
  Future<List<Perfil>> professoresDa(String academiaId) async {
    final s = await _usuarios
        .where('academiaId', isEqualTo: academiaId)
        .where('papel', isEqualTo: Papel.professor.name)
        .get();
    return _perfis(s);
  }

  Future<int> contarAlunos(String academiaId, {String? professorUid}) async {
    var q = _usuarios.where('academiaId', isEqualTo: academiaId).where('papel', isEqualTo: Papel.aluno.name);
    if (professorUid != null) q = q.where('professorUid', isEqualTo: professorUid);
    return (await q.count().get()).count ?? 0;
  }

  /// Dias com série registrada na semana atual de um aluno.
  Future<int> diasTreinadosNaSemana(String alunoUid) async {
    final id = SemanaTreino.idDe(SemanaTreino.inicioDe(DateTime.now()));
    final doc = await _usuarios.doc(alunoUid).collection('semanas').doc(id).get();
    if (!doc.exists) return 0;
    return SemanaTreino.fromFirestore(id, doc.data()!).diasTreinados.length;
  }

  // ─────────────────────────────────────────
  // CONVITES
  // ─────────────────────────────────────────

  Future<Convite?> buscarConvite(String codigo) async {
    final doc = await _convites.doc(codigo).get();
    return doc.exists ? _convite(doc.id, doc.data()!) : null;
  }

  Convite _convite(String codigo, Map<String, dynamic> m) => Convite(
        codigo: codigo,
        tipo: TipoConvite.de(m['tipo']),
        academiaId: m['academiaId'] ?? '',
        academiaNome: m['academiaNome'] ?? '',
        autorUid: m['autorUid'] ?? '',
        autorNome: m['autorNome'] ?? '',
        expiraEm: (m['expiraEm'] as Timestamp?)?.toDate() ?? DateTime(2000),
        autonomo: m['autonomo'] == true,
      );

  /// Convite de [autor] para a [academia]: reaproveita um que ainda valha
  /// por mais de um dia, para o link não mudar a cada toque.
  Future<Convite> conviteDe(Perfil autor, Academia academia, TipoConvite tipo) async {
    final existentes = await _convites
        .where('autorUid', isEqualTo: autor.uid)
        .where('tipo', isEqualTo: tipo.name)
        .get();
    final limite = DateTime.now().add(const Duration(days: 1));
    for (final d in existentes.docs) {
      final c = _convite(d.id, d.data());
      if (c.academiaId == academia.id && c.expiraEm.isAfter(limite)) return c;
    }

    final aleatorio = Random.secure();
    final codigo = List.generate(8, (_) => Convite.alfabeto[aleatorio.nextInt(Convite.alfabeto.length)]).join();
    final convite = Convite(
      codigo: codigo,
      tipo: tipo,
      academiaId: academia.id,
      academiaNome: academia.nome,
      autorUid: autor.uid,
      autorNome: autor.exibicao,
      expiraEm: DateTime.now().add(validadeConvite),
      autonomo: academia.autonomo,
    );
    await _convites.doc(codigo).set({
      'autonomo': academia.autonomo,
      'tipo': tipo.name,
      'academiaId': academia.id,
      'academiaNome': academia.nome,
      'autorUid': autor.uid,
      'autorNome': autor.exibicao,
      'criadoEm': FieldValue.serverTimestamp(),
      'expiraEm': Timestamp.fromDate(convite.expiraEm),
    });
    return convite;
  }

  /// Entra na academia pelo convite: como aluno do autor ou como professor.
  /// As regras conferem que o convite existe, vale e bate com os campos.
  Future<void> aceitarConvite(String uid, Convite c) {
    return _usuarios.doc(uid).update({
      'papel': c.tipo == TipoConvite.aluno ? Papel.aluno.name : Papel.professor.name,
      'academiaId': c.academiaId,
      'professorUid': c.tipo == TipoConvite.aluno ? c.autorUid : FieldValue.delete(),
      'convite': c.codigo,
    });
  }

  /// Desfaz o vínculo: o usuário volta a ser comum. Usado pelo próprio
  /// aluno (sair), pelo professor (desvincular aluno) e pelo dono.
  /// O plano montado pelo professor fica com o usuário.
  Future<void> desvincular(String uid) {
    return _usuarios.doc(uid).update({for (final c in camposVinculo) c: FieldValue.delete()});
  }

  /// Tira o professor da academia. Os alunos dele passam para o dono, para
  /// não ficarem com um plano que ninguém pode mais editar.
  Future<int> removerProfessor(Perfil professor, Academia academia) async {
    final alunos = await alunosDe(academia.id, professor.uid);
    final lote = _db.batch();
    for (final a in alunos) {
      lote.update(_usuarios.doc(a.uid), {'professorUid': academia.donoUid});
    }
    lote.update(_usuarios.doc(professor.uid), {for (final c in camposVinculo) c: FieldValue.delete()});
    await lote.commit();
    return alunos.length;
  }

  // ─────────────────────────────────────────
  // EQUIPAMENTOS (dono)
  // ─────────────────────────────────────────

  Future<void> salvarDisponibilidade(
    String academiaId, {
    required Set<String> equipamentosIndisponiveis,
    required Set<String> exerciciosOcultos,
  }) {
    return _academias.doc(academiaId).update({
      'equipamentosIndisponiveis': equipamentosIndisponiveis.toList()..sort(),
      'exerciciosOcultos': exerciciosOcultos.toList()..sort(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────
  // PAINEL DO SOFTWARE (admin)
  // ─────────────────────────────────────────

  Future<int> _contar(Query<Map<String, dynamic>> q) async => (await q.count().get()).count ?? 0;

  Future<EstatisticasSoftware> estatisticas() async {
    final r = await Future.wait([
      _contar(_academias),
      _contar(_academias.where('tipo', isEqualTo: Academia.tipoAutonomo)),
      _contar(_usuarios.where('papel', isEqualTo: Papel.dono.name)),
      _contar(_usuarios.where('papel', isEqualTo: Papel.professor.name)),
      _contar(_usuarios.where('papel', isEqualTo: Papel.aluno.name)),
      _contar(_usuarios),
    ]);
    // O autônomo é dono da própria "academia": sai das duas contagens
    return (
      academias: r[0] - r[1],
      donos: r[2] - r[1],
      autonomos: r[1],
      professores: r[3],
      alunos: r[4],
      usuarios: r[5],
    );
  }

  /// Contas mais novas, para acompanhar quem está entrando no app.
  Future<List<EntradaRecente>> entradasRecentes({int limite = 15}) async {
    final s = await _usuarios.orderBy('criadoEm', descending: true).limit(limite).get();
    return [
      for (final d in s.docs)
        (perfil: Perfil.fromMap(d.id, d.data()), criadoEm: (d.data()['criadoEm'] as Timestamp?)?.toDate()),
    ];
  }

  Future<List<ResumoAcademia>> resumoAcademias() async {
    final s = await _academias.get();
    final resumos = await Future.wait(s.docs.map((d) async {
      final academia = Academia.fromMap(d.id, d.data());
      final r = await Future.wait([
        _contar(_usuarios.where('academiaId', isEqualTo: academia.id).where('papel', isEqualTo: Papel.professor.name)),
        _contar(_usuarios.where('academiaId', isEqualTo: academia.id).where('papel', isEqualTo: Papel.aluno.name)),
      ]);
      final dono = await buscarPerfil(academia.donoUid);
      return (
        academia: academia,
        donoNome: dono?.exibicao ?? '—',
        // O dono também dá aula
        professores: r[0] + (dono?.papel == Papel.dono ? 1 : 0),
        alunos: r[1],
      );
    }));
    return resumos..sort((a, b) => a.academia.nome.compareTo(b.academia.nome));
  }

  /// Conta pelo e-mail. A pessoa precisa ter se cadastrado no app antes.
  Future<Perfil?> _contaPorEmail(String email) async {
    final s = await _usuarios.where('email', isEqualTo: email.trim()).limit(1).get();
    return s.docs.isEmpty ? null : Perfil.fromMap(s.docs.first.id, s.docs.first.data());
  }

  static String _semConta(String email) =>
      'Nenhuma conta com o e-mail ${email.trim()}. A pessoa precisa se cadastrar no app antes.';

  /// Cria a academia (ou o espaço do professor autônomo) e transforma a conta
  /// com [emailDono] em dona dela. Devolve uma mensagem de erro, ou nulo se
  /// deu certo.
  Future<String?> criarAcademia(String nome, String emailDono, {bool autonomo = false}) async {
    final dono = await _contaPorEmail(emailDono);
    if (dono == null) return _semConta(emailDono);
    if (dono.papel != Papel.usuario) return 'Esta conta já está vinculada a uma academia.';

    final ref = _academias.doc();
    final lote = _db.batch()
      ..set(ref, {
        'nome': nome.trim().isEmpty ? dono.exibicao : nome.trim(),
        'tipo': autonomo ? Academia.tipoAutonomo : Academia.tipoAcademia,
        'donoUid': dono.uid,
        'equipamentosIndisponiveis': <String>[],
        'exerciciosOcultos': <String>[],
        'criadoEm': FieldValue.serverTimestamp(),
      })
      ..update(_usuarios.doc(dono.uid), {
        'papel': Papel.dono.name,
        'academiaId': ref.id,
        'professorUid': FieldValue.delete(),
        'convite': FieldValue.delete(),
      });
    await lote.commit();
    return null;
  }

  /// Coloca a conta como professor de uma academia que já existe.
  Future<String?> adicionarProfessor(String email, Academia academia) async {
    final p = await _contaPorEmail(email);
    if (p == null) return _semConta(email);
    if (p.papel.ensina) return 'Esta conta já é professor ou dono de uma academia.';
    await _usuarios.doc(p.uid).update({
      'papel': Papel.professor.name,
      'academiaId': academia.id,
      'professorUid': FieldValue.delete(),
      'convite': FieldValue.delete(),
    });
    return null;
  }

  /// Coloca a conta como aluno de um professor (de academia ou autônomo).
  Future<String?> adicionarAluno(String emailAluno, String emailProfessor) async {
    final professor = await _contaPorEmail(emailProfessor);
    if (professor == null) return _semConta(emailProfessor);
    if (!professor.papel.ensina) {
      return 'A conta ${emailProfessor.trim()} não é professor de nenhuma academia.';
    }
    final aluno = await _contaPorEmail(emailAluno);
    if (aluno == null) return _semConta(emailAluno);
    if (aluno.papel.ensina) return 'Esta conta é professor ou dono; não pode ser aluno.';
    await _usuarios.doc(aluno.uid).update({
      'papel': Papel.aluno.name,
      'academiaId': professor.academiaId,
      'professorUid': professor.uid,
      'convite': FieldValue.delete(),
    });
    return null;
  }
}
