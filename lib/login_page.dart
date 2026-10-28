import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cadastro_veiculo.dart';
import 'creditos.dart';

const _azulNoite = Color(0xFF0B2545);
const _azul = Color(0xFF1565C0);
const _amarelo = Color(0xFFFFC24B);
const _texto = Color(0xFF0F172A);
const _textoSuave = Color(0xFF5B6577);
const _campoFundo = Color(0xFFF4F6FA);
const _campoBorda = Color(0xFFE2E8F0);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nome = TextEditingController();
  final _carro = TextEditingController();
  final _cor = TextEditingController();
  final _cpf = TextEditingController();
  final _rg = TextEditingController();
  final _placa = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _cadastro = false;
  bool _carregando = false;
  bool _mostrarSenha = false;
  Uint8List? _cnh;

  @override
  void dispose() {
    _nome.dispose();
    _carro.dispose();
    _cor.dispose();
    _cpf.dispose();
    _rg.dispose();
    _placa.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _salvarPerfil(User user, String nome, {bool temCnh = false}) {
    return FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'nome': nome,
      'email': user.email,
      'carro': _carro.text.trim(),
      'cor': _cor.text.trim(),
      'placa': _placa.text.trim().toUpperCase(),
      'cpf': soDigitos(_cpf.text),
      'rg': _rg.text.trim().toUpperCase(),
      'temCnh': temCnh,
      'role': 'motorista',
      'aprovado': false,
      'criadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _escolherCnh() async {
    final foto = await escolherFotoCnh(context);
    if (foto != null && mounted) setState(() => _cnh = foto);
  }

  /// Encerra a sessão se a conta não for de motorista.
  Future<void> _verificarMotorista(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.data()?['role'] != 'motorista') {
      await FirebaseAuth.instance.signOut();
      _aviso('Esta conta não é de motorista.');
    }
  }

  Future<void> _enviar() async {
    if (_cadastro) {
      final vazio = [_nome, _carro, _cor, _placa]
          .any((c) => c.text.trim().isEmpty);
      if (vazio) {
        _aviso('Preencha nome, modelo, cor e placa do carro.');
        return;
      }
      final erroDoc = erroDocumentos(_cpf.text, _rg.text);
      if (erroDoc != null) {
        _aviso(erroDoc);
        return;
      }
      if (_cnh == null) {
        _aviso('Envie a foto da sua CNH.');
        return;
      }
    }
    setState(() => _carregando = true);
    try {
      final auth = FirebaseAuth.instance;
      if (_cadastro) {
        final cred = await auth.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _senha.text);
        final cnh = _cnh!;
        await salvarCnh(cred.user!.uid, cnh);
        await _salvarPerfil(cred.user!, _nome.text.trim(), temCnh: true);
      } else {
        final cred = await auth.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _senha.text);
        await _verificarMotorista(cred.user!);
      }
    } on FirebaseAuthException catch (e) {
      _aviso(e.message ?? 'Erro ao entrar');
    } catch (e) {
      _aviso('Não foi possível concluir: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _entrarComGoogle() async {
    setState(() => _carregando = true);
    try {
      final cred =
          await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
      final user = cred.user!;
      final doc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (!(await doc.get()).exists) {
        await _salvarPerfil(user, user.displayName ?? '');
      } else {
        await _verificarMotorista(user);
      }
    } on FirebaseAuthException catch (e) {
      _aviso(e.message ?? 'Erro ao entrar com Google');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _esqueciSenha() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _aviso('Digite seu e-mail para recuperar a senha');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _aviso('Enviamos um link de recuperação para $email');
    } on FirebaseAuthException catch (e) {
      _aviso(e.message ?? 'Erro ao enviar e-mail');
    }
  }

  InputDecoration _decoracao(String dica, IconData icone, {Widget? sufixo}) {
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _campoBorda, width: 1.5),
    );
    return InputDecoration(
      hintText: dica,
      hintStyle: const TextStyle(color: Color(0xFF8A94A6)),
      prefixIcon: Icon(icone, color: const Color(0xFF64748B), size: 20),
      suffixIcon: sufixo,
      filled: true,
      fillColor: _campoFundo,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      enabledBorder: borda,
      border: borda,
      focusedBorder: borda.copyWith(
          borderSide: const BorderSide(color: _azul, width: 1.5)),
    );
  }

  Widget _rotulo(String texto, {Widget? acao}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(texto,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155))),
          const Spacer(),
          if (acao != null) acao,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topo = MediaQuery.paddingOf(context).top;
    final alturaHero = 300 + topo;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _azulNoite,
        body: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: alturaHero,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                          child: CustomPaint(painter: _MapaPainter())),
                      Positioned(
                        left: 28,
                        right: 28,
                        top: topo + 130,
                        child: const _Marca(),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                      minHeight: math.max(0.0, c.maxHeight - alturaHero)),
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: _formulario(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulario() {
    final botaoForma =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
                color: _campoBorda, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        const SizedBox(height: 20),
        Text(_cadastro ? 'Seja motorista PiraCar' : 'Bem-vindo de volta',
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: _texto)),
        const SizedBox(height: 4),
        Text(
            _cadastro
                ? 'Seu cadastro passa por aprovação antes da primeira corrida.'
                : 'Entre para começar a receber corridas.',
            style: const TextStyle(fontSize: 15, color: _textoSuave)),
        const SizedBox(height: 20),
        if (_cadastro) ...[
          _rotulo('Nome'),
          TextField(
            controller: _nome,
            textCapitalization: TextCapitalization.words,
            decoration: _decoracao('Seu nome', Icons.person_outline),
          ),
          const SizedBox(height: 16),
          _rotulo('Modelo do carro'),
          TextField(
            controller: _carro,
            textCapitalization: TextCapitalization.sentences,
            decoration:
                _decoracao('Ex.: Onix, HB20', Icons.directions_car_outlined),
          ),
          const SizedBox(height: 16),
          _rotulo('Cor do carro'),
          TextField(
            controller: _cor,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoracao('Ex.: Prata', Icons.palette_outlined),
          ),
          const SizedBox(height: 16),
          _rotulo('Placa'),
          TextField(
            controller: _placa,
            textCapitalization: TextCapitalization.characters,
            decoration: _decoracao('ABC1D23', Icons.pin_outlined),
          ),
          const SizedBox(height: 16),
          _rotulo('CPF'),
          TextField(
            controller: _cpf,
            keyboardType: TextInputType.number,
            decoration: _decoracao('000.000.000-00', Icons.badge_outlined),
          ),
          const SizedBox(height: 16),
          _rotulo('RG'),
          TextField(
            controller: _rg,
            textCapitalization: TextCapitalization.characters,
            decoration: _decoracao('Ex.: MG-12.345.678', Icons.credit_card),
          ),
          const SizedBox(height: 16),
          _rotulo('Foto da CNH'),
          CampoFotoCnh(foto: _cnh, onTap: _escolherCnh),
          const SizedBox(height: 16),
        ],
        _rotulo('E-mail'),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: _decoracao('voce@email.com', Icons.mail_outline),
        ),
        const SizedBox(height: 16),
        _rotulo(
          'Senha',
          acao: _cadastro
              ? null
              : GestureDetector(
                  onTap: _esqueciSenha,
                  child: const Text('Esqueci a senha',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _azul)),
                ),
        ),
        TextField(
          controller: _senha,
          obscureText: !_mostrarSenha,
          autofillHints: const [AutofillHints.password],
          decoration: _decoracao(
            'Sua senha',
            Icons.lock_outline,
            sufixo: IconButton(
              tooltip: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
              icon: Icon(
                  _mostrarSenha
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF64748B),
                  size: 20),
              onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: _carregando ? null : _enviar,
            style: FilledButton.styleFrom(
              backgroundColor: _azul,
              shape: botaoForma,
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: _carregando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_cadastro ? 'Criar conta' : 'Entrar'),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: Divider(color: _campoBorda)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou continue com',
                  style: TextStyle(fontSize: 13, color: _textoSuave)),
            ),
            Expanded(child: Divider(color: _campoBorda)),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: OutlinedButton(
            onPressed: _carregando ? null : _entrarComGoogle,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1F1F1F),
              side: const BorderSide(color: Color(0xFFDADCE0), width: 1.5),
              shape: botaoForma,
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(painter: _GooglePainter())),
                SizedBox(width: 12),
                Text('Entrar com Google'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_cadastro ? 'Já tem conta? ' : 'Ainda não tem conta? ',
                style: const TextStyle(fontSize: 14, color: _textoSuave)),
            GestureDetector(
              onTap: () => setState(() => _cadastro = !_cadastro),
              child: Text(_cadastro ? 'Entrar' : 'Cadastre-se',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _azul)),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Center(child: CreditosRodape()),
      ],
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 20,
                      offset: Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/logo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Pira', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'Car', style: TextStyle(color: _amarelo)),
                ],
              ),
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Motorista',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const SizedBox(
          width: 260,
          child: Text(
            'Dirija com a PiraCar e ganhe no seu ritmo.',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: Color(0xFFC9D6EA)),
          ),
        ),
      ],
    );
  }
}

