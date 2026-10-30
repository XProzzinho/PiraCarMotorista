import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cores.dart';
import 'excluir_conta.dart';

/// Tela "Cadastro em análise" (motorista ainda não aprovado pelo admin).
/// Fundo azul-escuro animado, documento sendo "escaneado", anel girando,
/// ondas pulsando e a linha do tempo: Enviado → Em análise → Aprovado.
class EmAnalisePage extends StatefulWidget {
  const EmAnalisePage({super.key});

  @override
  State<EmAnalisePage> createState() => _EmAnalisePageState();
}

class _EmAnalisePageState extends State<EmAnalisePage>
    with TickerProviderStateMixin {
  // Entrada (toca uma vez) e animação contínua (repete para sempre).
  late final AnimationController _entrada = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..forward();
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(seconds: 12))
    ..repeat();

  static const _verde = Color(0xFF2ECC71);
  static const _azulVivo = Color(0xFF2E86FF);
  static const _vermelho = Color(0xFFFF6B6B);

  @override
  void dispose() {
    _entrada.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// Progresso 0..1 da entrada entre [a] e [b] segundos.
  double _p(double a, double b) {
    final t = _entrada.value * 3.2;
    final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(x);
  }

  /// Aparece deslizando de baixo para cima.
  Widget _surge(double a, double b, Widget filho, {double dy = 24}) {
    final v = _p(a, b);
    return Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, (1 - v) * dy), child: filho),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fundoTopo = escuro ? const Color(0xFF1A1A1A) : const Color(0xFF0E264E);
    final fundoBase = escuro ? const Color(0xFF050505) : const Color(0xFF08142A);
    final destaque = escuro ? Colors.white : _azulVivo;
    final textoFraco = escuro ? const Color(0xFFA3A3A3) : azulClaroPainel;

    return Scaffold(
      backgroundColor: fundoBase,
      body: AnimatedBuilder(
        animation: Listenable.merge([_entrada, _loop]),
        builder: (context, _) {
          final s = _loop.value * 12; // segundos do loop
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [fundoTopo, fundoBase],
              ),
            ),
            child: Stack(
              children: [
                // Brilhos que flutuam no fundo
                Positioned(
                  top: 150,
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: Offset(math.sin(s * 0.8) * 50, 0),
                    child: Center(
                        child: _Brilho(cor: destaque.withOpacity(0.22), tam: 320)),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  right: -60 + math.cos(s * 0.6) * 25,
                  child: _Brilho(cor: amareloPainel.withOpacity(0.10), tam: 260),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _surge(
                                0,
                                .6,
                                Text('Uai Car Motorista',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(.9),
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: 280,
                                height: 280,
                                child: Transform.scale(
                                  scale: Curves.easeOutBack.transform(
                                      (_entrada.value * 3.2 / .8).clamp(0.0, 1.0)),
                                  child: CustomPaint(
                                    painter: _IconeAnalise(
                                      s: s,
                                      destaque: destaque,
                                      fundoDisco: escuro
                                          ? const Color(0xFF262626)
                                          : const Color(0xFF123060),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _surge(
                                .5,
                                1.1,
                                const Text('Cadastro em análise',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 10),
                              _surge(
                                .8,
                                1.4,
                                Text(
                                  'Estamos conferindo seus documentos.\n'
                                  'Você será avisado assim que for aprovado.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: textoFraco,
                                      fontSize: 15,
                                      height: 1.45),
                                ),
                              ),
                              const SizedBox(height: 26),
                              _surge(1.1, 1.8, _linhaDoTempo(s, textoFraco),
                                  dy: 40),
                              const SizedBox(height: 22),
                              _surge(2.2, 2.8, _aviso()),
                              const SizedBox(height: 30),
                              _surge(2.5, 3.1, _botoes()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _linhaDoTempo(double s, Color textoFraco) {
    const cinza = Color(0xFF5A6E91);
    final pulso = (math.sin(s * 5) + 1) / 2;
    final pontos = '.' * ((s * 2.5).floor() % 4);
    final linha1 = _p(1.8, 2.4);

    Widget etapa({
      required Widget bolinha,
      required String titulo,
      required String sub,
      required double aparece,
      bool apagada = false,
    }) {
      return Opacity(
        opacity: aparece,
        child: Row(
          children: [
            SizedBox(width: 44, height: 44, child: Center(child: bolinha)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          color: apagada ? const Color(0xFF8C9CB9) : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          color: apagada ? const Color(0xFF6E7E9B) : textoFraco,
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget ligacao(double cheio) => Padding(
          padding: const EdgeInsets.only(left: 20.5),
          child: Container(
            width: 3,
            height: 26,
            color: cinza,
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
                heightFactor: cheio, child: Container(color: _verde)),
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Column(
        children: [
          etapa(
            aparece: _p(1.4, 1.9),
            titulo: 'Cadastro enviado',
            sub: 'Dados e documentos recebidos',
            bolinha: Container(
              width: 28,
              height: 28,
              decoration:
                  const BoxDecoration(color: _verde, shape: BoxShape.circle),
              child: CustomPaint(painter: _Check(_p(1.6, 2.1))),
            ),
          ),
          ligacao(linha1),
          etapa(
            aparece: _p(1.65, 2.15),
            titulo: 'Em análise$pontos',
            sub: 'Nossa equipe está verificando',
            bolinha: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 34 + pulso * 12,
                  height: 34 + pulso * 12,
                  decoration: BoxDecoration(
                    color: amareloPainel.withOpacity(.28 * (1 - pulso * .6)),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                      color: amareloPainel, shape: BoxShape.circle),
                  child: Center(
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                          color: Color(0xFF08142A), shape: BoxShape.circle),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ligacao(0),
          etapa(
            aparece: _p(1.9, 2.4),
            apagada: true,
            titulo: 'Aprovado',
            sub: 'Fique online e receba corridas',
            bolinha: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cinza, width: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aviso() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: amareloPainel.withOpacity(.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_active, color: amareloPainel, size: 18),
            SizedBox(width: 8),
            Flexible(
              child: Text('Avisaremos você por notificação',
                  style: TextStyle(
                      color: amareloPainel,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  Widget _botoes() => Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(.8), width: 1.5),
                shape: const StadiumBorder(),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              child: const Text('Sair'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () =>
                excluirConta(context, colecoesExtras: ['cnh', 'carros']),
            style: TextButton.styleFrom(
              foregroundColor: _vermelho,
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir minha conta'),
          ),
        ],
      );
}

/// Mancha de luz desfocada do fundo.
class _Brilho extends StatelessWidget {
  const _Brilho({required this.cor, required this.tam});
  final Color cor;
  final double tam;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: tam,
          height: tam,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [cor, cor.withOpacity(0)]),
          ),
        ),
      );
}

/// Ondas, disco, anel girando e documento com a linha de escaneamento.
class _IconeAnalise extends CustomPainter {
  _IconeAnalise(
      {required this.s, required this.destaque, required this.fundoDisco});
  final double s;
  final Color destaque;
  final Color fundoDisco;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // Ondas pulsando
    for (var k = 0; k < 3; k++) {
      final f = ((s * .55) + k / 3) % 1;
      canvas.drawCircle(
        c,
        84 + f * 54,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = destaque.withOpacity((1 - f) * .5),
      );
    }

    // Disco
    canvas.drawCircle(c, 84, Paint()..color = fundoDisco);
    canvas.drawCircle(
      c,
      84,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = destaque.withOpacity(.5),
    );

    // Anel girando (amarelo + azul)
    final ret = Rect.fromCircle(center: c, radius: 96);
    final ang = s * 220 * math.pi / 180;
    final arco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(ret, ang, 100 * math.pi / 180, false,
        arco..color = amareloPainel);
    canvas.drawArc(ret, ang + math.pi, 50 * math.pi / 180, false,
        arco..color = destaque);

    // Documento
    const dw = 66.0, dh = 84.0;
    final doc = Rect.fromCenter(center: c, width: dw, height: dh);
    canvas.drawRRect(RRect.fromRectAndRadius(doc, const Radius.circular(10)),
        Paint()..color = const Color(0xFFF0F6FF));
    canvas.drawCircle(doc.topLeft + const Offset(21, 23), 10,
        Paint()..color = const Color(0xFF2E86FF));
    final traco = Paint()..color = const Color(0xFFB9C8E1);
    void barra(double x, double y, double w) => canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(doc.left + x, doc.top + y, w, 5),
            const Radius.circular(3)),
        traco);
    barra(36, 16, 20);
    barra(36, 27, 14);
    barra(11, 46, 44);
    barra(11, 57, 38);
    barra(11, 68, 28);

    // Linha de escaneamento subindo e descendo
    final p = (math.sin(s * 2.6) + 1) / 2;
    final y = doc.top + 6 + p * (dh - 12);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(doc, const Radius.circular(10)));
    canvas.drawRect(
      Rect.fromLTRB(doc.left, y - 16, doc.right, y),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            amareloPainel.withOpacity(.45),
            amareloPainel.withOpacity(0),
          ],
        ).createShader(Rect.fromLTRB(doc.left, y - 16, doc.right, y)),
    );
    canvas.restore();
    canvas.drawLine(
      Offset(doc.left - 3, y),
      Offset(doc.right + 3, y),
      Paint()
        ..color = amareloPainel
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_IconeAnalise old) =>
      old.s != s || old.destaque != destaque || old.fundoDisco != fundoDisco;
}

/// Check que se desenha aos poucos (0..1).
class _Check extends CustomPainter {
  _Check(this.v);
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    if (v <= 0) return;
    final c = size.center(Offset.zero);
    final a = c + const Offset(-6, 0);
    final b = c + const Offset(-1, 5);
    final d = c + const Offset(7, -5);
    final path = Path()..moveTo(a.dx, a.dy);
    if (v < .4) {
      final e = Offset.lerp(a, b, v / .4)!;
      path.lineTo(e.dx, e.dy);
    } else {
      final e = Offset.lerp(b, d, (v - .4) / .6)!;
      path
        ..lineTo(b.dx, b.dy)
        ..lineTo(e.dx, e.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF08142A),
    );
  }

  @override
  bool shouldRepaint(_Check old) => old.v != v;
}
