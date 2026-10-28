import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'foto_trocar.dart';

/// Peças visuais do cadastro em etapas (mesmo visual da tela de entrada).

const corNoite = Color(0xFF0E2647);
const corAzul = Color(0xFF1565C0);
const corAmarelo = Color(0xFFF5B82E);
const corTexto = Color(0xFF0F172A);
const corTextoSuave = Color(0xFF64748B);
const corRotulo = Color(0xFF334155);
const corCampoFundo = Color(0xFFF4F6FA);
const corCampoBorda = Color(0xFFE2E8F0);

/// Tela de uma etapa: topo azul com o mapa, nome PiraCar e barra de
/// progresso; painel branco com título, campos e o botão de baixo.
class EtapaCadastro extends StatelessWidget {
  const EtapaCadastro({
    super.key,
    required this.etapa,
    required this.total,
    required this.nomeEtapa,
    required this.titulo,
    required this.subtitulo,
    required this.campos,
    required this.textoBotao,
    required this.onBotao,
    required this.onVoltar,
    this.selo,
    this.carregando = false,
    this.rodape,
  });

  final int etapa;
  final int total;
  final String nomeEtapa;
  final String titulo;
  final String subtitulo;
  final List<Widget> campos;
  final String textoBotao;
  final VoidCallback onBotao;
  final VoidCallback onVoltar;
  final String? selo;
  final bool carregando;
  final Widget? rodape;

  @override
  Widget build(BuildContext context) {
    final topo = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: corNoite,
        body: Column(
          children: [
            SizedBox(
              height: topo + 200,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: topo + 110,
                    child: ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Colors.white, Colors.transparent],
                        stops: [0, 0.55, 1],
                      ).createShader(r),
                      blendMode: BlendMode.dstIn,
                      child: const CustomPaint(painter: _MapaTopo()),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    top: topo + 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Material(
                            color: const Color(0x24FFFFFF),
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Voltar',
                              onPressed: carregando ? null : onVoltar,
                              icon: const Icon(Icons.arrow_back_ios_new,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text: 'Pira',
                                    style: TextStyle(color: Colors.white)),
                                TextSpan(
                                    text: 'Car',
                                    style: TextStyle(color: corAmarelo)),
                              ]),
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5),
                            ),
                            const Spacer(),
                            if (selo != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0x24FFFFFF),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(selo!,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text('Etapa $etapa de $total',
                                style: const TextStyle(
                                    fontSize: 13,
                                    letterSpacing: 0.3,
                                    color: Color(0xFFC9D6EA))),
                            const Spacer(),
                            Text(nomeEtapa,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: corAmarelo)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: etapa / total),
                            duration: const Duration(milliseconds: 300),
                            builder: (context, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 4,
                              backgroundColor: const Color(0x29FFFFFF),
                              color: corAmarelo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(22, 26, 22, 12),
                          children: [
                            Text(titulo,
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: corTexto)),
                            const SizedBox(height: 4),
                            Text(subtitulo,
                                style: const TextStyle(
                                    fontSize: 15, color: corTextoSuave)),
                            const SizedBox(height: 18),
                            ...campos,
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (rodape != null) ...[
                              rodape!,
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              height: 60,
                              child: FilledButton(
                                onPressed: carregando ? null : onBotao,
                                style: FilledButton.styleFrom(
                                  backgroundColor: corAzul,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  textStyle: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700),
                                ),
                                child: carregando
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.6,
                                            color: Colors.white))
                                    : Text(textoBotao),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rótulo + campo de texto no estilo do cadastro.
class CampoCadastro extends StatelessWidget {
  const CampoCadastro({
    super.key,
    required this.rotulo,
    required this.controle,
    required this.dica,
    required this.icone,
    this.teclado,
    this.maiusculas = TextCapitalization.none,
    this.formatos,
    this.senha = false,
    this.sufixo,
  });

