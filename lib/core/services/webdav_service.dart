import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// WebDAV Cloud Backup and Restore Service
class WebDavService {
  final Dio _dio;
  WebDavService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              followRedirects: false,
            ),
          );

  static bool isSecureUrl(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(
      trimmed.contains('://') ? trimmed : 'https://$trimmed',
    );
    return uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                [
                  '127.0.0.1',
                  'localhost',
                  '::1',
                ].contains(uri.host.toLowerCase())));
  }

  String _formatBaseUrl(String url) {
    if (!isSecureUrl(url)) {
      throw const FormatException('请使用有效的 HTTPS WebDAV 地址');
    }
    final raw = url.trim();
    final uri = Uri.parse(raw.contains('://') ? raw : 'https://$raw');
    return uri
        .replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/')
        .toString();
  }

  String _getAuthHeader(String username, String password) {
    final credentials = '$username:$password';
    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }

  /// Test connection to the WebDAV server
  Future<bool> testConnection({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    try {
      final base = _formatBaseUrl(serverUrl);
      final auth = _getAuthHeader(username, password);

      final response = await _dio.request(
        base,
        options: Options(
          method: 'PROPFIND',
          headers: {'Authorization': auth, 'Depth': '0'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return response.statusCode == 200 || response.statusCode == 207;
    } catch (_) {
      return false;
    }
  }

  /// Ensure the target directory exists on the WebDAV server (using MKCOL)
  Future<bool> createDirectory({
    required String serverUrl,
    required String username,
    required String password,
    required String directoryName,
  }) async {
    try {
      final base = _formatBaseUrl(serverUrl);
      final dirUrl = '$base${Uri.encodeComponent(directoryName)}/';
      final auth = _getAuthHeader(username, password);

      final res = await _dio.request(
        dirUrl,
        options: Options(
          method: 'MKCOL',
          headers: {'Authorization': auth},
          validateStatus: (status) =>
              status != null &&
              (status == 201 || status == 405 || status == 200),
        ),
      );

      return res.statusCode == 201 ||
          res.statusCode == 405 ||
          res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Upload backup JSON to WebDAV directory
  Future<bool> uploadBackup({
    required String serverUrl,
    required String username,
    required String password,
    required String directoryName,
    required Map<String, dynamic> data,
  }) async {
    try {
      final base = _formatBaseUrl(serverUrl);
      final dirEnc = Uri.encodeComponent(directoryName);
      final auth = _getAuthHeader(username, password);

      // 1. Create directory if not exists
      final created = await createDirectory(
        serverUrl: serverUrl,
        username: username,
        password: password,
        directoryName: directoryName,
      );
      if (!created) return false;

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      // 2. Upload latest backup file
      final latestUrl = '$base$dirEnc/backup_lurk_latest.json';
      final res = await _dio.put(
        latestUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Authorization': auth,
            'Content-Type': 'application/json; charset=utf-8',
            'Content-Length': bytes.length,
          },
          validateStatus: (status) =>
              status != null &&
              (status == 200 || status == 201 || status == 204),
        ),
      );

      // 3. Upload historical timestamped file
      final timeStampUrl =
          '$base$dirEnc/backup_lurk_${DateTime.now().millisecondsSinceEpoch}.json';
      try {
        await _dio.put(
          timeStampUrl,
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {
              'Authorization': auth,
              'Content-Type': 'application/json; charset=utf-8',
              'Content-Length': bytes.length,
            },
            validateStatus: (status) => status != null && status < 300,
          ),
        );
      } catch (_) {}

      return res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  /// Download and parse the latest backup JSON from WebDAV
  Future<Map<String, dynamic>?> downloadLatestBackup({
    required String serverUrl,
    required String username,
    required String password,
    required String directoryName,
  }) async {
    try {
      final base = _formatBaseUrl(serverUrl);
      final dirEnc = Uri.encodeComponent(directoryName);
      final auth = _getAuthHeader(username, password);
      final latestUrl = '$base$dirEnc/backup_lurk_latest.json';

      final res = await _dio.get(
        latestUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Authorization': auth},
          validateStatus: (status) => status != null && status == 200,
        ),
      );

      if (res.statusCode == 200 && res.data != null) {
        final decoded = jsonDecode(res.data.toString());
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final webDavServiceProvider = Provider<WebDavService>((ref) => WebDavService());
