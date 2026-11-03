import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/exercicio.dart';
import '../models/grupo_muscular.dart';

/// Catálogo de exercícios. A musculação vem do Firestore; Corrida e
/// Alongamentos vêm de assets/data/catalogo_local.json, dentro do app. As
/// telas não precisam saber a diferença: os métodos juntam as duas fontes.
class ExercicioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      return (await buscarLocais()).where((ex) => ex.musculoPrimario == grupo).toList();
    }

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
    return [
      ...snapshot.docs.map((doc) => Exercicio.fromFirestore(doc.data())),
      ...await buscarLocais(),
    ];
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
    for (final ex in await buscarLocais()) {
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
