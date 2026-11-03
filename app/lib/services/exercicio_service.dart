import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercicio.dart';

class ExercicioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Busca todos os exercícios de um grupo muscular
  Future<List<Exercicio>> buscarPorGrupo(String grupo) async {
    final snapshot = await _db
        .collection('exercicios')
        .where('musculoPrimario', isEqualTo: grupo)
        .get();

    return snapshot.docs
        .map((doc) => Exercicio.fromFirestore(doc.data()))
        .toList();
  }

  // Busca todos os exercícios
  Future<List<Exercicio>> buscarTodos() async {
    final snapshot = await _db.collection('exercicios').get();
    return snapshot.docs
        .map((doc) => Exercicio.fromFirestore(doc.data()))
        .toList();
  }

  // Conta quantos exercícios existem em cada grupo muscular
  Future<Map<String, int>> contarPorGrupo() async {
    final snapshot = await _db.collection('exercicios').get();

    final contagem = <String, int>{};
    for (final doc in snapshot.docs) {
      final grupo = doc.data()['musculoPrimario'];
      if (grupo is String && grupo.isNotEmpty) {
        contagem[grupo] = (contagem[grupo] ?? 0) + 1;
      }
    }
    return contagem;
  }

  // Busca exercício por slug
  Future<Exercicio?> buscarPorSlug(String slug) async {
    final doc = await _db.collection('exercicios').doc(slug).get();
    if (doc.exists) {
      return Exercicio.fromFirestore(doc.data()!);
    }
    return null;
  }
}
