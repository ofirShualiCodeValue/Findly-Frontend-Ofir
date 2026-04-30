import 'client.dart';

class AuthApi {
  /// Returns { ok, is_new_user, dev_code? }
  static Future<Map<String, dynamic>> requestSms({
    required String phone,
    String? role,
    String? fullName,
  }) async {
    final r = await ApiClient.dio.post('/v1/shared/auth/sms/request', data: {
      'phone': phone,
      if (role != null) 'role': role,
      if (fullName != null) 'full_name': fullName,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// Returns { token, user }
  static Future<Map<String, dynamic>> verifySms({
    required String phone,
    required String code,
  }) async {
    final r = await ApiClient.dio.post('/v1/shared/auth/sms/verify', data: {
      'phone': phone,
      'code': code,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }
}
