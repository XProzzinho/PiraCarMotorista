import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'cores.dart';

/// Chat entre motorista e passageiro durante a corrida.
///
/// As mensagens ficam na própria corrida (corridas/{id}):
///   chat: [ {id, texto, deMotorista (bool), em (Timestamp)} ]
///   chatNaoLidasMotorista / chatNaoLidasPassageiro: quantas o lado ainda
///   não leu.
/// Este arquivo é igual nos apps do motorista e do passageiro.

const _azulNoite = Color(0xFF0B2545);
const _fundo = Color(0xFFF4F6FA);

final _corridas = FirebaseFirestore.instance.collection('corridas');

String _campoNaoLidas(bool souMotorista) =>
    souMotorista ? 'chatNaoLidasMotorista' : 'chatNaoLidasPassageiro';

/// A conversa só vale com a corrida aceita ou em andamento.
bool chatAberto(String? status) =>
    status == 'aceita' || status == 'em_andamento';

/// Bolinha flutuante que abre o chat, com o número de mensagens novas.
class BolinhaChat extends StatelessWidget {
  const BolinhaChat({
    super.key,
    required this.corridaId,
    required this.souMotorista,
    required this.outroId,
  });

  final String corridaId;
  final bool souMotorista;

  /// uid da outra pessoa (para mostrar o nome no topo do chat).
  final String? outroId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _corridas.doc(corridaId).snapshots(),
      builder: (context, snap) {
        final v = snap.data?.data()?[_campoNaoLidas(souMotorista)];
        final novas = v is num ? v.toInt() : 0;
        return SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: _azulNoite,
                shape: const CircleBorder(
                    side: BorderSide(color: Colors.white, width: 3)),
                elevation: 6,
                shadowColor: Colors.black45,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatCorridaPage(
                        corridaId: corridaId,
                        souMotorista: souMotorista,
                        outroId: outroId,
                      ),
                    ),
                  ),
                  child: const SizedBox(
                    width: 64,
                    height: 64,
                    child: Icon(Icons.chat_bubble_outline_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
              if (novas > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE24B4A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text('$novas',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ChatCorridaPage extends StatefulWidget {
  const ChatCorridaPage({
    super.key,
    required this.corridaId,
    required this.souMotorista,
    required this.outroId,
  });

  final String corridaId;
  final bool souMotorista;
  final String? outroId;

  @override
  State<ChatCorridaPage> createState() => _ChatCorridaPageState();
}

class _ChatCorridaPageState extends State<ChatCorridaPage> {
  final _texto = TextEditingController();
  final _rolagem = ScrollController();
  String? _nomeOutro;
  bool _enviando = false;
  int _ultimaQtd = -1;

  List<String> get _rapidas => widget.souMotorista
      ? const ['Estou chegando', 'Cheguei', 'Estou te esperando', 'Ok!']
      : const ['Já estou descendo', 'Estou no portão', 'Pode esperar 2 min?',
          'Ok!'];

  @override
  void initState() {
    super.initState();
    final id = widget.outroId;
    if (id != null) {
      FirebaseFirestore.instance.collection('users').doc(id).get().then((s) {
        final n = (s.data()?['nome'] ?? '').toString().trim();
        if (mounted && n.isNotEmpty) setState(() => _nomeOutro = n);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _texto.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _marcarLidas() async {
    try {
      await _corridas
          .doc(widget.corridaId)
          .update({_campoNaoLidas(widget.souMotorista): 0});
    } catch (_) {}
  }

  Future<void> _enviar(String texto) async {
    final t = texto.trim();
    if (t.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      final agora = Timestamp.now();
      await _corridas.doc(widget.corridaId).update({
        'chat': FieldValue.arrayUnion([
          {
            'id': '${agora.millisecondsSinceEpoch}-${t.hashCode}',
            'texto': t,
            'deMotorista': widget.souMotorista,
            'em': agora,
          }
        ]),
        _campoNaoLidas(!widget.souMotorista): FieldValue.increment(1),
      });
      _texto.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível enviar: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _descer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rolagem.hasClients) {
        _rolagem.animateTo(_rolagem.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      }
    });
  }

  String _hora(dynamic ts) {
    if (ts is! Timestamp) return '';
    final d = ts.toDate();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.hour)}:${dois(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final papel = widget.souMotorista ? 'Seu passageiro' : 'Seu motorista';
    return Scaffold(
      backgroundColor: fu(_fundo),
      appBar: AppBar(
        backgroundColor: _azulNoite,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: ta(Color(0xFFE8F1FD)),
              child: Icon(
                  widget.souMotorista
                      ? Icons.person_outline
                      : Icons.directions_car_filled_outlined,
                  color: const Color(0xFF1565C0),
                  size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_nomeOutro ?? papel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  if (_nomeOutro != null)
                    Text(papel,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _corridas.doc(widget.corridaId).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!.data() ?? const <String, dynamic>{};
          final aberto = chatAberto(d['status'] as String?);
          final msgs = ((d['chat'] as List?) ?? const [])
              .whereType<Map>()
              .toList()
            ..sort((a, b) {
              final ta = a['em'], tb = b['em'];
              if (ta is Timestamp && tb is Timestamp) return ta.compareTo(tb);
              return 0;
            });
          final minhasNaoLidas = d[_campoNaoLidas(widget.souMotorista)];
          if (minhasNaoLidas is num && minhasNaoLidas > 0) _marcarLidas();
          if (msgs.length != _ultimaQtd) {
            _ultimaQtd = msgs.length;
            _descer();
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _rolagem,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        aberto
                            ? 'O chat fecha quando a corrida terminar.'
                            : 'Corrida encerrada. O chat está fechado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: fr(Colors.black54)),
                      ),
                    ),
                    for (final m in msgs) _balao(m),
                  ],
                ),
              ),
              if (aberto) ...[
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final r in _rapidas)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(r),
                            backgroundColor: sup(Colors.white),
                            onPressed: _enviando ? null : () => _enviar(r),
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _texto,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 300,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: _enviar,
                            decoration: InputDecoration(
                              hintText: 'Escreva uma mensagem',
                              counterText: '',
                              filled: true,
                              fillColor: sup(Colors.white),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: _azulNoite,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Enviar',
                            onPressed: _enviando
                                ? null
                                : () => _enviar(_texto.text),
                            icon: const Icon(Icons.send_rounded,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _balao(Map m) {
    final meu = (m['deMotorista'] == true) == widget.souMotorista;
    return Align(
      alignment: meu ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: meu ? _azulNoite : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(meu ? 16 : 4),
            bottomRight: Radius.circular(meu ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text((m['texto'] ?? '').toString(),
                style: TextStyle(
                    fontSize: 15,
                    color: meu ? Colors.white : tx(Colors.black87))),
            const SizedBox(height: 2),
            Text(_hora(m['em']),
                style: TextStyle(
                    fontSize: 11,
                    color: meu ? Colors.white60 : fr(Colors.black45))),
          ],
        ),
      ),
    );
  }
}
