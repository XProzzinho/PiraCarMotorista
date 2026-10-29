import 'package:flutter/material.dart';

import 'cores.dart';

/// Painel de baixo que clareia e pulsa enquanto um cliente está chamando.
class PainelChamando extends StatefulWidget {
  const PainelChamando({
    super.key,
    required this.ativo,
    required this.constraints,
    required this.child,
  });

  final bool ativo;
  final BoxConstraints constraints;
  final Widget child;

  @override
  State<PainelChamando> createState() => _PainelChamandoState();
}

class _PainelChamandoState extends State<PainelChamando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    if (widget.ativo) _a.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PainelChamando old) {
    super.didUpdateWidget(old);
    if (widget.ativo && !_a.isAnimating) {
      _a.repeat(reverse: true);
    } else if (!widget.ativo && _a.isAnimating) {
      _a.stop();
      _a.value = 0;
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (context, filho) {
        final t = Curves.easeInOut.transform(_a.value);
        final base = decoracaoPainelAzul;
        final claro1 = escuro ? const Color(0xFF4A4A4A) : const Color(0xFF3B66C4);
        final claro2 = escuro ? const Color(0xFF7A7A7A) : const Color(0xFF6F98E8);
        final c1 = escuro ? const Color(0xFF141414) : azulPainel;
        final c2 = escuro ? const Color(0xFF2A2A2A) : azulPainel2;
        return Container(
          width: double.infinity,
          constraints: widget.constraints,
          decoration: widget.ativo
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(c1, claro1, t * 0.9)!,
                      Color.lerp(c2, claro2, t * 0.9)!,
                    ],
                  ),
                  borderRadius: base.borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Color.lerp(
                          Colors.black38, const Color(0xAAFFD23F), t)!,
                      blurRadius: 14 + 24 * t,
                    ),
                  ],
                )
              : base,
          child: filho,
        );
      },
    );
  }
}

/// Etiqueta amarela "CLIENTE CHAMANDO" que pisca.
class EtiquetaChamando extends StatefulWidget {
  const EtiquetaChamando({super.key});

  @override
  State<EtiquetaChamando> createState() => _EtiquetaChamandoState();
}

class _EtiquetaChamandoState extends State<EtiquetaChamando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.6).animate(_a),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: amareloPainel,
            borderRadius: BorderRadius.circular(99),
          ),
          child: const Text('● CLIENTE CHAMANDO',
              style: TextStyle(
                  color: azulPainel,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4)),
        ),
      ),
    );
  }
}
