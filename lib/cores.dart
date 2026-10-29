import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Cores do app. O modo escuro foi desligado: tudo fica no visual claro.
///
/// As funções abaixo recebem a cor do modo claro e devolvem a cor certa
/// para o modo atual. No modo claro devolvem a própria cor (o visual não
/// muda); no escuro trocam por tons escuros.
/// Este arquivo é igual nos três apps.

/// Escolha da pessoa: 'auto' (segue o celular), 'claro' ou 'escuro'.
String escolhaTema = 'auto';

bool _calcular() => escolhaTema == 'claro'
    ? false
    : (escolhaTema == 'escuro' ? true : _celularEscuro());

final modoEscuro = ValueNotifier<bool>(_celularEscuro());

/// Lê a escolha salva no celular. Chame no main(), antes do runApp.
Future<void> carregarTema() async {}

/// Troca a aparência e guarda a escolha.
Future<void> mudarTema(String escolha) async {}

const nomesTema = {
  'auto': 'Automático',
  'claro': 'Claro',
  'escuro': 'Escuro',
};

bool _celularEscuro() =>
    SchedulerBinding.instance.platformDispatcher.platformBrightness ==
    Brightness.dark;

/// true quando o app está no modo escuro.
bool get escuro => false;

/// Chamado quando o celular troca entre claro e escuro.
void atualizarModoEscuro() => modoEscuro.value = _calcular();

const _fundoEscuro = Color(0xFF0E1420);
const _cartaoEscuro = Color(0xFF1A2232);
const _tintaEscura = Color(0xFF1D3150);
const _linhaEscura = Color(0xFF2C3648);
const _textoEscuro = Color(0xFFE8EDF5);
const _fracoEscuro = Color(0xFF9AA7BA);

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
ThemeData temaPiraCar(Color semente) => ThemeData(
      colorSchemeSeed: semente,
      brightness: escuro ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: escuro ? _fundoEscuro : null,
      cardColor: escuro ? _cartaoEscuro : null,
      dialogBackgroundColor: escuro ? _cartaoEscuro : null,
    );

/// Estilo escuro do Google Maps (null no modo claro).
String? get estiloMapa => escuro ? _mapaEscuro : null;

const _mapaEscuro = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2533"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8a97ab"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a2130"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#3a4558"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#222b3b"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1c3328"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2e3a4f"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1a2130"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3d4c66"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#a3b0c2"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#262f40"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e2238"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4f6a8a"}]}
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
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => atualizarModoEscuro();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: modoEscuro,
      builder: (context, valor, _) =>
          KeyedSubtree(key: ValueKey(valor), child: widget.builder(context)),
    );
  }
}

/// Janela para escolher a aparência.
Future<void> escolherAparencia(BuildContext context) async {
  final nova = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Aparência'),
      children: [
        for (final e in nomesTema.entries)
          RadioListTile<String>(
            value: e.key,
            groupValue: escolhaTema,
            title: Text(e.value),
            subtitle: e.key == 'auto'
                ? const Text('Segue o modo do celular')
                : null,
            onChanged: (v) => Navigator.pop(c, v),
          ),
      ],
    ),
  );
  if (nova != null && nova != escolhaTema) await mudarTema(nova);
}

// ---- Painéis azul-escuros (estilo novo) ----
// Mesmas funções, mas devolvem tons para o fundo azul-escuro dos painéis.
const azulPainel = Color(0xFF14213D);
const azulPainel2 = Color(0xFF1F3563);
const amareloPainel = Color(0xFFFFD23F);
const azulClaroPainel = Color(0xFFAAB8D6);

/// Fundo azul-escuro (gradiente) dos painéis de baixo.
const decoracaoPainelAzul = BoxDecoration(
  gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [azulPainel, azulPainel2]),
  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
  boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 14)],
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
