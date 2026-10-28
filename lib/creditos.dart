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

/// Versão deste app. Ao lançar uma versão nova, mude aqui e no
/// pubspec.yaml (version).
const versaoApp = '1.0.1';

/// "Versão 1.0.0", pequeno, embaixo dos créditos.
class TextoVersao extends StatelessWidget {
  const TextoVersao({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Versão $versaoApp',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, color: Color(0xFF8A94A6)));
  }
}

/// Compara versões tipo 1.2.3. Negativo se [a] for mais antiga que [b].
int compararVersao(String a, String b) {
  List<int> partes(String v) =>
      v.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
  final pa = partes(a), pb = partes(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// Se o admin marcou uma versão mínima (config/app.[campo]) mais nova que
/// esta, mostra a tela "Atualize o app" no lugar do [child].
class VerificaVersao extends StatelessWidget {
  const VerificaVersao({super.key, required this.campo, required this.child});

  final String campo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('config').doc('app').snapshots(),
      builder: (context, snap) {
        final minima = (snap.data?.data()?[campo] ?? '').toString().trim();
        if (minima.isEmpty || compararVersao(versaoApp, minima) >= 0) {
          return child;
        }
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.system_update,
                      size: 72, color: Color(0xFF1E88E5)),
                  const SizedBox(height: 16),
                  const Text('Atualize o app',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(
                      'Esta versão ($versaoApp) não funciona mais. '
                      'Baixe a versão $minima ou mais nova para continuar '
                      'usando o Bora Car.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
