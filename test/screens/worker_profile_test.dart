// Widget test for WorkerProfileScreen. Verifies that the rating stars,
// chips and approve/reject buttons render correctly given a known
// API payload (Dio is intercepted in-process — no network).

import 'package:findly_app/api/client.dart';
import 'package:findly_app/screens/employer/worker_profile.dart';
import 'package:findly_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  // The profile screen is taller than a default phone — give the test
  // surface enough vertical room so the bottom buttons + history rows
  // are not offstage when finders search.
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: buildFindlyTheme(),
      locale: const Locale('he'),
      builder: (context, c) => Directionality(
        textDirection: TextDirection.rtl,
        child: c ?? const SizedBox(),
      ),
      home: child,
    ),
  );
  // Let the FutureBuilder/initial GET resolve.
  await tester.pumpAndSettle();
}

const _payload = {
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
      'avatar_url': null,
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
};

void main() {
  setUpAll(() async {
    // DateFormat('he') is used in the rating history — initialize locale data
    // before any test pumps the screen.
    await initializeDateFormatting('he', null);
  });

  late DioAdapter adapter;
  setUp(() {
    adapter = DioAdapter(dio: ApiClient.dio);
  });

  testWidgets('renders applicant header with name and rating summary', (tester) async {
    adapter.onGet(
      '/v1/employer/events/7/applications/22',
      (server) => server.reply(200, {'code': 200, 'message': 'ok', 'data': _payload}),
    );

    await _pump(
      tester,
      const WorkerProfileScreen(eventId: 7, applicationId: 22, canDecide: true),
    );

    expect(find.text('דנה כהן'), findsOneWidget);
    expect(find.text('4.5 (2)'), findsOneWidget);
  });

  testWidgets('renders specialty chips from industry_sub_categories', (tester) async {
    adapter.onGet(
      '/v1/employer/events/7/applications/22',
      (server) => server.reply(200, {'code': 200, 'message': 'ok', 'data': _payload}),
    );

    await _pump(
      tester,
      const WorkerProfileScreen(eventId: 7, applicationId: 22, canDecide: true),
    );

    expect(find.text('הפקה'), findsOneWidget);
    expect(find.text('צילום'), findsOneWidget);
  });

  testWidgets('shows approve + reject buttons when canDecide=true and status=pending', (tester) async {
    adapter.onGet(
      '/v1/employer/events/7/applications/22',
      (server) => server.reply(200, {'code': 200, 'message': 'ok', 'data': _payload}),
    );

    await _pump(
      tester,
      const WorkerProfileScreen(eventId: 7, applicationId: 22, canDecide: true),
    );

    expect(find.text('אישור'), findsOneWidget);
    expect(find.text('דחייה'), findsOneWidget);
  });

  testWidgets('hides approve/reject when canDecide=false', (tester) async {
    adapter.onGet(
      '/v1/employer/events/7/applications/22',
      (server) => server.reply(200, {'code': 200, 'message': 'ok', 'data': _payload}),
    );

    await _pump(
      tester,
      const WorkerProfileScreen(eventId: 7, applicationId: 22, canDecide: false),
    );

    expect(find.text('אישור'), findsNothing);
    expect(find.text('דחייה'), findsNothing);
  });

  testWidgets('hides approve/reject when application is not pending', (tester) async {
    final approvedPayload = Map<String, dynamic>.from(_payload);
    approvedPayload['application'] =
        {...(_payload['application'] as Map), 'status': 'approved'};

    adapter.onGet(
      '/v1/employer/events/7/applications/22',
      (server) => server.reply(200, {'code': 200, 'message': 'ok', 'data': approvedPayload}),
    );

    await _pump(
      tester,
      const WorkerProfileScreen(eventId: 7, applicationId: 22, canDecide: true),
    );

    expect(find.text('אישור'), findsNothing);
    expect(find.text('דחייה'), findsNothing);
  });

  testWidgets('shows error view when API returns 4xx', (tester) async {
    adapter.onGet(
      '/v1/employer/events/7/applications/22',
      (server) => server.reply(404, {'code': 404, 'message': 'Application not found', 'data': null}),
    );

    await _pump(
      tester,
      const WorkerProfileScreen(eventId: 7, applicationId: 22, canDecide: true),
    );

    expect(find.text('Application not found'), findsOneWidget);
  });

  testWidgets('shows "אין דירוג" when avg is null', (tester) async {
    final noRatingPayload = Map<String, dynamic>.from(_payload);
    noRatingPayload['rating'] = {'avg': null, 'count': 0, 'history': []};

    adapter.onGet(
      '/v1/employer/events/7/applications/22',
      (server) => server.reply(200, {'code': 200, 'message': 'ok', 'data': noRatingPayload}),
    );

    await _pump(
      tester,
      const WorkerProfileScreen(eventId: 7, applicationId: 22, canDecide: true),
    );

    expect(find.text('אין דירוג'), findsOneWidget);
    expect(find.text('אין דירוגים קודמים'), findsOneWidget);
  });
}
