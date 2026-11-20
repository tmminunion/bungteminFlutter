import 'dart:convert';
import 'package:http/http.dart' as http;

class AppControlStatus {
  const AppControlStatus({
    required this.mode,
    required this.isBlocked,
    required this.serviceName,
    required this.message,
    required this.ssoEnabled,
  });

  final String mode; // 'online' | 'maintenance' | 'shutdown'
  final bool isBlocked;
  final String serviceName;
  final String message;
  final bool ssoEnabled;

  bool get isShutdown => mode.toLowerCase() == 'shutdown';
  bool get isMaintenance => mode.toLowerCase() == 'maintenance';

  static const AppControlStatus online = AppControlStatus(
    mode: 'online',
    isBlocked: false,
    serviceName: 'Bungtemin Mobile (Flutter & Android)',
    message: 'Aplikasi berjalan normal.',
    ssoEnabled: false,
  );
}

class AppControlService {
  AppControlService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _statusUrl =
      'https://bungtemin.net/btapi/AppControl/status';

  Future<AppControlStatus> fetchStatus() async {
    try {
      final res = await _client
          .get(
            Uri.parse('$_statusUrl?t=${DateTime.now().millisecondsSinceEpoch}'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200 || res.statusCode == 503) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final mode = (decoded['mode'] ?? 'online').toString().toLowerCase();
          final blocked = decoded['is_blocked'] == true ||
              mode == 'maintenance' ||
              mode == 'shutdown';
          return AppControlStatus(
            mode: mode,
            isBlocked: blocked,
            serviceName: (decoded['service_name'] ??
                    'Bungtemin Mobile (Flutter & Android)')
                .toString(),
            message: (decoded['message'] ?? '').toString(),
            ssoEnabled: decoded['sso_enabled'] == true,
          );
        }
      }
    } catch (_) {
      // Fail-open jika offline sementara agar tidak mengunci user saat sinyal lemah
    }
    return AppControlStatus.online;
  }
}
