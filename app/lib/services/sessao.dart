import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/academia.dart';

/// Perfil do usuário logado e academia dele, para o app inteiro.
///
/// O modo academia ainda está em teste: só liga com
/// `--dart-define=EMULADOR=true` ou `--dart-define=ACADEMIAS=true`. Desligado,
/// [iniciar] não faz nada, os valores ficam nulos e o app se comporta como
/// sempre (todo mundo é usuário comum, catálogo completo).
class Sessao {
  Sessao._();

  static const habilitada =
      bool.fromEnvironment('EMULADOR') || bool.fromEnvironment('ACADEMIAS');

  /// Perfil do usuário logado; nulo sem login ou enquanto carrega.
  static final perfil = ValueNotifier<Perfil?>(null);

  /// Academia do usuário logado. O catálogo (ExercicioService) esconde o
  /// que ela não tem.
  static final academia = ValueNotifier<Academia?>(null);

  /// Código do link de convite (`?convite=...`) ainda não respondido.
  static final convitePendente = ValueNotifier<String?>(null);

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subPerfil;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subAcademia;
  static String? _academiaOuvida;

  static void iniciar() {
    if (!habilitada) return;
    final codigo = Uri.base.queryParameters['convite']?.trim().toUpperCase();
    if (codigo != null && codigo.isNotEmpty) convitePendente.value = codigo;
    FirebaseAuth.instance.authStateChanges().listen(_aoMudarUsuario);
  }

  static Future<void> _aoMudarUsuario(User? usuario) async {
    await _subPerfil?.cancel();
    _ouvirAcademia(null);
    perfil.value = null;
    if (usuario == null) return;

    final db = FirebaseFirestore.instance;
    var admin = false;
    try {
      admin = (await db.collection('admins').doc(usuario.uid).get()).exists;
    } catch (_) {
      // Sem permissão (regras antigas) ou sem rede: não é admin
    }
    // O usuário pode ter saído enquanto a consulta acima rodava
    if (FirebaseAuth.instance.currentUser?.uid != usuario.uid) return;

    // Com as mudanças de metadados, o snapshot chega de novo quando o
    // servidor confirma uma gravação (ex.: ao aceitar um convite)
    _subPerfil = db.collection('usuarios').doc(usuario.uid).snapshots(includeMetadataChanges: true).listen(
      (doc) {
        final p = Perfil.fromMap(usuario.uid, doc.data(), admin: admin);
        // Antes da confirmação, as regras ainda não veem o usuário como
        // membro e negariam a leitura da academia
        if (!doc.metadata.hasPendingWrites) _ouvirAcademia(p.academiaId);
        perfil.value = p;
      },
      onError: (Object e) {
        debugPrint('Sessão: $e');
        // Sem o perfil, o usuário segue como comum
        perfil.value = Perfil(uid: usuario.uid, admin: admin);
      },
    );
  }

  static void _ouvirAcademia(String? id) {
    if (id == _academiaOuvida) return;
    _academiaOuvida = id;
    _subAcademia?.cancel();
    _subAcademia = null;
    academia.value = null;
    if (id == null) return;
    _subAcademia = FirebaseFirestore.instance.collection('academias').doc(id).snapshots().listen(
      (doc) => academia.value = doc.exists ? Academia.fromMap(doc.id, doc.data()!) : null,
      onError: (Object e) {
        debugPrint('Sessão (academia): $e');
        // Sem acesso (ex.: acabou de sair da academia): catálogo completo,
        // e tenta de novo no próximo snapshot do perfil
        _academiaOuvida = null;
        academia.value = null;
      },
    );
  }

  /// Link que abre o app já com o convite.
  static String linkDoConvite(String codigo) {
    // No celular não há endereço próprio: usa o site publicado
    final origem = kIsWeb ? Uri.base.origin : 'https://appgym-7f699.web.app';
    return '$origem/?convite=$codigo';
  }
}
