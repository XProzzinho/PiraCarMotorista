import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cores do app, com modo claro e modo escuro (preto e branco).
///
/// As funções abaixo recebem a cor do modo claro e devolvem a cor certa
/// para o modo atual. No modo claro devolvem a própria cor (o visual não
/// muda); no escuro trocam por tons de preto, cinza e branco.
/// Este arquivo é igual nos três apps.

/// Escolha da pessoa: 'claro' (padrão) ou 'escuro'.
String escolhaTema = 'claro';

final modoEscuro = ValueNotifier<bool>(false);

/// Lê a escolha salva no celular. Chame no main(), antes do runApp.
Future<void> carregarTema() async {
  try {
    final p = await SharedPreferences.getInstance();
    escolhaTema = p.getString('tema') == 'escuro' ? 'escuro' : 'claro';
  } catch (_) {}
  modoEscuro.value = escolhaTema == 'escuro';
}

/// Troca a aparência e guarda a escolha.
Future<void> mudarTema(String escolha) async {
  escolhaTema = escolha == 'escuro' ? 'escuro' : 'claro';
  modoEscuro.value = escolhaTema == 'escuro';
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('tema', escolhaTema);
  } catch (_) {}
}

/// true quando o app está no modo escuro.
bool get escuro => modoEscuro.value;

/// Mantido por compatibilidade (o app não segue mais o celular).
void atualizarModoEscuro() {}

const _fundoEscuro = Color(0xFF0A0A0A);
const _cartaoEscuro = Color(0xFF181818);
const _tintaEscura = Color(0xFF262626);
const _linhaEscura = Color(0xFF333333);
const _textoEscuro = Color(0xFFF5F5F5);
const _fracoEscuro = Color(0xFFA3A3A3);

/// Fundo da tela.
Color fu(Color claro) => escuro ? _fundoEscuro : claro;

/// Cartões, painéis e caixas (no claro, geralmente branco).
Color sup(Color claro) => escuro ? _cartaoEscuro : claro;

/// Fundos coloridos clarinhos (azul-claro, amarelo-claro...).
Color ta(Color claro) => escuro ? _tintaEscura : claro;

/// Linhas e bordas.
Color ln(Color claro) => escuro ? _linhaEscura : claro;

/// Texto e ícones escuros (títulos).
Color tx(Color claro) => escuro ? _textoEscuro : claro;

/// Texto cinza (subtítulos, dicas).
Color fr(Color claro) => escuro ? _fracoEscuro : claro;

/// Tema do app (claro ou escuro) a partir da cor principal.
ThemeData temaPiraCar(Color semente) => escuro
    ? ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Color(0xFFD4D4D4),
          onSecondary: Colors.black,
          surface: _cartaoEscuro,
          onSurface: _textoEscuro,
        ),
        scaffoldBackgroundColor: _fundoEscuro,
        cardColor: _cartaoEscuro,
        dialogBackgroundColor: _cartaoEscuro,
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF111111), foregroundColor: Colors.white),
      )
    : ThemeData(
        colorSchemeSeed: semente,
        brightness: Brightness.light,
        useMaterial3: true,
      );

/// Estilo escuro do Google Maps (null no modo claro).
String? get estiloMapa => escuro ? _mapaEscuro : null;

const _mapaEscuro = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1c1c1c"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#9a9a9a"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#151515"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#3a3a3a"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#222222"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1f2a22"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2f2f2f"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#151515"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#454545"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#b0b0b0"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#262626"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0d0d0d"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#5a5a5a"}]}
]
''';

/// Observa o celular e avisa quando o tema muda. Use em volta do app.
class ObservadorTema extends StatefulWidget {
  const ObservadorTema({super.key, required this.builder});

  final Widget Function(BuildContext context) builder;

  @override
  State<ObservadorTema> createState() => _ObservadorTemaState();
}

class _ObservadorTemaState extends State<ObservadorTema>
    {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: modoEscuro,
      builder: (context, valor, _) =>
          KeyedSubtree(key: ValueKey(valor), child: widget.builder(context)),
    );
  }
}

/// Linha com o botão de modo escuro, para o menu lateral.
class ItemModoEscuro extends StatelessWidget {
  const ItemModoEscuro({super.key});

  @override
  Widget build(BuildContext context) {
    final cor = escuro ? Colors.white : const Color(0xFF4B5563);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => mudarTema(escuro ? 'claro' : 'escuro'),
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(escuro ? Icons.dark_mode : Icons.dark_mode_outlined,
                    size: 26, color: cor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Modo escuro',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: cor)),
                ),
                Switch(
                  value: escuro,
                  onChanged: (v) => mudarTema(v ? 'escuro' : 'claro'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Painéis azul-escuros (estilo novo) ----
// Mesmas funções, mas devolvem tons para o fundo azul-escuro dos painéis.
const azulPainel = Color(0xFF14213D);
const azulPainel2 = Color(0xFF1F3563);
const amareloPainel = Color(0xFFFFD23F);
const azulClaroPainel = Color(0xFFAAB8D6);

/// Fundo azul-escuro (gradiente) dos painéis de baixo.
BoxDecoration get decoracaoPainelAzul => BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: escuro
              ? const [Color(0xFF141414), Color(0xFF2A2A2A)]
              : const [azulPainel, azulPainel2]),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14)],
    );

/// Tema escuro para o conteúdo dos painéis (texto branco, botões claros).
ThemeData temaPainelAzul() => ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorSchemeSeed: azulPainel2,
    );

Color pfu(Color _) => const Color(0x14FFFFFF);
Color psup(Color _) => const Color(0x1AFFFFFF);
Color pta(Color _) => const Color(0x1FFFFFFF);
Color pln(Color _) => const Color(0x33FFFFFF);
Color ptx(Color _) => Colors.white;
Color pfr(Color _) => azulClaroPainel;
