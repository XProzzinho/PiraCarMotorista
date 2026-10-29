import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'cores.dart';

const _azulNoite = Color(0xFF0B2545);
const _azul = Color(0xFF1E88E5);
const _azulEscuro = Color(0xFF1565C0);

/// Painel "Você está offline": cartão, resumo do dia e barra de deslizar.
class PainelOffline extends StatelessWidget {
  const PainelOffline({
    super.key,
    required this.uid,
    required this.saldo,
    required this.aviso,
    required this.onOnline,
    required this.onLoja,
  });

  final String uid;
  final int saldo;
  final int aviso;
  final VoidCallback onOnline;
  final VoidCallback onLoja;

  @override
  Widget build(BuildContext context) {
    final semTokens = !podeRodar(saldo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CartaoStatus(
          icone: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: amareloPainel,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: amareloPainel.withOpacity(0.3), spreadRadius: 6),
              ],
            ),
            child: const Icon(Icons.power_settings_new,
                color: _azulNoite, size: 34),
          ),
          titulo: 'Você está offline',
          subtitulo: semTokens
              ? 'Saldo no limite. Recarregue para rodar.'
              : 'Pronto pra rodar em Pirapora?',
        ),
        const SizedBox(height: 14),
        if (semTokens)
          SizedBox(
            height: 62,
            child: FilledButton.icon(
              onPressed: onLoja,
              style: FilledButton.styleFrom(
                backgroundColor: amareloPainel,
                foregroundColor: _azulNoite,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Recarregar saldo'),
            ),
          )
        else
          DeslizarOnline(onConcluir: onOnline),
        if (!semTokens && saldo <= aviso)
          TextButton(
            onPressed: onLoja,
            child: Text(saldo <= 0
                ? 'Saldo negativo (${reais(saldo)}), recarregar'
                : 'Saldo baixo, recarregar'),
          ),
      ],
    );
  }
}

/// Ganhos hoje, corridas hoje e saldo.
class ResumoDia extends StatelessWidget {
  const ResumoDia({
    super.key,
    required this.uid,
    required this.saldo,
    required this.aviso,
    required this.onLoja,
  });

  final String uid;
  final int saldo;
  final int aviso;
  final VoidCallback onLoja;

  @override
  Widget build(BuildContext context) {
    return _ResumoHoje(
      uid: uid,
      builder: (corridas, ganhos) => Row(
        children: [
          Expanded(child: _Mini('Ganhos hoje', real(ganhos))),
          const SizedBox(width: 8),
          Expanded(child: _Mini('Corridas hoje', '$corridas')),
          const SizedBox(width: 8),
          Expanded(
            child: _Mini('Saldo', reais(saldo),
                alerta: saldo <= aviso, onTap: onLoja),
          ),
        ],
      ),
    );
  }
}

/// Lê as corridas finalizadas hoje pelo motorista e entrega a quantidade
/// e o total ganho para [builder].
class _ResumoHoje extends StatelessWidget {
  const _ResumoHoje({required this.uid, required this.builder});

  final String uid;
  final Widget Function(int corridas, double ganhos) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('corridas')
          .where('motoristaId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        final hoje = DateTime.now();
        var corridas = 0;
        double ganhos = 0;
        for (final d in snap.data?.docs ?? const []) {
          final c = d.data();
          final t = c['criadoEm'];
          if (c['status'] != 'finalizada' || t is! Timestamp) continue;
          final dt = t.toDate();
          if (dt.year != hoje.year ||
              dt.month != hoje.month ||
              dt.day != hoje.day) continue;
          corridas++;
          final v = c['valor'];
          if (v is num) ganhos += v;
        }
        return builder(corridas, ganhos);
      },
    );
  }
}

/// Cartão azul-escuro com o status (offline/online) do motorista.
class _CartaoStatus extends StatelessWidget {
  const _CartaoStatus(
      {required this.icone, required this.titulo, required this.subtitulo});

