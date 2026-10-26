import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'rota.dart';

const _azul = Color(0xFF1E88E5);
const _verde = Color(0xFF2E7D32);

const _nomesPagamento = {
  'credito': 'Cartão de crédito',
  'debito': 'Cartão de débito',
  'pix': 'Pix',
};

String _real(num v) =>
    'R\$ ${v.toDouble().toStringAsFixed(2).replaceAll('.', ',')}';

LatLng? _ll(dynamic gp) =>
    gp is GeoPoint ? LatLng(gp.latitude, gp.longitude) : null;

// Desenha um ícone (carrinho, bonequinho) dentro de um círculo colorido.
Future<BitmapDescriptor> _criarIcone(IconData icone, Color cor,
    {double tam = 110}) async {
  final gravador = ui.PictureRecorder();
  final canvas = Canvas(gravador);
  final centro = Offset(tam / 2, tam / 2);
  canvas.drawCircle(centro, tam / 2, Paint()..color = Colors.white);
  canvas.drawCircle(centro, tam / 2 - 7, Paint()..color = cor);
  final tp = TextPainter(textDirection: TextDirection.ltr)
    ..text = TextSpan(
      text: String.fromCharCode(icone.codePoint),
      style: TextStyle(
        fontSize: tam * 0.58,
        fontFamily: icone.fontFamily,
        package: icone.fontPackage,
        color: Colors.white,
      ),
    )
    ..layout();
  tp.paint(canvas, Offset((tam - tp.width) / 2, (tam - tp.height) / 2));
  final img =
      await gravador.endRecording().toImage(tam.toInt(), tam.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  // ignore: deprecated_member_use
  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}

// Toca o som de notificação do celular.
Future<void> _tocarSom() async {
  try {
    await const MethodChannel('flutter_ringtone_player')
        .invokeMethod('play', {'android': 2, 'ios': 1007, 'asAlarm': false});
  } catch (_) {}
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final dados = snap.data!.data() ?? {};
        if (dados['aprovado'] != true) return const _EmAnalise();
        return _MapaMotorista(dados: dados);
      },
    );
  }
}

class _EmAnalise extends StatelessWidget {
  const _EmAnalise();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top, size: 72, color: _azul),
              const SizedBox(height: 16),
              const Text('Cadastro em análise',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Assim que o seu cadastro for aprovado, você poderá ficar '
                'online e receber corridas.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapaMotorista extends StatefulWidget {
  final Map<String, dynamic> dados;
  const _MapaMotorista({required this.dados});

  @override
  State<_MapaMotorista> createState() => _MapaMotoristaState();
}

class _MapaMotoristaState extends State<_MapaMotorista> {
  static const _centroPirapora = LatLng(-17.3453, -44.9419);

  final _scaffold = GlobalKey<ScaffoldState>();
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  GoogleMapController? _mapa;
  LatLng? _eu;
  bool _online = false;

  BitmapDescriptor _iconeCarro =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  BitmapDescriptor _iconePessoa =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  StreamSubscription<Position>? _subPos;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subPedidos;
  final Set<String> _vistos = {};
  bool _primeiraLista = true;

  // Corrida ativa
  String? _corridaId;
  Map<String, dynamic>? _corrida;
  String? _statusAnterior;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subCorrida;
  DateTime _ultimoEnvio = DateTime.fromMillisecondsSinceEpoch(0);
  bool _aceitando = false;

  // Rota
  Rota? _rota;
  LatLng? _rotaOrigem;
  DateTime _rotaTentativa = DateTime.fromMillisecondsSinceEpoch(0);
  bool _buscandoRota = false;

  @override
  void initState() {
    super.initState();
    _carregarIcones();
    _iniciarLocalizacao();
    _retomarCorrida();
  }