  final String rotulo;
  final TextEditingController controle;
  final String dica;
  final IconData icone;
  final TextInputType? teclado;
  final TextCapitalization maiusculas;
  final List<TextInputFormatter>? formatos;
  final bool senha;
  final Widget? sufixo;

  @override
  Widget build(BuildContext context) {
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: corCampoBorda, width: 2),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: corRotulo)),
          const SizedBox(height: 7),
          TextField(
            controller: controle,
            keyboardType: teclado,
            textCapitalization: maiusculas,
            inputFormatters: formatos,
            obscureText: senha,
            style: const TextStyle(fontSize: 16, color: corTexto),
            decoration: InputDecoration(
              hintText: dica,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              prefixIcon: Icon(icone, color: corTextoSuave, size: 20),
              suffixIcon: sufixo,
              filled: true,
              fillColor: corCampoFundo,
              contentPadding: const EdgeInsets.symmetric(vertical: 17),
              enabledBorder: borda,
              border: borda,
              focusedBorder: borda.copyWith(
                  borderSide: const BorderSide(color: corAzul, width: 2)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dois campos lado a lado.
class LinhaCampos extends StatelessWidget {
  const LinhaCampos(this.a, this.b, {super.key});

  final Widget a;
  final Widget b;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
  }
}

/// Quadro para enviar uma foto de documento ou do carro.
class QuadroFoto extends StatelessWidget {
  const QuadroFoto({
    super.key,
    required this.titulo,
    required this.dica,
    required this.foto,
    required this.onTap,
    this.altura = 180,
  });

  final String titulo;
  final String dica;
  final Uint8List? foto;
  final VoidCallback onTap;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: corCampoFundo,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: altura,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: foto == null ? const Color(0xFFCBD5E1) : corAzul,
                  width: 2),
            ),
            child: foto != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(foto!, fit: BoxFit.cover),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text('Trocar foto',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                            color: Color(0xFFE3EDFA), shape: BoxShape.circle),
                        child: const Icon(Icons.photo_camera_outlined,
                            color: corAzul, size: 28),
                      ),
                      const SizedBox(height: 10),
                      Text(titulo,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: corTexto)),
                      const SizedBox(height: 2),
                      Text(dica,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, color: corTextoSuave)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Círculo grande da foto de perfil, com o botão de câmera.
class CirculoFoto extends StatelessWidget {
  const CirculoFoto({super.key, required this.foto, required this.onTap});

  final Uint8List? foto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 196,
              height: 196,
              decoration: BoxDecoration(
                color: corCampoFundo,
                shape: BoxShape.circle,
                border: Border.all(
                    color: foto == null ? const Color(0xFFCBD5E1) : corAzul,
                    width: 3),
                image: foto == null
                    ? null
                    : DecorationImage(
                        image: MemoryImage(foto!), fit: BoxFit.cover),
              ),
              child: foto == null
                  ? const Icon(Icons.person_outline,
                      size: 90, color: Color(0xFFCBD5E1))
                  : null,
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: corAzul,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Icon(Icons.photo_camera_outlined,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha de dica com o visto azul.
class DicaFoto extends StatelessWidget {
  const DicaFoto(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, size: 18, color: corAzul),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: const TextStyle(fontSize: 14, color: corRotulo)),
          ),
        ],
      ),
    );
  }
}

/// Pergunta câmera ou galeria e devolve a foto reduzida (ou null).
Future<Uint8List?> escolherFoto(
  BuildContext context, {
  required String titulo,
  bool frontal = false,
  double largura = 1280,
  int qualidade = 60,
  int limiteKb = 600,
}) async {
  final origem = await escolherOrigemFoto(context, titulo);
  if (origem == null) return null;

  final picker = ImagePicker();
  var l = largura;
  var q = qualidade;
  for (var tentativa = 0; tentativa < 3; tentativa++) {
    final foto = await picker.pickImage(
      source: origem,
      preferredCameraDevice: frontal ? CameraDevice.front : CameraDevice.rear,
      maxWidth: l,
      maxHeight: l,
      imageQuality: q,
    );
    if (foto == null) return null;
    final bytes = await foto.readAsBytes();
    if (bytes.length <= limiteKb * 1024) return bytes;
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Foto muito grande. Escolha de novo para reduzir.')));
    l *= 0.75;
    q = (q * 0.75).round();
  }
  return null;
}

