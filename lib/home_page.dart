import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _centro = LatLng(-22.7253, -47.6492);

  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  GoogleMapController? _mapa;
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _localizar();
  }

  Future<void> _localizar() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;
    final p = await Geolocator.getCurrentPosition();
    _mapa?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 15));
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PiraCar Motorista'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
                  style: TextStyle(fontSize: 18),
                ),
              ),
            );
          }
          return _telaAprovada();
        },
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
        final markers = <Marker>{};
        if (ativa != null) {
          final dados = ativa.data();
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
              markers: markers,
              onMapCreated: (c) => _mapa = c,
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ativa != null ? _painelAtiva(ativa) : _painelLivre(),
                ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emAndamento ? 'Corrida em andamento' : 'Vá buscar o passageiro',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Destino: ${dados['destinoTexto']}'),
        const SizedBox(height: 12),
        if (!emAndamento) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _mudarStatus(doc.id, 'em_andamento'),
              child: const Text('Iniciar corrida'),
            ),
          ),
          OutlinedButton(
            onPressed: () => _mudarStatus(doc.id, 'cancelada'),
            child: const Text('Cancelar corrida'),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _mudarStatus(doc.id, 'finalizada'),
              child: const Text('Finalizar corrida'),
            ),
          ),
      ],
    );
  }

  Widget _painelLivre() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_online ? 'Você está online' : 'Você está offline'),
          value: _online,
          onChanged: (v) => setState(() => _online = v),
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
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Aguardando pedidos de corrida...'),
          );
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place),
                title: Text(d.data()['destinoTexto'] ?? 'Destino'),
                trailing: FilledButton(
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
