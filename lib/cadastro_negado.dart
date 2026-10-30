import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cadastro_veiculo.dart';
import 'cores.dart';

/// Tela do motorista quando o admin nega o cadastro: mostra o que falta
/// (pendencias) e a mensagem da equipe (motivoNegado). Depois de corrigir,
/// o motorista envia de novo para análise.
class CadastroNegadoPage extends StatefulWidget {
  const CadastroNegadoPage({super.key, required this.dados});

  final Map<String, dynamic> dados;

  @override
  State<CadastroNegadoPage> createState() => _CadastroNegadoPageState();
}

class _CadastroNegadoPageState extends State<CadastroNegadoPage> {
  static const _vermelho = Color(0xFFFF6B6B);
  bool _enviando = false;

  Future<void> _reenviar() async {
    setState(() => _enviando = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'negado': false,
        'reenviadoEm': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível enviar: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendencias = ((widget.dados['pendencias'] as List?) ?? const [])
        .map((p) => p.toString())
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final motivo = (widget.dados['motivoNegado'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: const Color(0xFF08142A),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 46,
                backgroundColor: Color(0x33FF6B6B),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: _vermelho,
                  child: Icon(Icons.close_rounded,
                      color: Colors.white, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Cadastro não aprovado',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Corrija o que está abaixo e envie de novo para análise.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: azulClaroPainel, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (pendencias.isNotEmpty)
              _Cartao(
                titulo: 'O que falta para ser aprovado',
                filho: Column(
                  children: [
                    for (final p in pendencias)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: _vermelho, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(p,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (motivo.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Cartao(
                titulo: 'Mensagem da equipe Uai Car',
                filho: Text(motivo,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15.5, height: 1.4)),
              ),
            ],
            if (pendencias.isEmpty && motivo.isEmpty)
              _Cartao(
                titulo: 'O que falta para ser aprovado',
                filho: Text(
                    'Fale com a equipe Uai Car para saber o que corrigir.',
                    style: TextStyle(color: azulClaroPainel, fontSize: 15)),
              ),
            const SizedBox(height: 26),
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CompletarCadastroPage(
                        dados: widget.dados, editando: true),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                      color: Colors.white.withOpacity(.8), width: 1.5),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Corrigir meu cadastro'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _enviando ? null : _reenviar,
                style: FilledButton.styleFrom(
                  backgroundColor: amareloPainel,
                  foregroundColor: const Color(0xFF08142A),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                icon: const Icon(Icons.send_rounded),
                label: Text(_enviando
                    ? 'Enviando...'
                    : 'Já corrigi, enviar para nova análise'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: Text('Sair',
                  style: TextStyle(color: azulClaroPainel, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.titulo, required this.filho});

  final String titulo;
  final Widget filho;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo.toUpperCase(),
              style: const TextStyle(
                  color: amareloPainel,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6)),
          const SizedBox(height: 10),
          filho,
        ],
      ),
    );
  }
}
