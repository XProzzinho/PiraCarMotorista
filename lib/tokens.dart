import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'cores.dart';

// ---------- Regras dos tokens ----------

/// Chave Pix (telefone) para onde o motorista paga os tokens.
const chavePix = '+5534999116260';
const chavePixTexto = '(34) 99911-6260';

// Saldo em reais, guardado em centavos (users/{uid}.saldoCentavos).
// Cada corrida aceita custa o valor definido pela administração
// (config/app.custoCorridaCentavos; padrão R$ 0,50) com saldo positivo, e
// R$ 1,00 (ou o valor da administração, se for maior) com saldo zerado ou
// negativo. O saldo pode ficar negativo até -R$ 10,00.
const custoBase = 50;
const custoNegativoMinimo = 100;
const limiteNegativo = -1000;

/// Valor por corrida definido no app da administração (em centavos).
final custoConfig = ValueNotifier<int>(custoBase);
StreamSubscription? _subCusto;

/// Começa a acompanhar o valor por corrida definido pela administração.
void ouvirCustoCorrida() {
  _subCusto ??= FirebaseFirestore.instance
      .collection('config')
      .doc('app')
      .snapshots()
      .listen((s) {
    final v = s.data()?['custoCorridaCentavos'];
    custoConfig.value = v is num && v > 0 ? v.toInt() : custoBase;
  }, onError: (_) {});
}

int get custoPositivo => custoConfig.value;
int get custoNegativo =>
    custoPositivo > custoNegativoMinimo ? custoPositivo : custoNegativoMinimo;

/// Lê o valor por corrida direto do servidor (usado ao aceitar).
Future<int> custoCorridaAtual() async {
  try {
    final s = await FirebaseFirestore.instance
        .collection('config')
        .doc('app')
        .get();
    final v = s.data()?['custoCorridaCentavos'];
    if (v is num && v > 0) custoConfig.value = v.toInt();
  } catch (_) {}
  return custoConfig.value;
}

/// Abaixo disso (R$ 5,00) o motorista é avisado que o saldo está baixo.
const avisoSaldo = 500;

/// Recargas da loja, em reais.
const recargas = [5, 10];

int custoCorrida(int saldo) => saldo > 0 ? custoPositivo : custoNegativo;

/// Ainda dá para aceitar mais uma corrida sem passar de -R$ 10,00?
bool podeRodar(int saldo) => saldo - custoCorrida(saldo) >= limiteNegativo;

/// Valor em reais: 16.4 -> "R$ 16,40".
String real(num v) =>
    'R\$ ${v.toDouble().toStringAsFixed(2).replaceAll('.', ',')}';

/// Formata centavos como dinheiro: 750 -> "R$ 7,50", -300 -> "-R$ 3,00".
String reais(int centavos) {
  final s = (centavos.abs() / 100).toStringAsFixed(2).replaceAll('.', ',');
  return '${centavos < 0 ? '-' : ''}R\$ $s';
}

const _azulNoite = Color(0xFF0B2545);
const _amarelo = Color(0xFFFFC24B);
const _verde = Color(0xFF2E7D32);

/// Saldo em centavos. Quem ainda tem tokens antigos vale R$ 0,50 cada.
int saldoCentavos(Map<String, dynamic>? dados) {
  final s = dados?['saldoCentavos'];
  if (s is num) return s.toInt();
  final antigo = dados?['tokens'];
  return antigo is num ? antigo.toInt() * custoBase : 0;
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

Future<void> notificarSaldo(int saldo) async {
  await iniciarNotificacoes();
  final String titulo, texto;
  if (!podeRodar(saldo)) {
    titulo = 'Seu saldo acabou';
    texto = 'Você chegou no limite de ${reais(limiteNegativo)} e ficou '
        'offline. Faça uma recarga para voltar a receber corridas.';
  } else if (saldo <= 0) {
    titulo = 'Saldo negativo';
    texto = 'Seu saldo está em ${reais(saldo)}. Agora cada corrida custa '
        '${reais(custoNegativo)}. Faça uma recarga na loja.';
  } else {
    titulo = 'Seu saldo está acabando';
    texto = 'Restam ${reais(saldo)}. Faça uma recarga na loja do Uai Car.';
  }
  try {
    await _notificacoes.show(
      7,
      titulo,
      texto,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tokens',
          'Saldo',
          channelDescription: 'Avisos de saldo',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  } catch (_) {}
}

/// Aviso de corrida nova, com o som do PiraCar (res/raw/corrida.ogg).
/// Toca também com o app minimizado.
Future<void> notificarCorrida(String titulo, String texto) async {
  await iniciarNotificacoes();
  try {
    await _notificacoes.show(
      21,
      titulo,
      texto,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'corridas_piracar',
          'Corridas',
          channelDescription: 'Toque de corrida nova',
          importance: Importance.max,
          priority: Priority.max,
          sound: RawResourceAndroidNotificationSound('corrida'),
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          ticker: 'Nova corrida',
        ),
      ),
    );
  } catch (_) {}
}

// ---------- Selo de saldo (barra do topo) ----------

class SeloSaldo extends StatelessWidget {
  const SeloSaldo({super.key, required this.saldo, required this.onTap});

