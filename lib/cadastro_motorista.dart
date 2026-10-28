import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cadastro_etapas.dart';
import 'cadastro_veiculo.dart';
import 'categorias.dart';

/// Cadastro do motorista em etapas:
/// 1 Dados pessoais, 2 CNH, 3 Carro, 4 Foto de perfil, 5 E-mail e senha.
class CadastroMotoristaPage extends StatefulWidget {
  const CadastroMotoristaPage({super.key, this.email = ''});

  final String email;

  @override
  State<CadastroMotoristaPage> createState() => _CadastroMotoristaPageState();
}

class _CadastroMotoristaPageState extends State<CadastroMotoristaPage> {
  static const _total = 5;
  int _etapa = 1;
  bool _carregando = false;
  bool _verSenha = false;

  // categoria extra do carro ('sedan' ou 'conforto'); null = só PiraCar
  String? _extra;
  bool _ehMoto = false;
  bool _motoAtiva = false;
  StreamSubscription<bool>? _subMoto;

  List<String> get _categorias =>
      _ehMoto ? const ['moto'] : ['piracar', if (_extra != null) _extra!];

  @override
  void initState() {
    super.initState();
    _subMoto = motoAtiva().listen((v) {
      if (!mounted) return;
      setState(() {
        _motoAtiva = v;
        if (!v) _ehMoto = false;
      });
    });
  }

  final _nome = TextEditingController();
  final _cpf = TextEditingController();
  final _rg = TextEditingController();
  final _nascimento = TextEditingController();
  final _telefone = TextEditingController();
  final _cnhNumero = TextEditingController();
  final _cnhValidade = TextEditingController();
  final _modelo = TextEditingController();
  final _cor = TextEditingController();
  final _ano = TextEditingController();
  final _placa = TextEditingController();
  late final _email = TextEditingController(text: widget.email);
  final _senha = TextEditingController();
  final _senha2 = TextEditingController();

  Uint8List? _fotoCnh;
  Uint8List? _fotoCarro;
  Uint8List? _selfie;

