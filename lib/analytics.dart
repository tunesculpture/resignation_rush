import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsRequestLog {
  final String method;
  final String url;
  final Map<String, String> headers;
  final String body;
  final int timestampMs;
  final int? statusCode;
  final String? responseBody;

  const AnalyticsRequestLog({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
    required this.timestampMs,
    this.statusCode,
    this.responseBody,
  });
}

/// Client-side analytics compatibility layer for the test player.
///
/// The original player sends JSON to the existing analytics worker and signs
/// `timestamp + '.' + body` with HMAC-SHA256. The signature is URL-safe base64
/// without padding, matching Android Base64 flags used by the original APK.
class AnalyticsService {
  static const String _baseUrl =
      'https://views.securevid-teleplayer.workers.dev';
  static const String _hmacSecret =
      'NipoR/D4V8MghkbC3wny3reAIBPHDHHgnrjb4N55X8s=';
  static const String _prefsName = 'views_analytics';
  static const String _deviceKey = 'device_id';

  String? _deviceId;
  final Random _random = Random.secure();

  /// Optional diagnostic hook used by the test player UI. It observes the
  /// exact analytics HTTP request/response without changing the request logic.
  void Function(AnalyticsRequestLog log)? onRequest;
  final List<AnalyticsRequestLog> _requestHistory = <AnalyticsRequestLog>[];

  List<AnalyticsRequestLog> get requestHistory =>
      List.unmodifiable(_requestHistory);

  void _recordRequest(AnalyticsRequestLog log) {
    _requestHistory.add(log);
    if (_requestHistory.length > 20) {
      _requestHistory.removeAt(0);
    }
    onRequest?.call(log);
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceKey);
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = _uuidV4();
      await prefs.setString(_deviceKey, _deviceId!);
    }
  }

  String get deviceId => _deviceId ?? (throw StateError('Analytics not initialized'));

  /// Reports the playback session. The server is authoritative for whether
  /// the event is counted.
  Future<AnalyticsResult> reportPlayback({
    required String videoId,
    required int playedSec,
    required String reason,
    String? eventId,
  }) async {
    if (playedSec < 1) {
      return const AnalyticsResult.skipped('played_sec < 1');
    }

    final body = jsonEncode({
      'event_id': eventId ?? _uuidV4(),
      'device_id': deviceId,
      'video_id': videoId,
      'played_sec': playedSec,
    });

    return _postSigned(
      path: '/collect',
      body: body,
      parseResponse: true,
    );
  }

  /// Reports an add-video visit. This is intended to be called when a link is
  /// successfully added through the manual Add Link flow, matching the
  /// separate visit endpoint in the original APK.
  Future<AnalyticsResult> reportVideoVisit() async {
    const body = '{}';
    return _postSigned(
      path: '/collect_add_video_visit',
      body: body,
      parseResponse: false,
    );
  }

  Future<AnalyticsResult> _postSigned({
    required String path,
    required String body,
    required bool parseResponse,
  }) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final message = '$timestamp.$body';
    final key = utf8.encode(_hmacSecret);
    final digest = Hmac(sha256, key).convert(utf8.encode(message));
    final signature = base64Url.encode(digest.bytes).replaceAll('=', '');
    final url = '$_baseUrl$path';
    final headers = <String, String>{
      'X-Timestamp': timestamp,
      'X-Signature': signature,
      'Content-Type': 'application/json',
    };
    final sentAt = DateTime.now().millisecondsSinceEpoch;

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      _recordRequest(AnalyticsRequestLog(
        method: 'POST',
        url: url,
        headers: Map.unmodifiable(headers),
        body: body,
        timestampMs: sentAt,
        statusCode: response.statusCode,
        responseBody: response.body,
      ));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!parseResponse || response.body.trim().isEmpty) {
          return AnalyticsResult.success(
            statusCode: response.statusCode,
            rawBody: response.body,
          );
        }
        try {
          final decoded = jsonDecode(response.body);
          return AnalyticsResult.success(
            statusCode: response.statusCode,
            rawBody: response.body,
            ok: decoded is Map ? decoded['ok'] as bool? : null,
            counted: decoded is Map ? decoded['counted'] as bool? : null,
            remainingTodayLike:
                decoded is Map ? decoded['remaining_today_like'] as int? : null,
          );
        } catch (_) {
          return AnalyticsResult.success(
            statusCode: response.statusCode,
            rawBody: response.body,
          );
        }
      }
      return AnalyticsResult.failure(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      _recordRequest(AnalyticsRequestLog(
        method: 'POST',
        url: url,
        headers: Map.unmodifiable(headers),
        body: body,
        timestampMs: sentAt,
        responseBody: e.toString(),
      ));
      return AnalyticsResult.failure(e.toString());
    }
  }

  String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class AnalyticsResult {
  final bool success;
  final bool skipped;
  final String? error;
  final int? statusCode;
  final String? rawBody;
  final bool? ok;
  final bool? counted;
  final int? remainingTodayLike;

  const AnalyticsResult._({
    required this.success,
    this.skipped = false,
    this.error,
    this.statusCode,
    this.rawBody,
    this.ok,
    this.counted,
    this.remainingTodayLike,
  });

  const AnalyticsResult.skipped(String reason)
      : this._(success: true, skipped: true, error: reason);

  const AnalyticsResult.success({
    int? statusCode,
    String? rawBody,
    bool? ok,
    bool? counted,
    int? remainingTodayLike,
  }) : this._(
          success: true,
          statusCode: statusCode,
          rawBody: rawBody,
          ok: ok,
          counted: counted,
          remainingTodayLike: remainingTodayLike,
        );

  const AnalyticsResult.failure(String error)
      : this._(success: false, error: error);
}
