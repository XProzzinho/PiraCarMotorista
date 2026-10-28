import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final Map<int, BitmapDescriptor> _cache = {};

/// Carrinho visto de cima (frente para cima), com volume (efeito 3D):
/// sombra projetada, rodas aparecendo, lataria com brilho nas bordas,
/// cabine elevada com vidros e teto brilhante. Gira com a direção.
/// [cor] é a cor da carroceria.
Future<BitmapDescriptor> criarCarroDeCima(
    {Color cor = const Color(0xFF1F2937)}) async {
  final pronto = _cache[cor.value];
  if (pronto != null) return pronto;
  const w = 80.0, h = 150.0;
  const cx = w / 2;
  final claro = Color.lerp(cor, Colors.white, 0.45)!;
  final medio = Color.lerp(cor, Colors.white, 0.15)!;
  final escuro = Color.lerp(cor, Colors.black, 0.45)!;
  final gravador = ui.PictureRecorder();
  final c = Canvas(gravador);

  // sombra projetada no chão (deslocada, dá a sensação de altura)
  c.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 16, w - 20, h - 18), const Radius.circular(24)),
    Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
  );

  // rodas (aparecem dos lados)
  final pneu = Paint()..color = const Color(0xFF111111);
  for (final y in [26.0, h - 46]) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(5, y, 9, 24), const Radius.circular(4)),
        pneu);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w - 14, y, 9, 24), const Radius.circular(4)),
        pneu);
  }

  // lataria: degradê das bordas (escuras) para o centro (claro)
  const corpo = Rect.fromLTWH(9, 5, w - 18, h - 12);
  final rCorpo = RRect.fromRectAndRadius(corpo, const Radius.circular(22));
  c.drawRRect(
    rCorpo,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(9, 0),
        const Offset(w - 9, 0),
        [escuro, medio, claro, medio, escuro],
        [0, 0.22, 0.5, 0.78, 1],
      ),
  );
  // brilho de cima para baixo (capô e porta-malas mais claros)
  c.drawRRect(
    rCorpo,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 5),
        const Offset(0, h - 7),
        [
          Colors.white.withOpacity(0.28),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withOpacity(0.25),
        ],
        [0, 0.25, 0.7, 1],
      ),
  );
  // contorno
  c.drawRRect(
    rCorpo,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = escuro,
  );

  // vincos do capô
  final vinco = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = Colors.black.withOpacity(0.22);
  c.drawLine(const Offset(cx - 11, 12), const Offset(cx - 9, 38), vinco);
  c.drawLine(const Offset(cx + 11, 12), const Offset(cx + 9, 38), vinco);

  // retrovisores
  final retro = Paint()..color = escuro;
  c.drawOval(const Rect.fromLTWH(1, 50, 12, 8), retro);
  c.drawOval(const Rect.fromLTWH(w - 13, 50, 12, 8), retro);

  // cabine (parte de vidro, mais estreita: dá a ideia de ser mais alta)
  final cabine = Path()
    ..moveTo(17, 46)
    ..quadraticBezierTo(cx, 36, w - 17, 46)
    ..lineTo(w - 15, 112)
    ..quadraticBezierTo(cx, 120, 15, 112)
    ..close();
  c.drawPath(cabine, Paint()..color = const Color(0xFF0F172A));

  // para-brisa (degradê de reflexo)
  final parabrisa = Path()
    ..moveTo(18, 48)
    ..quadraticBezierTo(cx, 39, w - 18, 48)
    ..lineTo(w - 22, 64)
    ..quadraticBezierTo(cx, 60, 22, 64)
    ..close();
  c.drawPath(
    parabrisa,
    Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 40), const Offset(0, 64),
          [const Color(0xFFBFDBFE), const Color(0xFF3B82F6)]),
  );
  // vidro traseiro
  final traseiro = Path()
    ..moveTo(22, 100)
    ..quadraticBezierTo(cx, 103, w - 22, 100)
    ..lineTo(w - 17, 110)
    ..quadraticBezierTo(cx, 117, 17, 110)
    ..close();
  c.drawPath(
    traseiro,
    Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 100), const Offset(0, 116),
          [const Color(0xFF2563EB), const Color(0xFF93C5FD)]),
  );
  // vidros laterais
  final lateral = Paint()..color = const Color(0xFF60A5FA).withOpacity(0.85);
  c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(17, 68, 5, 28), const Radius.circular(2)),
      lateral);
  c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(w - 22, 68, 5, 28), const Radius.circular(2)),
      lateral);

  // teto (com brilho)
  final teto = RRect.fromRectAndRadius(
      const Rect.fromLTWH(24, 64, w - 48, 36), const Radius.circular(9));
  c.drawRRect(
    teto,
    Paint()
      ..shader = ui.Gradient.linear(const Offset(24, 64),
          const Offset(w - 24, 100), [claro, cor, escuro], [0, 0.55, 1]),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 67, 7, 30), const Radius.circular(4)),
    Paint()..color = Colors.white.withOpacity(0.35),
  );

  // faróis e lanternas
  final farol = Paint()..color = const Color(0xFFFEF3C7);
  c.drawOval(const Rect.fromLTWH(13, 7, 14, 7), farol);
  c.drawOval(const Rect.fromLTWH(w - 27, 7, 14, 7), farol);
  final lanterna = Paint()..color = const Color(0xFFEF4444);
  c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(13, h - 13, 14, 5), const Radius.circular(2)),
      lanterna);
  c.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(w - 27, h - 13, 14, 5), const Radius.circular(2)),
      lanterna);

  final img = await gravador.endRecording().toImage(w.toInt(), h.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  // ignore: deprecated_member_use
  final icone = BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  _cache[cor.value] = icone;
  return icone;
}
