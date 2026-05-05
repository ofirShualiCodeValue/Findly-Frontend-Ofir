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
  /// Either a full date_of_birth or year_of_birth must be provided;
  /// the Figma uses a year-only wheel picker.
  static Future<Map<String, dynamic>> completeRegistration({
    String? firstName,
    String? lastName,
    int? yearOfBirth,
    DateTime? dateOfBirth,
    required String workStatus, // 'freelancer' | 'salaried'
    required int locationRangeKm,
    required double baseHourlyRate,
    String? homeCity,
    double? homeLatitude,
    double? homeLongitude,
    List<int> industryIds = const [],
    List<int> industrySubCategoryIds = const [],
  }) async {
    final body = <String, dynamic>{
      'work_status': workStatus,
      'location_range_km': locationRangeKm,
      'base_hourly_rate': baseHourlyRate,
      'industry_ids': industryIds,
      'industry_subcategory_ids': industrySubCategoryIds,
    };
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (yearOfBirth != null) body['year_of_birth'] = yearOfBirth;
    if (dateOfBirth != null) {
      body['date_of_birth'] = '${dateOfBirth.year.toString().padLeft(4, '0')}-'
          '${dateOfBirth.month.toString().padLeft(2, '0')}-'
          '${dateOfBirth.day.toString().padLeft(2, '0')}';
    }
    if (homeCity != null) body['home_city'] = homeCity;
    if (homeLatitude != null) body['home_latitude'] = homeLatitude;
    if (homeLongitude != null) body['home_longitude'] = homeLongitude;

    final r = await ApiClient.dio.post('/v1/employee/profile/complete', data: body);
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

  /// Replaces the employee's industries with the given list.
  static Future<Map<String, dynamic>> setIndustries(List<int> industryIds) async {
    final r = await ApiClient.dio.put(
      '/v1/employee/profile/industries',
      data: {'industry_ids': industryIds},
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// Replaces the employee's industry sub-categories (specialties).
  static Future<Map<String, dynamic>> setIndustrySubCategories(List<int> subCategoryIds) async {
    final r = await ApiClient.dio.put(
      '/v1/employee/profile/industry-subcategories',
      data: {'industry_subcategory_ids': subCategoryIds},
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// Replaces the employee's certifications (m:n).
  static Future<Map<String, dynamic>> setCertifications(List<int> certificationIds) async {
    final r = await ApiClient.dio.put(
      '/v1/employee/profile/certifications',
      data: {'certification_ids': certificationIds},
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// Worker's own rating summary + recent feedback. Powers the stars
  /// beneath the avatar on the profile screen and the rating-history card.
  static Future<Map<String, dynamic>> getMyRating() async {
    final r = await ApiClient.dio.get('/v1/employee/profile/rating');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// Monthly earnings rollup: current_month, previous_month, total. Sums
  /// proposed_amount over approved applications, bucketed by event start.
  static Future<Map<String, dynamic>> getEarnings() async {
    final r = await ApiClient.dio.get('/v1/employee/profile/earnings');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  // ---------- Events ----------

  /// Employee feed. `tab` is either 'offers' (matched, not applied yet) or
  /// 'shifts' (events I have an application on). Pass match=false on the
  /// offers tab to bypass the matcher (debug).
  static Future<List<dynamic>> browseEvents({String tab = 'offers', bool match = true}) async {
    final r = await ApiClient.dio.get('/v1/employee/events', queryParameters: {
      'tab': tab,
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

  /// Cancels an application. Server returns 409 with errorCode
  /// 'CANCELLATION_POLICY_LATE' when within 48 h of the shift; the UI
  /// shows the policy popup and retries with `force: true`.
  static Future<void> cancelApplication(int id, {bool force = false}) async {
    final r = await ApiClient.dio.delete(
      '/v1/employee/applications/$id',
      queryParameters: force ? {'force': 'true'} : null,
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
  }

  // ---------- Notifications inbox ----------

  /// `type` filters to a single NotificationType (e.g. 'event_message'
  /// for broadcast announcements only).
  static Future<List<dynamic>> listNotifications({bool? unread, String? type}) async {
    final r = await ApiClient.dio.get('/v1/employee/notifications', queryParameters: {
      if (unread == true) 'unread': 'true',
      if (type != null) 'type': type,
      'page_size': 100,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }

  static Future<void> markNotificationRead(int id) async {
    final r = await ApiClient.dio.post('/v1/employee/notifications/$id/read');
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
