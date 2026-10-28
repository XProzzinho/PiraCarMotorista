import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'cadastro_veiculo.dart';
import 'excluir_conta.dart';
import 'aviso.dart';
import 'carro_icone.dart';
import 'foto.dart';
import 'foto_trocar.dart';
import 'menu_visual.dart';
import 'painel_offline.dart';
import 'rota.dart';
import 'tokens.dart';

const _azul = Color(0xFF1E88E5);
const _verde = Color(0xFF2E7D32);

const _nomesPagamento = {
  'credito': 'Cartão de crédito',
  'debito': 'Cartão de débito',
  'pix': 'Pix',
};

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

IconData _iconeManobra(String manobra) => switch (manobra) {
      'esquerda' => Icons.turn_left,
      'direita' => Icons.turn_right,
      'leve_esquerda' => Icons.turn_slight_left,
      'leve_direita' => Icons.turn_slight_right,
      'acentuada_esquerda' => Icons.turn_sharp_left,
      'acentuada_direita' => Icons.turn_sharp_right,
      'retorno' => Icons.u_turn_left,
      'rotatoria' => Icons.roundabout_right,
      'chegada' => Icons.flag,
      _ => Icons.straight,
    };

String _distancia(double m) {
  if (m < 1000) return '${((m / 10).round() * 10).clamp(0, 990)} m';
  return '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
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
        if (!snap.data!.exists) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final dados = snap.data!.data() ?? {};
        final incompleto = dados['temCnh'] != true ||
            (dados['cor'] ?? '').toString().trim().isEmpty ||
            (dados['placa'] ?? '').toString().trim().isEmpty ||
            (dados['cpf'] ?? '').toString().trim().isEmpty ||
            (dados['rg'] ?? '').toString().trim().isEmpty;
        if (dados['bloqueado'] == true) {
          return _Bloqueado(motivo: (dados['motivoBloqueio'] ?? '').toString());
        }
        if (incompleto) return CompletarCadastroPage(dados: dados);
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
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => excluirConta(context, colecoesExtras: ['cnh', 'carros']),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828)),
                icon: const Icon(Icons.person_remove),
                label: const Text('Excluir minha conta'),
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