/// Formata enquanto digita: 000.000.000-00
class FormatoCpf extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final s = StringBuffer();
    for (var i = 0; i < d.length && i < 11; i++) {
      if (i == 3 || i == 6) s.write('.');
      if (i == 9) s.write('-');
      s.write(d[i]);
    }
    final t = s.toString();
    return TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// Formata enquanto digita: DD/MM/AAAA
class FormatoData extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final s = StringBuffer();
    for (var i = 0; i < d.length && i < 8; i++) {
      if (i == 2 || i == 4) s.write('/');
      s.write(d[i]);
    }
    final t = s.toString();
    return TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// Formata enquanto digita: (38) 99999-9999
class FormatoTelefone extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final s = StringBuffer();
    for (var i = 0; i < d.length && i < 11; i++) {
      if (i == 0) s.write('(');
      if (i == 2) s.write(') ');
      if (i == 7 && d.length == 11) s.write('-');
      if (i == 6 && d.length < 11) s.write('-');
      s.write(d[i]);
    }
    final t = s.toString();
    return TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// Confere se DD/MM/AAAA é uma data real.
bool dataValida(String texto, {bool futuro = false}) {
  final d = texto.replaceAll(RegExp(r'\D'), '');
  if (d.length != 8) return false;
  final dia = int.parse(d.substring(0, 2));
  final mes = int.parse(d.substring(2, 4));
  final ano = int.parse(d.substring(4));
  final data = DateTime(ano, mes, dia);
  if (data.day != dia || data.month != mes) return false;
  final hoje = DateTime.now();
  if (futuro) return !data.isBefore(DateTime(hoje.year, hoje.month, hoje.day));
  return data.isBefore(hoje) && ano > 1900;
}

/// Idade em anos completos a partir de DD/MM/AAAA.
int idade(String texto) {
  final d = texto.replaceAll(RegExp(r'\D'), '');
  final nasc = DateTime(int.parse(d.substring(4)), int.parse(d.substring(2, 4)),
      int.parse(d.substring(0, 2)));
  final hoje = DateTime.now();
  var anos = hoje.year - nasc.year;
  if (hoje.month < nasc.month ||
      (hoje.month == nasc.month && hoje.day < nasc.day)) {
    anos--;
  }
  return anos;
}

/// Ruas, rio e rota pontilhada do topo (igual à tela de entrada).
class _MapaTopo extends CustomPainter {
  const _MapaTopo();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 390;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(s);
    final rua = Paint()
      ..color = const Color(0xFF1B3A63)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-20, 22), const Offset(410, 26), rua);
    canvas.drawLine(const Offset(-20, 84), const Offset(410, 98), rua);
    canvas.drawLine(const Offset(85, -20), const Offset(95, 300), rua);
    canvas.drawLine(const Offset(168, -20), const Offset(172, 300), rua);
    canvas.drawLine(const Offset(240, -20), const Offset(236, 300), rua);
    canvas.drawLine(const Offset(352, -20), const Offset(356, 300), rua);

    final rota = Path()
      ..moveTo(120, 70)
      ..quadraticBezierTo(170, 66, 196, 36)
      ..quadraticBezierTo(216, 12, 300, 6);
    final pont = Paint()
      ..color = corAmarelo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    for (final m in rota.computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 2), pont);
      }
    }
    canvas.drawCircle(const Offset(120, 70), 9, Paint()..color = corNoite);
    canvas.drawCircle(
        const Offset(120, 70),
        9,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
