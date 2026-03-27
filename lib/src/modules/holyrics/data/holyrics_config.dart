import 'package:shared_preferences/shared_preferences.dart';

class HolyricsConfig {
  final String ip;
  final int port;
  final String token;

  HolyricsConfig({required this.ip, required this.port, required this.token});

  /// Save configuration to shared preferences
  static Future<void> saveConfig(HolyricsConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('holyrics_ip', config.ip);
    await prefs.setInt('holyrics_port', config.port);
    await prefs.setString('holyrics_token', config.token);
  }

  /// Load configuration from shared preferences
  static Future<HolyricsConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('holyrics_ip');
    final port = prefs.getInt('holyrics_port');
    final token = prefs.getString('holyrics_token');

    if (ip == null || ip.isEmpty || token == null || token.isEmpty) {
      return null;
    }

    return HolyricsConfig(ip: ip, port: port ?? 8080, token: token);
  }

  /// Clear configuration from shared preferences
  static Future<void> clearConfig() async {
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
