import 'client.dart';

class EmployeeApi {
  static Future<List<dynamic>> browseEvents({int? areaId, int? categoryId}) async {
    final r = await ApiClient.dio.get('/v1/employee/events', queryParameters: {
      if (areaId != null) 'area_id': areaId,
      if (categoryId != null) 'category_id': categoryId,
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
}
