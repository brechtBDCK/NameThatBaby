import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:name_that_baby/core/session_store.dart';
import 'package:name_that_baby/core/domain.dart';
import 'package:name_that_baby/main.dart';

void main() {
  testWidgets('welcome makes the private offline promise', (tester) async {
    await tester.pumpWidget(NameThatBaby(store: SessionStore()));
    expect(find.text('NameThatBaby'), findsOneWidget);
    expect(find.text('Private & offline'), findsOneWidget);
  });

  testWidgets('bundled data coverage is available locally', (tester) async {
    await tester.pumpWidget(MaterialApp(home: DataSources(back: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Name data & coverage'), findsOneWidget);
    expect(find.textContaining('fixture data'), findsOneWidget);
  });

  testWidgets('choosing card supports a left swipe for No', (tester) async {
    final store = SessionStore();
    final candidate = store.current!;
    await tester.pumpWidget(
      MaterialApp(
        home: Choosing(store: store, done: () {}),
      ),
    );

    final card = find.ancestor(
      of: find.text(candidate.name),
      matching: find.byType(GestureDetector),
    );
    await tester.fling(card, const Offset(-600, 0), 1200);
    await tester.pump();

    expect(store.votes[candidate.id], VoteValue.no);
  });
}
