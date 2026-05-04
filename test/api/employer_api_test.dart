// API tests for EmployerApi. We don't hit a real server — instead, we
// install http_mock_adapter on the Dio used by ApiClient and assert on
// (a) the request URL/payload and (b) the parsed return value.

import 'package:findly_app/api/client.dart';
import 'package:findly_app/api/employer_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late DioAdapter adapter;

  setUp(() {
    // Replace the Dio's HTTP adapter so requests are intercepted in-process.
    adapter = DioAdapter(dio: ApiClient.dio);
  });

  group('EmployerApi.rateWorker', () {
    test('PUTs the rating + comment and returns the parsed payload', () async {
      adapter.onPut(
        '/v1/employer/events/7/applications/22/rating',
        (server) => server.reply(200, {
          'code': 200,
          'message': 'ok',
          'data': {
            'application_id': 22,
            'worker_user_id': 33,
            'rating': 5,
            'comment': 'amazing',
            'worker_rating': {'avg': 4.7, 'count': 12},
          },
        }),
        data: {'rating': 5, 'comment': 'amazing'},
      );

      final res = await EmployerApi.rateWorker(7, 22, rating: 5, comment: 'amazing');

      expect(res['rating'], 5);
      expect(res['worker_rating']['avg'], 4.7);
      expect(res['worker_rating']['count'], 12);
    });

    test('throws ApiException on 4xx with the server message', () async {
      adapter.onPut(
        '/v1/employer/events/7/applications/22/rating',
        (server) => server.reply(409, {
          'code': 409,
          'message': 'The shift has not ended yet',
          'data': null,
        }),
        data: {'rating': 5},
      );

      expect(
        () => EmployerApi.rateWorker(7, 22, rating: 5),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 409)
              .having((e) => e.message, 'message', 'The shift has not ended yet'),
        ),
      );
    });
  });

  group('EmployerApi.getApplication', () {
    test('GETs the full applicant payload and parses it', () async {
      adapter.onGet(
        '/v1/employer/events/7/applications/22',
        (server) => server.reply(200, {
          'code': 200,
          'message': 'ok',
          'data': {
            'application': {
              'id': 22,
              'status': 'pending',
              'proposed_amount': '500',
              'note': 'available',
              'created_at': '2026-04-01T10:00:00Z',
              'decided_at': null,
            },
            'applicant': {
              'id': 33,
              'full_name': 'דנה כהן',
              'phone': '+972500000000',
              'email': 'dana@example.com',
              'profile': {
                'avatar_url': '/uploads/a.jpg',
                'date_of_birth': '1995-04-12',
                'work_status': 'freelancer',
                'home_city': 'תל אביב',
                'location_range_km': 30,
                'base_hourly_rate': '60',
              },
              'industries': [
                {'id': 1, 'name': 'אירועים', 'slug': 'events'}
              ],
              'industry_sub_categories': [
                {'id': 11, 'industry_id': 1, 'name': 'הפקה', 'slug': 'production'},
                {'id': 12, 'industry_id': 1, 'name': 'צילום', 'slug': 'photo'},
              ],
            },
            'rating': {
              'avg': 4.5,
              'count': 2,
              'history': [
                {
                  'id': 7,
                  'rating': 5,
                  'comment': 'מצוינת',
                  'created_at': '2026-03-01T00:00:00Z',
                  'event': {'id': 1, 'name': 'חתונה'},
                }
              ],
            },
          },
        }),
      );

      final res = await EmployerApi.getApplication(7, 22);

      expect(res['applicant']['full_name'], 'דנה כהן');
      expect(res['applicant']['profile']['work_status'], 'freelancer');
      expect((res['applicant']['industry_sub_categories'] as List).length, 2);
      expect(res['rating']['avg'], 4.5);
      expect(res['rating']['history'][0]['event']['name'], 'חתונה');
    });

    test('throws ApiException on 404', () async {
      adapter.onGet(
        '/v1/employer/events/7/applications/999',
        (server) => server.reply(404, {
          'code': 404,
          'message': 'Application not found',
          'data': null,
        }),
      );

      expect(
        () => EmployerApi.getApplication(7, 999),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 404),
        ),
      );
    });
  });

  group('EmployerApi.decideApplication', () {
    test('PATCHes status + note', () async {
      adapter.onPatch(
        '/v1/employer/events/7/applications/22',
        (server) => server.reply(200, {
          'code': 200,
          'message': 'ok',
          'data': {'id': 22, 'status': 'approved'},
        }),
        data: {'status': 'approved', 'note': 'great fit'},
      );

      final res = await EmployerApi.decideApplication(7, 22, 'approved', note: 'great fit');
      expect(res['status'], 'approved');
    });
  });
}
