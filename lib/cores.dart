import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Modo escuro do PiraCar: segue a configuração do celular.
///
/// As funções abaixo recebem a cor do modo claro e devolvem a cor certa
/// para o modo atual. No modo claro devolvem a própria cor (o visual não
/// muda); no escuro trocam por tons escuros.
/// Este arquivo é igual nos três apps.

final modoEscuro = ValueNotifier<bool>(_celularEscuro());

bool _celularEscuro() =>
    SchedulerBinding.instance.platformDispatcher.platformBrightness ==
    Brightness.dark;

/// true quando o app está no modo escuro.
bool get escuro => modoEscuro.value;

/// Chamado quando o celular troca entre claro e escuro.
void atualizarModoEscuro() => modoEscuro.value = _celularEscuro();

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