  final int saldo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cor = saldo <= 0
        ? Colors.red.shade600
        : (saldo <= avisoSaldo ? Colors.orange.shade600 : _azulNoite);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                color: _amarelo, size: 17),
            const SizedBox(width: 5),
            Text(reais(saldo),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ---------- Loja (recargas) ----------

class LojaSaldoPage extends StatefulWidget {
  const LojaSaldoPage({super.key});

  @override
  State<LojaSaldoPage> createState() => _LojaSaldoPageState();
}

class _LojaSaldoPageState extends State<LojaSaldoPage> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  int? _escolhida; // em reais
  bool _enviando = false;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('users').doc(_uid);

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // O motorista digita o valor da recarga (em reais inteiros).
  Future<void> _outroValor() async {
    final ctrl = TextEditingController();
    final v = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Outro valor'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
              prefixText: 'R\$ ',
              hintText: 'Ex.: 15',
              helperText: 'De R\$ 1 até R\$ 500, em reais inteiros'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                final n = int.tryParse(ctrl.text) ?? 0;
                if (n < 1 || n > 500) return;
                Navigator.pop(c, n);
              },
              child: const Text('Usar')),
        ],
      ),
    );
    if (v != null && mounted) setState(() => _escolhida = v);
  }

  Future<void> _copiarPix() async {
    await Clipboard.setData(const ClipboardData(text: chavePix));
    _aviso('Chave Pix copiada!');
  }

  // O motorista avisa que pagou; o admin confere o Pix e libera o saldo.
  Future<void> _jaPaguei() async {
    final v = _escolhida;
    if (v == null) return;
    setState(() => _enviando = true);
    try {
      await _ref.update({
        'pedidoTokens': {
          'valor': v,
          'centavos': v * 100,
          'pedidoEm': FieldValue.serverTimestamp(),
        },
      });
      _aviso('Pedido enviado! O saldo entra assim que o Pix for conferido.');
      setState(() => _escolhida = null);
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
      backgroundColor: fu(Color(0xFFF4F6FA)),
      appBar: AppBar(
        title: const Text('Recarregar saldo'),
        centerTitle: true,
        backgroundColor: _azulNoite,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          final dados = snap.data?.data();
          final saldo = saldoCentavos(dados);
          final pedido = dados?['pedidoTokens'];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _cartaoSaldo(saldo),
              const SizedBox(height: 12),
              _regras(),
              const SizedBox(height: 16),
              if (pedido is Map)
                _pedidoPendente(pedido)
              else ...[
                const Text('Escolha a recarga',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final v in recargas) ...[
                      Expanded(child: _cartaoRecarga(v)),
                      if (v != recargas.last) const SizedBox(width: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _outroValor,
                  icon: const Icon(Icons.edit),
                  label: Text(_escolhida != null && !recargas.contains(_escolhida)
                      ? 'Outro valor: ${reais(_escolhida! * 100)} (trocar)'
                      : 'Outro valor'),
                ),
                if (_escolhida != null) ...[
                  const SizedBox(height: 16),
                  _pagamento(_escolhida!),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _cartaoSaldo(int saldo) {
    final negativo = saldo < 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _azulNoite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _amarelo,
            child: Icon(Icons.account_balance_wallet,
                color: _azulNoite, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seu saldo',
                    style: TextStyle(color: Color(0xFFC9D6EA))),
                Text(reais(saldo),
                    style: TextStyle(
                        color: negativo
                            ? const Color(0xFFFF8A80)
                            : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800)),
                if (!podeRodar(saldo))
                  Text(
                      'Limite de ${reais(limiteNegativo)} atingido: '
                      'recarregue para voltar a rodar.',
                      style: const TextStyle(color: Color(0xFFFF8A80)))
                else if (negativo)
                  const Text('Saldo negativo: faça uma recarga.',
                      style: TextStyle(color: Color(0xFFFFCC80)))
                else if (saldo <= avisoSaldo)
                  const Text('Saldo baixo, faça uma recarga.',
                      style: TextStyle(color: Color(0xFFFFCC80))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _regras() {
    Widget linha(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(i, size: 18, color: fr(Colors.black54)),
              const SizedBox(width: 8),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 13.5))),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sup(Colors.white),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          linha(Icons.check_circle_outline,
              'Com saldo positivo, cada corrida custa ${reais(custoPositivo)}.'),
          linha(Icons.remove_circle_outline,
              'Com saldo zerado ou negativo, cada corrida custa ${reais(custoNegativo)}.'),
          linha(Icons.block,
              'O saldo pode ficar negativo até ${reais(limiteNegativo)}.'),
        ],
      ),
    );
  }

  Widget _cartaoRecarga(int v) {
    final sel = _escolhida == v;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _escolhida = v),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: sup(Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: sel ? _azulNoite : ln(Color(0xFFE2E8F0)),
              width: sel ? 2.5 : 1.5),
        ),
        child: Column(
          children: [
            const Icon(Icons.add_card, color: Color(0xFFFFB300), size: 32),
            const SizedBox(height: 6),
            Text(reais(v * 100),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _verde)),
            Text('${v * 100 ~/ custoPositivo} corridas',
                style: TextStyle(fontSize: 12, color: fr(Colors.black54))),
          ],
        ),
      ),
    );
  }

  Widget _pagamento(int v) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sup(Colors.white),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pague ${reais(v * 100)} por Pix',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: fu(Color(0xFFF4F6FA)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code_2, color: fr(Colors.black54)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chave Pix (telefone)',
                          style:
                              TextStyle(fontSize: 12, color: fr(Colors.black54))),
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
          Text(
            'Depois de pagar, toque em "Já fiz o Pix". O saldo entra '
            'assim que o pagamento for conferido.',
            style: TextStyle(fontSize: 13, color: fr(Colors.black54)),
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
    final v = pedido['valor'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sup(Colors.white),
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
          Text(v is num
              ? 'Recarga de ${reais((v * 100).round())}.'
              : 'Recarga pedida.'),
          Text(
              'Assim que o Pix for conferido, o valor entra no seu saldo.',
              style: TextStyle(color: fr(Colors.black54))),
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
