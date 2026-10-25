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
  final _carro = TextEditingController();
  final _placa = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _cadastro = false;
  bool _carregando = false;

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _enviar() async {
    setState(() => _carregando = true);
    try {
      final auth = FirebaseAuth.instance;
      final db = FirebaseFirestore.instance;
      if (_cadastro) {
        final cred = await auth.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _senha.text);
        await db.collection('users').doc(cred.user!.uid).set({
          'nome': _nome.text.trim(),
          'email': _email.text.trim(),
          'carro': _carro.text.trim(),
          'placa': _placa.text.trim().toUpperCase(),
          'role': 'motorista',
          'aprovado': false,
          'criadoEm': FieldValue.serverTimestamp(),
        });
      } else {
        final cred = await auth.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _senha.text);
        final doc = await db.collection('users').doc(cred.user!.uid).get();
        if (doc.data()?['role'] != 'motorista') {
          await auth.signOut();
          _aviso('Esta conta não é de motorista.');
        }
      }
    } on FirebaseAuthException catch (e) {
      _aviso(e.message ?? 'Erro ao entrar');
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
                const Icon(Icons.directions_car, size: 72),
                const Text('PiraCar Motorista',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                if (_cadastro) ...[
                  TextField(
                    controller: _nome,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  TextField(
                    controller: _carro,
                    decoration:
                        const InputDecoration(labelText: 'Carro (modelo e cor)'),
                  ),
                  TextField(
                    controller: _placa,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Placa'),
                  ),
                ],
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
