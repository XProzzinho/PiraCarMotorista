import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Botão de segurança da corrida (escudo vermelho ao lado do chat).
/// Abre: Ligar 190, Ligar 192, Enviar SOS para a central e Fazer denúncia.
/// O SOS vai para a coleção "emergencias" e a denúncia para "denuncias";
/// as duas aparecem no app admin (Administração > Emergências / Denúncias).
/// Este arquivo é igual nos apps do passageiro e do motorista.

final _db = FirebaseFirestore.instance;
const _vermelho = Color(0xFFD32F2F);
const _azulNoite = Color(0xFF0B2545);

class BotaoSeguranca extends StatelessWidget {
  const BotaoSeguranca({
    super.key,
    required this.corridaId,
    required this.souMotorista,
    required this.outroId,
    this.tamanho = 64,
  });

  final String corridaId;
  final bool souMotorista;

  /// uid da outra pessoa da corrida (para a denúncia).
  final String? outroId;

  /// 64 flutuando no mapa; 48 dentro do cartão da outra pessoa.
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final noCartao = tamanho < 64;
    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: Material(
        color: _vermelho,
        shape: CircleBorder(
            side: noCartao
                ? BorderSide.none
                : const BorderSide(color: Colors.white, width: 3)),
        elevation: noCartao ? 0 : 6,
        shadowColor: Colors.black45,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => abrirSeguranca(context,
              corridaId: corridaId,
              souMotorista: souMotorista,
              outroId: outroId),
          child: Icon(Icons.shield,
              color: Colors.white, size: tamanho * 0.47),
        ),
      ),
    );
  }
}

Future<void> abrirSeguranca(
  BuildContext context, {
  required String corridaId,
  required bool souMotorista,
  required String? outroId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.shield, color: _vermelho, size: 28),
                SizedBox(width: 10),
                Text('Segurança',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _azulNoite)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Em perigo, ligue para a polícia. O alerta de SOS avisa a '
              'equipe Uai Car com a sua localização.',
              style: TextStyle(fontSize: 14, color: Color(0xFF5B6B85)),
            ),
            const SizedBox(height: 16),
            _Opcao(
              icone: Icons.local_police,
              titulo: 'Ligar 190',
              sub: 'Polícia Militar',
              cor: _vermelho,
              forte: true,
              onTap: () => _ligar('190'),
            ),
            _Opcao(
              icone: Icons.local_hospital,
              titulo: 'Ligar 192',
              sub: 'SAMU (emergência médica)',
              cor: const Color(0xFFE65100),
              onTap: () => _ligar('192'),
            ),
            _Opcao(
              icone: Icons.sos,
              titulo: 'Enviar SOS para a central',
              sub: 'A equipe Uai Car recebe o alerta e onde você está',
              cor: _vermelho,
              onTap: () async {
                Navigator.pop(ctx);
                await _enviarSos(context,
                    corridaId: corridaId, souMotorista: souMotorista);
              },
            ),
            _Opcao(
              icone: Icons.report_outlined,
              titulo: 'Fazer uma denúncia',
              sub: souMotorista
                  ? 'Algo errado com o passageiro'
                  : 'Algo errado com o motorista ou o carro',
              cor: _azulNoite,
              onTap: () {
                Navigator.pop(ctx);
                fazerDenuncia(context,
                    corridaId: corridaId,
                    souMotorista: souMotorista,
                    outroId: outroId);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.icone,
    required this.titulo,
    required this.sub,
    required this.cor,
    required this.onTap,
    this.forte = false,
  });

  final IconData icone;
  final String titulo;
  final String sub;
  final Color cor;
  final VoidCallback onTap;
  final bool forte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: forte ? cor : cor.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icone, color: forte ? Colors.white : cor, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: forte ? Colors.white : _azulNoite)),
                      Text(sub,
                          style: TextStyle(
                              fontSize: 13,
                              color: forte
                                  ? Colors.white70
                                  : const Color(0xFF5B6B85))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: forte ? Colors.white : const Color(0xFF9AA6BA)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _ligar(String numero) async {
  try {
    await launchUrl(Uri(scheme: 'tel', path: numero));
  } catch (_) {}
}

Future<Map<String, dynamic>> _dadosUsuario(String? uid) async {
  if (uid == null) return {};
  try {
    final d = await _db.collection('users').doc(uid).get();
    return d.data() ?? {};
  } catch (_) {
    return {};
  }
}

Future<Position?> _posicao() async {
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
    );
  } catch (_) {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}

