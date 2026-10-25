import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

const _chave = String.fromEnvironment('MAPS_KEY');

class Rota {
  final List<LatLng> pontos;
  final int metros;
  final int segundos;
  Rota(this.pontos, this.metros, this.segundos);

  String get resumo {
    final km = (metros / 1000).toStringAsFixed(1);
    final min = (segundos / 60).ceil();
    return '$km km • $min min';
  }
}

Map<String, dynamic> _ponto(LatLng p) => {
      'location': {
        'latLng': {'latitude': p.latitude, 'longitude': p.longitude}
      }
    };

Future<Rota?> buscarRota(LatLng origem, LatLng destino) async {
  try {
    final resp = await http.post(
      Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
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
      }),
    );
    if (resp.statusCode != 200) return null;
    final r = (jsonDecode(resp.body)['routes'] as List).first;
    final seg =
        int.tryParse(r['duration'].toString().replaceAll('s', '')) ?? 0;
    return Rota(
      _decodificar(r['polyline']['encodedPolyline'] as String),
      (r['distanceMeters'] ?? 0) as int,
      seg,
    );
  } catch (_) {
    return null;
  }
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
