import 'package:flutter_test/flutter_test.dart';
import 'package:journal/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JournalApp());
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Todo List'), findsOneWidget);
  });
}
