import 'package:flutter/material.dart';
import 'package:ipe_flutter/src/modules/holyrics/data/holyrics_config.dart';
import 'package:ipe_flutter/src/modules/holyrics/data/holyrics_service.dart';
import 'package:ipe_flutter/src/shared/utils/app_toast.dart';

class HolyricsSettingsScreen extends StatefulWidget {
  const HolyricsSettingsScreen({Key? key}) : super(key: key);

  @override
  State<HolyricsSettingsScreen> createState() => _HolyricsSettingsScreenState();
}

class _HolyricsSettingsScreenState extends State<HolyricsSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  bool _isTestingConnection = false;
  bool _obscureToken = true;
  String? _connectionStatus;
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final config = await HolyricsConfig.loadConfig();
    if (config != null && mounted) {
      setState(() {
        _ipController.text = config.ip;
        _portController.text = config.port.toString();
        _tokenController.text = config.token;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final config = HolyricsConfig(
      ip: _ipController.text.trim(),
      port: int.tryParse(_portController.text) ?? 8080,
      token: _tokenController.text.trim(),
    );

    if (!config.isValid()) {
      showErrorToast(context, 'Verifique os valores de configuração');
      return;
    }

    await HolyricsConfig.saveConfig(config);
    if (mounted) {
      showSuccessToast(context, 'Configuração salva com sucesso!');
    }
  }

  Future<void> _testConnection() async {
    if (!mounted) return;

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testando conexão...';
      _statusColor = Colors.blue;
    });

    final service = HolyricsService();
    final isConnected = await service.testConnection();
    await service.close();

    if (!mounted) return;

    setState(() {
      _isTestingConnection = false;
      if (isConnected) {
        _connectionStatus = 'Conexão bem-sucedida!';
        _statusColor = Colors.green;
      } else {
        _connectionStatus =
            'Falha na conexão. Verifique suas configurações e a rede.';
        _statusColor = Colors.red;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integração com Holyrics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Endereço IP do Holyrics',
                  hintText: 'ex., 192.168.0.10',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o endereço IP do Holyrics';
                  }
                  // Basic IP validation
                  final ipPattern = RegExp(
                    r'^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$',
                  );
                  if (!ipPattern.hasMatch(value)) {
                    return 'Informe um IP válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Porta do Holyrics',
                  hintText: 'ex., 8080',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe a porta';
                  }
                  final port = int.tryParse(value);
                  if (port == null) {
                    return 'Informe uma porta válida';
                  }
                  if (port < 1 || port > 65535) {
                    return 'A porta deve estar entre 1 e 65535';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: 'Token da API',
                  hintText: 'Informe o token da API',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureToken ? Icons.visibility : Icons.visibility_off,
                    ),
                    tooltip: _obscureToken ? 'Exibir token' : 'Ocultar token',
                    onPressed: () =>
                        setState(() => _obscureToken = !_obscureToken),
                  ),
                ),
                obscureText: _obscureToken,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o token da API';
                  }
                  if (value.length < 3) {
                    return 'Token é curto demais';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveConfig,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Salvar Configuração'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isTestingConnection ? null : _testConnection,
                icon: _isTestingConnection
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.wifi),
                label: _isTestingConnection
                    ? const Text('Testando...')
                    : const Text('Testar Conexão'),
              ),
              const SizedBox(height: 24),
              if (_connectionStatus != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusColor),
                  ),
                  child: Text(
                    _connectionStatus!,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 32),
              const Text(
                'Notas Importantes:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Certifique-se de que o seu dispositivo móvel e o computador executando o Holyrics estejam na mesma rede Wi-Fi.\n'
                '• O servidor da API Holyrics deve estar habilitado nas configurações do Holyrics.\n'
                '• A porta da API deve estar acessível (não bloqueada pelo firewall).\n'
                '• Esta configuração é armazenada localmente no seu dispositivo.\n'
                '• Nenhum dado é enviado para servidores externos - toda a comunicação é local.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
