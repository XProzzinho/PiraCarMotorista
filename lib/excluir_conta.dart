import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Exclui a conta do usuário logado:
/// 1) confirma a identidade (senha ou Google),
/// 2) apaga os dados pessoais no Firestore,
/// 3) apaga o login. O app volta sozinho para a tela de entrada.
///
/// As corridas ficam no histórico (sem os dados pessoais do cadastro).
Future<void> excluirConta(BuildContext context,
    {List<String> colecoesExtras = const []}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  void aviso(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  final temSenha = user.providerData.any((p) => p.providerId == 'password');
  final senhaCtrl = TextEditingController();

  final confirmou = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.person_remove, color: Color(0xFFC62828), size: 36),
      title: const Text('Excluir minha conta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seu cadastro, sua foto e seus dados pessoais serão apagados '
            'para sempre. Não dá para desfazer.',
          ),
          if (temSenha) ...[
            const SizedBox(height: 14),
            TextField(
              controller: senhaCtrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Digite sua senha para confirmar',
                border: OutlineInputBorder(),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Text('Você vai confirmar com a sua conta do Google.',
                style: TextStyle(color: Colors.black54)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828)),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  final senha = senhaCtrl.text;
  senhaCtrl.dispose();
  if (confirmou != true) return;

  // 1) confirma que é a própria pessoa
  try {
    if (temSenha) {
      if (senha.isEmpty) {
        aviso('Digite sua senha para excluir a conta.');
        return;
      }
      await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: senha));
    } else {
      await user.reauthenticateWithProvider(GoogleAuthProvider());
    }
  } on FirebaseAuthException catch (e) {
    aviso(e.code == 'wrong-password' || e.code == 'invalid-credential'
        ? 'Senha incorreta.'
        : 'Não foi possível confirmar sua identidade: ${e.message ?? e.code}');
    return;
  }

  // 2) apaga os dados pessoais
  final db = FirebaseFirestore.instance;
  try {
    for (final c in colecoesExtras) {
      await db.collection(c).doc(user.uid).delete();
    }
    await db.collection('users').doc(user.uid).delete();
  } catch (e) {
    aviso('Não foi possível apagar seus dados. Nada foi excluído. ($e)');
    return;
  }

  // 3) apaga o login (o app volta para a tela de entrada)
  try {
    await user.delete();
  } on FirebaseAuthException catch (e) {
    aviso('Seus dados foram apagados, mas o login não: ${e.message ?? e.code}');
    await FirebaseAuth.instance.signOut();
  }
}

/// Botão vermelho "Excluir minha conta".
class BotaoExcluirConta extends StatelessWidget {
  const BotaoExcluirConta({super.key, this.colecoesExtras = const []});

  final List<String> colecoesExtras;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_remove, color: Color(0xFFC62828)),
      title: const Text('Excluir minha conta',
          style: TextStyle(
              color: Color(0xFFC62828), fontWeight: FontWeight.w600)),
      onTap: () => excluirConta(context, colecoesExtras: colecoesExtras),
    );
  }
}
