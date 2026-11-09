import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/exercicio.dart';
import '../models/grupo_muscular.dart';
import 'sessao.dart';

/// Catálogo de exercícios. A musculação vem do Firestore; Corrida e
/// Alongamentos vêm de assets/data/catalogo_local.json, dentro do app. As
/// telas não precisam saber a diferença: os métodos juntam as duas fontes.
///
/// Para quem é de uma academia (modo em teste), as listas deixam de fora o
/// que ela não tem (Academia.visivel). Sem academia, nada muda.
class ExercicioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static List<Exercicio> _daAcademia(Iterable<Exercicio> lista) {
    final academia = Sessao.academia.value;
    return academia == null ? lista.toList() : lista.where(academia.visivel).toList();
  }

  // O arquivo local é lido uma vez só por execução do app
  static Future<List<Exercicio>>? _locais;

  static Future<List<Exercicio>> buscarLocais() {
    return _locais ??= rootBundle.loadString('assets/data/catalogo_local.json').then((texto) {
      final dados = jsonDecode(texto) as Map<String, dynamic>;
      return [
        for (final e in dados['exercicios'] as List) Exercicio.fromFirestore(Map<String, dynamic>.from(e)),
      ];
    });
  }

  // Busca todos os exercícios de um grupo muscular
  Future<List<Exercicio>> buscarPorGrupo(String grupo) async {
    if (GrupoMuscular.codigosLocais.contains(grupo)) {
      return _daAcademia((await buscarLocais()).where((ex) => ex.musculoPrimario == grupo));
    }

    final snapshot = await _db
        .collection('exercicios')
        .where('musculoPrimario', isEqualTo: grupo)
        .get();

    return _daAcademia(snapshot.docs.map((doc) => Exercicio.fromFirestore(doc.data())));
  }

  // Busca todos os exercícios. [incluirOcultos] ignora a academia (tela em
  // que o dono escolhe o que ocultar).
  Future<List<Exercicio>> buscarTodos({bool incluirOcultos = false}) async {
    final snapshot = await _db.collection('exercicios').get();
    final todos = [
      ...snapshot.docs.map((doc) => Exercicio.fromFirestore(doc.data())),
      ...await buscarLocais(),
    ];
    return incluirOcultos ? todos : _daAcademia(todos);
  }

  // Conta quantos exercícios existem em cada grupo muscular
  Future<Map<String, int>> contarPorGrupo() async {
    final contagem = <String, int>{};
    for (final ex in await buscarTodos()) {
      if (ex.musculoPrimario.isEmpty) continue;
      contagem[ex.musculoPrimario] = (contagem[ex.musculoPrimario] ?? 0) + 1;
    }
    return contagem;
  }

  // Busca exercício por slug
  Future<Exercicio?> buscarPorSlug(String slug) async {
    for (final ex in await buscarLocais()) {
      if (ex.slug == slug) return ex;
    }
    final doc = await _db.collection('exercicios').doc(slug).get();
    if (doc.exists) {
      return Exercicio.fromFirestore(doc.data()!);
    }
    return null;
  }
}
