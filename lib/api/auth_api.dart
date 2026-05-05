import 'package:dio/dio.dart';
import 'client.dart';

class AuthApi {
  /// Send an OTP to the phone. Backend never creates a User here — that
  /// happens only after `verify` + `register`.
  ///
  /// Returns `{ ok: true, dev_code? }`.
  static Future<Map<String, dynamic>> requestSms({required String phone}) async {
    final r = await ApiClient.dio.post(
      '/v1/shared/auth/sms/request',
      data: {'phone': phone},
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// Verify the OTP. The shape of `data` differs based on whether the
  /// phone already has a user:
  ///
  ///   - Existing user: `{ token, user, is_new_user: false }` — caller
  ///     can save the session via `authStore.setSession`.
  ///   - New user: `{ registration_token, is_new_user: true }` — caller
  ///     should navigate to the register screen and pass the token to
  ///     [register].
  static Future<Map<String, dynamic>> verifySms({
    required String phone,
    required String code,
  }) async {
    final r = await ApiClient.dio.post(
      '/v1/shared/auth/sms/verify',
      data: {'phone': phone, 'code': code},
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// Finish signup with a phone-bound `registration_token` from
  /// [verifySms]. Returns the same shape as a successful login:
  /// `{ token, user, is_new_user: false }`.
  static Future<Map<String, dynamic>> register({
    required String registrationToken,
    required String fullName,
    required String role, // 'employer' | 'employee'
  }) async {
    final r = await ApiClient.dio.post(
      '/v1/shared/auth/register',
      data: {'full_name': fullName, 'role': role},
      options: Options(
        // Don't let the global interceptor inject the existing session
        // token — the registration token must be the only Bearer here.
        headers: {'Authorization': 'Bearer $registrationToken'},
      ),
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }
}
