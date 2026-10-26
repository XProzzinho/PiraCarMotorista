import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

// Fotos de perfil ficam no próprio cadastro (users/{uid}.foto) em base64,
// pequenas (até ~400 px), para não precisar do Firebase Storage.

final Map<int, Uint8List> _cache = {};

Uint8List? fotoBytes(dynamic foto) {
  if (foto is! String || foto.isEmpty) return null;
  final chave = foto.hashCode;
  final pronto = _cache[chave];
  if (pronto != null) return pronto;
  try {
    final b = base64Decode(foto);
    if (_cache.length > 60) _cache.clear();
    return _cache[chave] = b;
  } catch (_) {
    return null;
  }
}

String iniciaisNome(String? nome) {
  final partes =
      (nome ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (partes.isEmpty) return '?';
  final ultima = partes.length > 1 ? partes.last[0] : '';
  return (partes.first[0] + ultima).toUpperCase();
}

/// Foto redonda do perfil; sem foto, mostra as iniciais do nome.
class FotoPerfil extends StatelessWidget {
  const FotoPerfil({
    super.key,
    required this.dados,
    this.raio = 24,
    this.fundo = const Color(0xFF1B3A63),
    this.fotoUrl,
  });

  final Map<String, dynamic>? dados;
  final double raio;
  final Color fundo;
  final String? fotoUrl;

  @override
  Widget build(BuildContext context) {
    final bytes = fotoBytes(dados?['foto']);
    ImageProvider? img;
    if (bytes != null) {
      img = MemoryImage(bytes);
    } else if ((fotoUrl ?? '').isNotEmpty) {
      img = NetworkImage(fotoUrl!);
    }
    return CircleAvatar(
      radius: raio,
      backgroundColor: fundo,
      foregroundImage: img,
      child: Text(
        iniciaisNome(dados?['nome']?.toString()),
        style: TextStyle(
            fontSize: raio * 0.7,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      ),
    );
  }
}
