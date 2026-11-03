import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/treino.dart';

/// Leitura e gravação dos treinos do usuário logado.
///
/// Estrutura no Firestore (tudo abaixo de `usuarios/{uid}`, visível só para o
/// próprio usuário pelas regras de segurança):
/// - `plano/{1..7}`          → `{exercicios: [{id, nome, slug}]}`
/// - `semanas/{AAAA-MM-DD}`  → `{inicio, dias: {'1': [{id, nome, slug, series}]}}`
///   O id é a segunda-feira da semana. Só a semana atual é gravada pelo app,
///   então as semanas passadas ficam como foram registradas.
class TreinoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid;

  TreinoService({String? uid}) : uid = uid ?? FirebaseAuth.instance.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _usuario => _db.collection('usuarios').doc(uid);
  CollectionReference<Map<String, dynamic>> get _plano => _usuario.collection('plano');
  CollectionReference<Map<String, dynamic>> get _semanas => _usuario.collection('semanas');

  // ─────────────────────────────────────────
  // PLANO (estrutura de cada dia)
  // ─────────────────────────────────────────

  /// Dia (1–7) → exercícios planejados, para os sete dias de uma vez.
  Future<Map<int, List<ExercicioTreino>>> buscarPlano() async {
    final snapshot = await _plano.get();
    return {
      for (final doc in snapshot.docs)
        int.parse(doc.id): [
          for (final e in (doc.data()['exercicios'] as List? ?? []))
            ExercicioTreino.fromMap(Map<String, dynamic>.from(e)),
        ],
    };
  }

  Future<List<ExercicioTreino>> buscarPlanoDoDia(int dia) async {
    final doc = await _plano.doc('$dia').get();
    return [
      for (final e in (doc.data()?['exercicios'] as List? ?? []))
        ExercicioTreino.fromMap(Map<String, dynamic>.from(e)),
    ];
  }

  Future<void> salvarPlano(int dia, List<ExercicioTreino> exercicios) {
    return _plano.doc('$dia').set({
      'exercicios': [for (final e in exercicios) e.toPlanoMap()],
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────
  // REGISTROS SEMANAIS
  // ─────────────────────────────────────────

  Future<SemanaTreino?> buscarSemana(DateTime inicio) async {
    final id = SemanaTreino.idDe(inicio);
    final doc = await _semanas.doc(id).get();
    if (!doc.exists) return null;
    return SemanaTreino.fromFirestore(id, doc.data()!);
  }

  /// Grava o que foi feito num dia da semana atual. Só esse dia é
  /// substituído (merge), os outros dias da semana ficam intactos.
  /// Exercícios sem nenhuma série preenchida não entram no registro.
  Future<void> salvarDiaDaSemana(DateTime inicio, int dia, List<ExercicioTreino> exercicios) {
    final feitos = exercicios.where((e) => e.seriesPreenchidas.isNotEmpty);
    return _semanas.doc(SemanaTreino.idDe(inicio)).set({
      'inicio': Timestamp.fromDate(inicio),
      'atualizadoEm': FieldValue.serverTimestamp(),
      'dias': {
        '$dia': [for (final e in feitos) e.toRegistroMap()],
      },
    }, SetOptions(merge: true));
  }

  /// Semanas registradas, da mais recente para a mais antiga. [antesDe]
  /// exclui a semana informada e as posteriores.
  ///
  /// Filtra e ordena aqui, não na consulta: ordenar pelo id em ordem
  /// decrescente exigiria um índice criado à mão no Firestore. São poucos
  /// documentos (um por semana), então buscar todos é barato.
  Future<List<SemanaTreino>> buscarHistorico({DateTime? antesDe, int? limite}) async {
    final snapshot = await _semanas.get();
    final limiteId = antesDe == null ? null : SemanaTreino.idDe(antesDe);
    final docs = snapshot.docs
        .where((doc) => limiteId == null || doc.id.compareTo(limiteId) < 0)
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    final semanas = docs
        .map((doc) => SemanaTreino.fromFirestore(doc.id, doc.data()))
        .where((s) => s.diasTreinados.isNotEmpty);
    return (limite == null ? semanas : semanas.take(limite)).toList();
  }
}
