import 'package:flutter/material.dart';

/// Peças do menu lateral (três tracinhos), iguais nos três apps PiraCar.

const corMenuTitulo = Color(0xFF0B2545);
const corMenuAmarelo = Color(0xFFFFC24B);
const corMenuNome = Color(0xFFE0A21A);
const corMenuTexto = Color(0xFF4B5563);
const corMenuIcone = Color(0xFF6B7280);
const corMenuDestaque = Color(0xFFF1F3F7);

/// A gaveta branca que desliza da esquerda.
class GavetaPiraCar extends StatelessWidget {
  const GavetaPiraCar({
    super.key,
    required this.cabecalho,
    required this.itens,
    this.rodape = true,
  });

  final Widget cabecalho;
  final List<Widget> itens;
  final bool rodape;

  @override
  Widget build(BuildContext context) {
    final p = MediaQuery.paddingOf(context);
    return Drawer(
      width: 310,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, p.top + 28, 18, p.bottom + 16),
        children: [
          cabecalho,
          const SizedBox(height: 22),
          ...itens,
          if (rodape) ...[
            const SizedBox(height: 28),
            const Center(
              child: Text('Desenvolvido por Geanderson Alves @GeanAlves',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: corMenuIcone)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Foto grande com borda amarela, "Olá, Nome!" e uma linha embaixo.
class CabecalhoMenu extends StatelessWidget {
  const CabecalhoMenu({
    super.key,
    required this.nome,
    required this.foto,
    this.subtitulo,
    this.onFoto,
  });

  final String nome;
  final Widget foto;
  final String? subtitulo;
  final VoidCallback? onFoto;

  @override
  Widget build(BuildContext context) {
    final primeiro = nome.trim().split(RegExp(r'\s+')).first;
    return Row(
      children: [
        GestureDetector(
          onTap: onFoto,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: corMenuAmarelo, shape: BoxShape.circle),
                child: foto,
              ),
              if (onFoto != null)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: corMenuAmarelo,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.edit, size: 14, color: corMenuTitulo),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Olá, '),
                  TextSpan(
                      text: '$primeiro!',
                      style: const TextStyle(color: corMenuNome)),
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: corMenuTitulo),
              ),
              if (subtitulo != null && subtitulo!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitulo!,
                    style: const TextStyle(fontSize: 13, color: corMenuTexto)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Um item do menu: ícone em linha + texto. O primeiro fica destacado.
class ItemMenu extends StatelessWidget {
  const ItemMenu(this.icone, this.texto, this.onTap,
      {super.key, this.destaque = false, this.contador = 0, this.cor});

  final IconData icone;
  final String texto;
  final VoidCallback onTap;
  final bool destaque;
  final int contador;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final corTexto = cor ?? (destaque ? corMenuTitulo : corMenuTexto);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: destaque ? corMenuDestaque : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(icone,
                      size: 26,
                      color: cor ?? (destaque ? corMenuTitulo : corMenuIcone)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(texto,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                destaque ? FontWeight.w600 : FontWeight.w500,
                            color: corTexto)),
                  ),
                  if (contador > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 24),
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: corMenuAmarelo,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$contador',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: corMenuTitulo)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fecha o menu e abre uma tela.
void abrirDoMenu(BuildContext context, Widget tela) {
  Navigator.pop(context);
  Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
}

/// Barra azul-escura com voltar, usada nas telas abertas pelo menu.
AppBar barraTela(String titulo) => AppBar(
      title: Text(titulo),
      backgroundColor: corMenuTitulo,
      foregroundColor: Colors.white,
    );

/// Uma linha "rótulo ........ valor" dentro de um cartão branco.
class LinhaDado extends StatelessWidget {
  const LinhaDado(this.rotulo, this.valor, {super.key, this.ultima = false});

  final String rotulo;
  final String valor;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final vazio = valor.trim().isEmpty;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFEEF0F3))),
      ),
      child: Row(
        children: [
          Text(rotulo,
              style: const TextStyle(fontSize: 14, color: corMenuTexto)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(vazio ? 'Não informado' : valor,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: vazio ? const Color(0xFF94A3B8) : corMenuTitulo)),
          ),
        ],
      ),
    );
  }
}

/// Cartão branco arredondado com várias LinhaDado.
class CartaoDados extends StatelessWidget {
  const CartaoDados({super.key, required this.linhas});

  final List<Widget> linhas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: linhas),
    );
  }
}

/// Foto grande com o botão "Editar foto" embaixo (tela de Configurações).
class FotoEditavel extends StatelessWidget {
  const FotoEditavel({super.key, required this.foto, required this.onEditar});

  final Widget foto;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onEditar,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: corMenuAmarelo, shape: BoxShape.circle),
                child: foto,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: corMenuAmarelo,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF4F6FA), width: 3),
                  ),
                  child: const Icon(Icons.photo_camera_outlined,
                      size: 17, color: corMenuTitulo),
                ),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onEditar, child: const Text('Editar foto')),
      ],
    );
  }
}

/// Botões "Editar dados" (azul-escuro) e "Excluir minha conta" (vermelho).
class BotoesConta extends StatelessWidget {
  const BotoesConta(
      {super.key, required this.onEditar, required this.onExcluir});

  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: onEditar,
            style: FilledButton.styleFrom(
              backgroundColor: corMenuTitulo,
              shape: const StadiumBorder(),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.edit, color: corMenuAmarelo),
            label: const Text('Editar dados'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: onExcluir,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB91C1C),
              side: const BorderSide(color: Color(0xFFDC2626), width: 2),
              shape: const StadiumBorder(),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir minha conta'),
          ),
        ),
      ],
    );
  }
}
