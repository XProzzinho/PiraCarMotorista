import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'menu_visual.dart' show barraTela;

/// Versão dos textos aceitos no cadastro (data da última mudança).
const versaoTermos = '2026-10-29';

/// Termos de Uso e Política de Privacidade, lidos de assets/legal/.
/// Para mudar o texto, edite o .md e troque a versaoTermos.
class TermosPage extends StatelessWidget {
  const TermosPage({super.key, required this.privacidade});

  final bool privacidade;

  static void abrir(BuildContext context, {required bool privacidade}) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TermosPage(privacidade: privacidade)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = privacidade ? 'Política de Privacidade' : 'Termos de Uso';
    final arquivo = privacidade ? 'privacidade' : 'termos';
    return Scaffold(
      appBar: barraTela(titulo),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/legal/$arquivo.md'),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Não foi possível abrir o texto.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: _Markdown(snap.data!),
          );
        },
      ),
    );
  }
}

/// Mostra o markdown simples dos textos: títulos, parágrafos, listas
/// (com subitens), tabelas, **negrito** e [links](url) (só o texto).
class _Markdown extends StatelessWidget {
  const _Markdown(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.onSurface;
    final base = TextStyle(fontSize: 15, height: 1.45, color: cor);
    final blocos = <Widget>[];
    final linhas = texto.split('\n');
    var i = 0;
    while (i < linhas.length) {
      final l = linhas[i];
      final t = l.trim();
      if (t.isEmpty) {
        i++;
        continue;
      }
      if (t.startsWith('# ')) {
        blocos.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(t.substring(2),
              style: base.copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
        ));
        i++;
      } else if (t.startsWith('## ')) {
        blocos.add(Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(t.substring(3),
              style: base.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
        ));
        i++;
      } else if (t.startsWith('|')) {
        final linhasTabela = <List<String>>[];
        while (i < linhas.length && linhas[i].trim().startsWith('|')) {
          final c = linhas[i].trim();
          if (!RegExp(r'^\|[\s\-:|]+\|$').hasMatch(c)) {
            linhasTabela.add(c
                .substring(1, c.length - 1)
                .split('|')
                .map((s) => s.trim())
                .toList());
          }
          i++;
        }
        blocos.add(_tabela(linhasTabela, base));
      } else if (t.startsWith('- ')) {
        while (i < linhas.length && linhas[i].trim().startsWith('- ')) {
          final recuo = linhas[i].length - linhas[i].trimLeft().length;
          blocos.add(Padding(
            padding: EdgeInsets.only(left: recuo > 0 ? 22 : 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recuo > 0 ? '◦  ' : '•  ', style: base),
                Expanded(
                    child: _rico(linhas[i].trim().substring(2), base)),
              ],
            ),
          ));
          i++;
        }
        blocos.add(const SizedBox(height: 6));
      } else {
        blocos.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _rico(t, base),
        ));
        i++;
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: blocos);
  }

  Widget _tabela(List<List<String>> linhas, TextStyle base) {
    if (linhas.isEmpty) return const SizedBox.shrink();
    final colunas = linhas.first.length;
    final borda = base.color!.withOpacity(0.15);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Table(
        border: TableBorder.all(color: borda),
        columnWidths: {
          for (var c = 0; c < colunas; c++)
            c: c == 0 ? const FlexColumnWidth(1.4) : const FlexColumnWidth(1)
        },
        children: [
          for (var r = 0; r < linhas.length; r++)
            TableRow(
              decoration: r == 0 ? BoxDecoration(color: borda) : null,
              children: [
                for (var c = 0; c < colunas; c++)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: _rico(
                        c < linhas[r].length ? linhas[r][c] : '',
                        base.copyWith(
                            fontSize: 12.5,
                            fontWeight:
                                r == 0 ? FontWeight.w700 : FontWeight.w400)),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // **negrito** e [texto](link) -> texto
  Widget _rico(String s, TextStyle base) {
    s = s.replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!);
    final partes = s.split('**');
    return Text.rich(TextSpan(
      style: base,
      children: [
        for (var k = 0; k < partes.length; k++)
          TextSpan(
              text: partes[k],
              style: k.isOdd
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : null),
      ],
    ));
  }
}

/// "Termos de Uso · Política de Privacidade", para o rodapé do menu.
class LinksTermos extends StatelessWidget {
  const LinksTermos({super.key, required this.cor});

  final Color cor;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cor,
        decoration: TextDecoration.underline,
        decorationColor: cor);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => TermosPage.abrir(context, privacidade: false),
          child: Text('Termos de Uso', style: estilo),
        ),
        Text('·', style: TextStyle(color: cor)),
        TextButton(
          onPressed: () => TermosPage.abrir(context, privacidade: true),
          child: Text('Política de Privacidade', style: estilo),
        ),
      ],
    );
  }
}

