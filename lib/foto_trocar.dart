import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Pergunta se a foto vem da câmera ou da galeria.
Future<ImageSource?> escolherOrigemFoto(BuildContext context, String titulo) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(titulo,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tirar foto agora'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Abre câmera ou galeria, reduz a foto e salva no cadastro do usuário.
Future<void> trocarFotoPerfil(BuildContext context) async {
  void aviso(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  final origem = await escolherOrigemFoto(context, 'Foto do perfil');
  if (origem == null) return;
  try {
    final foto = await ImagePicker().pickImage(
      source: origem,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );
    if (foto == null) return;
    final bytes = await foto.readAsBytes();
    if (bytes.length > 300 * 1024) {
      aviso('Foto muito grande, tente outra.');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'foto': base64Encode(bytes)});
    aviso('Foto atualizada!');
  } catch (e) {
    aviso('Não foi possível salvar a foto: $e');
  }
}
