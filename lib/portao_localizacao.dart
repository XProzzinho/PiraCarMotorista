import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Pede a localização assim que o app abre (antes do login).
/// O Android mostra "Durante o uso do app" / "Só desta vez" / "Não permitir".
/// Enquanto a localização não estiver permitida e o GPS ligado, mostra esta
/// tela; ao voltar das configurações do celular, confere de novo sozinho.
/// Este arquivo é igual nos apps do passageiro e do motorista.
class PortaoLocalizacao extends StatefulWidget {
  const PortaoLocalizacao({
    super.key,
    required this.child,
    required this.souMotorista,
  });

  final Widget child;
  final bool souMotorista;

  @override
  State<PortaoLocalizacao> createState() => _PortaoLocalizacaoState();
}

enum _Estado { conferindo, ok, pedir, negadoSempre, gpsDesligado }

class _PortaoLocalizacaoState extends State<PortaoLocalizacao>
    with WidgetsBindingObserver {
  static const _fundo = Color(0xFF0B2545);
  static const _amarelo = Color(0xFFFFC24B);

  _Estado _estado = _Estado.conferindo;
  bool _pediuUmaVez = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conferir(pedirSeFaltar: true);
    Geolocator.getServiceStatusStream()
        .listen((_) => _conferir(), onError: (_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // voltou das configurações do celular
    if (s == AppLifecycleState.resumed && _estado != _Estado.ok) _conferir();
  }

  Future<void> _conferir({bool pedirSeFaltar = false}) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && pedirSeFaltar && !_pediuUmaVez) {
        _pediuUmaVez = true;
        perm = await Geolocator.requestPermission();
      }
      final gps = await Geolocator.isLocationServiceEnabled();
      _Estado novo;
      if (perm == LocationPermission.deniedForever) {
        novo = _Estado.negadoSempre;
      } else if (perm == LocationPermission.denied ||
          perm == LocationPermission.unableToDetermine) {
        novo = _Estado.pedir;
      } else if (!gps) {
        novo = _Estado.gpsDesligado;
      } else {
        novo = _Estado.ok;
      }
      if (mounted) setState(() => _estado = novo);
    } catch (_) {
      // se o plugin falhar, não trava o app
      if (mounted) setState(() => _estado = _Estado.ok);
    }
  }

  Future<void> _botao() async {
    switch (_estado) {
      case _Estado.pedir:
        await Geolocator.requestPermission();
      case _Estado.negadoSempre:
        await Geolocator.openAppSettings();
      case _Estado.gpsDesligado:
        await Geolocator.openLocationSettings();
      default:
        break;
    }
    await _conferir();
  }

  @override
  Widget build(BuildContext context) {
    if (_estado == _Estado.ok) return widget.child;
    if (_estado == _Estado.conferindo) {
      return const Scaffold(
        backgroundColor: _fundo,
        body: Center(child: CircularProgressIndicator(color: _amarelo)),
      );
    }

    final (titulo, texto, botao, dica) = switch (_estado) {
      _Estado.gpsDesligado => (
          'Ligue o GPS',
          'A localização do celular está desligada. Ligue para o Uai Car '
              'funcionar.',
          'Ligar localização',
          null,
        ),
      _Estado.negadoSempre => (
          'Permita a localização',
          'A localização foi negada. Abra as configurações e, em '
              'Permissões > Local, escolha "Permitir durante o uso do app".',
          'Abrir configurações',
          'Depois é só voltar para o app.',
        ),
      _ => (
          'Ative a localização',
          widget.souMotorista
              ? 'O Uai Car Motorista precisa da sua localização para te '
                  'mostrar no mapa e mandar as corridas mais perto de você.'
              : 'O Uai Car precisa da sua localização para saber onde te '
                  'buscar e chamar o motorista mais perto.',
          'Permitir localização',
          'Escolha "Durante o uso do app".',
        ),
    };

    return Scaffold(
      backgroundColor: _fundo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                    color: Color(0x1FFFFFFF), shape: BoxShape.circle),
                child: Center(
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                        color: _amarelo, shape: BoxShape.circle),
                    child: Icon(
                        _estado == _Estado.gpsDesligado
                            ? Icons.location_off
                            : Icons.location_on,
                        size: 56,
                        color: _fundo),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Text(texto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFC9D6EA), fontSize: 16, height: 1.45)),
              if (dica != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _amarelo.withOpacity(.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(dica,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: _amarelo,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _botao,
                  style: FilledButton.styleFrom(
                    backgroundColor: _amarelo,
                    foregroundColor: _fundo,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  child: Text(botao),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
