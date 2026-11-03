import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_treino_ia/models/exercicio.dart';
import 'package:tcc_treino_ia/models/grupo_muscular.dart';
import 'package:tcc_treino_ia/models/treino.dart';

/// Confere o catálogo de Corrida e Alongamentos que fica dentro do app.
void main() {
  final dados = jsonDecode(File('assets/data/catalogo_local.json').readAsStringSync());
  final exercicios = [
    for (final e in dados['exercicios'] as List) Exercicio.fromFirestore(Map<String, dynamic>.from(e)),
  ];

  test('cada grupo local tem exercícios e uma capa que existe', () {
    for (final g in GrupoMuscular.todos.where((g) => g.local)) {
      expect(exercicios.where((e) => e.musculoPrimario == g.codigo), isNotEmpty, reason: g.codigo);
      expect(File(g.imagemCapa).existsSync(), isTrue, reason: g.imagemCapa);
    }
  });

  test('todo exercício local tem grupo local, imagens e tipo de registro válido', () {
    final slugs = <String>{};
    for (final ex in exercicios) {
      expect(slugs.add(ex.slug), isTrue, reason: 'slug repetido: ${ex.slug}');
      expect(GrupoMuscular.codigosLocais, contains(ex.musculoPrimario), reason: ex.slug);
      expect(TipoRegistro.values.map((t) => t.name), contains(ex.registro), reason: ex.slug);
      expect(ex.nome, isNotEmpty);
      expect(ex.steps, isNotEmpty, reason: ex.slug);
      for (var i = 1; i <= ex.frames.length; i++) {
        final img = 'assets/images/${ex.slug}-$i.webp';
        expect(File(img).existsSync(), isTrue, reason: img);
      }
    }
  });

  test('corrida e tiro registram distância; alongamentos, tempo', () {
    String registroDe(String slug) => exercicios.firstWhere((e) => e.slug == slug).registro;
    expect(registroDe('corrida'), 'distancia');
    expect(registroDe('longao'), 'distancia');
    expect(registroDe('tiro'), 'intervalado');
    expect(
      exercicios.where((e) => e.musculoPrimario == 'ALONGAMENTO').map((e) => e.registro).toSet(),
      {'tempo'},
    );
  });
}
