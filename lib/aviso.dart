import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'cores.dart';

/// Faixa com o aviso que o admin publica (config/avisos -> [tipo]).
/// Depois que a pessoa fecha no X, só volta quando chegar um aviso novo.
class AvisoBanner extends StatelessWidget {
  const AvisoBanner({super.key, required this.tipo});

  /// 'motorista' ou 'passageiro'
  final String tipo;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('config').doc('avisos').snapshots(),
      builder: (context, snapA) {
        final aviso = snapA.data?.data()?[tipo];
        if (aviso is! Map) return const SizedBox.shrink();
        final texto = (aviso['texto'] ?? '').toString().trim();
        final em = aviso['em'];
        if (texto.isEmpty || em is! Timestamp) return const SizedBox.shrink();
        final id = em.millisecondsSinceEpoch;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: db.collection('users').doc(uid).snapshots(),
          builder: (context, snapU) {
            if (!snapU.hasData) return const SizedBox.shrink();
            if (snapU.data!.data()?['avisoLido'] == id) {
              return const SizedBox.shrink();
            }
            return _Faixa(
              texto: texto,
              onFechar: () => db
                  .collection('users')
                  .doc(uid)
                  .update({'avisoLido': id}).catchError((_) {}),
            );
          },
        );
      },
    );
  }
}

class _Faixa extends StatelessWidget {
  const _Faixa({required this.texto, required this.onFechar});

  final String texto;
  final VoidCallback onFechar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B2545),
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                  color: Color(0xFFFFC24B), shape: BoxShape.circle),
              child: Icon(Icons.campaign,
                  size: 20, color: Color(0xFF0B2545)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Aviso PiraCar',
                        style: TextStyle(
                            color: Color(0xFFFFC24B),
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(texto,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, height: 1.3)),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Fechar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: onFechar,
            ),
          ],
        ),
      ),
    );
  }
}
