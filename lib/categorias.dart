import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'cores.dart';

/// Categorias de corrida do PiraCar.
///
/// Corrida (corridas/{id}.categoria): 'piracar', 'sedan', 'conforto' ou 'moto'.
/// Motorista (users/{uid}.categorias): lista, ex. ['piracar', 'sedan'].
///   Carro: sempre 'piracar' + opcional 'sedan' ou 'conforto'.
///   Moto: só ['moto'].
/// A moto só aparece quando o admin liga config/app.motoAtiva.

class Categoria {
  const Categoria(this.id, this.nome, this.descricao, this.multiplicador);

  final String id;
  final String nome;
  final String descricao;
  final double multiplicador;
}

const catPiracar = Categoria('piracar', 'Uai Car', 'Carro do dia a dia', 1.0);
const catSedan = Categoria('sedan', 'Sedan', 'Mais espaço no porta-malas', 1.2);
const catConforto =
    Categoria('conforto', 'Conforto', 'Carros novos e espaçosos', 1.4);
const catMoto = Categoria('moto', 'Moto', 'Mais rápido e mais barato', 0.7);

const todasCategorias = [catPiracar, catSedan, catConforto, catMoto];

Categoria categoriaPorId(String? id) => todasCategorias.firstWhere(
      (c) => c.id == id,
      orElse: () => catPiracar,
    );

/// Categorias de um motorista (quem é antigo e não tem nada é PiraCar).
List<String> categoriasDoMotorista(Map<String, dynamic>? dados) {
  final l = (dados?['categorias'] as List?)?.whereType<String>().toList();
  return (l == null || l.isEmpty) ? const ['piracar'] : l;
}

/// O motorista pode receber uma corrida desta categoria?
bool motoristaAtende(Map<String, dynamic>? dados, String? categoriaCorrida) =>
    categoriasDoMotorista(dados).contains(categoriaCorrida ?? 'piracar');

/// Texto curto: "Uai Car e Sedan".
String nomesCategorias(Map<String, dynamic>? dados) =>
    categoriasDoMotorista(dados)
        .map((id) => categoriaPorId(id).nome)
        .join(' e ');

/// A moto está ligada pelo admin?
Stream<bool> motoAtiva() => FirebaseFirestore.instance
    .collection('config')
    .doc('app')
    .snapshots()
    .map((s) => s.data()?['motoAtiva'] == true)
    .handleError((_) => false);

/// Desenho do veículo da categoria (de lado).
class DesenhoVeiculo extends StatelessWidget {
  const DesenhoVeiculo(this.categoria, {super.key, this.largura = 96});

  final String categoria;
  final double largura;

  @override
  Widget build(BuildContext context) {
    final id = todasCategorias.any((c) => c.id == categoria)
        ? categoria
        : 'piracar';
    return SizedBox(
      width: largura,
      height: largura * 0.46,
      child: Image.asset(
        'assets/veiculos/$id.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        // sem a imagem, usa o desenho
        errorBuilder: (_, __, ___) =>
            CustomPaint(painter: _VeiculoPainter(categoria)),
      ),
    );
  }
}

class _VeiculoPainter extends CustomPainter {
  const _VeiculoPainter(this.categoria);

  final String categoria;

