import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cenas animadas do "Como funciona" (este arquivo é igual nos dois apps).
/// Cada cena roda em loop: ~3,6 s de animação, uma pausa e recomeça.
/// Nomes das cenas:
///   passageiro: busca, preco, radar, acompanha, avalia, menu_p
///   motorista:  analise, saldo, online, aceita, busca_m, finaliza, menu_m
class CenaTutorial extends StatefulWidget {
  const CenaTutorial({super.key, required this.nome});

  final String nome;

  @override
  State<CenaTutorial> createState() => _CenaTutorialState();
}

class _CenaTutorialState extends State<CenaTutorial>
    with SingleTickerProviderStateMixin {
  static const _duracao = 4.8; // segundos de cada volta
  late final AnimationController _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_duracao * 1000).round()))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 320 / 290,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * _duracao;
          // some de leve no fim da volta e volta no começo
          final a = _ease(t / .3) * (1 - _ease((t - (_duracao - .35)) / .35));
          return Opacity(
            opacity: a.clamp(0.0, 1.0),
            child: CustomPaint(
              painter: _PintorCena(widget.nome, t),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

// ---------- utilidades ----------
double _cl(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
double _ease(double x) {
  x = _cl(x);
  return 1 - math.pow(1 - x, 3).toDouble();
}

double _back(double x) {
  x = _cl(x);
  const c = 1.9;
  return 1 + (c + 1) * math.pow(x - 1, 3) + c * math.pow(x - 1, 2);
}

double _p(double t, double a, double b) => _ease((t - a) / (b - a));
double _lerp(double a, double b, double k) => a + (b - a) * k;

const _navy = Color(0xFF0B2545);
const _navy2 = Color(0xFF143460);
const _amarelo = Color(0xFFFFC24B);
const _branco = Colors.white;
const _suave = Color(0xFFC9D6EA);
const _azul = Color(0xFF2E86FF);
const _verde = Color(0xFF2ECC71);
const _mapa = Color(0xFFE2E9F3);
const _escuro = Color(0xFF08142A);
const _cinza = Color(0xFF7887A0);
const _vermelho = Color(0xFFF05050);
const _claro = Color(0xFFF4F6FA);

class _PintorCena extends CustomPainter {
  _PintorCena(this.nome, this.t);

  final String nome;
  final double t;
  late Canvas c;

  static const sw = 320.0, sh = 290.0;

  @override
  void paint(Canvas canvas, Size size) {
    c = canvas;
    canvas.save();
    canvas.scale(size.width / sw, size.height / sh);
    switch (nome) {
      case 'busca':
        _busca();
      case 'preco':
        _preco();
      case 'radar':
        _radar();
      case 'acompanha':
        _acompanha();
      case 'avalia':
        _avalia();
      case 'menu_p':
        _menu(['Minhas viagens', 'Adicionar cupom', 'Ajuda', 'Fale conosco',
          'Como funciona'], 'Olá, Ana!');
      case 'analise':
        _analise();
      case 'saldo':
        _saldo();
      case 'online':
        _online();
      case 'aceita':
        _aceita();
      case 'busca_m':
        _buscaMotorista();
      case 'finaliza':
        _finaliza();
      case 'menu_m':
        _menu(['Ganhos de hoje', 'Recarregar saldo', 'Configurações',
          'Termos de Uso', 'Como funciona'], 'Olá, Carlos!');
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorCena old) => old.t != t || old.nome != nome;

  // ---------- desenhos base ----------
  Color _a(Color cor, double a) => cor.withOpacity(_cl(a) * cor.opacity);

  void _card(double x0, double y0, double x1, double y1,
      {double r = 16, Color cor = _branco, double a = 1, Color? borda}) {
    if (a <= 0) return;
    final rr = RRect.fromLTRBR(x0, y0, x1, y1, Radius.circular(r));
    c.drawRRect(rr, Paint()..color = _a(cor, a));
    if (borda != null) {
      c.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _a(borda, a));
    }
  }

  void _texto(double x, double y, String s, double tam, Color cor,
      {double a = 1, FontWeight peso = FontWeight.w400, bool centro = false}) {
    if (a <= 0) return;
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: tam, fontWeight: peso, color: _a(cor, a), height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(centro ? x - tp.width / 2 : x, y));
  }

  void _desenharMapa([double a = 1]) {
    _card(0, 0, sw, sh, r: 24, cor: _mapa, a: a);
    final rua = Paint()..color = _a(_branco, a);
    c.save();
    c.clipRRect(RRect.fromLTRBR(0, 0, sw, sh, const Radius.circular(24)));
    for (final x in [70.0, 170.0, 260.0]) {
      c.drawRect(Rect.fromLTWH(x, 0, 14, sh), rua);
    }
    for (final y in [60.0, 150.0, 230.0]) {
      c.drawRect(Rect.fromLTWH(0, y, sw, 14), rua);
    }
    c.restore();
    _card(184, 164, 256, 226, r: 6, cor: const Color(0xFFCDE6CD), a: a);
  }

  void _carro(double cx, double cy,
      {double ang = 0, Color cor = _escuro, double a = 1, double esc = 1}) {
    if (a <= 0) return;
    final l = 30 * esc, w = 16 * esc;
    c.save();
    c.translate(cx, cy);
    c.rotate(ang);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: l, height: w),
            Radius.circular(4 * esc)),
        Paint()..color = _a(cor, a));
    final vidro = Paint()..color = _a(const Color(0xFFA0C8FF), a);
    c.drawRect(Rect.fromLTRB(l * .12, -w * .36, l * .32, w * .36), vidro);
    c.drawRect(Rect.fromLTRB(-l * .38, -w * .34, -l * .25, w * .34), vidro);
    c.restore();
  }

  void _pessoa(double cx, double cy,
      {Color cor = _azul, double a = 1, double esc = 1}) {
    if (a <= 0) return;
    final p = Paint()..color = _a(cor, a);
    c.drawCircle(Offset(cx, cy - 20 * esc), 7 * esc, p);
    c.drawRRect(
        RRect.fromLTRBR(cx - 11 * esc, cy - 11 * esc, cx + 11 * esc,
            cy + 6 * esc, Radius.circular(8 * esc)),
        p);
  }

  void _pino(double cx, double cy, {double a = 1}) {
    if (a <= 0) return;
    const r = 13.0;
    final p = Paint()..color = _a(_vermelho, a);
    c.drawPath(
        Path()
          ..moveTo(cx - r * .8, cy - r * 1.2)
          ..lineTo(cx + r * .8, cy - r * 1.2)
          ..lineTo(cx, cy)
          ..close(),
        p);
    c.drawCircle(Offset(cx, cy - r * 1.4), r, p);
    c.drawCircle(Offset(cx, cy - r * 1.4), r * .4, Paint()..color = _a(_branco, a));
  }

  /// Desenha a fração [k] do caminho; devolve a ponta e o ângulo.
  (Offset, double) _caminho(List<Offset> pts, double k,
      {Color cor = _azul, double larg = 6, double a = 1}) {
    final seg = <double>[];
    for (var i = 0; i < pts.length - 1; i++) {
      seg.add((pts[i + 1] - pts[i]).distance);
    }
    final tot = seg.fold<double>(0, (s, v) => s + v);
    final alvo = tot * _cl(k);
    var acc = 0.0;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    var ponta = pts[0];
    var ang = 0.0;
    for (var i = 0; i < seg.length; i++) {
      final d = pts[i + 1] - pts[i];
      ang = math.atan2(d.dy, d.dx);
      if (acc + seg[i] >= alvo) {
        final q = seg[i] == 0 ? 0.0 : (alvo - acc) / seg[i];
        ponta = Offset.lerp(pts[i], pts[i + 1], q)!;
        path.lineTo(ponta.dx, ponta.dy);
        break;
      }
      acc += seg[i];
      ponta = pts[i + 1];
      path.lineTo(ponta.dx, ponta.dy);
    }
    if (a > 0) {
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = larg
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = _a(cor, a));
    }
    return (ponta, ang);
  }

  void _pulso(double cx, double cy, double tt, Color cor,
      {double rmax = 60, int n = 3, double a = 1}) {
    for (var k = 0; k < n; k++) {
      final f = (tt * .7 + k / n) % 1;
      c.drawCircle(
          Offset(cx, cy),
          10 + f * rmax,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _a(cor, (1 - f) * .8 * a));
    }
  }

  void _botao(double x0, double y0, double x1, double y1, String s, Color cor,
      Color corTexto,
      {double a = 1, bool aperta = false}) {
    final e = aperta ? 3.0 : 0.0;
    _card(x0 + e, y0 + e, x1 - e, y1 - e, r: (y1 - y0) / 2, cor: cor, a: a);
    _texto((x0 + x1) / 2, (y0 + y1) / 2 - 8, s, 15, corTexto,
        a: a, peso: FontWeight.w600, centro: true);
  }

  void _estrela(double cx, double cy, double r, Color cor, {double a = 1}) {
    if (a <= 0 || r <= 0) return;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * .45;
      final an = -math.pi / 2 + i * math.pi / 5;
      final o = Offset(cx + rr * math.cos(an), cy + rr * math.sin(an));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    path.close();
    c.drawPath(path, Paint()..color = _a(cor, a));
  }

  void _check(double cx, double cy, double r, double k, {double a = 1}) {
    if (a <= 0 || r <= 0) return;
    c.drawCircle(Offset(cx, cy), r, Paint()..color = _a(_verde, a));
    if (k <= 0) return;
    final p0 = Offset(cx - r * .45, cy);
    final p1 = Offset(cx - r * .1, cy + r * .35);
    final p2 = Offset(cx + r * .5, cy - r * .35);
    final path = Path()..moveTo(p0.dx, p0.dy);
    if (k < .4) {
      final e = Offset.lerp(p0, p1, k / .4)!;
      path.lineTo(e.dx, e.dy);
    } else {
      final e = Offset.lerp(p1, p2, (k - .4) / .6)!;
      path
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(e.dx, e.dy);
    }
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .22
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _a(_branco, a));
  }

  void _botaoChat(double x, double y, double a) {
    _card(x, y, x + 38, y + 38, r: 19, cor: _amarelo, a: a);
    _card(x + 10, y + 11, x + 28, y + 25, r: 4, cor: _navy, a: a);
  }

  // ---------- cenas do passageiro ----------
  void _busca() {
    _desenharMapa();
    _pessoa(90, 200);
    _pulso(90, 190, t, _azul, rmax: 30, n: 2);
    final k = _p(t, 0, .5);
    _card(16, 16 - (1 - k) * 20, sw - 16, 62 - (1 - k) * 20, r: 23, a: k);
    const alvo = 'Praça da Matriz';
    final n = (_cl((t - .5) / 1.2) * alvo.length).floor();
    final cursor = n > 0 && n < alvo.length && (t * 3).floor().isOdd ? '|' : '';
    _texto(50, 31 - (1 - k) * 20, n > 0 ? alvo.substring(0, n) + cursor : 'Para onde vamos?',
        15, n > 0 ? _escuro : _cinza,
        a: k, peso: FontWeight.w600);
    c.drawCircle(
        Offset(34, 39 - (1 - k) * 20),
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _a(_cinza, k));
    if (t > 1.8) {
      final q = _back((t - 1.8) / .5);
      if (t > 2.2) {
        _caminho(const [Offset(90, 180), Offset(90, 67), Offset(230, 67), Offset(230, 110)],
            _p(t, 2.2, 3.0),
            larg: 5);
        _pessoa(90, 200);
      }
      _pino(230, 120 - (1 - q) * 70, a: _cl((t - 1.8) * 4));
    }
  }

  void _preco() {
    _card(0, 0, sw, sh, r: 24);
    _texto(sw / 2, 22, 'Valor da corrida', 14, _cinza, centro: true);
    final v = 14.80 * _p(t, .2, 1.4);
    _texto(sw / 2, 42, 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}', 38,
        _escuro,
        peso: FontWeight.bold, centro: true);
    const cats = ['PiraCar', 'Sedan', 'Conforto'];
    final sel = t < 1.6 ? 0 : (t < 2.3 ? 1 : 0);
    for (var i = 0; i < 3; i++) {
      final k = _p(t, .5 + i * .15, .9 + i * .15);
      final x0 = 18.0 + i * 98;
      _card(x0, 108, x0 + 88, 180,
          r: 14,
          cor: i == sel ? const Color(0xFFE8F1FF) : _claro,
          a: k,
          borda: i == sel ? _azul : null);
      _carro(x0 + 44, 134, a: k, esc: .9);
      _texto(x0 + 44, 154, cats[i], 12, _escuro,
          a: k, peso: FontWeight.w600, centro: true);
    }
    const pags = ['Pix', 'Crédito', 'Débito'];
    final psel = t > 1.4 ? [0, 1, 0][(_cl((t - 1.4) / 1.6) * 3).floor() % 3] : 0;
    for (var i = 0; i < 3; i++) {
      final k = _p(t, 1.0 + i * .12, 1.4 + i * .12);
      final x0 = 18.0 + i * 98;
      _card(x0, 198, x0 + 88, 232, r: 17, cor: i == psel ? _amarelo : _claro, a: k);
      _texto(x0 + 44, 208, pags[i], 13, _escuro,
          a: k, peso: FontWeight.w600, centro: true);
    }
    _botao(18, 246, sw - 18, 280, 'Pedir corrida', _navy, _branco,
        a: _p(t, 1.6, 2.0), aperta: t > 2.6 && t < 2.8);
  }

  void _radar() {
    _desenharMapa();
    const cx = 160.0, cy = 150.0;
    _pulso(cx, cy - 10, t, _azul, rmax: 110);
    const carros = [
      [40.0, 40.0, .3],
      [280.0, 60.0, 2.6],
      [260.0, 250.0, 3.5],
      [205.0, 160.0, 3.14],
      [60.0, 260.0, 1.2],
    ];
    for (var i = 0; i < carros.length; i++) {
      final hl = i == 3 && t > 1.5;
      if (hl) _pulso(carros[i][0], carros[i][1], t * 1.4, _amarelo, rmax: 26, n: 2);
      _carro(carros[i][0], carros[i][1],
          ang: carros[i][2], cor: hl ? _amarelo : _escuro);
    }
    _pessoa(cx, cy);
    if (t > 1.5) {
      final k = _p(t, 1.5, 2.2);
      c.drawLine(
          const Offset(cx + 12, cy - 10),
          Offset(_lerp(cx + 12, 190, k), _lerp(cy - 10, 158, k)),
          Paint()
            ..strokeWidth = 3
            ..color = _amarelo);
    }
    final k = _p(t, 2.2, 2.7);
    _card(50, 16 - (1 - k) * 15, sw - 50, 50 - (1 - k) * 15, r: 17, cor: _navy, a: k);
    _texto(sw / 2, 27 - (1 - k) * 15, 'Motorista encontrado!', 13, _amarelo,
        a: k, peso: FontWeight.w600, centro: true);
  }

  void _acompanha() {
    _desenharMapa();
    const rota = [
      Offset(260, 30),
      Offset(260, 67),
      Offset(77, 67),
      Offset(77, 157),
      Offset(140, 157),
    ];
    _caminho(rota, _p(t, .2, 1.2), cor: const Color(0xFF96AAC8));
    _pessoa(150, 170);
    _pulso(150, 160, t, _azul, rmax: 28, n: 2);
    final (ponta, ang) = _caminho(rota, _p(t, 1.0, 3.0) * .93, a: 0);
    _carro(ponta.dx, ponta.dy, ang: ang, cor: _navy);
    final kk = _p(t, .6, 1.1);
    final y0 = sh - 86 + (1 - kk) * 60;
    _card(12, y0, sw - 12, y0 + 74, a: kk);
    c.drawCircle(Offset(47, y0 + 37), 23, Paint()..color = _a(_azul, kk));
    _pessoa(47, y0 + 48, cor: _branco, a: kk, esc: .85);
    _texto(82, y0 + 16, 'João · Onix prata', 14, _escuro,
        a: kk, peso: FontWeight.w600);
    final placa = _p(t, 1.6, 2.0) > 0;
    _card(82, y0 + 38, 172, y0 + 62,
        r: 6, cor: placa ? const Color(0xFFFFF0C8) : const Color(0xFFF0F3F8), a: kk);
    _texto(127, y0 + 43, 'ABC-1D23', 13, _escuro,
        a: kk, peso: FontWeight.bold, centro: true);
    _botaoChat(sw - 64, y0 + 18, kk);
  }

  void _avalia() {
    _card(0, 0, sw, sh, r: 24);
    _check(sw / 2, 52, 28, _p(t, .2, .8), a: _p(t, 0, .3));
    _texto(sw / 2, 92, 'Você chegou!', 20, _escuro,
        a: _p(t, .4, .8), peso: FontWeight.bold, centro: true);
    _texto(sw / 2, 120, 'Pago com Pix · R\$ 14,80', 14, _cinza,
        a: _p(t, .6, 1.0), centro: true);
    for (var i = 0; i < 5; i++) {
      final st = 1.2 + i * .25;
      final q = t > st ? _back((t - st) / .35) : 0.0;
      _estrela(60.0 + i * 50, 185, 18, const Color(0xFFE1E6EE));
      if (q > 0) _estrela(60.0 + i * 50, 185, 18 * (.6 + .4 * q), _amarelo);
    }
    _botao(40, 236, sw - 40, 272, 'Enviar avaliação', _navy, _branco,
        a: _p(t, 2.4, 2.8));
  }

  void _menu(List<String> itens, String ola) {
    _desenharMapa(.6);
    c.drawRRect(RRect.fromLTRBR(0, 0, sw, sh, const Radius.circular(24)),
        Paint()..color = Colors.black.withOpacity(.35 * _p(t, .2, .8)));
    final mx = _lerp(-210, 0, _p(t, .2, 1.0));
    c.save();
    c.clipRRect(RRect.fromLTRBR(0, 0, sw, sh, const Radius.circular(24)));
    _card(mx, 0, mx + 205, sh, r: 22);
    c.drawCircle(Offset(mx + 41, 41), 23, Paint()..color = _azul);
    _pessoa(mx + 41, 50, cor: _branco, esc: .9);
    _texto(mx + 74, 33, ola, 15, _escuro, peso: FontWeight.bold);
    for (var i = 0; i < itens.length; i++) {
      final ka = _p(t, .7 + i * .18, 1.1 + i * .18);
      final yy = 88.0 + i * 38;
      final dx = (1 - ka) * -20;
      final sel = t > 1.9 && ((t - 1.9) / .45).floor() % itens.length == i;
      if (sel) {
        _card(mx + 10, yy - 6, mx + 195, yy + 26,
            r: 12, cor: const Color(0xFFE6F0FF), a: ka);
      }
      c.drawCircle(Offset(mx + 27 + dx, yy + 10), 7,
          Paint()..color = _a(sel ? _amarelo : _azul, ka));
      _texto(mx + 44 + dx, yy + 3, itens[i], 14, _escuro,
          a: ka, peso: FontWeight.w600);
    }
    c.restore();
  }

  // ---------- cenas do motorista ----------
  void _analise() {
    _card(0, 0, sw, sh, r: 24, cor: _navy2);
    const cx = sw / 2, cy = 120.0;
    _pulso(cx, cy, t, _azul, rmax: 80);
    final aprovado = t > 2.2;
    if (!aprovado) {
      _card(cx - 40, cy - 52, cx + 40, cy + 52, r: 10, cor: const Color(0xFFF0F6FF));
      c.drawCircle(const Offset(cx - 17, cy - 29), 11, Paint()..color = _azul);
      const linhas = [
        [2.0, 22.0],
        [2.0, 14.0],
        [-28.0, 54.0],
        [-28.0, 46.0],
        [-28.0, 34.0],
      ];
      for (var j = 0; j < linhas.length; j++) {
        final ly = cy - 38 + j * 13 + (j > 1 ? 10 : 0);
        _card(cx + linhas[j][0], ly, cx + linhas[j][0] + linhas[j][1], ly + 5,
            r: 3, cor: const Color(0xFFB9C8E1));
      }
      final p = (math.sin(t * 3.4) + 1) / 2;
      final yy = cy - 46 + p * 92;
      c.drawLine(
          Offset(cx - 44, yy),
          Offset(cx + 44, yy),
          Paint()
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = _amarelo);
    } else {
      _check(cx, cy, 46 * _back((t - 2.2) / .45), _p(t, 2.4, 2.9));
    }
    _texto(cx, 212, aprovado ? 'Cadastro aprovado!' : 'Documentos e veículo', 16,
        aprovado ? _amarelo : _branco,
        peso: FontWeight.w600, centro: true);
    final pontos = '.' * ((t * 3).floor() % 4);
    _texto(cx, 238, aprovado ? 'Pronto para rodar' : 'Conferindo$pontos', 14,
        _suave,
        centro: true);
  }

  void _saldo() {
    _card(0, 0, sw, sh, r: 24);
    _texto(sw / 2, 22, 'Seu saldo', 14, _cinza, centro: true);
    final v = 20.0 * _p(t, 1.0, 2.0);
    _texto(sw / 2, 42, 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}', 38,
        v > 0 ? _verde : _escuro,
        peso: FontWeight.bold, centro: true);
    const cx = sw / 2, cy = 170.0;
    for (var i = 0; i < 3; i++) {
      final k = _cl((t - (.3 + i * .25)) / .6);
      if (k > 0 && k < 1) {
        final yy = _lerp(100, cy - 10, k * k);
        final o = Offset(cx - 2 + i * 12, yy);
        c.drawCircle(o, 14, Paint()..color = _amarelo);
        c.drawCircle(
            o,
            14,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFDCA01E));
      }
    }
    _card(cx - 70, cy - 30, cx + 70, cy + 50, cor: _navy);
    _card(cx + 30, cy, cx + 76, cy + 26, r: 10, cor: _navy2);
    c.drawCircle(const Offset(cx + 51, cy + 13), 5, Paint()..color = _amarelo);
    final k = _p(t, 1.9, 2.4);
    _card(60, 244, sw - 60, 276, cor: const Color(0xFFE6F8EE), a: k);
    _texto(sw / 2, 254, 'Recarga por Pix liberada', 13, const Color(0xFF1E9650),
        a: k, peso: FontWeight.w600, centro: true);
  }

  void _online() {
    _desenharMapa();
    final on = t > 1.6;
    final k = _p(t, .6, 1.6);
    if (on) _pulso(160, 120, t, _azul);
    _carro(160, 120, cor: _navy, esc: 1.3);
    _card(12, sh - 96, sw - 12, sh - 12, r: 20, cor: _navy);
    _texto(sw / 2, sh - 84, on ? 'Você está online' : 'Você está offline', 16,
        on ? _amarelo : _branco,
        peso: FontWeight.bold, centro: true);
    const bx0 = 26.0, bx1 = sw - 26;
    _card(bx0, sh - 58, bx1, sh - 22,
        r: 18, cor: on ? _azul : const Color(0xFF3C5073));
    if (!on) {
      _texto(sw / 2 + 16, sh - 47, 'Deslize para ficar online', 13, _suave,
          a: 1 - k, peso: FontWeight.w600, centro: true);
    } else {
      _texto(sw / 2 - 16, sh - 47, 'Online', 14, _branco,
          peso: FontWeight.w600, centro: true);
    }
    final kx = _lerp(bx0 + 4, bx1 - 34, k);
    c.drawCircle(Offset(kx + 15, sh - 40), 15, Paint()..color = _branco);
    c.drawPath(
        Path()
          ..moveTo(kx + 12, sh - 46)
          ..lineTo(kx + 18, sh - 40)
          ..lineTo(kx + 12, sh - 34),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _navy);
    final g = _p(t, 2.0, 2.4);
    _card(18, 16, 120, 44, r: 14, a: g);
    c.drawCircle(const Offset(33, 30), 5, Paint()..color = _a(_verde, g));
    _texto(46, 24, 'GPS ligado', 12, _escuro, a: g, peso: FontWeight.w600);
  }

  void _aceita() {
    _desenharMapa(.7);
    final k = _back((t - .2) / .5);
    final sh2 = t > .7 && t < 1.6 ? math.sin(t * 40) * 3 : 0.0;
    final y0 = 36 + (1 - k) * 200;
    final a = _cl(k);
    _card(18 + sh2, y0, sw - 18 + sh2, y0 + 236, r: 20, cor: _navy, a: a);
    _texto(40 + sh2, y0 + 18, 'Nova corrida', 14, _amarelo,
        a: a, peso: FontWeight.w600);
    _texto(40 + sh2, y0 + 42, 'R\$ 14,80', 34, _branco,
        a: a, peso: FontWeight.bold);
    _texto(40 + sh2, y0 + 88, '2,3 km até o passageiro', 13, _suave, a: a);
    _texto(40 + sh2, y0 + 110, 'Destino: Centro · 4,1 km', 13, _suave, a: a);
    final rest = t < 2.5 ? _cl(1 - (t - .7) / 2.0) : .1;
    final o = Offset(sw - 62 + sh2, y0 + 62);
    final anel = Rect.fromCircle(center: o, radius: 26);
    c.drawCircle(
        o,
        26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = _a(const Color(0xFF3C5073), a));
    c.drawArc(
        anel,
        -math.pi / 2,
        2 * math.pi * rest,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = _a(_amarelo, a));
    _texto(o.dx, o.dy - 8, '${math.max(1, (20 * rest).floor())}', 16, _branco,
        a: a, peso: FontWeight.bold, centro: true);
    if (t < 1.6) {
      _pulso(sw / 2, y0 + 188, t * 1.5, _amarelo, rmax: 40, n: 2, a: a);
    }
    final ok = t > 2.5;
    _botao(36 + sh2, y0 + 166, sw - 36 + sh2, y0 + 210, ok ? 'Aceita!' : 'Aceitar',
        ok ? _verde : _amarelo, _navy,
        a: a, aperta: t > 2.3 && t < 2.5);
  }

  void _buscaMotorista() {
    _desenharMapa();
    const rota = [
      Offset(40, 260),
      Offset(40, 157),
      Offset(177, 157),
      Offset(177, 67),
      Offset(240, 67),
    ];
    _caminho(rota, _p(t, 0, .8));
    _pessoa(250, 80);
    _pulso(250, 70, t, _azul, rmax: 26, n: 2);
    final (ponta, ang) = _caminho(rota, _p(t, .6, 2.2) * .95, a: 0);
    _carro(ponta.dx, ponta.dy, ang: ang, cor: _navy);
    final k = _p(t, 2.1, 2.5);
    _botao(30, sh - 56 + (1 - k) * 30, sw - 30, sh - 16 + (1 - k) * 30,
        'Iniciar corrida', _amarelo, _navy,
        a: k, aperta: t > 3.0 && t < 3.2);
    _botaoChat(sw - 56, 16, _p(t, .4, .8));
  }

  void _finaliza() {
    _card(0, 0, sw, sh, r: 24);
    if (t < 1.3) {
      _desenharMapa();
      _carro(_lerp(60, 200, _p(t, 0, 1.0)), 157, cor: _navy);
      c.drawLine(
          const Offset(232, 170),
          const Offset(232, 120),
          Paint()
            ..strokeWidth = 3
            ..color = _escuro);
      c.drawPath(
          Path()
            ..moveTo(232, 120)
            ..lineTo(262, 130)
            ..lineTo(232, 140)
            ..close(),
          Paint()..color = _vermelho);
      _botao(30, sh - 56, sw - 30, sh - 16, 'Finalizar corrida', _vermelho,
          _branco,
          aperta: t > 1.05);
      return;
    }
    final k = _p(t, 1.3, 1.7);
    _texto(sw / 2, 22, 'Receba do passageiro', 14, _cinza, a: k, centro: true);
    _texto(sw / 2, 42, 'R\$ 14,80', 38, _verde,
        a: k, peso: FontWeight.bold, centro: true);
    const pags = ['Pix', 'Crédito', 'Débito'];
    for (var i = 0; i < 3; i++) {
      final kk = _p(t, 1.5 + i * .12, 1.9 + i * .12);
      final x0 = 18.0 + i * 98;
      _card(x0, 104, x0 + 88, 138, r: 17, cor: i == 0 ? _amarelo : _claro, a: kk);
      _texto(x0 + 44, 114, pags[i], 13, _escuro,
          a: kk, peso: FontWeight.w600, centro: true);
    }
    final ka = _p(t, 2.0, 2.3);
    _texto(sw / 2, 162, 'Avalie o passageiro', 14, _escuro,
        a: ka, peso: FontWeight.w600, centro: true);
    for (var i = 0; i < 5; i++) {
      final st = 2.2 + i * .18;
      final q = t > st ? _back((t - st) / .3) : 0.0;
      _estrela(60.0 + i * 50, 215, 18, const Color(0xFFE1E6EE), a: ka);
      if (q > 0) _estrela(60.0 + i * 50, 215, 18 * (.6 + .4 * q), _amarelo);
    }
  }
}
