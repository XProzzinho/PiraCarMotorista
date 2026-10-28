import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

const _chave = String.fromEnvironment('MAPS_KEY');

// Motivo da última falha ao buscar a rota (para mostrar na tela).
String erroRota = '';

// Uma manobra da rota ("vire à direita na R. X"), para o modo navegação.
// manobra: reto, esquerda, direita, leve_esquerda, leve_direita,
// acentuada_esquerda, acentuada_direita, retorno, rotatoria, chegada.
class Passo {
  final LatLng ponto;
  final String texto;
  final String manobra;
  const Passo(this.ponto, this.texto, this.manobra);
}

class Rota {
  final List<LatLng> pontos;
  final int metros;
  final int segundos;
  final bool estimada;
  final List<Passo> passos;
  Rota(this.pontos, this.metros, this.segundos,
      {this.estimada = false, this.passos = const []});

  String get resumo {
    final km = (metros / 1000).toStringAsFixed(1);
    final min = (segundos / 60).ceil();
    return '${estimada ? '≈ ' : ''}$km km • $min min';
  }
}

// Busca a rota pelas ruas e devolve a MAIS CURTA.
// 1º tenta o Google; se falhar, tenta o OSRM (gratuito, sem chave).
Future<Rota?> buscarRota(LatLng origem, LatLng destino) async {
  erroRota = '';
  final google = await _rotaGoogle(origem, destino);
  if (google != null) return google;
  final osrm = await _rotaOsrm(origem, destino);
  if (osrm != null) return osrm;
  return null;
}

Rota? _maisCurta(List<Rota> rotas) {
  if (rotas.isEmpty) return null;
  return rotas.reduce((a, b) => a.metros <= b.metros ? a : b);
}

Map<String, dynamic> _ponto(LatLng p) => {
      'location': {
        'latLng': {'latitude': p.latitude, 'longitude': p.longitude}
      }
    };

Future<Rota?> _rotaGoogle(LatLng origem, LatLng destino) async {
  if (_chave.isEmpty) {
    erroRota = 'Google: a chave não chegou no app';
    return null;
  }
  try {
    final resp = await http
        .post(
          Uri.parse(
              'https://routes.googleapis.com/directions/v2:computeRoutes'),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _chave,
            'X-Goog-FieldMask':
                'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration,'
                    'routes.legs.steps.startLocation,routes.legs.steps.navigationInstruction',
          },
          body: jsonEncode({
            'origin': _ponto(origem),
            'destination': _ponto(destino),
            'travelMode': 'DRIVE',
            'computeAlternativeRoutes': true,
            'languageCode': 'pt-BR',
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) {
      var msg = '';
      try {
        msg = (jsonDecode(resp.body)['error']['message'] ?? '').toString();
      } catch (_) {}
      erroRota = 'Google: erro ${resp.statusCode} $msg';
      return null;
    }
    final lista = jsonDecode(resp.body)['routes'] as List? ?? [];
    final rotas = <Rota>[];
    for (final r in lista) {
      final enc = r['polyline']?['encodedPolyline'];
      if (enc == null) continue;
      final pontos = _decodificar(enc as String);
      rotas.add(Rota(
        pontos,
        ((r['distanceMeters'] ?? 0) as num).toInt(),
        int.tryParse(r['duration'].toString().replaceAll('s', '')) ?? 0,
        passos: _passosGoogle(r, pontos),
      ));
    }
    final melhor = _maisCurta(rotas);
    if (melhor == null) erroRota = 'Google: nenhuma rota';
    return melhor;
  } catch (e) {
    erroRota = 'Google: $e';
    return null;
  }
}

Future<Rota?> _rotaOsrm(LatLng origem, LatLng destino) async {
  try {
    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origem.longitude},${origem.latitude};'
        '${destino.longitude},${destino.latitude}'
        '?overview=full&geometries=polyline&alternatives=true&steps=true');
    final resp = await http
        .get(url, headers: {'User-Agent': 'Bora Car'})
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) {
      erroRota += ' | OSRM: erro ${resp.statusCode}';
      return null;
    }
    final dados = jsonDecode(resp.body);
    if (dados['code'] != 'Ok') {
      erroRota += ' | OSRM: ${dados['code']}';
      return null;
    }
    final rotas = <Rota>[];
    for (final r in (dados['routes'] as List)) {
      rotas.add(Rota(
        _decodificar(r['geometry'] as String),
        (r['distance'] as num).round(),
        (r['duration'] as num).round(),
        passos: _passosOsrm(r),
      ));
    }
    return _maisCurta(rotas);
  } catch (e) {
    erroRota += ' | OSRM: $e';
    return null;
  }
}

// Último recurso (só para estimar o preço; não é desenhada no mapa).
Rota rotaEstimada(LatLng origem, LatLng destino) {
  final reta = Geolocator.distanceBetween(
      origem.latitude, origem.longitude, destino.latitude, destino.longitude);
  final metros = (reta * 1.3).round();
  return Rota([origem, destino], metros, (metros / 8.3).round(),
      estimada: true);
}

