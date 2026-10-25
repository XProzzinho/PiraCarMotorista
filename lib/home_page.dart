import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _cadastro = false;
  bool _carregando = false;

  Future<void> _enviar() async {
    setState(() => _carregando = true);
    try {
      final auth = FirebaseAuth.instance;
      if (_cadastro) {
        final cred = await auth.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _senha.text);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'nome': _nome.text.trim(),
          'email': _email.text.trim(),
          'role': 'passageiro',
          'criadoEm': FieldValue.serverTimestamp(),
        });
      } else {
        await auth.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _senha.text);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'Erro ao entrar')));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset('assets/logo.png',
                      width: 140, height: 140),
                ),
                const SizedBox(height: 12),
                const Text('PiraCar',
                    style:
                        TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                if (_cadastro)
                  TextField(
                    controller: _nome,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                TextField(
                  controller: _senha,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _carregando ? null : _enviar,
                    child: Text(_cadastro ? 'Criar conta' : 'Entrar'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _cadastro = !_cadastro),
                  child: Text(_cadastro
                      ? 'Já tenho conta'
                      : 'Não tenho conta, quero me cadastrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
