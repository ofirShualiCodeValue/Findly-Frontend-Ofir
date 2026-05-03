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