/// Caixa "Li e aceito os Termos de Uso e a Política de Privacidade",
/// obrigatória para criar a conta.
class AceiteTermos extends StatefulWidget {
  const AceiteTermos(
      {super.key, required this.aceito, required this.onChanged});

  final bool aceito;
  final ValueChanged<bool> onChanged;

  @override
  State<AceiteTermos> createState() => _AceiteTermosState();
}

class _AceiteTermosState extends State<AceiteTermos> {
  late final _termos = TapGestureRecognizer()
    ..onTap = () => TermosPage.abrir(context, privacidade: false);
  late final _privacidade = TapGestureRecognizer()
    ..onTap = () => TermosPage.abrir(context, privacidade: true);

  @override
  void dispose() {
    _termos.dispose();
    _privacidade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.onSurface;
    const link = TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF1565C0),
        decoration: TextDecoration.underline);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: widget.aceito,
          onChanged: (v) => widget.onChanged(v ?? false),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 13.5, height: 1.35, color: cor),
              children: [
                const TextSpan(text: 'Li e aceito os '),
                TextSpan(
                    text: 'Termos de Uso', style: link, recognizer: _termos),
                const TextSpan(text: ' e a '),
                TextSpan(
                    text: 'Política de Privacidade',
                    style: link,
                    recognizer: _privacidade),
                const TextSpan(text: ' do Uai Car.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Antes de entrar no app, quem ainda não aceitou a versão atual dos
/// termos (contas antigas, ou depois de uma mudança no texto) precisa
/// aceitar.
class PortaoTermos extends StatelessWidget {
  const PortaoTermos({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return child;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final dados = snap.data!.data();
        // conta ainda sendo criada (o cadastro já grava o aceite)
        if (dados == null || dados['termosVersao'] == versaoTermos) {
          return child;
        }
        return AceitarTermosPage(uid: uid);
      },
    );
  }
}

class AceitarTermosPage extends StatefulWidget {
  const AceitarTermosPage({super.key, required this.uid});

  final String uid;

  @override
  State<AceitarTermosPage> createState() => _AceitarTermosPageState();
}

class _AceitarTermosPageState extends State<AceitarTermosPage> {
  bool _aceito = false;
  bool _salvando = false;

  Future<void> _continuar() async {
    setState(() => _salvando = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({
        'termosAceitosEm': FieldValue.serverTimestamp(),
        'termosVersao': versaoTermos,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $e')));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _botaoLer(String texto, bool privacidade) {
    return OutlinedButton.icon(
      onPressed: () => TermosPage.abrir(context, privacidade: privacidade),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
      ),
      icon: const Icon(Icons.description_outlined),
      label: Text(texto),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: Color(0xFFFFC24B),
                child: Icon(Icons.verified_user_outlined,
                    size: 46, color: Color(0xFF0B2545)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Termos de Uso e Privacidade',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: cor)),
            const SizedBox(height: 10),
            Text(
              'Para continuar usando o Uai Car, leia e aceite os Termos de '
              'Uso e a Política de Privacidade.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15.5, height: 1.4, color: cor.withOpacity(0.75)),
            ),
            const SizedBox(height: 28),
            _botaoLer('Ler os Termos de Uso', false),
            const SizedBox(height: 12),
            _botaoLer('Ler a Política de Privacidade', true),
            const SizedBox(height: 20),
            AceiteTermos(
              aceito: _aceito,
              onChanged: (v) => setState(() => _aceito = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _aceito && !_salvando ? _continuar : null,
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                child: Text(_salvando ? 'Salvando...' : 'Aceitar e continuar'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
