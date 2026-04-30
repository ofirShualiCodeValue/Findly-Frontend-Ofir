// Smoke test — boots the app and verifies it renders without errors.
import 'package:flutter_test/flutter_test.dart';
import 'package:findly_app/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const FindlyApp());
    expect(find.byType(FindlyApp), findsOneWidget);
  });
}
