import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
const versaoApp = '1.0.3';

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

const _azulVersao = Color(0xFF1E6FD9);
const _azulEscuroVersao = Color(0xFF0B2545);

Future<void> _abrirLinkVersao(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || url.trim().isEmpty) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Versão mínima (admin: config/app.[campo], ex.: versaoMinimaPassageiro).
/// Se este app for mais antigo:
/// - com bloquearVersao<App> ligado, mostra a tela cheia "Nova versão
///   disponível" e não deixa usar;
/// - senão, mostra só um aviso em cima da tela, que dá para fechar.
/// O botão "Atualizar agora" abre config/app.linkAtualizar<App>.
class VerificaVersao extends StatefulWidget {
  const VerificaVersao({super.key, required this.campo, required this.child});

  final String campo;
  final Widget child;

  @override
  State<VerificaVersao> createState() => _VerificaVersaoState();
}

class _VerificaVersaoState extends State<VerificaVersao> {
  static bool _fechouAviso = false;

  @override
  Widget build(BuildContext context) {
    final app = widget.campo.replaceFirst('versaoMinima', '');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('config').doc('app').snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() ?? const <String, dynamic>{};
        final minima = (d[widget.campo] ?? '').toString().trim();
        if (minima.isEmpty || compararVersao(versaoApp, minima) >= 0) {
          return widget.child;
        }
        final link = (d['linkAtualizar$app'] ?? '').toString().trim();
        if (d['bloquearVersao$app'] == true) {
          return TelaNovaVersao(minima: minima, link: link);
        }
        if (_fechouAviso) return widget.child;
        return Stack(
          children: [
            widget.child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Material(
                    color: _azulEscuroVersao,
                    elevation: 6,
                    shadowColor: Colors.black38,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: link.isEmpty ? null : () => _abrirLinkVersao(link),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                  color: _azulVersao, shape: BoxShape.circle),
                              child: const Icon(Icons.download_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Atualize o app',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                    'Esta versão ($versaoApp) vai deixar de '
                                    'funcionar em breve. Baixe a versão '
                                    '$minima.',
                                    style: const TextStyle(
                                        color: Color(0xFFC9D6EA),
                                        fontSize: 12,
                                        height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Fechar',
                              icon: const Icon(Icons.close,
                                  color: Color(0xFFC9D6EA), size: 20),
                              onPressed: () =>
                                  setState(() => _fechouAviso = true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tela cheia, fundo branco e botões azuis: "Nova versão disponível".
class TelaNovaVersao extends StatelessWidget {
  const TelaNovaVersao({super.key, required this.minima, required this.link});

  final String minima;
  final String link;

  Widget _versao(String titulo, String valor, Color cor) => Column(
        children: [
          Text(titulo,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A879A))),
          const SizedBox(height: 2),
          Text(valor,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: cor)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                    color: Color(0xFFE8F1FC), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: const BoxDecoration(
                      color: _azulVersao, shape: BoxShape.circle),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 54),
                ),
              ),
              const SizedBox(height: 30),
              const Text('Nova versão disponível',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: _azulEscuroVersao)),
              const SizedBox(height: 10),
              const Text(
                  'Para continuar usando o Uai Car, atualize o app. '
                  'É rapidinho.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, height: 1.5, color: Color(0xFF5B6B82))),
              const SizedBox(height: 28),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                    color: const Color(0xFFF2F5FA),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _versao('Sua versão', versaoApp, _azulEscuroVersao),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Icon(Icons.arrow_forward_rounded,
                          color: _azulVersao),
                    ),
                    _versao('Nova versão', minima, _azulVersao),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _azulVersao,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Atualizar agora'),
                  onPressed: () {
                    if (link.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('O link da nova versão ainda não foi '
                              'colocado. Fale com o suporte.')));
                      return;
                    }
                    _abrirLinkVersao(link);
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _azulVersao,
                    side: const BorderSide(color: _azulVersao, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Falar com o suporte'),
                  onPressed: () => _abrirLinkVersao(
                      'https://wa.me/5534999116260?text='
                      '${Uri.encodeComponent('Olá! Preciso de ajuda para atualizar o Uai Car (versão $versaoApp).')}'),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Uai Car',
                  style: TextStyle(fontSize: 12, color: Color(0xFFA0AABA))),
            ],
          ),
        ),
      ),
    );
  }
}
