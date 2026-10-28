import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cadastro_etapas.dart';

const _azul = Color(0xFF1565C0);
const _campoFundo = Color(0xFFF4F6FA);
const _campoBorda = Color(0xFFE2E8F0);

String soDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

bool cpfValido(String cpf) {
  final d = soDigitos(cpf).split('').map(int.parse).toList();
  if (d.length != 11 || d.toSet().length == 1) return false;
  int digito(int n) {
    var soma = 0;
    for (var i = 0; i < n; i++) {
      soma += d[i] * (n + 1 - i);
    }
    final r = (soma * 10) % 11;
    return r == 10 ? 0 : r;
  }

  return digito(9) == d[9] && digito(10) == d[10];
}

/// Confere CPF e RG; devolve a mensagem de erro ou null se estiver ok.
String? erroDocumentos(String cpf, String rg) {
  if (!cpfValido(cpf)) return 'CPF inválido. Confira os números.';
  if (rg.trim().length < 5) return 'Digite o número do seu RG.';
  return null;
}

/// Salva a foto da CNH num documento separado (cnh/{uid}), para não pesar
/// as listas de motoristas.
Future<void> salvarCnh(String uid, Uint8List bytes) {
  return FirebaseFirestore.instance.collection('cnh').doc(uid).set({
    'foto': base64Encode(bytes),
    'enviadoEm': FieldValue.serverTimestamp(),
  });
}

/// Quadro para escolher e ver a foto da CNH.
class CampoFotoCnh extends StatelessWidget {
  const CampoFotoCnh({super.key, required this.foto, required this.onTap});

  final Uint8List? foto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: _campoFundo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: foto == null ? _campoBorda : _azul, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: foto == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_outlined, size: 36, color: Color(0xFF64748B)),
                  SizedBox(height: 6),
                  Text('Toque para enviar a foto da CNH',
                      style: TextStyle(color: Color(0xFF5B6577))),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(foto!, fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Trocar foto',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

InputDecoration decoracaoCampo(String dica, IconData icone, {Widget? sufixo}) {
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
    focusedBorder:
        borda.copyWith(borderSide: const BorderSide(color: _azul, width: 1.5)),
  );
}

Widget rotuloCampo(String texto, {Widget? acao}) {
  final rotulo = Text(texto,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)));
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: acao == null
        ? rotulo
        : Row(children: [rotulo, const Spacer(), acao]),
  );
}

/// Tela para o motorista completar os dados do carro e enviar a CNH
/// (aparece para quem se cadastrou antes ou entrou com o Google).
class CompletarCadastroPage extends StatefulWidget {
  const CompletarCadastroPage(
      {super.key, required this.dados, this.editando = false});

  final Map<String, dynamic> dados;

  /// Aberta pelas Configurações: volta depois de salvar.
  final bool editando;

  @override
  State<CompletarCadastroPage> createState() => _CompletarCadastroPageState();
}

class _CompletarCadastroPageState extends State<CompletarCadastroPage> {
  late final _nome = TextEditingController(text: _txt('nome'));
  late final _modelo = TextEditingController(text: _txt('carro'));
  late final _cor = TextEditingController(text: _txt('cor'));
  late final _placa = TextEditingController(text: _txt('placa'));
  late final _cpf = TextEditingController(text: _txt('cpf'));
  late final _rg = TextEditingController(text: _txt('rg'));
  Uint8List? _cnh;
  bool _salvando = false;

  String _txt(String k) => (widget.dados[k] ?? '').toString();
  bool get _jaTemCnh => widget.dados['temCnh'] == true;

  @override
  void dispose() {
    _nome.dispose();
    _modelo.dispose();
    _cor.dispose();
    _placa.dispose();
    _cpf.dispose();
    _rg.dispose();
    super.dispose();
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _escolherCnh() async {
    // até 700 KB: o Firestore aceita até 1 MB por documento
    final foto =
        await escolherFoto(context, titulo: 'Foto da CNH', limiteKb: 700);
    if (foto != null && mounted) setState(() => _cnh = foto);
  }

  Future<void> _salvar() async {
    if ([_nome, _modelo, _cor, _placa].any((c) => c.text.trim().isEmpty)) {
      _aviso('Preencha nome, modelo, cor e placa do carro.');
      return;
    }
    final erroDoc = erroDocumentos(_cpf.text, _rg.text);
    if (erroDoc != null) {
      _aviso(erroDoc);
      return;
    }
    if (_cnh == null && !_jaTemCnh) {
      _aviso('Envie a foto da sua CNH.');
      return;
    }
    setState(() => _salvando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      if (_cnh != null) await salvarCnh(uid, _cnh!);
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'nome': _nome.text.trim(),
        'carro': _modelo.text.trim(),
        'cor': _cor.text.trim(),
        'placa': _placa.text.trim().toUpperCase(),
        'cpf': soDigitos(_cpf.text),
        'rg': _rg.text.trim().toUpperCase(),
        'temCnh': true,
      });
      if (widget.editando && mounted) Navigator.pop(context);
    } catch (e) {
      _aviso('Não foi possível salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editando ? 'Editar dados' : 'Complete seu cadastro'),
        centerTitle: true,
        actions: widget.editando ? null : [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Precisamos dos seus documentos, dos dados do carro e da foto '
              'da CNH para liberar as corridas.',
              style: TextStyle(fontSize: 15, color: Color(0xFF5B6577)),
            ),
            const SizedBox(height: 20),
            rotuloCampo('Nome'),
            TextField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              decoration: decoracaoCampo('Seu nome', Icons.person_outline),
            ),
            const SizedBox(height: 16),
            rotuloCampo('Modelo do carro'),
            TextField(
              controller: _modelo,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoracaoCampo(
                  'Ex.: Onix, HB20', Icons.directions_car_outlined),
            ),
            const SizedBox(height: 16),
            rotuloCampo('Cor do carro'),
            TextField(
              controller: _cor,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  decoracaoCampo('Ex.: Prata', Icons.palette_outlined),
            ),
            const SizedBox(height: 16),
            rotuloCampo('Placa'),
            TextField(
              controller: _placa,
              textCapitalization: TextCapitalization.characters,
              decoration: decoracaoCampo('ABC1D23', Icons.pin_outlined),
            ),
            const SizedBox(height: 16),
            rotuloCampo('CPF'),
            TextField(
              controller: _cpf,
              keyboardType: TextInputType.number,
              decoration: decoracaoCampo('000.000.000-00', Icons.badge_outlined),
            ),
            const SizedBox(height: 16),
            rotuloCampo('RG'),
            TextField(
              controller: _rg,
              textCapitalization: TextCapitalization.characters,
              decoration: decoracaoCampo('Ex.: MG-12.345.678', Icons.credit_card),
            ),
            const SizedBox(height: 16),
            rotuloCampo(_jaTemCnh
                ? 'Foto da CNH (já enviada, toque para trocar)'
                : 'Foto da CNH'),
            CampoFotoCnh(foto: _cnh, onTap: _escolherCnh),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _salvando ? null : _salvar,
                style: FilledButton.styleFrom(
                  backgroundColor: _azul,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Salvar',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