/// Mapa estilizado do topo: ruas, rio e uma rota tracejada até o destino.
/// Desenhado numa grade de 390x300 e escalado para a largura da tela.
class _MapaPainter extends CustomPainter {
  const _MapaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 390;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, -50 * s);
    canvas.scale(s);

    final ruaLarga = Paint()
      ..color = const Color(0xFF1B3A63)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final ruaFina = Paint()
      ..color = const Color(0xFF163357)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    void rua(Paint p, double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);

    rua(ruaLarga, -20, 60, 410, 40);
    rua(ruaLarga, -20, 150, 410, 175);
    rua(ruaLarga, 70, -400, 95, 460);
    rua(ruaLarga, 250, -400, 230, 460);
    rua(ruaLarga, 330, -400, 360, 460);
    rua(ruaFina, -20, 105, 410, 110);
    rua(ruaFina, 160, -400, 170, 460);
    rua(ruaFina, 20, 230, 410, 215);

    final rio = Path()
      ..moveTo(-30, 260)
      ..cubicTo(60, 210, 120, 290, 210, 245)
      ..cubicTo(300, 200, 340, 205, 420, 250);
    canvas.drawPath(
        rio,
        Paint()
          ..color = const Color(0x8C1E5A9A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.round);

    final rota = Path()
      ..moveTo(95, 150)
      ..cubicTo(140, 160, 165, 120, 170, 105)
      ..cubicTo(175, 90, 225, 60, 248, 60)
      ..lineTo(330, 45);
    final pontilhado = Paint()
      ..color = _amarelo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final m in rota.computeMetrics()) {
      for (double d = 0; d < m.length; d += 11) {
        canvas.drawPath(m.extractPath(d, d + 2), pontilhado);
      }
    }

    canvas.drawCircle(const Offset(95, 150), 9, Paint()..color = _azulNoite);
    canvas.drawCircle(
        const Offset(95, 150),
        9,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    canvas.drawCircle(
        const Offset(330, 45), 16, Paint()..color = const Color(0x40FFC24B));
    canvas.drawCircle(const Offset(330, 45), 8, Paint()..color = _amarelo);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo "G" do Google desenhado em quatro arcos coloridos.
class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final traco = w * 0.2;
    final rect = Rect.fromCircle(
        center: Offset(w / 2, w / 2), radius: (w - traco) / 2);
    Paint cor(int c) => Paint()
      ..color = Color(c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = traco;

    const grau = math.pi / 180;
    canvas.drawArc(rect, -40 * grau, -100 * grau, false, cor(0xFFEA4335));
    canvas.drawArc(rect, -140 * grau, -80 * grau, false, cor(0xFFFBBC05));
    canvas.drawArc(rect, 140 * grau, -95 * grau, false, cor(0xFF34A853));
    canvas.drawArc(rect, 45 * grau, -45 * grau, false, cor(0xFF4285F4));
    canvas.drawRect(
        Rect.fromLTWH(w / 2, w / 2 - traco / 2, w / 2 - traco / 4, traco),
        Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