  final Widget icone;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          icone,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitulo,
                    style: const TextStyle(
                        color: azulClaroPainel, fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão do menu com os ganhos de hoje (corridas finalizadas hoje).
class GanhosHojeTile extends StatelessWidget {
  const GanhosHojeTile({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return _ResumoHoje(
      uid: uid,
      builder: (_, ganhos) => Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text('Ganhos de hoje',
                  style: TextStyle(color: azulClaroPainel, fontSize: 14)),
            ),
            Text(real(ganhos),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// Painel "Você está online": procurando corridas + botão Ficar offline.
class PainelOnline extends StatelessWidget {
  const PainelOnline({
    super.key,
    required this.uid,
    required this.saldo,
    required this.aviso,
    required this.onOffline,
    required this.onLoja,
  });

  final String uid;
  final int saldo;
  final int aviso;
  final VoidCallback onOffline;
  final VoidCallback onLoja;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CartaoStatus(
          icone: _Pulso(),
          titulo: 'Você está online',
          subtitulo: 'Procurando corridas perto de você...',
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 58,
          child: OutlinedButton.icon(
            onPressed: onOffline,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF8A80),
              side: const BorderSide(color: Color(0xFFFF8A80), width: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40)),
              textStyle:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            icon: const Icon(Icons.power_settings_new),
            label: const Text('Ficar offline'),
          ),
        ),
      ],
    );
  }
}

/// Bolinha verde pulsando, indicando que está procurando corridas.
class _Pulso extends StatefulWidget {
  const _Pulso();

  @override
  State<_Pulso> createState() => _PulsoState();
}

class _PulsoState extends State<_Pulso> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF43A047);
    return SizedBox(
      width: 66,
      height: 66,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 50 + 16 * _a.value,
              height: 50 + 16 * _a.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: verde.withOpacity(0.45 * (1 - _a.value)),
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration:
                  const BoxDecoration(color: verde, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_tethering,
                  color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.rotulo, this.valor, {this.alerta = false, this.onTap});

  final String rotulo;
  final String valor;
  final bool alerta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: alerta ? const Color(0x33FFD23F) : const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 9, 8, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: azulClaroPainel)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: alerta
                            ? amareloPainel
                            : Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra azul: arrastar a bolinha até o fim chama [onConcluir].
class DeslizarOnline extends StatefulWidget {
  const DeslizarOnline({super.key, required this.onConcluir});

  final VoidCallback onConcluir;

  @override
  State<DeslizarOnline> createState() => _DeslizarOnlineState();
}

class _DeslizarOnlineState extends State<DeslizarOnline>
    with SingleTickerProviderStateMixin {
  static const _altura = 62.0;
  static const _bola = 50.0;
  double _x = 0;
  late final AnimationController _volta = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250))
    ..addListener(() => setState(() => _x = _inicioVolta * (1 - _volta.value)));
  double _inicioVolta = 0;

  @override
  void dispose() {
    _volta.dispose();
    super.dispose();
  }

  void _soltar(double max) {
    if (_x >= max * 0.85) {
      HapticFeedback.mediumImpact();
      setState(() => _x = max);
      widget.onConcluir();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _x = 0);
      });
    } else {
      _inicioVolta = _x;
      _volta.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final max = c.maxWidth - _bola - 12;
      final progresso = max <= 0 ? 0.0 : (_x / max).clamp(0.0, 1.0);
      return Container(
        height: _altura,
        decoration: BoxDecoration(
          color: amareloPainel,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
                color: amareloPainel.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 1 - progresso,
              child: const Padding(
                padding: EdgeInsets.only(left: 44),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Deslize para ficar online'),
                      TextSpan(
                          text: '  ›››',
                          style: TextStyle(color: Color(0x990B2545))),
                    ],
                  ),
                  style: TextStyle(
                      color: _azulNoite,
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Positioned(
              left: 6 + _x,
              top: 6,
              child: GestureDetector(
                onHorizontalDragStart: (_) => _volta.stop(),
                onHorizontalDragUpdate: (d) => setState(
                    () => _x = (_x + d.delta.dx).clamp(0.0, max)),
                onHorizontalDragEnd: (_) => _soltar(max),
                child: Container(
                  width: _bola,
                  height: _bola,
                  decoration: BoxDecoration(
                    color: sup(Colors.white),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x33000000), blurRadius: 6)
                    ],
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: _azulNoite, size: 32),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
