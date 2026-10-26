import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ---------- Regras dos tokens ----------

/// Chave Pix (telefone) para onde o motorista paga os tokens.
const chavePix = '+5534999116260';
const chavePixTexto = '(34) 99911-6260';

/// Com quantos tokens o motorista começa a ser avisado.
const avisoTokens = 10;

class PacoteTokens {
  final int quantidade;
  final double preco;
  const PacoteTokens(this.quantidade, this.preco);
}

const pacotes = [PacoteTokens(10, 5), PacoteTokens(20, 10)];

const _azulNoite = Color(0xFF0B2545);
const _amarelo = Color(0xFFFFC24B);
const _verde = Color(0xFF2E7D32);

String _real(num v) =>
    'R\$ ${v.toDouble().toStringAsFixed(2).replaceAll('.', ',')}';

int saldoTokens(Map<String, dynamic>? dados) {
  final t = dados?['tokens'];
  return t is num ? t.toInt() : 0;
}

// ---------- Notificação ----------

final _notificacoes = FlutterLocalNotificationsPlugin();
bool _notifIniciada = false;

Future<void> iniciarNotificacoes() async {
  if (_notifIniciada) return;
  try {
    await _notificacoes.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    await _notificacoes
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _notifIniciada = true;
  } catch (_) {}
}

Future<void> notificarTokens(int saldo) async {
  await iniciarNotificacoes();
  final titulo =
      saldo <= 0 ? 'Seus tokens acabaram' : 'Seus tokens estão acabando';
  final texto = saldo <= 0
      ? 'Você ficou offline. Compre mais tokens na loja para voltar a receber corridas.'
      : 'Restam $saldo ${saldo == 1 ? 'token' : 'tokens'}. Compre mais na loja do PiraCar.';
  try {
    await _notificacoes.show(
      7,
      titulo,
      texto,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tokens',
          'Tokens',
          channelDescription: 'Avisos de saldo de tokens',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  } catch (_) {}
}

// ---------- Selo de saldo (barra do topo) ----------

class SeloTokens extends StatelessWidget {
  const SeloTokens({super.key, required this.saldo, required this.onTap});

  final int saldo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final baixo = saldo <= avisoTokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: saldo <= 0
              ? Colors.red.shade600
              : (baixo ? Colors.orange.shade600 : _azulNoite),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.toll, color: _amarelo, size: 18),
            const SizedBox(width: 4),
            Text('$saldo',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ---------- Loja ----------

class LojaTokensPage extends StatefulWidget {
  const LojaTokensPage({super.key});

  @override
  State<LojaTokensPage> createState() => _LojaTokensPageState();
}

class _LojaTokensPageState extends State<LojaTokensPage> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  PacoteTokens? _escolhido;
  bool _enviando = false;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('users').doc(_uid);

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copiarPix() async {
    await Clipboard.setData(const ClipboardData(text: chavePix));
    _aviso('Chave Pix copiada!');
  }

  // O motorista avisa que pagou; o admin confere o Pix e libera os tokens.
  Future<void> _jaPaguei() async {
    final p = _escolhido;
    if (p == null) return;
    setState(() => _enviando = true);
    try {
      await _ref.update({
        'pedidoTokens': {
          'quantidade': p.quantidade,
          'valor': p.preco,
          'pedidoEm': FieldValue.serverTimestamp(),
        },
      });
      _aviso('Pedido enviado! Os tokens entram assim que o Pix for conferido.');
      setState(() => _escolhido = null);
    } catch (e) {
      _aviso('Não foi possível enviar o pedido: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cancelarPedido() async {
    try {
      await _ref.update({'pedidoTokens': FieldValue.delete()});
    } catch (e) {
      _aviso('Não foi possível cancelar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Loja de tokens'),
        centerTitle: true,
        backgroundColor: _azulNoite,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          final dados = snap.data?.data();
          final saldo = saldoTokens(dados);
          final pedido = dados?['pedidoTokens'];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _cartaoSaldo(saldo),
              const SizedBox(height: 16),
              if (pedido is Map)
                _pedidoPendente(pedido)
              else ...[
                const Text('Escolha um pacote',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Cada corrida aceita usa 1 token.',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final p in pacotes) ...[
                      Expanded(child: _cartaoPacote(p)),
                      if (p != pacotes.last) const SizedBox(width: 12),
                    ],
                  ],
                ),
                if (_escolhido != null) ...[
                  const SizedBox(height: 16),
                  _pagamento(_escolhido!),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _cartaoSaldo(int saldo) {
    final baixo = saldo <= avisoTokens;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _azulNoite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: _amarelo,
            child: Icon(Icons.toll, color: _azulNoite, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seu saldo',
                    style: TextStyle(color: Color(0xFFC9D6EA))),
                Text('$saldo ${saldo == 1 ? 'token' : 'tokens'}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                if (saldo <= 0)
                  const Text('Sem tokens: você não pode ficar online.',
                      style: TextStyle(color: Color(0xFFFF8A80)))
                else if (baixo)
                  const Text('Saldo baixo, compre mais tokens.',
                      style: TextStyle(color: Color(0xFFFFCC80))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoPacote(PacoteTokens p) {
    final sel = _escolhido == p;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _escolhido = p),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: sel ? _azulNoite : const Color(0xFFE2E8F0),
              width: sel ? 2.5 : 1.5),
        ),
        child: Column(
          children: [
            const Icon(Icons.toll, color: Color(0xFFFFB300), size: 34),
            const SizedBox(height: 6),
            Text('${p.quantidade} tokens',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(_real(p.preco),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _verde)),
            Text('${_real(p.preco / p.quantidade)} por corrida',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _pagamento(PacoteTokens p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pague ${_real(p.preco)} por Pix',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_2, color: Colors.black54),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chave Pix (telefone)',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      Text(chavePixTexto,
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _copiarPix,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Depois de pagar, toque em "Já fiz o Pix". Os tokens entram '
            'assim que o pagamento for conferido.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _verde),
              onPressed: _enviando ? null : _jaPaguei,
              child: _enviando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Já fiz o Pix',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pedidoPendente(Map pedido) {
    final qtd = pedido['quantidade'];
    final valor = pedido['valor'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text('Pagamento em análise',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Pedido de $qtd tokens'
              '${valor is num ? ' (${_real(valor)})' : ''}.'),
          const Text(
              'Assim que o Pix for conferido, os tokens entram no seu saldo.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _cancelarPedido,
              child: const Text('Cancelar pedido'),
            ),
          ),
        ],
      ),
    );
  }
}
