import 'client.dart';

/// Shared taxonomy lookups usable from both employer and employee flows.
class SharedApi {
  /// Event TYPES (חתונה, בר מצווה …) — employer side.
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

  /// Service INDUSTRIES (הפקת אירועים, קייטרינג …) with sub_categories[]
  /// nested. Used by the employee registration flow.
  static Future<List<dynamic>> industries() async {
    final r = await ApiClient.dio.get('/v1/shared/industries');
    if (r.statusCode != 200) throw ApiException.fromResponse(r);
    return List<dynamic>.from(r.data['data']);
  }
}
