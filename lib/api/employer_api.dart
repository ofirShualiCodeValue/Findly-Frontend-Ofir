import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'client.dart';

class EmployerApi {
  static Future<Map<String, dynamic>> getProfile() async {
    final r = await ApiClient.dio.get('/v1/employer/profile');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> patchProfile(Map<String, dynamic> body) async {
    final r = await ApiClient.dio.patch('/v1/employer/profile', data: body);
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// First-time post-signup completion form (single-shot). Required for
  /// the system to flip `business.is_complete` to true.
  static Future<Map<String, dynamic>> completeRegistration({
    String? fullName,
    required String businessName,
    String? ownerName,
    String? vatNumber,
    String? contactEmail,
    required String address,
    required List<int> activityAreaIds,
    required List<int> eventCategoryIds,
    required List<int> industryIds,
  }) async {
    final r = await ApiClient.dio.post('/v1/employer/profile/complete', data: {
      if (fullName != null) 'full_name': fullName,
      'business_name': businessName,
      if (ownerName != null) 'owner_name': ownerName,
      if (vatNumber != null) 'vat_number': vatNumber,
      if (contactEmail != null) 'contact_email': contactEmail,
      'address': address,
      'activity_area_ids': activityAreaIds,
      'event_category_ids': eventCategoryIds,
      'industry_ids': industryIds,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> setActivityAreas(List<int> areaIds) async {
    final r = await ApiClient.dio.put('/v1/employer/profile/activity-areas',
        data: {'area_ids': areaIds});
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> setEventCategories(List<int> categoryIds) async {
    final r = await ApiClient.dio.put('/v1/employer/profile/event-categories',
        data: {'category_ids': categoryIds});
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> uploadLogo(XFile file) async {
    final MultipartFile mp = kIsWeb
        ? MultipartFile.fromBytes(await file.readAsBytes(), filename: file.name)
        : await MultipartFile.fromFile(file.path, filename: file.name);
    final form = FormData.fromMap({'file': mp});
    final r = await ApiClient.dio.post('/v1/employer/profile/logo', data: form);
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<List<dynamic>> listEvents({String? status}) async {
    final r = await ApiClient.dio.get('/v1/employer/events', queryParameters: {
      if (status != null) 'status': status,
      'page_size': 100,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> getEvent(int id) async {
    final r = await ApiClient.dio.get('/v1/employer/events/$id');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> createEvent(Map<String, dynamic> body) async {
    final r = await ApiClient.dio.post('/v1/employer/events', data: body);
    if (r.statusCode != 201) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> updateEvent(int id, Map<String, dynamic> body) async {
    final r = await ApiClient.dio.patch('/v1/employer/events/$id', data: body);
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<void> cancelEvent(int id) async {
    final r = await ApiClient.dio.delete('/v1/employer/events/$id');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
  }

  /// Full applicant profile + ratings history for the "worker profile"
  /// modal the employer opens before approve/reject.
  static Future<Map<String, dynamic>> getApplication(int eventId, int applicationId) async {
    final r = await ApiClient.dio.get(
      '/v1/employer/events/$eventId/applications/$applicationId',
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// `sortBy` is one of 'created_at' (default) | 'price' | 'rating'.
  static Future<List<dynamic>> listApplications(
    int eventId, {
    String? status,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? sortBy,
  }) async {
    final r = await ApiClient.dio.get('/v1/employer/events/$eventId/applications', queryParameters: {
      if (status != null) 'status': status,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (minRating != null) 'min_rating': minRating,
      if (sortBy != null) 'sort_by': sortBy,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }

  // ---------- Shifts ----------

  static Future<List<dynamic>> listShifts(int eventId) async {
    final r = await ApiClient.dio.get('/v1/employer/events/$eventId/shifts');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }

  /// Throws ApiException with errorCode 'SHIFT_DURATION_INVALID' when the
  /// duration is outside 6–12 hours; the data carries
  /// {min_hours, max_hours, actual_hours} for the popup.
  static Future<Map<String, dynamic>> createShift(
    int eventId, {
    required DateTime startAt,
    required DateTime endAt,
    String? contactPersonName,
    String? contactPersonPhone,
    String? notes,
    List<Map<String, dynamic>> staffingRequirements = const [],
  }) async {
    final r = await ApiClient.dio.post(
      '/v1/employer/events/$eventId/shifts',
      data: {
        'start_at': startAt.toUtc().toIso8601String(),
        'end_at': endAt.toUtc().toIso8601String(),
        if (contactPersonName != null) 'contact_person_name': contactPersonName,
        if (contactPersonPhone != null) 'contact_person_phone': contactPersonPhone,
        if (notes != null) 'notes': notes,
        if (staffingRequirements.isNotEmpty) 'staffing_requirements': staffingRequirements,
      },
    );
    if (r.statusCode != 201) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<void> deleteShift(int eventId, int shiftId) async {
    final r = await ApiClient.dio.delete('/v1/employer/events/$eventId/shifts/$shiftId');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
  }

  /// Capacity status for an event, including a per-shift / per-role breakdown.
  static Future<Map<String, dynamic>> getCapacity(int eventId) async {
    final r = await ApiClient.dio.get('/v1/employer/events/$eventId/capacity');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// Rate the worker on an approved application after the shift ended.
  /// Idempotent — re-calling updates the rating.
  static Future<Map<String, dynamic>> rateWorker(
    int eventId,
    int applicationId, {
    required int rating,
    String? comment,
  }) async {
    final r = await ApiClient.dio.put(
      '/v1/employer/events/$eventId/applications/$applicationId/rating',
      data: {
        'rating': rating,
        if (comment != null) 'comment': comment,
      },
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> decideApplication(int eventId, int appId, String status, {String? note}) async {
    final r = await ApiClient.dio.patch('/v1/employer/events/$eventId/applications/$appId', data: {
      'status': status,
      if (note != null) 'note': note,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  /// Approve / reject the worker's reported hours.
  /// Allowed only when `hours_status == 'pending_approval'` — the worker
  /// has reported hours and is waiting for the employer's decision.
  /// `status` must be 'approved' or 'rejected'.
  static Future<Map<String, dynamic>> decideHours(
    int eventId,
    int applicationId, {
    required String status,
  }) async {
    final r = await ApiClient.dio.patch(
      '/v1/employer/events/$eventId/applications/$applicationId/hours',
      data: {'status': status},
    );
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<Map<String, dynamic>> sendNotification(int eventId, String title, String? body) async {
    final r = await ApiClient.dio.post('/v1/employer/events/$eventId/notifications', data: {
      'title': title,
      if (body != null) 'body': body,
    });
    if (r.statusCode != 201) throw ApiException.fromResponse(r);
    return Map<String, dynamic>.from(r.data['data']);
  }

  static Future<List<dynamic>> notificationHistory(int eventId) async {
    final r = await ApiClient.dio.get('/v1/employer/events/$eventId/notifications');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }

  // ---------- Employer notifications inbox ----------

  static Future<List<dynamic>> listNotifications({bool? unread}) async {
    final r = await ApiClient.dio.get('/v1/employer/notifications', queryParameters: {
      if (unread == true) 'unread': 'true',
      'page_size': 100,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }

  static Future<void> markNotificationRead(int id) async {
    final r = await ApiClient.dio.post('/v1/employer/notifications/$id/read');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
  }

  static Future<List<dynamic>> getCategories() async {
    final r = await ApiClient.dio.get('/v1/employer/categories');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }

  static Future<List<dynamic>> getAreas() async {
    final r = await ApiClient.dio.get('/v1/employer/areas');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }
}
