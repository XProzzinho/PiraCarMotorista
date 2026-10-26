import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

const _chave = String.fromEnvironment('MAPS_KEY');

// Motivo da última falha ao buscar a rota (para mostrar na tela).
String erroRota = '';

class Rota {
  final List<LatLng> pontos;
  final int metros;
  final int segundos;
  final bool estimada;
  Rota(this.pontos, this.metros, this.segundos, {this.estimada = false});

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
                'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration',
          },
          body: jsonEncode({
            'origin': _ponto(origem),
            'destination': _ponto(destino),
            'travelMode': 'DRIVE',
            'computeAlternativeRoutes': true,
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
      rotas.add(Rota(
        _decodificar(enc as String),
        ((r['distanceMeters'] ?? 0) as num).toInt(),
        int.tryParse(r['duration'].toString().replaceAll('s', '')) ?? 0,
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
        '?overview=full&geometries=polyline&alternatives=true');
    final resp = await http
        .get(url, headers: {'User-Agent': 'PiraCar'})
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
  while (i < s.length) {
    int b, shift = 0, res = 0;
    do {
      b = s.codeUnitAt(i++) - 63;
      res |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
    shift = 0;
    res = 0;
    do {
      b = s.codeUnitAt(i++) - 63;
      res |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
    pontos.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return pontos;
}