  @override
  void dispose() {
    _subMoto?.cancel();
    for (final c in [
      _nome, _cpf, _rg, _nascimento, _telefone, _cnhNumero, _cnhValidade,
      _modelo, _cor, _ano, _placa, _email, _senha, _senha2,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _aviso(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  String? _erroDaEtapa() {
    switch (_etapa) {
      case 1:
        if (_nome.text.trim().split(RegExp(r'\s+')).length < 2) {
          return 'Digite seu nome completo.';
        }
        final erroDoc = erroDocumentos(_cpf.text, _rg.text);
        if (erroDoc != null) return erroDoc;
        if (!dataValida(_nascimento.text)) {
          return 'Data de nascimento inválida. Use DD/MM/AAAA.';
        }
        if (idade(_nascimento.text) < 18) {
          return 'Para dirigir no PiraCar é preciso ter 18 anos ou mais.';
        }
        if (soDigitos(_telefone.text).length < 10) {
          return 'Digite o telefone com DDD.';
        }
        return null;
      case 2:
        if (soDigitos(_cnhNumero.text).length < 9) {
          return 'Digite o número da CNH.';
        }
        if (!dataValida(_cnhValidade.text, futuro: true)) {
          return 'A validade da CNH está errada ou vencida.';
        }
        if (_fotoCnh == null) return 'Envie a foto da CNH.';
        return null;
      case 3:
        if ([_modelo, _cor, _placa].any((c) => c.text.trim().isEmpty)) {
          return 'Preencha modelo, cor e placa.';
        }
        final ano = int.tryParse(_ano.text.trim());
        if (ano == null || ano < 1980 || ano > DateTime.now().year + 1) {
          return 'Digite o ano do carro.';
        }
        if (_placa.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length != 7) {
          return 'A placa tem 7 letras e números (ex.: ABC1D23).';
        }
        return null;
      case 4:
        if (_selfie == null) return 'Tire uma selfie para o seu perfil.';
        return null;
      default:
        if (!_email.text.contains('@')) return 'Digite um e-mail válido.';
        if (_senha.text.length < 6) {
          return 'A senha precisa ter pelo menos 6 caracteres.';
        }
        if (_senha.text != _senha2.text) return 'As senhas não são iguais.';
        return null;
    }
  }

  void _avancar() {
    FocusScope.of(context).unfocus();
    final erro = _erroDaEtapa();
    if (erro != null) {
      _aviso(erro);
      return;
    }
    if (_etapa < _total) {
      setState(() => _etapa++);
    } else {
      _criarConta();
    }
  }

  void _voltar() {
    FocusScope.of(context).unfocus();
    if (_etapa > 1) {
      setState(() => _etapa--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _criarConta() async {
    setState(() => _carregando = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _senha.text);
      final user = cred.user!;
      final db = FirebaseFirestore.instance;
      await salvarCnh(user.uid, _fotoCnh!);
      var temFotoCarro = false;
      if (_fotoCarro != null) {
        try {
          await db.collection('carros').doc(user.uid).set({
            'foto': base64Encode(_fotoCarro!),
            'enviadoEm': FieldValue.serverTimestamp(),
          });
          temFotoCarro = true;
        } catch (_) {
          // sem permissão ainda: o cadastro segue sem a foto do carro
        }
      }
      await db.collection('users').doc(user.uid).set({
        'nome': _nome.text.trim(),
        'email': user.email,
        'cpf': soDigitos(_cpf.text),
        'rg': _rg.text.trim().toUpperCase(),
        'nascimento': _nascimento.text.trim(),
        'telefone': soDigitos(_telefone.text),
        'cnhNumero': soDigitos(_cnhNumero.text),
        'cnhValidade': _cnhValidade.text.trim(),
        'carro': _modelo.text.trim(),
        'cor': _cor.text.trim(),
        'ano': _ano.text.trim(),
        'placa': _placa.text
            .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
            .toUpperCase(),
        'foto': base64Encode(_selfie!),
        'temCnh': true,
        'temFotoCarro': temFotoCarro,
        'categorias': _categorias,
        'role': 'motorista',
        'aprovado': false,
        'criadoEm': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      _aviso(switch (e.code) {
        'email-already-in-use' => 'Esse e-mail já tem conta. Volte e entre.',
        'invalid-email' => 'E-mail inválido.',
        'weak-password' => 'Senha fraca. Use pelo menos 6 caracteres.',
        _ => e.message ?? 'Não foi possível criar a conta.',
      });
    } catch (e) {
      _aviso('Não foi possível concluir o cadastro: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _etapa == 1 && !_carregando,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu && !_carregando) _voltar();
      },
      child: switch (_etapa) {
        1 => _dados(),
        2 => _cnh(),
        3 => _carro(),
        4 => _foto(),
        _ => _acesso(),
      },
    );
  }

  EtapaCadastro _base({
    required String nomeEtapa,
    required String titulo,
    required String subtitulo,
    required List<Widget> campos,
    String botao = 'Próxima etapa',
    Widget? rodape,
  }) {
    return EtapaCadastro(
      key: ValueKey(_etapa),
      etapa: _etapa,
      total: _total,
      selo: 'Motorista',
      nomeEtapa: nomeEtapa,
      titulo: titulo,
      subtitulo: subtitulo,
      campos: campos,
      textoBotao: botao,
      onBotao: _avancar,
      onVoltar: _voltar,
      carregando: _carregando,
      rodape: rodape,
    );
  }

  Widget _dados() => _base(
        nomeEtapa: 'Dados pessoais',
        titulo: 'Seus dados',
        subtitulo: 'Igual estão no seu documento.',
        campos: [
          CampoCadastro(
            rotulo: 'Nome completo',
            controle: _nome,
            dica: 'Seu nome completo',
            icone: Icons.person_outline,
            maiusculas: TextCapitalization.words,
          ),
          CampoCadastro(
            rotulo: 'CPF',
            controle: _cpf,
            dica: '000.000.000-00',
            icone: Icons.badge_outlined,
            teclado: TextInputType.number,
            formatos: [FormatoCpf()],
          ),
          CampoCadastro(
            rotulo: 'RG',
            controle: _rg,
            dica: 'Número do RG',
            icone: Icons.credit_card,
            maiusculas: TextCapitalization.characters,
          ),
          LinhaCampos(
            CampoCadastro(
              rotulo: 'Nascimento',
              controle: _nascimento,
              dica: 'DD/MM/AAAA',
              icone: Icons.calendar_today_outlined,
              teclado: TextInputType.number,
              formatos: [FormatoData()],
            ),
            CampoCadastro(
              rotulo: 'Telefone',
              controle: _telefone,
              dica: '(38) 99999-9999',
              icone: Icons.phone_outlined,
              teclado: TextInputType.phone,
              formatos: [FormatoTelefone()],
            ),
          ),
        ],
      );

  Widget _cnh() => _base(
        nomeEtapa: 'Documentos',
        titulo: 'Sua CNH',
        subtitulo: 'A gente confere para deixar todo mundo seguro.',
        campos: [
          CampoCadastro(
            rotulo: 'Número da CNH',
            controle: _cnhNumero,
            dica: 'Número do registro',
            icone: Icons.badge_outlined,
            teclado: TextInputType.number,
            formatos: [FilteringTextInputFormatter.digitsOnly],
          ),
          CampoCadastro(
            rotulo: 'Validade',
            controle: _cnhValidade,
            dica: 'DD/MM/AAAA',
            icone: Icons.event_outlined,
            teclado: TextInputType.number,
            formatos: [FormatoData()],
          ),
          QuadroFoto(
            titulo: 'Foto da CNH',
            dica: 'Toque para tirar ou escolher da galeria',
            foto: _fotoCnh,
            onTap: () async {
              final f = await escolherFoto(context,
                  titulo: 'Foto da CNH', limiteKb: 600);
              if (f != null && mounted) setState(() => _fotoCnh = f);
            },
          ),
        ],
      );

  Widget _carro() => _base(
        nomeEtapa: 'Carro',
        titulo: 'Seu carro',
        subtitulo: 'É assim que o passageiro vai achar você.',
        campos: [
          CampoCadastro(
            rotulo: 'Modelo',
            controle: _modelo,
            dica: 'Ex.: Fiat Uno',
            icone: Icons.directions_car_outlined,
            maiusculas: TextCapitalization.words,
          ),
          LinhaCampos(
            CampoCadastro(
              rotulo: 'Cor',
              controle: _cor,
              dica: 'Branco',
              icone: Icons.palette_outlined,
              maiusculas: TextCapitalization.sentences,
            ),
            CampoCadastro(
              rotulo: 'Ano',
              controle: _ano,
              dica: '2015',
              icone: Icons.calendar_today_outlined,
              teclado: TextInputType.number,
              formatos: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
            ),
          ),
          CampoCadastro(
            rotulo: 'Placa',
            controle: _placa,
            dica: 'ABC1D23',
            icone: Icons.pin_outlined,
            maiusculas: TextCapitalization.characters,
            formatos: [LengthLimitingTextInputFormatter(8)],
          ),
          const SizedBox(height: 6),
          const Text('Em quais categorias você roda?',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: corTexto)),
          const SizedBox(height: 4),
          const Text(
              'O PiraCar já vem marcado. Se o seu carro for sedan ou '
              'confortável, marque mais uma (é opcional).',
              style: TextStyle(fontSize: 14, color: corTextoSuave)),
          const SizedBox(height: 12),
          CartaoCategoria(
            categoria: catPiracar,
            selecionado: !_ehMoto,
            descricao: 'Sempre ativa para carros',
            onTap: _ehMoto ? () => setState(() => _ehMoto = false) : null,
            direita: _marca(!_ehMoto, quadrada: true),
          ),
          for (final c in [catSedan, catConforto])
            CartaoCategoria(
              categoria: c,
              selecionado: !_ehMoto && _extra == c.id,
              descricao: c.id == 'sedan'
                  ? 'Carro com porta-malas'
                  : 'Carro novo, SUV ou mais espaçoso',
              onTap: () => setState(() {
                _ehMoto = false;
                _extra = _extra == c.id ? null : c.id;
              }),
              direita: _marca(!_ehMoto && _extra == c.id),
            ),
          if (_motoAtiva)
            CartaoCategoria(
              categoria: catMoto,
              selecionado: _ehMoto,
              descricao: 'Rodo de moto (no lugar do carro)',
              onTap: () => setState(() => _ehMoto = !_ehMoto),
              direita: _marca(_ehMoto),
            ),
          const SizedBox(height: 8),
          QuadroFoto(
            titulo: _ehMoto ? 'Foto da moto' : 'Foto do carro',
            dica: 'De lado, com a placa aparecendo (opcional)',
            foto: _fotoCarro,
            altura: 130,
            onTap: () async {
              final f = await escolherFoto(context,
                  titulo: 'Foto do carro',
                  largura: 1000,
                  qualidade: 55,
                  limiteKb: 450);
              if (f != null && mounted) setState(() => _fotoCarro = f);
            },
          ),
        ],
      );

  Widget _foto() => _base(
        nomeEtapa: 'Foto de perfil',
        titulo: 'Sua foto de perfil',
        subtitulo: 'Aparece para o passageiro quando você aceita a corrida.',
        campos: [
          const SizedBox(height: 6),
          CirculoFoto(
            foto: _selfie,
            onTap: () async {
              final f = await escolherFoto(context,
                  titulo: 'Foto de perfil',
                  frontal: true,
                  largura: 400,
                  qualidade: 70,
                  limiteKb: 300);
              if (f != null && mounted) setState(() => _selfie = f);
            },
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            decoration: BoxDecoration(
              color: corCampoFundo,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                DicaFoto('Rosto de frente e bem iluminado'),
                DicaFoto('Sem óculos escuros ou boné'),
              ],
            ),
          ),
        ],
      );

  Widget _acesso() => _base(
        nomeEtapa: 'Acesso',
        titulo: 'Crie seu acesso',
        subtitulo: 'É com esse e-mail e senha que você vai entrar.',
        botao: 'Enviar cadastro',
        rodape: const Text(
          'Seu cadastro passa por aprovação antes da primeira corrida.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: corTextoSuave),
        ),
        campos: [
          CampoCadastro(
            rotulo: 'E-mail',
            controle: _email,
            dica: 'voce@email.com',
            icone: Icons.mail_outline,
            teclado: TextInputType.emailAddress,
          ),
          CampoCadastro(
            rotulo: 'Senha',
            controle: _senha,
            dica: 'Mínimo de 6 caracteres',
            icone: Icons.lock_outline,
            senha: !_verSenha,
            sufixo: IconButton(
              tooltip: _verSenha ? 'Ocultar senha' : 'Mostrar senha',
              icon: Icon(
                  _verSenha
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: corTextoSuave,
                  size: 20),
              onPressed: () => setState(() => _verSenha = !_verSenha),
            ),
          ),
          CampoCadastro(
            rotulo: 'Confirme a senha',
            controle: _senha2,
            dica: 'Digite de novo',
            icone: Icons.lock_outline,
            senha: !_verSenha,
          ),
        ],
      );

  Widget _marca(bool marcado, {bool quadrada = false}) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: marcado && quadrada ? corAzul : null,
        borderRadius: BorderRadius.circular(quadrada ? 8 : 13),
        border: Border.all(
            color: marcado ? corAzul : const Color(0xFFCBD5E1), width: 2),
      ),
      child: marcado
          ? (quadrada
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                        color: corAzul, shape: BoxShape.circle),
                  ),
                ))
          : null,
    );
  }
}
