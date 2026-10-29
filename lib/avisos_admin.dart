import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recebe as notificações enviadas pelo admin (coleção "notificacoes") e as
/// mostra na barra do celular. Funciona com o app aberto ou minimizado; as
/// que chegaram com o app fechado aparecem quando ele for aberto de novo.
/// Igual no passageiro e no motorista; [publico] é 'passageiros' ou
/// 'motoristas'.
final _avisosPlugin = FlutterLocalNotificationsPlugin();
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subAvisos;

Future<void> iniciarAvisosAdmin(String publico) async {
  try {
    await _avisosPlugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    await _avisosPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  const chave = 'ultimo_aviso_admin';
  var visto = prefs.getInt(chave);
  if (visto == null) {
    // primeira vez neste celular: só vale o que for enviado daqui pra frente
    visto = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(chave, visto);
  }
  var ultimo = visto;

  _subAvisos?.cancel();
  _subAvisos = FirebaseFirestore.instance
      .collection('notificacoes')
      .orderBy('criadoEm', descending: true)
      .limit(5)
      .snapshots()
      .listen((snap) async {
    final novos = <Map<String, dynamic>>[];
    for (final d in snap.docs) {
      final m = d.data();
      final t = m['criadoEm'];
      if (t is! Timestamp) continue; // ainda gravando
      final ms = t.millisecondsSinceEpoch;
      if (ms <= ultimo) continue;
      final destino = m['destino'];
      if (destino != 'todos' && destino != publico) continue;
      novos.add({...m, '_ms': ms});
    }
    if (novos.isEmpty) return;
    novos.sort((a, b) => (a['_ms'] as int).compareTo(b['_ms'] as int));
    for (final m in novos) {
      final ms = m['_ms'] as int;
      if (ms > ultimo) ultimo = ms;
      final titulo = (m['titulo'] ?? 'Uai Car').toString();
      final texto = (m['texto'] ?? '').toString();
      try {
        await _avisosPlugin.show(
          1000 + (ms % 100000),
          titulo,
          texto,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'avisos_admin',
              'Avisos do Uai Car',
              channelDescription: 'Mensagens enviadas pela administração',
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(texto),
            ),
          ),
        );
      } catch (_) {}
    }
    await prefs.setInt(chave, ultimo);
  }, onError: (_) {});
}