class _MapaMotoristaState extends State<_MapaMotorista>
    with WidgetsBindingObserver {
  static const _centroPirapora = LatLng(-17.3453, -44.9419);

  final _scaffold = GlobalKey<ScaffoldState>();
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  GoogleMapController? _mapa;
  LatLng? _eu;

  // Mapa 3D: câmera inclinada que segue o carro e gira com a direção.
  bool _seguir = true;
  double _direcao = 0;
  LatLng? _pontoDirecao; // último ponto usado para calcular a direção
  int _passo = 1; // próxima manobra da rota (modo navegação)
  double _zoom3d = 17.5;
  double _giroMapa = 0; // para onde o mapa está girado (bearing da câmera)
  bool _online = false;

  BitmapDescriptor _iconeCarro =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  BitmapDescriptor _iconePessoa =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  StreamSubscription<Position>? _subPos;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subPedidos;
  final Set<String> _vistos = {};

  // Oferta de corrida (cartão grande, estilo Uber)
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _pedidos = [];
  // Pedido recusado (ou que passou o tempo) -> rodada da oferta
  // (ofertadoEm). Se o passageiro oferecer de novo, aparece de novo.
  final Map<String, Object?> _recusados = {};
  String? _ofertaId;
  Rota? _ofertaAteMim;
  Rota? _ofertaViagem;
  String? _ofertaEndereco;
  double? _ofertaNota;
  int _ofertaNotas = 0;
  Map<String, dynamic>? _ofertaPassageiro;
  bool _primeiraLista = true;

  // Corrida ativa
  String? _corridaId;
  Map<String, dynamic>? _corrida;
  String? _statusAnterior;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subCorrida;
  DateTime _ultimoEnvio = DateTime.fromMillisecondsSinceEpoch(0);
  bool _aceitando = false;

  // Próxima corrida, aceita antes de terminar a atual (fila).
  String? _proximaId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subProxima;

  // Rota
  Rota? _rota;
  LatLng? _rotaOrigem;
  DateTime _rotaTentativa = DateTime.fromMillisecondsSinceEpoch(0);
  bool _buscandoRota = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregarIcones();
    _iniciarLocalizacao();
    _retomarCorrida();
    iniciarNotificacoes();
    ouvirCustoCorrida();
  }

  int get _saldo => saldoCentavos(widget.dados);

  // Acompanha o saldo: avisa quando estiver acabando e deixa offline ao zerar.
  @override
  void didUpdateWidget(covariant _MapaMotorista antigo) {
    super.didUpdateWidget(antigo);
    final antes = saldoCentavos(antigo.dados);
    final agora = _saldo;
    if (agora < antes && agora <= avisoSaldo) notificarSaldo(agora);
    final bloqueado = widget.dados['bloqueado'] == true;
    if ((!podeRodar(agora) || bloqueado) && _online && _corridaId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_online) return;
        _alternarOnline();
        if (!bloqueado) {
          _aviso('Seu saldo chegou no limite. Faça uma recarga para ficar online.');
        }
      });
    }
  }

  void _abrirLoja() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const LojaSaldoPage()));

  // ---------- Presença no mapa do passageiro ----------
  // Motorista online e livre publica a posição no próprio cadastro
  // (online, posicao, direcao), e o app do passageiro mostra o carrinho.

  Timer? _batida;
  DateTime _ultimaPresenca = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _disponivel => _online && _corridaId == null;

  /// Distância (em linha reta) que falta para deixar o passageiro.
  double? get _faltaParaDeixar {
    final c = _corrida;
    final dest = _ll(c?['destino']);
    if (_eu == null || dest == null || c?['status'] != 'em_andamento') {
      return null;
    }
    return Geolocator.distanceBetween(
        _eu!.latitude, _eu!.longitude, dest.latitude, dest.longitude);
  }

  /// Perto de deixar o passageiro (até 1,2 km) e ainda sem próxima
  /// corrida: já pode receber a próxima.
  bool get _quaseLivre {
    if (!_online || _corridaId == null || _proximaId != null) return false;
    final falta = _faltaParaDeixar;
    return falta != null && falta <= 1200;
  }

  /// Pode receber oferta agora (livre, ou terminando a corrida).
  bool get _podeReceber => _disponivel || _quaseLivre;

  Future<void> _publicarPresenca({bool forcar = false}) async {
    if (!_podeReceber || _eu == null) return;
    final agora = DateTime.now();
    if (!forcar && agora.difference(_ultimaPresenca).inSeconds < 8) return;
    _ultimaPresenca = agora;
    final quase = !_disponivel;
    final dest = _ll(_corrida?['destino']);
    try {
      await _db.collection('users').doc(_uid).update({
        'online': true,
        'posicao': GeoPoint(_eu!.latitude, _eu!.longitude),
        'direcao': _direcao,
        'posicaoEm': FieldValue.serverTimestamp(),
        'quaseLivre': quase,
        'livreEm': quase && dest != null
            ? GeoPoint(dest.latitude, dest.longitude)
            : FieldValue.delete(),
        'restanteMetros': quase ? (_faltaParaDeixar ?? 0).round() : 0,
      });
    } catch (_) {}
  }

  // Liga/desliga a presença conforme o motorista fica quase livre.
  void _conferirFila() {
    if (_corridaId == null) return;
    final quer = _quaseLivre;
    if (quer && _batida == null) {
      _ligarPresenca(true);
      _escolherOferta();
    } else if (!quer && _batida != null) {
      _ligarPresenca(false);
      if (_ofertaId != null && _proximaId == null) _mostrarOferta(null);
    }
  }

  Future<void> _sairDoMapa() async {
    try {
      await _db
          .collection('users')
          .doc(_uid)
          .update({'online': false, 'quaseLivre': false});
    } catch (_) {}
  }

  void _ligarPresenca(bool ligar) {
    _batida?.cancel();
    _batida = null;
    if (ligar) {
      _publicarPresenca(forcar: true);
      // a cada 25 s confirma que continua online, mesmo parado
      _batida = Timer.periodic(const Duration(seconds: 25),
          (_) => _publicarPresenca(forcar: true));
    } else {
      _sairDoMapa();
    }
  }

  // Minimizar o app NÃO deixa offline: ele segue recebendo corridas em
  // segundo plano (com aviso fixo na barra do celular). Só fechar de vez
  // o app deixa offline.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached && _online && _corridaId == null) {
      _alternarOnline();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reavaliador?.cancel();
    _batida?.cancel();
    if (_online) _sairDoMapa();
    _subPos?.cancel();
    _subPedidos?.cancel();
    _subCorrida?.cancel();
    _subProxima?.cancel();
    super.dispose();
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _carregarIcones() async {
    try {
      final carro = await criarCarroDeCima();
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
    _ouvirPosicao();
  }

  // Online: a localização roda como serviço do Android (aviso fixo na
  // barra), para o app continuar recebendo corridas minimizado.
  void _ouvirPosicao() {
    _subPos?.cancel();
    final emSegundoPlano = _online || _corridaId != null;
    _subPos = Geolocator.getPositionStream(
      locationSettings: emSegundoPlano
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 4,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'PiraCar: você está online',
                notificationText:
                    'Recebendo corridas mesmo com o app minimizado.',
                enableWakeLock: true,
              ),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 4,
            ),
    ).listen((p) => _novaPosicao(p), onError: (_) {});
  }

  void _novaPosicao(Position p, {bool centralizar = false}) {
    if (!mounted) return;
    final ll = LatLng(p.latitude, p.longitude);
    // só usa a direção quando o carro está andando (parado ela oscila)
    if (p.speed > 1.5 && p.heading >= 0) {
      _direcao = p.heading;
      _pontoDirecao = ll;
    } else if (_pontoDirecao == null) {
      _pontoDirecao = ll;
    } else if (Geolocator.distanceBetween(_pontoDirecao!.latitude,
            _pontoDirecao!.longitude, ll.latitude, ll.longitude) >=
        8) {
      // sem bússola do GPS: calcula pela direção em que o carro andou
      final b = Geolocator.bearingBetween(_pontoDirecao!.latitude,
          _pontoDirecao!.longitude, ll.latitude, ll.longitude);
      _direcao = (b + 360) % 360;
      _pontoDirecao = ll;
    }
    setState(() {
      _eu = ll;
      if (centralizar) _seguir = true;
      _avancarPasso(ll);
    });
    if (_seguir) _camera3d();
    _enviarPosicao(ll);
    _conferirFila();
    _publicarPresenca();
    _atualizarRota();
  }

  // Passa para a próxima manobra quando o carro chega perto da atual.
  void _avancarPasso(LatLng eu) {
    final passos = _rota?.passos ?? const <Passo>[];
    while (_passo < passos.length - 1) {
      final p = passos[_passo].ponto;
      if (Geolocator.distanceBetween(
              eu.latitude, eu.longitude, p.latitude, p.longitude) >
          25) {
        break;
      }
      _passo++;
    }
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
        'motoristaDir': _direcao,
        'motoristaPosEm': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ---------- Online / pedidos ----------

  void _alternarOnline() {
    if (!_online && !podeRodar(_saldo)) {
      _aviso('Seu saldo chegou no limite de ${reais(limiteNegativo)}. '
          'Faça uma recarga para ficar online.');
      _abrirLoja();
      return;
    }
    setState(() => _online = !_online);
    _ligarPresenca(_online && _corridaId == null);
    _ouvirPosicao();
    if (_online) {
      _primeiraLista = true;
      _vistos.clear();
      _reavaliador?.cancel();
      _reavaliador =
          Timer.periodic(const Duration(seconds: 5), (_) => _reavaliar());
      _subPedidos = _db
          .collection('corridas')
          .where('status', isEqualTo: 'solicitada')
          .snapshots()
          .listen(_novosPedidos, onError: (_) {});
    } else {
      _reavaliador?.cancel();
      _reavaliador = null;
      _subPedidos?.cancel();
      _subPedidos = null;
      _pedidos = [];
      _recusados.clear();
      _mostrarOferta(null);
    }
  }

  // Regra do motorista mais perto: o app do passageiro oferece o pedido
  // a um motorista por vez (campo ofertadoPara). Só aparece para mim o
  // pedido oferecido a mim. Se o despacho parar por mais de 60 s (app do
  // passageiro fechado, por exemplo), o pedido fica aberto para todos.
  static const _tempoOferta = 20;
  Timer? _reavaliador;

  bool _paraMim(Map<String, dynamic> m) {
    if (m['ofertadoPara'] == _uid) return true;
    final ref = m['ofertadoEm'] ?? m['criadoEm'];
    if (ref is Timestamp) {
      return DateTime.now().difference(ref.toDate()).inSeconds > 60;
    }
    return false;
  }

  void _avisarNovos() {
    var novo = false;
    for (final d in _pedidos) {
      final rodada = '${d.id}|${d.data()['ofertadoEm']}';
      if (_paraMim(d.data()) && _vistos.add(rodada) && !_primeiraLista) {
        novo = true;
      }
    }
    _primeiraLista = false;
    if (novo && _online && _podeReceber) _alertar();
  }

  void _reavaliar() {
    if (!mounted || !_online) return;
    _avisarNovos();
    setState(() {});
    if (_ofertaId != null && _oferta == null) _mostrarOferta(null);
    _escolherOferta();
  }

  void _novosPedidos(QuerySnapshot<Map<String, dynamic>> snap) {
    // mais antigo primeiro
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final ta = a.data()['criadoEm'], tb = b.data()['criadoEm'];
        if (ta is! Timestamp) return 1;
        if (tb is! Timestamp) return -1;
        return ta.compareTo(tb);
      });
    if (!mounted) return;
    setState(() => _pedidos = docs);
    _avisarNovos();
    if (_ofertaId != null && _oferta == null) _mostrarOferta(null);
    _escolherOferta();
  }

  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> get _visiveis =>
      _pedidos.where((d) => _paraMim(d.data()));

  Map<String, dynamic>? get _oferta {
    for (final d in _visiveis) {
      if (d.id == _ofertaId) return d.data();
    }
    return null;
  }

  bool _recusei(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      _recusados.containsKey(d.id) &&
      _recusados[d.id] == d.data()['ofertadoEm'];

  int get _outrosPedidos =>
      _visiveis.where((d) => !_recusei(d)).length - (_oferta != null ? 1 : 0);

  void _escolherOferta() {
    if (!_online || !_podeReceber) return;
    if (_oferta != null) return; // continua mostrando a atual
    for (final d in _visiveis) {
      if (!_recusei(d)) {
        _mostrarOferta(d.id);
        return;
      }
    }
    if (_ofertaId != null) _mostrarOferta(null);
  }

  void _recusarOferta({bool avisar = true}) {
    final id = _ofertaId;
    if (id != null) {
      _recusados[id] = _oferta?['ofertadoEm'];
      // devolve o pedido para ir ao próximo motorista mais perto
      if (avisar && _oferta?['ofertadoPara'] == _uid) {
        _db.collection('corridas').doc(id).update({
          'ofertadoPara': null,
          'recusadoPor': FieldValue.arrayUnion([_uid]),
        }).catchError((_) {});
      }
    }
    _mostrarOferta(null);
    _escolherOferta();
  }

  // Prepara a oferta: rota até o passageiro, rota da viagem, endereço e nota.
  Future<void> _mostrarOferta(String? id) async {
    if (!mounted) return;
    setState(() {
      _ofertaId = id;
      _ofertaAteMim = null;
      _ofertaViagem = null;
      _ofertaEndereco = null;
      _ofertaNota = null;
      _ofertaNotas = 0;
      _ofertaPassageiro = null;
    });
    final d = _oferta;
    if (id == null || d == null) {
      if (_eu != null) _voltar3d();
      return;
    }
    final origem = _ll(d['origem']);
    final destino = _ll(d['destino']);
    final eu = _eu;

    Future<void> ateMim() async {
      if (origem == null || eu == null) return;
      final r = await buscarRota(eu, origem) ?? rotaEstimada(eu, origem);
      if (mounted && _ofertaId == id) setState(() => _ofertaAteMim = r);
    }

    Future<void> viagem() async {
      if (origem == null || destino == null) return;
      final r =
          await buscarRota(origem, destino) ?? rotaEstimada(origem, destino);
      if (mounted && _ofertaId == id) setState(() => _ofertaViagem = r);
    }

    Future<void> endereco() async {
      if (origem == null) return;
      try {
        final l =
            await placemarkFromCoordinates(origem.latitude, origem.longitude);
        if (l.isEmpty) return;
        final pm = l.first;
        final partes = [
          [pm.thoroughfare, pm.subThoroughfare]
              .where((s) => (s ?? '').isNotEmpty)
              .join(', '),
          pm.subLocality,
        ].where((s) => (s ?? '').isNotEmpty).toList();
        final txt = partes.isEmpty ? (pm.street ?? '') : partes.join(' - ');
        if (mounted && _ofertaId == id && txt.isNotEmpty) {
          setState(() => _ofertaEndereco = txt);
        }
      } catch (_) {}
    }

    Future<void> passageiro() async {
      final pid = d['passageiroId'];
      if (pid is! String) return;
      try {
        final s = await _db.collection('users').doc(pid).get();
        if (mounted && _ofertaId == id) {
          setState(() => _ofertaPassageiro = s.data());
        }
      } catch (_) {}
    }

    Future<void> nota() async {
      final pid = d['passageiroId'];
      if (pid is! String) return;
      try {
        final q = await _db
            .collection('corridas')
            .where('passageiroId', isEqualTo: pid)
            .get();
        final notas = q.docs
            .map((x) => x.data()['avaliacaoPassageiro'])
            .whereType<num>()
            .toList();
        if (!mounted || _ofertaId != id) return;
        setState(() {
          _ofertaNotas = notas.length;
          _ofertaNota = notas.isEmpty
              ? null
              : notas.reduce((a, b) => a + b) / notas.length;
        });
      } catch (_) {}
    }

    await Future.wait([ateMim(), viagem(), endereco(), nota(), passageiro()]);
    if (!mounted || _ofertaId != id) return;
    _ajustarCamera([
      if (eu != null) eu,
      if (origem != null) origem,
      if (destino != null) destino,
      ...?_ofertaAteMim?.pontos,
      ...?_ofertaViagem?.pontos,
    ]);
  }

  Future<void> _alertar() async {
    // a corrida mais nova oferecida a mim
    Map<String, dynamic>? d;
    for (final x in _visiveis) {
      d = x.data();
    }
    final valor = d?['valor'];
    final destino = (d?['destinoTexto'] ?? '').toString();
    notificarCorrida(
      valor is num
          ? 'Nova corrida! R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}'
          : 'Nova corrida!',
      destino.isEmpty ? 'Toque para ver e aceitar.' : 'Destino: $destino',
    );
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
      String? andamento, aceita;
      for (final d in q.docs) {
        final s = d.data()['status'];
        if (s == 'em_andamento') andamento ??= d.id;
        if (s == 'aceita') aceita ??= d.id;
      }
      if (andamento != null) {
        _acompanhar(andamento);
        if (aceita != null) _guardarProxima(aceita);
      } else if (aceita != null) {
        _acompanhar(aceita);
      }
    } catch (_) {}
  }

  Future<void> _aceitar(String id) async {
    setState(() => _aceitando = true);
    // terminando outra corrida: esta fica na fila, para depois
    final naFila = _corridaId != null;
    try {
      final ref = _db.collection('corridas').doc(id);
      final eu = _db.collection('users').doc(_uid);
      // Aceitar a corrida desconta o valor da administração (padrão
      // R$ 0,50) ou R$ 1,00 com saldo negativo.
      await custoCorridaAtual();
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final perfil = await tx.get(eu);
        if (snap.data()?['status'] != 'solicitada') {
          throw 'Essa corrida já foi aceita por outro motorista.';
        }
        final saldo = saldoCentavos(perfil.data());
        if (!podeRodar(saldo)) {
          throw 'Seu saldo chegou no limite. Faça uma recarga na loja.';
        }
        final custo = custoCorrida(saldo);
        tx.update(ref, {
          'status': 'aceita',
          'motoristaId': _uid,
          'taxaCentavos': custo,
          'naFila': naFila,
        });
        tx.update(eu, {'saldoCentavos': saldo - custo});
      });
      setState(() {
        _ofertaId = null;
        _ofertaAteMim = null;
        _ofertaViagem = null;
      });
      _ligarPresenca(false); // ocupado: some do mapa do passageiro
      if (naFila) {
        _guardarProxima(id);
        _aviso('Próxima corrida aceita! Termine esta e siga para o '
            'próximo passageiro.');
        if (_eu != null) _voltar3d();
      } else {
        _acompanhar(id);
      }
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
            ? 'Corrida finalizada. Receba ${real(v)} do passageiro.'
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
    final proxima = _proximaId;
    if (proxima != null) {
      // já tem a próxima corrida: vai buscar o próximo passageiro
      _subProxima?.cancel();
      _subProxima = null;
      _proximaId = null;
      _ligarPresenca(false);
      _db
          .collection('corridas')
          .doc(proxima)
          .update({'naFila': false}).catchError((_) {});
      _acompanhar(proxima);
      return;
    }
    if (_eu != null) {
      _voltar3d();
    }
    if (_online) _ligarPresenca(true); // livre de novo
    _escolherOferta();
  }

  // Guarda a próxima corrida (fila) e fica de olho se o passageiro cancelar.
  void _guardarProxima(String id) {
    _subProxima?.cancel();
    setState(() => _proximaId = id);
    _subProxima =
        _db.collection('corridas').doc(id).snapshots().listen((doc) {
      final s = doc.data()?['status'];
      if (!mounted || _proximaId != id) return;
      if (s == 'cancelada' || s == null) {
        _subProxima?.cancel();
        _subProxima = null;
        setState(() => _proximaId = null);
        _aviso('O próximo passageiro cancelou a corrida.');
      }
    }, onError: (_) {});
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
    setState(() {
      _rota = rota;
      _passo = 1;
      _avancarPasso(origem);
    });
    if (primeira) {
      _ajustarCamera([origem, alvo, ...rota.pontos]);
      // mostra a rota inteira por 4 s e volta a seguir o carro em 3D
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _corridaId != null && !_seguir) _voltar3d();
      });
    }
  }

  void _camera3d() {
    if (_eu == null) return;
    _mapa?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: _eu!,
      zoom: _zoom3d,
      tilt: 60,
      bearing: _direcao,
    )));
  }

  void _voltar3d() {
    setState(() => _seguir = true);
    _camera3d();
  }

  void _ajustarCamera(List<LatLng> pts) {
    if (pts.length < 2) return;
    setState(() => _seguir = false); // visão geral da rota (de cima)
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
      _voltar3d();
    }
  }

  // ---------- Tela ----------

  @override
  Widget build(BuildContext context) {
    final status = _corrida?['status'];
    final origem = _ll(_corrida?['origem']);
    final destino = _ll(_corrida?['destino']);
    final corRota = status == 'aceita' ? Colors.green : _azul;
    final oferta = _podeReceber ? _oferta : null;
    final ofOrigem = _ll(oferta?['origem']);
    final ofDestino = _ll(oferta?['destino']);
    final navegando = _navegando;

    return Scaffold(
      key: _scaffold,
      drawer: _menu(),
      body: Stack(
        children: [
          Listener(
            onPointerDown: (_) {
              if (_seguir) setState(() => _seguir = false);
            },
            child: GoogleMap(
            initialCameraPosition: const CameraPosition(
                target: _centroPirapora, zoom: 16, tilt: 60),
            buildingsEnabled: true,
            tiltGesturesEnabled: true,
            compassEnabled: false,
            onCameraMove: (pos) {
              if (_seguir) _zoom3d = pos.zoom.clamp(14.0, 20.0);
              // o carrinho fica "em pé" na tela (não achata com o mapa
              // inclinado); gira conforme a direção e o giro do mapa
              if ((pos.bearing - _giroMapa).abs() > 1.5) {
                setState(() => _giroMapa = pos.bearing);
              }
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding:
                EdgeInsets.only(
                    top: navegando ? 300 : 90,
                    bottom: oferta != null ? 400 : 280),
            polylines: {
              if (oferta != null && _ofertaAteMim != null)
                Polyline(
                  polylineId: const PolylineId('ateMim'),
                  points: _ofertaAteMim!.pontos,
                  width: 5,
                  color: Colors.grey.shade600,
                  patterns: [PatternItem.dash(18), PatternItem.gap(10)],
                ),
              if (oferta != null && _ofertaViagem != null)
                Polyline(
                  polylineId: const PolylineId('viagem'),
                  points: _ofertaViagem!.pontos,
                  width: 6,
                  color: const Color(0xFF1F2937),
                ),
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
                  flat: false,
                  rotation: (_direcao - _giroMapa + 360) % 360,
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
              if (ofOrigem != null)
                Marker(
                  markerId: const MarkerId('ofertaOrigem'),
                  position: ofOrigem,
                  icon: _iconePessoa,
                  anchor: const Offset(0.5, 0.5),
                  zIndex: 2,
                  infoWindow: const InfoWindow(title: 'Passageiro'),
                ),
              if (ofDestino != null)
                Marker(
                  markerId: const MarkerId('ofertaDestino'),
                  position: ofDestino,
                  infoWindow: InfoWindow(
                      title: (oferta?['destinoTexto'] ?? 'Destino').toString()),
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
              if (_eu != null) _camera3d();
            },
          ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                _barraTopo(),
                if (navegando)
                  _bannerNavegacao()
                else
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: AvisoBanner(tipo: 'motorista'),
                  ),
              ],
            ),
          ),
          if (!_seguir && _eu != null)
            Positioned(
              left: 12,
              bottom: oferta != null ? 420 : 300,
              child: Material(
                color: Colors.white,
                elevation: 4,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _voltar3d,
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.navigation_outlined, color: _verde),
                        SizedBox(width: 8),
                        Text('Recentralizar',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _verde)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: oferta != null ? 420 : 300,
            child: Column(
              children: [
                _botaoRedondo(Icons.my_location, _voltar3d),
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

  bool get _navegando {
    final s = _corrida?['status'];
    return _corridaId != null &&
        (s == 'aceita' || s == 'em_andamento') &&
        (_rota?.passos.length ?? 0) > 1;
  }

  // Faixa verde do topo: próxima manobra e a distância até ela.
  Widget _bannerNavegacao() {
    final passos = _rota!.passos;
    final i = _passo.clamp(0, passos.length - 1);
    final atual = passos[i];
    final depois = i + 1 < passos.length ? passos[i + 1] : null;
    final distancia = _eu == null
        ? null
        : Geolocator.distanceBetween(_eu!.latitude, _eu!.longitude,
            atual.ponto.latitude, atual.ponto.longitude);
    const fundo = Color(0xFF0B5E55);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: fundo,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Icon(_iconeManobra(atual.manobra),
                        color: Colors.white, size: 44),
                    if (distancia != null)
                      Text(_distancia(distancia),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    atual.texto.isEmpty ? 'Siga em frente' : atual.texto,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.2),
                  ),
                ),
              ],
            ),
          ),
          if (depois != null)
            Container(
              margin: const EdgeInsets.only(left: 0),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFF094B44),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Depois,',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Icon(_iconeManobra(depois.manobra),
                      color: Colors.white, size: 22),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _barraTopo() {
    // Só o botão redondo do menu, solto em cima do mapa.
    return SafeArea(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: Colors.black38,
            child: IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu_rounded,
                  size: 26, color: Color(0xFF0B2545)),
              onPressed: () => _scaffold.currentState?.openDrawer(),
            ),
          ),
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
    final nome = (d['nome'] ?? 'Motorista').toString();
    final placa = (d['placa'] ?? '').toString();
    return GavetaPiraCar(
      cabecalho: CabecalhoMenu(
        nome: nome,
        subtitulo: [
          if (placa.isNotEmpty) placa,
          'Saldo ${reais(_saldo)}',
        ].join(' · '),
        foto: FotoPerfil(dados: d, raio: 38),
        onFoto: () => trocarFotoPerfil(context),
      ),
      itens: [
        GanhosHojeTile(uid: _uid),
        const SizedBox(height: 10),
        ItemMenu(Icons.account_balance_wallet_outlined, 'Recarregar saldo', () {
          Navigator.pop(context);
          _abrirLoja();
        }, destaque: true),
        ItemMenu(Icons.settings_outlined, 'Configurações', () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ConfiguracoesMotorista(uid: _uid),
            ),
          );
        }),
        ItemMenu(Icons.logout, 'Sair', () async {
          Navigator.pop(context);
          _batida?.cancel();
          await _sairDoMapa();
          FirebaseAuth.instance.signOut();
        }),
      ],
    );
  }

  Widget _painelInferior() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height *
              (_podeReceber && _oferta != null ? 0.6 : 0.45)),
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
                    ? (_quaseLivre && _oferta != null
                        ? _cartaoOferta()
                        : _painelCorrida())
                    : (_online
                        ? (_oferta != null
                            ? _cartaoOferta()
                            : PainelOnline(
                                uid: _uid,
                                saldo: _saldo,
                                aviso: avisoSaldo,
                                onOffline: () {
                                  if (_online) _alternarOnline();
                                },
                                onLoja: _abrirLoja,
                              ))
                        : _painelOffline()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _painelOffline() {
    return PainelOffline(
      uid: _uid,
      saldo: _saldo,
      aviso: avisoSaldo,
      onOnline: () {
        if (!_online) _alternarOnline();
      },
      onLoja: _abrirLoja,
    );
  }

  String _tempo(int segundos) {
    final min = (segundos / 60).ceil();
    if (min < 60) return '$min min';
    final h = min ~/ 60, m = min % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  String _km(num metros) =>
      '${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  Widget _cartaoOferta() {
    final d = _oferta!;
    final id = _ofertaId!;
    final valor = d['valor'];
    final forma = _nomesPagamento[d['pagamento']];
    final ate = _ofertaAteMim;
    final vg = _ofertaViagem;
    final kmViagem = vg != null
        ? vg.metros
        : ((d['distanciaKm'] is num) ? (d['distanciaKm'] as num) * 1000 : null);
    final longa = vg != null && vg.segundos > 45 * 60;
    const cinza = TextStyle(fontSize: 14, color: Colors.black54);
    const forte = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    final exclusiva = d['ofertadoPara'] == _uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_corridaId != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Próxima corrida: o passageiro espera você terminar esta.',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0B2545)),
            ),
          ),
        if (exclusiva)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('tempo_${id}_${d['ofertadoEm']}'),
              tween: Tween(begin: 1, end: 0),
              duration: const Duration(seconds: _tempoOferta),
              onEnd: () {
                // passou o tempo: devolve o pedido para o próximo
                if (mounted && _ofertaId == id) _recusarOferta();
              },
              builder: (context, v, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      color: v > 0.33 ? const Color(0xFF276EF1) : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Você é o motorista mais perto • ${(v * _tempoOferta).ceil()} s para aceitar',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car, color: Colors.white, size: 15),
                  SizedBox(width: 4),
                  Text('PiraCar',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
              ),
            ),
            if (forma != null) ...[
              const SizedBox(width: 8),
              Text(forma,
                  style: const TextStyle(
                      color: _azul,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
            const Spacer(),
            if (_outrosPedidos > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text('+$_outrosPedidos',
                    style: const TextStyle(color: Colors.black45)),
              ),
            Material(
              color: Colors.grey.shade200,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _aceitando ? null : _recusarOferta,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (valor is num)
          Text(real(valor),
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Row(
          children: [
            FotoPerfil(dados: _ofertaPassageiro, raio: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                (_ofertaPassageiro?['nome'] ?? 'Passageiro').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.star_rounded, size: 18, color: Colors.black87),
            const SizedBox(width: 3),
            Text(
              _ofertaNota == null
                  ? 'Novo'
                  : '${_ofertaNota!.toStringAsFixed(2).replaceAll('.', ',')} '
                      '($_ofertaNotas)',
              style: cinza,
            ),
          ],
        ),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 22,
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          color: Colors.black, shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.black26,
                      ),
                    ),
                    Container(width: 10, height: 10, color: Colors.black),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ate == null
                          ? 'Calculando distância...'
                          : '${_tempo(ate.segundos)} (${_km(ate.metros)}) de distância',
                      style: forte,
                    ),
                    Text(_ofertaEndereco ?? 'Local de embarque', style: cinza),
                    const SizedBox(height: 14),
                    Text(
                      vg == null
                          ? (kmViagem != null
                              ? 'Viagem de ${_km(kmViagem)}'
                              : 'Calculando viagem...')
                          : 'Viagem de ${_tempo(vg.segundos)} (${_km(vg.metros)})',
                      style: forte,
                    ),
                    Text((d['destinoTexto'] ?? 'Destino').toString(),
                        style: cinza),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (longa) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.route, size: 18, color: Colors.black54),
              SizedBox(width: 6),
              Text('Viagem longa (mais de 45 min)', style: cinza),
            ],
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF276EF1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            onPressed: _aceitando ? null : () => _aceitar(id),
            child: _aceitando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : const Text('Aceitar'),
          ),
        ),
      ],
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
        if (c['passageiroId'] is String)
          _CartaoPassageiro(uid: c['passageiroId'] as String),
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
            'Você recebe: ${real(valor)}${forma != null ? ' • $forma' : ''}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _verde),
          ),
        const Text('O pagamento é feito direto pelo passageiro no fim.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        if (_proximaId != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.queue, size: 18, color: Color(0xFF276EF1)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Próxima corrida aceita. Ao finalizar esta, a rota '
                      'até o próximo passageiro aparece sozinha.',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
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

/// Foto e nome do passageiro durante a corrida.
class _CartaoPassageiro extends StatelessWidget {
  const _CartaoPassageiro({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final m = snap.data?.data();
        if (m == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              FotoPerfil(dados: m, raio: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Passageiro',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text((m['nome'] ?? 'Passageiro').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Configurações do motorista: foto, dados do carro, saldo,
/// Editar dados e Excluir minha conta.
class _ConfiguracoesMotorista extends StatelessWidget {
  const _ConfiguracoesMotorista({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: barraTela('Configurações'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          final d = snap.data?.data() ?? const <String, dynamic>{};
          final saldo = saldoCentavos(d);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
            children: [
              FotoEditavel(
                foto: FotoPerfil(dados: d, raio: 50),
                onEditar: () => trocarFotoPerfil(context),
              ),
              const SizedBox(height: 10),
              CartaoDados(linhas: [
                LinhaDado('Nome completo', (d['nome'] ?? '').toString()),
                LinhaDado('Placa', (d['placa'] ?? '').toString()),
                LinhaDado('Carro', (d['carro'] ?? '').toString()),
                LinhaDado('Cor', (d['cor'] ?? '').toString(), ultima: true),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Saldo',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: corMenuTitulo)),
                    ),
                    Text(reais(saldo),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: corMenuTitulo)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BotoesConta(
                onEditar: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CompletarCadastroPage(dados: d, editando: true),
                  ),
                ),
                onExcluir: () async {
                  await excluirConta(context, colecoesExtras: ['cnh', 'carros']);
                  if (FirebaseAuth.instance.currentUser == null &&
                      context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tela que aparece quando a administração bloqueia o motorista.
class _Bloqueado extends StatelessWidget {
  const _Bloqueado({required this.motivo});

  final String motivo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B2545),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, color: Colors.white, size: 56),
                ),
                const SizedBox(height: 22),
                const Text('Você está bloqueado pela administração',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  motivo.trim().isNotEmpty
                      ? motivo
                      : 'Enquanto estiver bloqueado, você não pode ficar '
                          'online nem receber corridas. Fale com a '
                          'administração do PiraCar.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFC9D6EA), fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
