import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_treino_ia/models/exercicio.dart';
import 'package:tcc_treino_ia/models/grupo_muscular.dart';

/// Confere a base de musculação gerada por data/scripts/gerar_base_appgym.py
/// (a mesma que é importada para o Firestore) contra os assets do app.
void main() {
  final dados = jsonDecode(File('../data/appgym_exercises.json').readAsStringSync());
  final exercicios = [
    for (final e in dados['exercicios'] as List) Exercicio.fromFirestore(Map<String, dynamic>.from(e)),
  ];

  test('todo exercício tem grupo de musculação, slug único e suas imagens', () {
    final gruposFirestore = {for (final g in GrupoMuscular.todos) if (!g.local) g.codigo};
    final slugs = <String>{};
    for (final ex in exercicios) {
      expect(slugs.add(ex.slug), isTrue, reason: 'slug repetido: ${ex.slug}');
      expect(gruposFirestore, contains(ex.musculoPrimario), reason: ex.slug);
      // Isometrias (prancha) podem ter um quadro só; o resto mostra o movimento
      expect(ex.frames.length, greaterThanOrEqualTo(ex.tipo == 'isometric' ? 1 : 2), reason: ex.slug);
      for (var i = 1; i <= ex.frames.length; i++) {
        final img = 'assets/images/${ex.slug}-$i.webp';
        expect(File(img).existsSync(), isTrue, reason: img);
      }
    }
  });

  test('os dois quadros de cada exercício são imagens diferentes', () {
    // Quadros iguais indicam ilustração com defeito na fonte (o Agachamento
    // Hack tinha os dois quadros idênticos). Imagem errada com quadros
    // diferentes não é pega aqui: isso exige olhar as imagens.
    for (final ex in exercicios.where((e) => e.frames.length >= 2)) {
      final a = File('assets/images/${ex.slug}-1.webp').readAsBytesSync();
      final b = File('assets/images/${ex.slug}-2.webp').readAsBytesSync();
      expect(_iguais(a, b), isFalse, reason: ex.slug);
    }
  });

  test('cada grupo de musculação tem exercícios e uma capa que existe', () {
    for (final g in GrupoMuscular.todos.where((g) => !g.local)) {
      expect(exercicios.where((e) => e.musculoPrimario == g.codigo), isNotEmpty, reason: g.codigo);
      expect(File(g.imagemCapa).existsSync(), isTrue, reason: g.imagemCapa);
    }
  });
}

bool _iguais(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
