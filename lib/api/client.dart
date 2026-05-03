import 'package:dio/dio.dart';
import '../config.dart';
import '../store/auth_store.dart';

class ApiClient {
  static final Dio _dio = _create();

  static Dio _create() {
    final dio = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
      contentType: 'application/json',
      validateStatus: (status) => status != null && status < 500,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final t = authStore.token;
        if (t != null) {
          options.headers['Authorization'] = 'Bearer $t';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401 && authStore.isLoggedIn) {
          await authStore.clear();
        }
        handler.next(e);
      },
    ));
    return dio;
  }

  static Dio get dio => _dio;
}

class ApiException implements Exception {
  final int? code;
  final String message;
  final Map<String, dynamic>? data;
  ApiException(this.code, this.message, {this.data});

  /// Domain-specific error code carried under `data.code` (e.g.
  /// "AGE_REQUIREMENT_NOT_MET"). Null for plain validation errors.
  String? get errorCode => data?['code'] as String?;

  @override
  String toString() => 'ApiException($code): $message';

  static ApiException fromResponse(Response<dynamic> r) {
    final body = r.data;
    final msg = body is Map && body['message'] is String ? body['message'] as String : 'שגיאה';
    final code = body is Map && body['code'] is int ? body['code'] as int : r.statusCode;
    final data = body is Map && body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : null;
    return ApiException(code, msg, data: data);
  }
}