  @override
  void paint(Canvas canvas, Size size) {
    final largo = categoria == 'sedan' || categoria == 'conforto';
    final vw = largo ? 140.0 : 120.0;
    const vh = 56.0;
    final s = (size.width / vw) < (size.height / vh)
        ? size.width / vw
        : size.height / vh;
    canvas.save();
    canvas.translate((size.width - vw * s) / 2, (size.height - vh * s) / 2);
    canvas.scale(s);

    Paint cor(int c) => Paint()..color = Color(c);
    void roda(double x, double r, int pneu, int aro) {
      canvas.drawCircle(Offset(x, 44), r, cor(pneu));
      canvas.drawCircle(Offset(x, 44), r * 0.45, cor(aro));
    }

    canvas.drawOval(
        Rect.fromCenter(center: Offset(vw / 2, 50), width: vw - 16, height: 8),
        cor(0x1A0F172A));

    switch (categoria) {
      case 'moto':
        Paint linha(int c, double w) => Paint()
          ..color = Color(c)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawCircle(const Offset(26, 42), 12, linha(0xFF1F2937, 6));
        canvas.drawCircle(const Offset(94, 42), 12, linha(0xFF1F2937, 6));
        canvas.drawPath(
            Path()
              ..moveTo(26, 42)
              ..lineTo(48, 24)
              ..lineTo(74, 24)
              ..lineTo(84, 32)
              ..lineTo(94, 42),
            linha(0xFFDC2626, 7));
        canvas.drawLine(
            const Offset(50, 18), const Offset(72, 18), linha(0xFF1F2937, 6));
        canvas.drawPath(
            Path()
              ..moveTo(82, 22)
              ..lineTo(90, 14)
              ..lineTo(98, 14),
            linha(0xFF1F2937, 4));
      case 'sedan':
        canvas.drawPath(
            Path()
              ..moveTo(8, 38)
              ..quadraticBezierTo(8, 31, 18, 30)
              ..lineTo(38, 28)
              ..lineTo(54, 16)
              ..quadraticBezierTo(58, 14, 64, 14)
              ..lineTo(88, 14)
              ..quadraticBezierTo(94, 14, 98, 18)
              ..lineTo(110, 28)
              ..lineTo(128, 30)
              ..quadraticBezierTo(134, 31, 134, 38)
              ..lineTo(134, 44)
              ..lineTo(8, 44)
              ..close(),
            cor(0xFFC7CDD6));
        canvas.drawPath(
            Path()
              ..moveTo(44, 28)
              ..lineTo(56, 18)
              ..lineTo(72, 18)
              ..lineTo(72, 28)
              ..close(),
            cor(0xFFCFE3F5));
        canvas.drawPath(
            Path()
              ..moveTo(76, 18)
              ..lineTo(92, 18)
              ..quadraticBezierTo(95, 18, 97, 21)
              ..lineTo(104, 28)
              ..lineTo(76, 28)
              ..close(),
            cor(0xFFCFE3F5));
        canvas.drawRect(const Rect.fromLTWH(128, 32, 6, 4), cor(0xFFFFF4D6));
        roda(34, 9, 0xFF1F2937, 0xFFE2E8F0);
        roda(110, 9, 0xFF1F2937, 0xFFE2E8F0);
      case 'conforto':
        canvas.drawPath(
            Path()
              ..moveTo(8, 40)
              ..quadraticBezierTo(8, 30, 18, 28)
              ..lineTo(32, 26)
              ..lineTo(44, 10)
              ..quadraticBezierTo(46, 8, 52, 8)
              ..lineTo(100, 8)
              ..quadraticBezierTo(108, 8, 112, 14)
              ..lineTo(120, 26)
              ..quadraticBezierTo(132, 28, 132, 38)
              ..lineTo(132, 44)
              ..lineTo(8, 44)
              ..close(),
            cor(0xFF0E2647));
        canvas.drawPath(
            Path()
              ..moveTo(38, 26)
              ..lineTo(48, 12)
              ..lineTo(74, 12)
              ..lineTo(74, 26)
              ..close(),
            cor(0xFF9FB4CC));
        canvas.drawPath(
            Path()
              ..moveTo(78, 12)
              ..lineTo(102, 12)
              ..quadraticBezierTo(106, 12, 108, 16)
              ..lineTo(114, 26)
              ..lineTo(78, 26)
              ..close(),
            cor(0xFF9FB4CC));
        canvas.drawRect(const Rect.fromLTWH(126, 31, 6, 4), cor(0xFFF5B82E));
        roda(34, 10, 0xFF111827, 0xFF94A3B8);
        roda(106, 10, 0xFF111827, 0xFF94A3B8);
      default:
        canvas.drawPath(
            Path()
              ..moveTo(10, 38)
              ..quadraticBezierTo(10, 30, 20, 28)
              ..lineTo(36, 26)
              ..lineTo(50, 14)
              ..quadraticBezierTo(54, 12, 60, 12)
              ..lineTo(82, 12)
              ..quadraticBezierTo(88, 12, 92, 18)
              ..lineTo(100, 28)
              ..quadraticBezierTo(110, 30, 110, 38)
              ..lineTo(110, 44)
              ..lineTo(10, 44)
              ..close(),
            cor(0xFFF5B82E));
        canvas.drawPath(
            Path()
              ..moveTo(40, 26)
              ..lineTo(52, 16)
              ..lineTo(66, 16)
              ..lineTo(66, 26)
              ..close(),
            cor(0xFFCFE3F5));
        canvas.drawPath(
            Path()
              ..moveTo(70, 16)
              ..lineTo(84, 16)
              ..quadraticBezierTo(87, 16, 89, 20)
              ..lineTo(94, 26)
              ..lineTo(70, 26)
              ..close(),
            cor(0xFFCFE3F5));
        canvas.drawRect(const Rect.fromLTWH(104, 32, 6, 4), cor(0xFFFFF4D6));
        roda(32, 9, 0xFF1F2937, 0xFFCBD5E1);
        roda(88, 9, 0xFF1F2937, 0xFFCBD5E1);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VeiculoPainter old) =>
      old.categoria != categoria;
}

/// Cartão de categoria (desenho, nome, descrição e preço ou marca).
class CartaoCategoria extends StatelessWidget {
  const CartaoCategoria({
    super.key,
    required this.categoria,
    required this.selecionado,
    required this.onTap,
    this.direita,
    this.descricao,
  });

  final Categoria categoria;
  final bool selecionado;
  final VoidCallback? onTap;
  final Widget? direita;
  final String? descricao;

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF1565C0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selecionado ? ta(Color(0xFFF3F8FF)) : sup(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: selecionado ? azul : ln(Color(0xFFE2E8F0)), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
            child: Row(
              children: [
                DesenhoVeiculo(categoria.id, largura: 88),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      categoria.id == 'piracar'
                          ? Text.rich(
                              TextSpan(children: [
                                TextSpan(text: 'Uai '),
                                TextSpan(
                                    text: 'Car',
                                    style:
                                        TextStyle(color: Color(0xFFC98A0B))),
                              ]),
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: tx(Color(0xFF0F172A))),
                            )
                          : Text(categoria.nome,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: tx(Color(0xFF0F172A)))),
                      const SizedBox(height: 2),
                      Text(descricao ?? categoria.descricao,
                          style: TextStyle(
                              fontSize: 13, color: fr(Color(0xFF64748B)))),
                    ],
                  ),
                ),
                if (direita != null) direita!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
