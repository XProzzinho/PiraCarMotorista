import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final Map<int, BitmapDescriptor> _cache = {};

/// Carrinho visto de cima (frente para cima), para girar com a direção.
/// [cor] é a cor da carroceria.
Future<BitmapDescriptor> criarCarroDeCima(
    {Color cor = const Color(0xFF1F2937)}) async {
  final pronto = _cache[cor.value];
  if (pronto != null) return pronto;
  const w = 64.0, h = 124.0;
  final claro = Color.lerp(cor, Colors.white, 0.18)!;
  final escuro = Color.lerp(cor, Colors.black, 0.25)!;
  final gravador = ui.PictureRecorder();
  final c = Canvas(gravador);
  // sombra
  c.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 12, w - 14, h - 14), const Radius.circular(18)),
    Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
  );
  // retrovisores
  final retro = Paint()..color = escuro;
  c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(1, 40, 10, 7), const Radius.circular(3)),
      retro);
  c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(w - 11, 40, 10, 7), const Radius.circular(3)),
      retro);
  // carroceria
  c.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 4, w - 14, h - 10), const Radius.circular(18)),
    Paint()
      ..shader = ui.Gradient.linear(const Offset(7, 0), const Offset(w - 7, 0),
          [cor, claro, cor], [0, 0.5, 1]),
  );
  // para-brisa e vidro traseiro
  final vidro = Paint()..color = const Color(0xFF93C5FD);
  c.drawPath(
      Path()
        ..moveTo(14, 42)
        ..lineTo(w - 14, 42)
        ..lineTo(w - 18, 30)
        ..quadraticBezierTo(w / 2, 24, 18, 30)
        ..close(),
      vidro);
  c.drawPath(
      Path()
        ..moveTo(16, 90)
        ..lineTo(w - 16, 90)
        ..lineTo(w - 19, 99)
        ..quadraticBezierTo(w / 2, 103, 19, 99)
        ..close(),
      vidro);
  // teto
  c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(15, 44, w - 30, 44), const Radius.circular(8)),
      Paint()..color = Color.lerp(cor, Colors.white, 0.3)!);
  // faróis e lanternas
  final farol = Paint()..color = const Color(0xFFFDE68A);
  c.drawOval(const Rect.fromLTWH(12, 6, 11, 6), farol);
  c.drawOval(const Rect.fromLTWH(w - 23, 6, 11, 6), farol);
  final lanterna = Paint()..color = const Color(0xFFEF4444);
  c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(12, h - 12, 11, 4), const Radius.circular(2)),
      lanterna);
  c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(w - 23, h - 12, 11, 4), const Radius.circular(2)),
      lanterna);
  final img = await gravador.endRecording().toImage(w.toInt(), h.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  // ignore: deprecated_member_use
  final icone = BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  _cache[cor.value] = icone;
  return icone;
}
