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

  static Future<List<dynamic>> listApplications(int eventId, {String? status}) async {
    final r = await ApiClient.dio.get('/v1/employer/events/$eventId/applications', queryParameters: {
      if (status != null) 'status': status,
    });
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
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
