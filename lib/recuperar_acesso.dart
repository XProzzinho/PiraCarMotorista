import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Janela "Recuperar acesso" da tela de login (igual nos três apps).
/// - Senha: envia por e-mail um link para criar uma nova.
/// - E-mail: chama o suporte pelo WhatsApp (só quando [comWhatsApp]).
Future<void> recuperarAcesso(BuildContext context,
    {String emailInicial = '', bool comWhatsApp = true}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _RecuperarAcesso(emailInicial: emailInicial, comWhatsApp: comWhatsApp),
  );
}

class _RecuperarAcesso extends StatefulWidget {
  const _RecuperarAcesso(
      {required this.emailInicial, required this.comWhatsApp});

  final String emailInicial;
  final bool comWhatsApp;

  @override
  State<_RecuperarAcesso> createState() => _RecuperarAcessoState();
}

class _RecuperarAcessoState extends State<_RecuperarAcesso> {
  late final _email = TextEditingController(text: widget.emailInicial);
  bool _enviando = false;
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _ok = false;
        _msg = 'Digite o e-mail do seu cadastro.';
      });
      return;
    }
    setState(() {
      _enviando = true;
      _msg = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _ok = true;
      _msg = 'Enviamos o link para $email. Olhe também o Spam.';
    } on FirebaseAuthException catch (e) {
      _ok = false;
      _msg = e.code == 'user-not-found'
          ? 'Não achamos cadastro com esse e-mail.'
          : (e.code == 'invalid-email'
              ? 'E-mail inválido.'
              : 'Não foi possível enviar: ${e.message ?? e.code}');
    } catch (e) {
      _ok = false;
      _msg = 'Não foi possível enviar: $e';
    }
    if (mounted) setState(() => _enviando = false);
  }

  Future<void> _whatsapp() async {
    final texto = Uri.encodeComponent(
        'Olá! Esqueci o e-mail do meu cadastro no Uai Car. '
        'Pode me ajudar a recuperar? Meu nome e telefone: ');
    final uri = Uri.parse('https://wa.me/5534999116260?text=$texto');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        setState(() {
          _ok = false;
          _msg = 'Não consegui abrir o WhatsApp. Chame (34) 99911-6260.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ok = false;
          _msg = 'Não consegui abrir o WhatsApp. Chame (34) 99911-6260.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recuperar acesso'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Esqueci a senha',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Digite seu e-mail e enviamos um link para criar '
                'uma senha nova.'),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  hintText: 'voce@email.com',
                  prefixIcon: Icon(Icons.mail_outline),
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _enviando ? null : _enviar,
                child: Text(_enviando ? 'Enviando...' : 'Enviar link'),
              ),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 8),
              Text(_msg!,
                  style: TextStyle(
                      color: _ok ? Colors.green : Colors.redAccent,
                      fontWeight: FontWeight.w600)),
            ],
            if (widget.comWhatsApp) ...[
              const Divider(height: 28),
              const Text('Esqueci o e-mail',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Chame o suporte pelo WhatsApp e informe seu nome '
                  'e telefone do cadastro. Nós achamos seu e-mail.'),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _whatsapp,
                  icon: const Icon(Icons.chat),
                  label: const Text('Chamar no WhatsApp'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar')),
      ],
    );
  }
}