  @override
  void dispose() {
    _subPos?.cancel();
    _subPedidos?.cancel();
    _subCorrida?.cancel();
    super.dispose();
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _carregarIcones() async {
    try {
      final carro = await _criarIcone(Icons.directions_car, _verde);
      final pessoa = await _criarIcone(Icons.person, Colors.blue.shade700);
      if (!mounted) return;
      setState(() {
        _iconeCarro = carro;
        _iconePessoa = pessoa;
      });
    } catch (_) {}
  }

  // ---------- Localização ----------

  Future<void> _iniciarLocalizacao() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _aviso('Permita o acesso à localização para usar o app.');
      return;
    }
    try {
      final p = await Geolocator.getCurrentPosition();
      _novaPosicao(p, centralizar: true);
    } catch (_) {}
    _subPos = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((p) => _novaPosicao(p));
  }

  void _novaPosicao(Position p, {bool centralizar = false}) {
    if (!mounted) return;
    final ll = LatLng(p.latitude, p.longitude);
    setState(() => _eu = ll);
    if (centralizar) {
      _mapa?.animateCamera(CameraUpdate.newLatLngZoom(ll, 15));
    }
    _enviarPosicao(ll);
    _atualizarRota();
  }

  // Manda a posição para o passageiro acompanhar (no máximo a cada 4 s).
  Future<void> _enviarPosicao(LatLng ll, {bool agora = false}) async {
    final status = _corrida?['status'];
    if (_corridaId == null ||
        (status != 'aceita' && status != 'em_andamento')) return;
    final t = DateTime.now();
    if (!agora && t.difference(_ultimoEnvio).inSeconds < 4) return;
    _ultimoEnvio = t;
    try {
      await _db.collection('corridas').doc(_corridaId).update({
        'motoristaPos': GeoPoint(ll.latitude, ll.longitude),
        'motoristaPosEm': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ---------- Online / pedidos ----------

  void _alternarOnline() {
    setState(() => _online = !_online);
    if (_online) {
      _primeiraLista = true;
      _vistos.clear();
      _subPedidos = _db
          .collection('corridas')
          .where('status', isEqualTo: 'solicitada')
          .snapshots()
          .listen(_novosPedidos, onError: (_) {});
    } else {
      _subPedidos?.cancel();
      _subPedidos = null;
    }
  }

  void _novosPedidos(QuerySnapshot<Map<String, dynamic>> snap) {
    var novo = false;
    for (final d in snap.docs) {
      if (_vistos.add(d.id) && !_primeiraLista) novo = true;
    }
    _primeiraLista = false;
    if (novo && _online && _corridaId == null) _alertar();
  }

  Future<void> _alertar() async {
    _tocarSom();
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 350));
    HapticFeedback.heavyImpact();
  }

  // ---------- Corrida ----------

  // Se o app foi fechado no meio de uma corrida, retoma ela.
  Future<void> _retomarCorrida() async {
    try {
      final q = await _db
          .collection('corridas')
          .where('motoristaId', isEqualTo: _uid)
          .get();
      if (!mounted) return;
      for (final d in q.docs) {
        final s = d.data()['status'];
        if (s == 'aceita' || s == 'em_andamento') {
          _acompanhar(d.id);
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _aceitar(String id) async {
    setState(() => _aceitando = true);
    try {
      final ref = _db.collection('corridas').doc(id);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.data()?['status'] != 'solicitada') {
          throw 'Essa corrida já foi aceita por outro motorista.';
        }
        tx.update(ref, {'status': 'aceita', 'motoristaId': _uid});
      });
      _acompanhar(id);
    } catch (e) {
      _aviso(e is String ? e : 'Não foi possível aceitar: $e');
    } finally {
      if (mounted) setState(() => _aceitando = false);
    }
  }

  void _acompanhar(String id) {
    _subCorrida?.cancel();
    setState(() {
      _corridaId = id;
      _corrida = null;
      _statusAnterior = null;
      _rota = null;
      _rotaOrigem = null;
    });
    _subCorrida =
        _db.collection('corridas').doc(id).snapshots().listen((doc) {
      final d = doc.data();
      if (d == null || !mounted) return;
      final status = d['status'] as String?;
      if (status == 'cancelada') {
        _encerrar('A corrida foi cancelada.');
        return;
      }
      if (status == 'finalizada') {
        final v = d['valor'];
        _encerrar(v is num
            ? 'Corrida finalizada. Receba ${_real(v)} do passageiro.'
            : 'Corrida finalizada.');
        _avaliarPassageiro(id);
        return;
      }
      final mudou = status != _statusAnterior;
      setState(() {
        _corrida = d;
        _statusAnterior = status;
        if (mudou) {
          _rota = null;
          _rotaOrigem = null;
        }
      });
      if (mudou) {
        if (_eu != null) _enviarPosicao(_eu!, agora: true);
        _atualizarRota(forcar: true);
      }
    }, onError: (_) {});
  }

  void _encerrar(String msg) {
    _subCorrida?.cancel();
    _subCorrida = null;
    setState(() {
      _corridaId = null;
      _corrida = null;
      _statusAnterior = null;
      _rota = null;
      _rotaOrigem = null;
    });
    _aviso(msg);
    if (_eu != null) {
      _mapa?.animateCamera(CameraUpdate.newLatLngZoom(_eu!, 15));
    }
  }

  // Ao fim da corrida, o motorista dá de 1 a 5 estrelas ao passageiro.
  // A nota fica na própria corrida e aparece no perfil do passageiro.
  Future<void> _avaliarPassageiro(String corridaId) async {
    final nota = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AvaliacaoDialog(),
    );
    if (nota == null) return;
    try {
      await _db.collection('corridas').doc(corridaId).update({
        'avaliacaoPassageiro': nota,
        'avaliadoEm': FieldValue.serverTimestamp(),
      });
      _aviso('Obrigado pela avaliação!');
    } catch (e) {
      _aviso('Não foi possível salvar a avaliação: $e');
    }
  }

  Future<void> _mudarStatus(String status) async {
    try {
      await _db
          .collection('corridas')
          .doc(_corridaId)
          .update({'status': status});
    } catch (e) {
      _aviso('Não foi possível atualizar a corrida: $e');
    }
  }

  Future<void> _confirmarCancelamento() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancelar corrida?'),
        content: const Text('O passageiro será avisado.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Voltar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cancelar corrida')),
        ],
      ),
    );
    if (ok == true) _mudarStatus('cancelada');
  }

  // ---------- Rota ----------

  LatLng? get _alvo {
    final c = _corrida;
    if (c == null) return null;
    if (c['status'] == 'aceita') return _ll(c['origem']);
    if (c['status'] == 'em_andamento') return _ll(c['destino']);
    return null;
  }

  // Rota pelas ruas até o passageiro (ou até o destino). Recalcula só se
  // o motorista andou mais de 200 m, e no máximo a cada 10 segundos.
  Future<void> _atualizarRota({bool forcar = false}) async {
    final alvo = _alvo;
    if (_buscandoRota || _eu == null || alvo == null) return;
    final agora = DateTime.now();
    if (!forcar && agora.difference(_rotaTentativa).inSeconds < 10) return;
    final longe = _rotaOrigem == null ||
        Geolocator.distanceBetween(_rotaOrigem!.latitude,
                _rotaOrigem!.longitude, _eu!.latitude, _eu!.longitude) >
            200;
    if (!forcar && _rota != null && !longe) return;
    _rotaTentativa = agora;
    _buscandoRota = true;
    final status = _corrida?['status'];
    final origem = _eu!;
    final exata = await buscarRota(origem, alvo);
    _buscandoRota = false;
    if (!mounted || _corrida?['status'] != status) return;
    final rota = exata ?? rotaEstimada(origem, alvo);
    final primeira = _rota == null;
    _rotaOrigem = origem;
    setState(() => _rota = rota);
    if (primeira) _ajustarCamera([origem, alvo, ...rota.pontos]);
  }

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
        70,
      ));
    } catch (_) {}
  }

  void _verRota() {
    final alvo = _alvo;
    if (_eu != null && alvo != null) {
      _ajustarCamera([_eu!, alvo, ...?_rota?.pontos]);
    } else if (_eu != null) {
      _mapa?.animateCamera(CameraUpdate.newLatLngZoom(_eu!, 15));
    }
  }

  // ---------- Tela ----------

  @override
  Widget build(BuildContext context) {
    final status = _corrida?['status'];
    final origem = _ll(_corrida?['origem']);
    final destino = _ll(_corrida?['destino']);
    final corRota = status == 'aceita' ? Colors.green : _azul;

    return Scaffold(
      key: _scaffold,
      drawer: _menu(),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                const CameraPosition(target: _centroPirapora, zoom: 13),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(top: 90, bottom: 280),
            polylines: {
              if (_rota != null && !_rota!.estimada)
                Polyline(
                  polylineId: const PolylineId('rota'),
                  points: _rota!.pontos,
                  width: 6,
                  color: corRota,
                ),
            },
            markers: {
              if (_eu != null)
                Marker(
                  markerId: const MarkerId('eu'),
                  position: _eu!,
                  icon: _iconeCarro,
                  anchor: const Offset(0.5, 0.5),
                  zIndex: 3,
                  infoWindow: const InfoWindow(title: 'Você'),
                ),
              if (status == 'aceita' && origem != null)
                Marker(
                  markerId: const MarkerId('passageiro'),
                  position: origem,
                  icon: _iconePessoa,
                  anchor: const Offset(0.5, 0.5),
                  zIndex: 2,
                  infoWindow: const InfoWindow(title: 'Passageiro'),
                ),
              if (destino != null)
                Marker(
                  markerId: const MarkerId('destino'),
                  position: destino,
                  infoWindow: InfoWindow(
                      title: (_corrida?['destinoTexto'] ?? 'Destino')
                          .toString()),
                ),
            },
            onMapCreated: (c) {
              _mapa = c;
              if (_eu != null) {
                c.animateCamera(CameraUpdate.newLatLngZoom(_eu!, 15));
              }
            },
          ),
          Positioned(top: 0, left: 0, right: 0, child: _barraTopo()),
          Positioned(
            right: 12,
            bottom: 300,
            child: Column(
              children: [
                _botaoRedondo(Icons.my_location, () {
                  if (_eu != null) {
                    _mapa?.animateCamera(
                        CameraUpdate.newLatLngZoom(_eu!, 16));
                  }
                }),
                const SizedBox(height: 10),
                _botaoRedondo(Icons.add,
                    () => _mapa?.animateCamera(CameraUpdate.zoomIn())),
                const SizedBox(height: 10),
                _botaoRedondo(Icons.remove,
                    () => _mapa?.animateCamera(CameraUpdate.zoomOut())),
                const SizedBox(height: 10),
                _botaoRedondo(Icons.navigation, _verRota),
              ],
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: _painelInferior()),
        ],
      ),
    );
  }

  Widget _barraTopo() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffold.currentState?.openDrawer(),
            ),
            const Text('PiraCar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: _corridaId == null ? _alternarOnline : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _online ? Colors.green : Colors.grey.shade500,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_online ? Icons.wifi_tethering : Icons.power_settings_new,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(_online ? 'Online' : 'Offline',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _botaoRedondo(IconData icone, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icone, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _menu() {
    final d = widget.dados;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: _azul),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: _azul),
            ),
            accountName: Text((d['nome'] ?? 'Motorista').toString()),
            accountEmail: Text((d['email'] ??
                    FirebaseAuth.instance.currentUser?.email ??
                    '')
                .toString()),
          ),
          ListTile(
            leading: const Icon(Icons.directions_car),
            title: Text((d['carro'] ?? '-').toString()),
            subtitle: const Text('Carro'),
          ),
          ListTile(
            leading: const Icon(Icons.badge),
            title: Text((d['placa'] ?? '-').toString()),
            subtitle: const Text('Placa'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _painelInferior() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: _corridaId != null
                    ? _painelCorrida()
                    : (_online ? _listaPedidos() : _painelOffline()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _painelOffline() {
    return Column(
      children: [
        const Text('Você está offline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Fique online para receber pedidos de corrida.'),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _alternarOnline,
            child: const Text('Ficar online'),
          ),
        ),
      ],
    );
  }

  Widget _listaPedidos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('corridas')
          .where('status', isEqualTo: 'solicitada')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('Erro ao carregar pedidos: ${snap.error}');
        }
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(Icons.search, size: 36, color: Colors.black45),
                SizedBox(height: 6),
                Text('Aguardando pedidos de corrida...'),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pedidos (${docs.length})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final doc in docs) _cartaoPedido(doc.id, doc.data()),
          ],
        );
      },
    );
  }

  Widget _cartaoPedido(String id, Map<String, dynamic> d) {
    final origem = _ll(d['origem']);
    String? ateVoce;
    if (origem != null && _eu != null) {
      final m = Geolocator.distanceBetween(_eu!.latitude, _eu!.longitude,
          origem.latitude, origem.longitude);
      ateVoce = 'Passageiro a ${(m / 1000).toStringAsFixed(1)} km de você';
    }
    final valor = d['valor'];
    final km = d['distanciaKm'];
    final forma = _nomesPagamento[d['pagamento']];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Para: ${d['destinoTexto'] ?? '-'}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (km is num) Text('Corrida de ${km.toStringAsFixed(1)} km'),
                  if (ateVoce != null)
                    Text(ateVoce,
                        style: const TextStyle(color: Colors.black54)),
                  if (forma != null)
                    Text(forma,
                        style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                if (valor is num)
                  Text(_real(valor),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _verde)),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: _aceitando ? null : () => _aceitar(id),
                  child: const Text('Aceitar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _painelCorrida() {
    final c = _corrida;
    if (c == null) return const LinearProgressIndicator();
    final status = c['status'];
    final valor = c['valor'];
    final forma = _nomesPagamento[c['pagamento']];
    final indoBuscar = status == 'aceita';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(indoBuscar ? 'Indo buscar o passageiro' : 'Corrida em andamento',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(_rota == null
            ? 'Calculando rota...'
            : '${indoBuscar ? 'Passageiro' : 'Destino'} a ${_rota!.resumo}'),
        const SizedBox(height: 6),
        Text('Destino: ${c['destinoTexto'] ?? '-'}'),
        if (valor is num)
          Text(
            'Você recebe: ${_real(valor)}${forma != null ? ' • $forma' : ''}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _verde),
          ),
        const Text('O pagamento é feito direto pelo passageiro no fim.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 12),
        if (indoBuscar) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _mudarStatus('em_andamento'),
              child: const Text('Iniciar corrida'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _confirmarCancelamento,
              child: const Text('Cancelar corrida'),
            ),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _verde),
              onPressed: () => _mudarStatus('finalizada'),
              child: const Text('Finalizar corrida'),
            ),
          ),
      ],
    );
  }
}

class _AvaliacaoDialog extends StatefulWidget {
  const _AvaliacaoDialog();

  @override
  State<_AvaliacaoDialog> createState() => _AvaliacaoDialogState();
}

class _AvaliacaoDialogState extends State<_AvaliacaoDialog> {
  int _nota = 0;

  static const _legendas = ['', 'Muito ruim', 'Ruim', 'Regular', 'Bom', 'Excelente'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Como foi o passageiro?', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i ${i == 1 ? 'estrela' : 'estrelas'}',
                  iconSize: 38,
                  onPressed: () => setState(() => _nota = i),
                  icon: Icon(
                    i <= _nota ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFFFB300),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_legendas[_nota],
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: _nota == 0 ? null : () => Navigator.pop(context, _nota),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
