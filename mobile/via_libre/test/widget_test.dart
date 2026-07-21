import 'package:flutter_test/flutter_test.dart';
import 'package:via_libre/main.dart';

void main() {
  testWidgets('App loads successfully smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ViaLibreApp());

    // Verify that our app header text is present.
    expect(find.text('Vía Libre'), findsOneWidget);
  });
}
