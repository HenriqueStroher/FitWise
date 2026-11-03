import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Cadastro, login e logout por e-mail e senha. O login só é exigido na área
/// "Meus Treinos"; o resto do app não depende deste serviço.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Também emite quando o perfil muda (ex.: o nome gravado logo após o
  /// cadastro), não só no login e no logout.
  Stream<User?> get usuario => _auth.userChanges();

  User? get usuarioAtual => _auth.currentUser;

  Future<void> entrar(String email, String senha) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: senha);
  }

  Future<void> cadastrar(String nome, String email, String senha) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: senha,
    );
    final user = cred.user!;
    await user.updateDisplayName(nome.trim());
    await _db.collection('usuarios').doc(user.uid).set({
      'nome': nome.trim(),
      'email': email.trim(),
      'criadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recuperarSenha(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sair() => _auth.signOut();

  /// Mensagem em português para os erros mais comuns do Firebase Auth.
  static String mensagemDeErro(Object erro) {
    if (erro is! FirebaseAuthException) return 'Algo deu errado. Tente novamente.';
    switch (erro.code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Já existe uma conta com este e-mail.';
      case 'weak-password':
        return 'A senha precisa ter pelo menos 6 caracteres.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      case 'operation-not-allowed':
        return 'Login por e-mail e senha não está habilitado no Firebase.';
      default:
        return erro.message ?? 'Algo deu errado. Tente novamente.';
    }
  }
}
