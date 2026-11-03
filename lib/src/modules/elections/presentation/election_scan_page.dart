import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/app_exception.dart';
import '../data/elections_repository.dart';
import '../models/election_logic.dart';
import 'widgets/manual_code_field.dart';

/// Lê o QR code mostrado por quem conduz a eleição e faz o check-in do membro.
/// Devolve (`Navigator.pop`) o id da eleição em que entrou. O campo de
/// código/link fica sempre visível: câmera negada, QR ruim ou simulador.
class ElectionScanPage extends StatefulWidget {
  const ElectionScanPage({super.key});

  @override
  State<ElectionScanPage> createState() => _ElectionScanPageState();
}

class _ElectionScanPageState extends State<ElectionScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _busy = false;
  String? _message;

  Future<void> _enter(String electionId) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await context.read<ElectionsRepository>().checkIn(electionId);
      if (mounted) Navigator.of(context).pop(electionId);
    } on AppException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'Algo deu errado. Tente de novo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final id = parseElectionId(raw);
      if (id == null) {
        setState(() => _message = 'QR inválido.');
        return;
      }
      _enter(id);
      return;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar na votação')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Aponte a câmera para o QR code mostrado por quem está '
            'conduzindo a eleição.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Câmera indisponível. Digite o código ou o link abaixo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_message != null)
            Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 24),
          Text(
            'Ou digite o código ou cole o link da votação:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ManualCodeField(onElectionId: _enter),
        ],
      ),
    );
  }
}
