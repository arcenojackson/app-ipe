import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HolyricsConfig {
  final String ip;
  final int port;
  final String token;

  HolyricsConfig({required this.ip, required this.port, required this.token});

  Map<String, dynamic> toMap() => {
    'ip': ip,
    'port': port,
    'token': token,
  };

  factory HolyricsConfig.fromMap(Map<String, dynamic> map) => HolyricsConfig(
    ip: map['ip'] as String? ?? '',
    port: (map['port'] as num?)?.toInt() ?? 8080,
    token: map['token'] as String? ?? '',
  );

  /// Save configuration to Firestore (shared) and SharedPreferences (local cache)
  static Future<void> saveConfig(HolyricsConfig config) async {
    // Salva no Firestore (compartilhado entre todos os usuários)
    await FirebaseFirestore.instance
        .collection('settings')
        .doc('holyrics')
        .set(config.toMap());

    // Cache local para acesso offline
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('holyrics_ip', config.ip);
    await prefs.setInt('holyrics_port', config.port);
    await prefs.setString('holyrics_token', config.token);
  }

  /// Load configuration from Firestore (primary) with SharedPreferences fallback
  static Future<HolyricsConfig?> loadConfig() async {
    // Tenta Firestore primeiro (config compartilhada)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('holyrics')
          .get();

      if (doc.exists && doc.data() != null) {
        final config = HolyricsConfig.fromMap(doc.data()!);
        if (config.isValid()) {
          // Atualiza cache local
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('holyrics_ip', config.ip);
          await prefs.setInt('holyrics_port', config.port);
          await prefs.setString('holyrics_token', config.token);
          return config;
        }
      }
    } catch (_) {
      // Firestore indisponível — cai para cache local
    }

    // Fallback: SharedPreferences (modo offline)
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('holyrics_ip');
    final port = prefs.getInt('holyrics_port');
    final token = prefs.getString('holyrics_token');

    if (ip == null || ip.isEmpty || token == null || token.isEmpty) {
      return null;
    }

    return HolyricsConfig(ip: ip, port: port ?? 8080, token: token);
  }

  /// Clear configuration from Firestore and SharedPreferences
  static Future<void> clearConfig() async {
    // Remove do Firestore
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('holyrics')
          .delete();
    } catch (_) {}

    // Limpa cache local
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('holyrics_ip');
    await prefs.remove('holyrics_port');
    await prefs.remove('holyrics_token');
  }

  /// Validate configuration
  bool isValid() {
    return ip.isNotEmpty && port > 0 && port <= 65535 && token.isNotEmpty;
  }

  @override
  String toString() {
    return 'HolyricsConfig(ip: $ip, port: $port, token: [hidden])';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HolyricsConfig &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port &&
          token == other.token;

  @override
  int get hashCode => Object.hash(ip, port, token);
}
