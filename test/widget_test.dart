import 'package:flutter_test/flutter_test.dart';
import 'package:name_that_baby/core/session_store.dart';
import 'package:name_that_baby/main.dart';

void main() {
  testWidgets('welcome makes the private offline promise', (tester) async {
    await tester.pumpWidget(NameThatBaby(store: SessionStore()));
    expect(find.text('NameThatBaby'), findsOneWidget);
    expect(find.text('Private & offline'), findsOneWidget);
  });
}
