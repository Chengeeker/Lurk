import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../constants/tieba_constants.dart';

class SignInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['skip_sign'] == true ||
        options.headers['x_bd_data_type'] == 'protobuf') {
      return handler.next(options);
    }

    final Map<String, dynamic> params = {};

    if (options.queryParameters.isNotEmpty) {
      params.addAll(options.queryParameters);
    }

    if (options.data is Map<String, dynamic>) {
      params.addAll(options.data as Map<String, dynamic>);
    } else if (options.data is FormData) {
      final formData = options.data as FormData;
      for (var field in formData.fields) {
        params[field.key] = field.value;
      }
    }

    params.putIfAbsent('_client_version', () => TiebaConstants.defaultClientVersion);
    params.putIfAbsent('_client_type', () => TiebaConstants.defaultClientType);
    params.putIfAbsent('cuid', () => 'baidutiebaapp4134907038753229');
    params.putIfAbsent('timestamp', () => DateTime.now().millisecondsSinceEpoch.toString());

    final sign = calculateSign(params);
    params['sign'] = sign;

    if (options.method == 'GET') {
      options.queryParameters = params;
    } else {
      if (options.data is FormData) {
        final originalFormData = options.data as FormData;
        final newFormData = FormData();
        params.forEach((k, v) {
          newFormData.fields.add(MapEntry(k, v.toString()));
        });
        newFormData.files.addAll(originalFormData.files);
        options.data = newFormData;
      } else {
        options.data = params;
      }
    }

    handler.next(options);
  }

  static String calculateSign(Map<String, dynamic> params) {
    final sortedKeys = params.keys.toList()..sort();
    final buffer = StringBuffer();
    for (var key in sortedKeys) {
      buffer.write('$key=${params[key]}');
    }
    buffer.write(TiebaConstants.appSecret);
    final bytes = utf8.encode(buffer.toString());
    final digest = md5.convert(bytes);
    return digest.toString();
  }
}
