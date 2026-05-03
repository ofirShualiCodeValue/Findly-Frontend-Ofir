import 'client.dart';

/// Shared taxonomy lookups (industries / activity areas) usable from
/// both employer and employee flows.
class SharedApi {
  static Future<List<dynamic>> categories() async {
    final r = await ApiClient.dio.get('/v1/shared/categories');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }

  static Future<List<dynamic>> areas() async {
    final r = await ApiClient.dio.get('/v1/shared/areas');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }
}