List<LatLng> _decodificar(String s) {
  final pontos = <LatLng>[];
  int i = 0, lat = 0, lng = 0;
  // lê o próximo número da polyline do Google
  int proximo() {
    int b, shift = 0, res = 0;
    do {
      b = s.codeUnitAt(i++) - 63;
      res |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
  }

  while (i < s.length) {
    lat += proximo();
    lng += proximo();
    pontos.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return pontos;
}

// ---------- Manobras (modo navegação) ----------

const _manobrasGoogle = {
  'TURN_LEFT': 'esquerda',
  'TURN_RIGHT': 'direita',
  'TURN_SLIGHT_LEFT': 'leve_esquerda',
  'TURN_SLIGHT_RIGHT': 'leve_direita',
  'TURN_SHARP_LEFT': 'acentuada_esquerda',
  'TURN_SHARP_RIGHT': 'acentuada_direita',
  'UTURN_LEFT': 'retorno',
  'UTURN_RIGHT': 'retorno',
  'ROUNDABOUT_LEFT': 'rotatoria',
  'ROUNDABOUT_RIGHT': 'rotatoria',
  'ROUNDABOUT_STRAIGHT': 'rotatoria',
  'ROUNDABOUT_SLIGHT_LEFT': 'rotatoria',
  'ROUNDABOUT_SLIGHT_RIGHT': 'rotatoria',
  'ROUNDABOUT_SHARP_LEFT': 'rotatoria',
  'ROUNDABOUT_SHARP_RIGHT': 'rotatoria',
  'ROUNDABOUT_U_TURN': 'rotatoria',
  'ROUNDABOUT_COUNTERCLOCKWISE': 'rotatoria',
  'ROUNDABOUT_CLOCKWISE': 'rotatoria',
  'RAMP_LEFT': 'leve_esquerda',
  'RAMP_RIGHT': 'leve_direita',
  'FORK_LEFT': 'leve_esquerda',
  'FORK_RIGHT': 'leve_direita',
  'MERGE': 'reto',
};

List<Passo> _passosGoogle(dynamic rota, List<LatLng> pontos) {
  final passos = <Passo>[];
  try {
    for (final leg in (rota['legs'] as List? ?? const [])) {
      for (final s in (leg['steps'] as List? ?? const [])) {
        final ll = s['startLocation']?['latLng'];
        if (ll == null) continue;
        final nav = s['navigationInstruction'] ?? const {};
        passos.add(Passo(
          LatLng((ll['latitude'] as num).toDouble(),
              (ll['longitude'] as num).toDouble()),
          (nav['instructions'] ?? '').toString().replaceAll('\n', ' '),
          _manobrasGoogle[nav['maneuver']] ?? 'reto',
        ));
      }
    }
    if (pontos.isNotEmpty) {
      passos.add(Passo(pontos.last, 'Você chegou ao destino', 'chegada'));
    }
  } catch (_) {}
  return passos;
}

const _ladosOsrm = {
  'left': 'esquerda',
  'right': 'direita',
  'slight left': 'leve_esquerda',
  'slight right': 'leve_direita',
  'sharp left': 'acentuada_esquerda',
  'sharp right': 'acentuada_direita',
  'uturn': 'retorno',
  'straight': 'reto',
};

List<Passo> _passosOsrm(dynamic rota) {
  final passos = <Passo>[];
  try {
    for (final leg in (rota['legs'] as List? ?? const [])) {
      for (final s in (leg['steps'] as List? ?? const [])) {
        final m = s['maneuver'] ?? const {};
        final loc = m['location'] as List;
        final ponto =
            LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble());
        final tipo = (m['type'] ?? '').toString();
        final rua = (s['name'] ?? '').toString();
        final naRua = rua.isEmpty ? '' : ' na $rua';
        String manobra;
        String texto;
        if (tipo == 'arrive') {
          manobra = 'chegada';
          texto = 'Você chegou ao destino';
        } else if (tipo == 'roundabout' || tipo == 'rotary') {
          manobra = 'rotatoria';
          final saida = m['exit'];
          texto = 'Na rotatória, pegue a ${saida ?? ''}ª saída$naRua'
              .replaceAll('a ª', 'a');
        } else if (tipo == 'depart') {
          manobra = 'reto';
          texto = rua.isEmpty ? 'Siga em frente' : 'Siga pela $rua';
        } else {
          manobra = _ladosOsrm[m['modifier']] ?? 'reto';
          texto = switch (manobra) {
            'esquerda' => 'Vire à esquerda$naRua',
            'direita' => 'Vire à direita$naRua',
            'leve_esquerda' => 'Mantenha-se à esquerda$naRua',
            'leve_direita' => 'Mantenha-se à direita$naRua',
            'acentuada_esquerda' => 'Vire acentuadamente à esquerda$naRua',
            'acentuada_direita' => 'Vire acentuadamente à direita$naRua',
            'retorno' => 'Faça o retorno$naRua',
            _ => rua.isEmpty ? 'Siga em frente' : 'Continue pela $rua',
          };
        }
        passos.add(Passo(ponto, texto, manobra));
      }
    }
  } catch (_) {}
  return passos;
}