void _aviso(BuildContext context, String texto, {bool erro = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(texto),
    backgroundColor: erro ? _vermelho : const Color(0xFF1E8E3E),
    duration: const Duration(seconds: 5),
  ));
}

Future<void> _enviarSos(BuildContext context,
    {required String corridaId, required bool souMotorista}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  _aviso(context, 'Enviando alerta de SOS...');
  try {
    final eu = await _dadosUsuario(uid);
    final pos = await _posicao();
    await _db.collection('emergencias').add({
      'uid': uid,
      'nome': (eu['nome'] ?? '').toString(),
      'telefone': (eu['telefone'] ?? '').toString(),
      'tipo': souMotorista ? 'motorista' : 'passageiro',
      'corridaId': corridaId,
      if (pos != null) 'lat': pos.latitude,
      if (pos != null) 'lng': pos.longitude,
      'resolvido': false,
      'criadoEm': FieldValue.serverTimestamp(),
    });
    _aviso(context,
        'Alerta enviado! A equipe Uai Car foi avisada. Em perigo, ligue 190.');
  } catch (e) {
    _aviso(context, 'Não foi possível enviar o SOS. Ligue 190.', erro: true);
  }
}

const _motivosPassageiro = [
  'Assédio ou desrespeito',
  'Direção perigosa',
  'Carro ou placa diferente do app',
  'Cobrança diferente do combinado',
  'Motorista agressivo',
  'Outro',
];

const _motivosMotorista = [
  'Assédio ou desrespeito',
  'Passageiro agressivo',
  'Não pagou a corrida',
  'Danos ao carro',
  'Outro',
];

Future<void> fazerDenuncia(
  BuildContext context, {
  required String corridaId,
  required bool souMotorista,
  required String? outroId,
}) {
  final motivos = souMotorista ? _motivosMotorista : _motivosPassageiro;
  final texto = TextEditingController();
  String? motivo;
  var enviando = false;

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Fazer uma denúncia'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('O que aconteceu?',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final m in motivos)
                RadioListTile<String>(
                  value: m,
                  groupValue: motivo,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(m),
                  onChanged: (v) => setD(() => motivo = v),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: texto,
                maxLines: 4,
                minLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Conte o que aconteceu (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const Text(
                'A denúncia vai só para a equipe Uai Car. A outra pessoa '
                'não fica sabendo.',
                style: TextStyle(fontSize: 12, color: Color(0xFF5B6B85)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: enviando ? null : () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _vermelho),
            onPressed: motivo == null || enviando
                ? null
                : () async {
                    setD(() => enviando = true);
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    try {
                      final eu = await _dadosUsuario(uid);
                      final outro = await _dadosUsuario(outroId);
                      await _db.collection('denuncias').add({
                        'deId': uid,
                        'deNome': (eu['nome'] ?? '').toString(),
                        'deTipo': souMotorista ? 'motorista' : 'passageiro',
                        'contraId': outroId,
                        'contraNome': (outro['nome'] ?? '').toString(),
                        'motivo': motivo,
                        if (texto.text.trim().isNotEmpty)
                          'texto': texto.text.trim(),
                        'corridaId': corridaId,
                        'resolvido': false,
                        'criadoEm': FieldValue.serverTimestamp(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _aviso(context,
                          'Denúncia enviada. A equipe Uai Car vai analisar.');
                    } catch (_) {
                      setD(() => enviando = false);
                      _aviso(context,
                          'Não foi possível enviar a denúncia. Tente de novo.',
                          erro: true);
                    }
                  },
            child: Text(enviando ? 'Enviando...' : 'Enviar'),
          ),
        ],
      ),
    ),
  );
}
