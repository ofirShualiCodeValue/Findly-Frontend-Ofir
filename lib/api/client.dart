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
  ApiException(this.code, this.message);

  @override
  String toString() => 'ApiException($code): $message';

  static ApiException fromResponse(Response<dynamic> r) {
    final data = r.data;
    final msg = data is Map && data['message'] is String ? data['message'] as String : 'שגיאה';
    final code = data is Map && data['code'] is int ? data['code'] as int : r.statusCode;
    return ApiException(code, msg);
  }
}
