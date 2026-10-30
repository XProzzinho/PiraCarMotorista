import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'cores.dart';

/// Pix com QR Code automático (API de pagamento).
///
/// Fica escondido até o admin ligar em Administração → API de pagamento
/// (config/pagamento.ativo == true).
///
/// Ao tocar, o app cria um pedido em `pagamentos_pix`:
///   motoristaUid, valor (reais), status: 'pendente', criadoEm
/// O servidor (Cloud Function) gera o Pix pela API e grava no pedido:
///   qrCodeBase64 (imagem PNG), copiaECola, status: 'aguardando'
/// Quando o Pix cai, o servidor grava status: 'pago' e soma no saldo.

const _azulNoite = Color(0xFF0B2545);
const _verde = Color(0xFF2E7D32);

/// Botão "Pagar com QR Code automático". Não mostra nada enquanto a API
/// de pagamento estiver desligada no admin.
class BotaoQrAutomatico extends StatelessWidget {
  const BotaoQrAutomatico({super.key, required this.valor});

  /// Valor da recarga em reais.
  final int valor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('config')
          .doc('pagamento')
          .snapshots(),
      builder: (context, snap) {
        if (snap.data?.data()?['ativo'] != true) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _azulNoite,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Pagar com QR Code automático',
                      style:
                          TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  onPressed: () {
                    final cfg = snap.data?.data() ?? const <String, dynamic>{};
                    if (cfg['provedor'] == 'infinitepay') {
                      pagarInfinitePay(context, valor,
                          (cfg['handle'] ?? '').toString());
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => QrAutomaticoPage(valor: valor)),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text('O saldo entra sozinho assim que o Pix cair.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: fr(Colors.black54))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Divider(color: ln(Colors.black12))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('ou pague pela chave',
                      style:
                          TextStyle(fontSize: 12, color: fr(Colors.black45))),
                ),
                Expanded(child: Divider(color: ln(Colors.black12))),
              ]),
            ],
          ),
        );
      },
    );
  }
}

/// InfinitePay: cria um link de pagamento (Pix ou cartão) pela API pública
/// (só precisa da InfiniteTag), abre no navegador e deixa o pedido de
/// recarga pendente em users/{uid}.pedidoTokens, como no Pix manual.
/// O admin confere no app da InfinitePay e aprova em Recarga de motorista.
Future<void> pagarInfinitePay(
    BuildContext context, int valor, String handle) async {
  final msg = ScaffoldMessenger.of(context);
  void aviso(String t) => msg.showSnackBar(SnackBar(content: Text(t)));
  final uid = FirebaseAuth.instance.currentUser?.uid;
  var tag = handle.trim().replaceFirst(r'$', '');
  final m = RegExp(r'infinitepay\.io/([^/?#\s]+)').firstMatch(tag);
  if (m != null) tag = m.group(1)!;
  if (uid == null || tag.isEmpty) {
    aviso('Pagamento automático indisponível agora. Use a chave Pix.');
    return;
  }
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  final nav = Navigator.of(context, rootNavigator: true);
  try {
    final nsu = 'recarga_${uid}_${DateTime.now().millisecondsSinceEpoch}';
    final r = await http
        .post(
          Uri.parse('https://api.checkout.infinitepay.io/links'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'handle': tag,
            'order_nsu': nsu,
            'items': [
              {
                'description': 'Recarga de saldo Uai Car Motorista',
                'quantity': 1,
                'price': valor * 100,
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));
    final corpo = jsonDecode(r.body);
    String link = '';
    if (corpo is Map) {
      for (final k in ['url', 'link', 'checkout_url', 'payment_url']) {
        final v = corpo[k];
        if (v is String && v.startsWith('http')) {
          link = v;
          break;
        }
      }
    }
    if (r.statusCode >= 300 || link.isEmpty) {
      throw 'resposta ${r.statusCode}';
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'pedidoTokens': {
        'valor': valor,
        'centavos': valor * 100,
        'pedidoEm': FieldValue.serverTimestamp(),
        'via': 'infinitepay',
        'orderNsu': nsu,
        'link': link,
      },
    });
    nav.pop();
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    aviso('Pague na página da InfinitePay. O saldo entra assim que o '
        'pagamento for conferido.');
  } catch (e) {
    nav.pop();
    aviso('Não deu para abrir o pagamento agora ($e). Use a chave Pix.');
  }
}

class QrAutomaticoPage extends StatefulWidget {
  const QrAutomaticoPage({super.key, required this.valor});

  final int valor;

  @override
  State<QrAutomaticoPage> createState() => _QrAutomaticoPageState();
}

class _QrAutomaticoPageState extends State<QrAutomaticoPage> {
  DocumentReference<Map<String, dynamic>>? _pedido;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _criarPedido();
  }

  Future<void> _criarPedido() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _erro = 'Entre na sua conta de novo.');
      return;
    }
    try {
      final ref =
          await FirebaseFirestore.instance.collection('pagamentos_pix').add({
        'motoristaUid': uid,
        'valor': widget.valor,
        'status': 'pendente',
        'criadoEm': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _pedido = ref);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não foi possível gerar o Pix: $e');
    }
  }

  Uint8List? _imagem(String b64) {
    try {
      return base64Decode(b64.contains(',') ? b64.split(',').last : b64);
    } catch (_) {
      return null;
    }
  }

  Widget _centro(List<Widget> filhos) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: filhos),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fu(const Color(0xFFF4F6FA)),
      appBar: AppBar(
        backgroundColor: _azulNoite,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Pix automático'),
      ),
      body: _erro != null
          ? _centro([
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_erro!, textAlign: TextAlign.center),
            ])
          : _pedido == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _pedido!.snapshots(),
                  builder: (context, snap) {
                    final d = snap.data?.data() ?? const <String, dynamic>{};
                    final status = (d['status'] ?? 'pendente').toString();
                    if (status == 'pago') return _pago();
                    if (status == 'erro' || status == 'cancelado') {
                      return _centro([
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        const Text(
                            'Não deu para gerar o Pix agora. Use a chave Pix '
                            'na tela anterior.',
                            textAlign: TextAlign.center),
                      ]);
                    }
                    final b64 = (d['qrCodeBase64'] ?? '').toString();
                    final copia = (d['copiaECola'] ?? '').toString();
                    if (b64.isEmpty && copia.isEmpty) {
                      return _centro(const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Gerando o QR Code...'),
                      ]);
                    }
                    return _qr(b64, copia);
                  },
                ),
    );
  }

  Widget _qr(String b64, String copia) {
    final img = b64.isEmpty ? null : _imagem(b64);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Pague R\$ ${widget.valor},00',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Abra o app do seu banco e leia o QR Code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fr(Colors.black54))),
        const SizedBox(height: 18),
        if (img != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.memory(img, width: 230, height: 230),
            ),
          ),
        if (copia.isNotEmpty) ...[
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copiar Pix copia e cola'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copia));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código Pix copiado!')));
              },
            ),
          ),
        ],
        const SizedBox(height: 22),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Esperando o pagamento...'),
          ],
        ),
      ],
    );
  }

  Widget _pago() => _centro([
        Container(
          width: 96,
          height: 96,
          decoration:
              const BoxDecoration(color: _verde, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 60),
        ),
        const SizedBox(height: 18),
        const Text('Pagamento recebido!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('R\$ ${widget.valor},00 já entrou no seu saldo.',
            style: TextStyle(color: fr(Colors.black54))),
        const SizedBox(height: 22),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _verde),
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
      ]);
}
