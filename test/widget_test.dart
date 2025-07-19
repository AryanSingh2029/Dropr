import 'package:flutter_test/flutter_test.dart';
import 'package:campus_buddy/main.dart'; // import your actual app

void main() {
  testWidgets('DropBuddyApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DropBuddyApp());

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
