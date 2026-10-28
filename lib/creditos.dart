import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const textoCreditosPadrao = 'Desenvolvido por Geanderson Alves  @GeanAlves';

/// Texto do rodapé da tela de entrada. O admin pode trocar em
/// Administração (config/app.creditos). Sem internet, mostra o padrão.
class CreditosRodape extends StatelessWidget {
  const CreditosRodape({super.key});

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(fontSize: 12.5, color: Color(0xFF8A94A6));
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('config').doc('app').snapshots(),
      builder: (context, snap) {
        final texto = (snap.data?.data()?['creditos'] ?? '').toString().trim();
        if (texto.isNotEmpty) {
          return Text(texto, textAlign: TextAlign.center, style: estilo);
        }
        return const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Desenvolvido por '),
              TextSpan(
                  text: 'Geanderson Alves',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: '  @GeanAlves'),
            ],
          ),
          textAlign: TextAlign.center,
          style: estilo,
        );
      },
    );
  }
}
