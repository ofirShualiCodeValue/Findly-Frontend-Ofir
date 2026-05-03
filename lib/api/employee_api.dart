import 'package:dio/dio.dart';
import 'client.dart';

class EmployeeApi {
  // ---------- Profile ----------

  /// Returns the full profile (User + EmployeeProfile + industries + activityAreas).
  static Future<Map<String, dynamic>> getProfile() async {
    final r = await ApiClient.dio.get('/v1/employee/profile');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// Partial update of any profile fields.
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    final r = await ApiClient.dio.patch('/v1/employee/profile', data: body);
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// First-time registration completion. Throws ApiException with
  /// errorCode == 'AGE_REQUIREMENT_NOT_MET' if the user is under 18.
  static Future<Map<String, dynamic>> completeRegistration({
    required DateTime dateOfBirth,
    required String workStatus, // 'freelancer' | 'self_employed'
    required int locationRangeKm,
    required double baseHourlyRate,
    required double homeLatitude,
    required double homeLongitude,
    List<int> industryIds = const [],
  }) async {
    final dob = '${dateOfBirth.year.toString().padLeft(4, '0')}-'
        '${dateOfBirth.month.toString().padLeft(2, '0')}-'
        '${dateOfBirth.day.toString().padLeft(2, '0')}';
    final r = await ApiClient.dio.post('/v1/employee/profile/complete', data: {
      'date_of_birth': dob,
      'work_status': workStatus,
      'location_range_km': locationRangeKm,
      'base_hourly_rate': baseHourlyRate,
      'home_latitude': homeLatitude,
      'home_longitude': homeLongitude,
      'industry_ids': industryIds,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final r = await ApiClient.dio.post(
      '/v1/employee/profile/avatar',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> addIndustry(int industryId) async {
    final r = await ApiClient.dio.post(
      '/v1/employee/profile/industries',
      data: {'industry_id': industryId},
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> removeIndustry(int industryId) async {
    final r = await ApiClient.dio.delete('/v1/employee/profile/industries/$industryId');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  // ---------- Events ----------

  /// `match=on` (default) returns only events that match the employee's
  /// industries, location range, and base rate.
  static Future<List<dynamic>> browseEvents({bool match = true}) async {
    final r = await ApiClient.dio.get('/v1/employee/events', queryParameters: {
      if (!match) 'match': 'off',
      'page_size': 100,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> getEvent(int id) async {
    final r = await ApiClient.dio.get('/v1/employee/events/$id');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<void> markInterest(int eventId, String status) async {
    // status: 'interested' | 'not_interested'
    final r = await ApiClient.dio.post(
      '/v1/employee/events/$eventId/interest',
      data: {'status': status},
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
  }

  // ---------- Applications ----------

  static Future<Map<String, dynamic>> apply(int eventId, double proposedAmount, {String? note}) async {
    final r = await ApiClient.dio.post('/v1/employee/events/$eventId/apply', data: {
      'proposed_amount': proposedAmount,
      if (note != null) 'note': note,
    });
    if (r.statusCode != 201) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<List<dynamic>> myApplications({String? status}) async {
    final r = await ApiClient.dio.get('/v1/employee/applications', queryParameters: {
      if (status != null) 'status': status,
      'page_size': 100,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }

  static Future<void> cancelApplication(int id) async {
    final r = await ApiClient.dio.delete('/v1/employee/applications/$id');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
  }

  /// Available only after the shift's end_at has passed and the application
  /// is approved. Backend moves hours_status to 'pending_approval'.
  static Future<Map<String, dynamic>> reportHours(int applicationId, double hours) async {
    final r = await ApiClient.dio.post(
      '/v1/employee/applications/$applicationId/report-hours',
      data: {'hours': hours},
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }
}
