import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'rota.dart';

const _verde = Color(0xFF1B8A5A);
const _verdeClaro = Color(0xFFE3F4EA);
const _escuro = Color(0xFF111B3A);
const _cinza = Color(0xFF6B7385);
const _azul = Color(0xFF1E6FEB);

const _nomesPagamento = {
  'credito': 'Cartão de crédito',
  'debito': 'Cartão de débito',
  'pix': 'Pix',
};

String _real(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _centro = LatLng(-17.3453, -44.9419);

  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  GoogleMapController? _mapa;
  bool _online = false;
  Rota? _rota;
  String? _rotaChave;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final Set<String> _vistos = {};
  bool _temAtiva = false;

  StreamSubscription<Position>? _subPos;
  String? _corridaPosId;
  DateTime _ultimoEnvio = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _localizar();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subPos?.cancel();
    super.dispose();
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Liga/desliga o modo online e fica de olho nos pedidos novos.
  void _alternarOnline(bool v) {
    setState(() => _online = v);
    _sub?.cancel();
    _sub = null;
    if (!v) return;
    _vistos.clear();
    _sub = _db
        .collection('corridas')
        .where('status', isEqualTo: 'solicitada')
        .snapshots()
        .listen((snap) {
      var novo = false;
      for (final d in snap.docs) {
        if (_vistos.add(d.id)) novo = true;
      }
      if (novo && !_temAtiva) _tocar();
    });
  }

  void _tocar() {
    try {
      FlutterRingtonePlayer().playNotification();
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  // Envia a posição do motorista para a corrida ativa (o passageiro vê).
  Future<void> _enviarPosicao(String corridaId, Position p) async {
    try {
      await _db.collection('corridas').doc(corridaId).update({
        'motoristaPos': GeoPoint(p.latitude, p.longitude),
        'motoristaPosEm': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _gerenciarPosicao(QueryDocumentSnapshot<Map<String, dynamic>>? ativa) {
    if (ativa == null) {
      _subPos?.cancel();
      _subPos = null;
      _corridaPosId = null;
      return;
    }
    if (_corridaPosId == ativa.id) return;
    final id = ativa.id;
    _corridaPosId = id;
    _subPos?.cancel();
    Geolocator.getCurrentPosition()
        .then((p) => _enviarPosicao(id, p))
        .catchError((_) {});
    _subPos = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((p) {
      final agora = DateTime.now();
      if (agora.difference(_ultimoEnvio).inSeconds < 4) return;
      _ultimoEnvio = agora;
      _enviarPosicao(id, p);
    });
  }

  Future<void> _localizar() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }
    await _centralizar();
  }

  Future<void> _centralizar() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      _mapa?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 15));
    } catch (_) {
      _aviso('Não foi possível obter sua localização.');
    }
  }

  Future<void> _aceitar(String id) async {
    try {
      await _db
          .collection('corridas')
          .doc(id)
          .update({'status': 'aceita', 'motoristaId': _uid});
    } catch (_) {
      _aviso('Não foi possível aceitar. Outro motorista pode ter aceitado antes.');
    }
  }

  Future<void> _mudarStatus(String id, String status) async {
    try {
      await _db.collection('corridas').doc(id).update({'status': status});
    } catch (_) {
      _aviso('Não foi possível atualizar a corrida.');
    }
  }

  LatLng _ll(GeoPoint g) => LatLng(g.latitude, g.longitude);

  void _ajustarCamera(List<LatLng> pts) {
    if (pts.length < 2) return;
    double minLat = pts.first.latitude, maxLat = minLat;
    double minLng = pts.first.longitude, maxLng = minLng;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    try {
      _mapa?.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ));
    } catch (_) {}
  }

  // aceita: rota da posição do motorista até o passageiro.
  // em_andamento: rota do passageiro até o destino.
  void _garantirRota(QueryDocumentSnapshot<Map<String, dynamic>>? ativa) {
    if (ativa == null) {
      if (_rotaChave != null && mounted) {
        setState(() {
          _rota = null;
          _rotaChave = null;
        });
      }
      return;
    }
    final chave = '${ativa.id}:${ativa.data()['status']}';
    if (chave == _rotaChave) return;
    _rotaChave = chave;
    _carregarRota(chave, ativa.data());
  }

  Future<void> _carregarRota(String chave, Map<String, dynamic> d) async {
    if (mounted) setState(() => _rota = null);
    LatLng origem;
    LatLng destino;
    if (d['status'] == 'aceita') {
      try {
        final p = await Geolocator.getCurrentPosition();
        origem = LatLng(p.latitude, p.longitude);
      } catch (_) {
        _aviso('Não foi possível obter sua localização.');
        return;
      }
      destino = _ll(d['origem']);
    } else {
      origem = _ll(d['origem']);
      destino = _ll(d['destino']);
    }
    final rota = await buscarRota(origem, destino);
    if (!mounted || chave != _rotaChave) return;
    if (rota == null) {
      _aviso('Não foi possível traçar a rota.');
      return;
    }
    setState(() => _rota = rota);
    _ajustarCamera(rota.pontos);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _menu(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        iconTheme: const IconThemeData(color: _escuro),
        titleSpacing: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            const TextSpan(children: [
              TextSpan(text: 'PiraCar ', style: TextStyle(color: _escuro)),
              TextSpan(text: 'Motorista', style: TextStyle(color: _verde)),
            ]),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          _pilula(),
          IconButton(
            icon: const Icon(Icons.logout, color: _escuro),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('users').doc(_uid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final aprovado = userSnap.data!.data()?['aprovado'] == true;
          if (!aprovado) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Cadastro em análise.\nVocê poderá aceitar corridas assim que for aprovado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: _escuro),
                ),
              ),
            );
          }
          return _telaAprovada();
        },
      ),
    );
  }

  Widget _pilula() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _online ? _verdeClaro : const Color(0xFFEDEFF4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: _online ? _verde : _cinza),
          const SizedBox(width: 6),
          Text(
            _online ? 'Online' : 'Offline',
            style: TextStyle(
              color: _online ? _verde : _cinza,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _db.collection('users').doc(_uid).snapshots(),
              builder: (context, snap) {
                final m = snap.data?.data() ?? {};
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: _verdeClaro,
                    child: Icon(Icons.person, color: _verde),
                  ),
                  title: Text(m['nome'] ?? 'Motorista'),
                  subtitle: Text('${m['carro'] ?? '-'} • ${m['placa'] ?? '-'}'),
                );
              },
            ),
            const Divider(),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () => FirebaseAuth.instance.signOut(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botaoRedondo(IconData icone, VoidCallback onTap,
      {Color cor = _escuro}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icone, color: cor),
        ),
      ),
    );
  }

  Widget _zoom() {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, color: _escuro),
            onPressed: () => _mapa?.animateCamera(CameraUpdate.zoomIn()),
          ),
          const SizedBox(
            width: 28,
            child: Divider(height: 1),
          ),
          IconButton(
            icon: const Icon(Icons.remove, color: _escuro),
            onPressed: () => _mapa?.animateCamera(CameraUpdate.zoomOut()),
          ),
        ],
      ),
    );
  }

  Widget _folha(Widget conteudo) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            conteudo,
          ],
        ),
      ),
    );
  }

  Widget _telaAprovada() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('corridas')
          .where('motoristaId', isEqualTo: _uid)
          .snapshots(),
      builder: (context, snap) {
        QueryDocumentSnapshot<Map<String, dynamic>>? ativa;
        for (final d in snap.data?.docs ?? []) {
          final s = d.data()['status'];
          if (s == 'aceita' || s == 'em_andamento') ativa = d;
        }
        final ativaFinal = ativa;
        _temAtiva = ativaFinal != null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _garantirRota(ativaFinal);
          _gerenciarPosicao(ativaFinal);
        });

        final markers = <Marker>{};
        if (ativaFinal != null) {
          final dados = ativaFinal.data();
          markers.add(Marker(
              markerId: const MarkerId('origem'),
              position: _ll(dados['origem']),
              infoWindow: const InfoWindow(title: 'Passageiro')));
          markers.add(Marker(
              markerId: const MarkerId('destino'),
              position: _ll(dados['destino']),
              infoWindow: InfoWindow(title: dados['destinoTexto'] ?? 'Destino')));
        }
        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition:
                  const CameraPosition(target: _centro, zoom: 13),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              padding: const EdgeInsets.only(bottom: 140),
              markers: markers,
              polylines: {
                if (_rota != null && ativaFinal != null)
                  Polyline(
                    polylineId: const PolylineId('rota'),
                    points: _rota!.pontos,
                    width: 5,
                    color: _azul,
                  ),
              },
              onMapCreated: (c) => _mapa = c,
            ),
            Positioned(
              top: 16,
              left: 16,
              child: _botaoRedondo(Icons.gps_fixed, _centralizar),
            ),
            Positioned(top: 16, right: 16, child: _zoom()),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 12),
                    child: _botaoRedondo(
                      Icons.navigation,
                      () => _rota != null
                          ? _ajustarCamera(_rota!.pontos)
                          : _centralizar(),
                      cor: _azul,
                    ),
                  ),
                  _folha(ativaFinal != null
                      ? _painelAtiva(ativaFinal)
                      : _painelLivre()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _painelAtiva(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final dados = doc.data();
    final emAndamento = dados['status'] == 'em_andamento';
    final valor = (dados['valor'] as num?)?.toDouble();
    final forma = _nomesPagamento[dados['pagamento']];
    final botao = FilledButton.styleFrom(
      backgroundColor: _verde,
      minimumSize: const Size.fromHeight(48),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          emAndamento ? 'Corrida em andamento' : 'Vá buscar o passageiro',
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: _escuro),
        ),
        const SizedBox(height: 4),
        Text('Destino: ${dados['destinoTexto']}',
            style: const TextStyle(color: _cinza)),
        if (valor != null)
          Text(
            'Receber ${_real(valor)}${forma != null ? ' • $forma' : ''}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: _escuro),
          ),
        if (_rota != null)
          Text(
            emAndamento
                ? 'Até o destino: ${_rota!.resumo}'
                : 'Até o passageiro: ${_rota!.resumo}',
            style: const TextStyle(color: _cinza),
          ),
        const SizedBox(height: 14),
        if (!emAndamento) ...[
          FilledButton(
            style: botao,
            onPressed: () => _mudarStatus(doc.id, 'em_andamento'),
            child: const Text('Iniciar corrida'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
            onPressed: () => _mudarStatus(doc.id, 'cancelada'),
            child: const Text('Cancelar corrida'),
          ),
        ] else
          FilledButton(
            style: botao,
            onPressed: () => _mudarStatus(doc.id, 'finalizada'),
            child: const Text('Finalizar corrida'),
          ),
      ],
    );
  }

  Widget _painelLivre() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: _verdeClaro,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.circle, size: 14, color: _verde),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _online ? 'Você está online' : 'Você está offline',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _escuro),
                  ),
                  Text(
                    _online
                        ? 'Aguardando pedidos de corrida'
                        : 'Ative para começar a receber corridas',
                    style: const TextStyle(color: _cinza),
                  ),
                ],
              ),
            ),
            Switch(
              value: _online,
              onChanged: _alternarOnline,
              activeColor: Colors.white,
              activeTrackColor: _verde,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFC5CAD9),
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent),
            ),
          ],
        ),
        if (_online) _pedidos(),
      ],
    );
  }

  Widget _pedidos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('corridas')
          .where('status', isEqualTo: 'solicitada')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final valor = (d.data()['valor'] as num?)?.toDouble();
              final forma = _nomesPagamento[d.data()['pagamento']];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place, color: _verde),
                title: Text(d.data()['destinoTexto'] ?? 'Destino'),
                subtitle: valor == null
                    ? null
                    : Text('${_real(valor)}${forma != null ? ' • $forma' : ''}'),
                trailing: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _verde),
                  onPressed: () => _aceitar(d.id),
                  child: const Text('Aceitar'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
