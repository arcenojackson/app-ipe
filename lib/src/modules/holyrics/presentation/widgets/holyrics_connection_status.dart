import 'package:flutter/material.dart';
import 'package:ipe_flutter/src/modules/holyrics/data/holyrics_service.dart';

class HolyricsConnectionStatus extends StatefulWidget {
  const HolyricsConnectionStatus({Key? key}) : super(key: key);

  @override
  State<HolyricsConnectionStatus> createState() =>
      _HolyricsConnectionStatusState();
}

class _HolyricsConnectionStatusState extends State<HolyricsConnectionStatus> {
  bool _isLoading = true;
  bool _isConnected = false;
  String _statusMessage = 'Checking connection...';

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final service = HolyricsService();
    final isConnected = await service.testConnection();
    await service.close();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isConnected = isConnected;
      _statusMessage = isConnected
          ? 'Connected to Holyrics'
          : 'Disconnected from Holyrics';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isConnected
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                )
              : Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
          const SizedBox(width: 8),
          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 12,
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
