import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../constants/tieba_constants.dart';
import 'sign_interceptor.dart';

class TiebaDioClient {
  final Dio dio;
  final Ref? _ref;

  TiebaDioClient([this._ref])
      : dio = Dio(
          BaseOptions(
            baseUrl: TiebaConstants.baseNativeUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            headers: {
              'User-Agent': TiebaConstants.defaultUserAgent,
              'Host': 'c.tieba.baidu.com',
            },
            contentType: Headers.formUrlEncodedContentType,
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final account = _ref?.read(authStateProvider).activeAccount;
          if (account != null && account.isLogin) {
            options.headers['Cookie'] =
                'ka=open; BDUSS=${account.bduss}; STOKEN=${account.stoken}; BAIDUID=${account.baiduid}';
            options.headers['client_logid'] = DateTime.now().millisecondsSinceEpoch.toString();
            if (account.uid.isNotEmpty) {
              options.headers['client_user_token'] = account.uid;
            }

            if (options.data is Map) {
              final map = options.data as Map;
              map.putIfAbsent('BDUSS', () => account.bduss);
              map.putIfAbsent('bduss', () => account.bduss);
              map.putIfAbsent('bdusstoken', () => account.bduss);
              map.putIfAbsent('stoken', () => account.stoken);
            }
          }
          handler.next(options);
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          if (response.data is String) {
            try {
              response.data = jsonDecode(response.data as String);
            } catch (_) {}
          }
          handler.next(response);
        },
      ),
    );

    dio.interceptors.add(SignInterceptor());
  }

  Future<Response> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.post(
      path,
      data: data ?? {},
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }
}

final tiebaDioClientProvider = Provider<TiebaDioClient>((ref) {
  return TiebaDioClient(ref);
});
