import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:name_that_baby/core/session_store.dart';
import 'package:name_that_baby/core/domain.dart';
import 'package:name_that_baby/app/shell.dart';
import 'package:name_that_baby/main.dart';

void main() {
  testWidgets('welcome makes the private offline promise', (tester) async {
    await tester.pumpWidget(NameThatBaby(store: SessionStore()));
    expect(find.text('NameThatBaby'), findsOneWidget);
    expect(find.text('Private & offline'), findsOneWidget);
    expect(find.byType(BrandMark), findsOneWidget);
  });

  testWidgets('camera recovery explains how to reopen scanning', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CameraRecovery()));

    expect(
      find.text('Camera access is needed to scan a code.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('enable Camera in Android Settings'),
      findsOneWidget,
    );
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
    await tester.pump(const Duration(milliseconds: 999));
    expect(store.votes[candidate.id], isNull);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(store.votes[candidate.id], VoteValue.no);
  });

  testWidgets('choosing visibly identifies the active category', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Choosing(store: SessionStore(), done: () {}),
      ),
    );

    expect(find.textContaining('Girls ·'), findsOneWidget);
  });

  testWidgets('choosing can return home and resume later', (tester) async {
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Choosing(
          store: SessionStore(),
          done: () {},
          back: () => returned = true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Back'));

    expect(returned, isTrue);
  });

  testWidgets('home exposes shared favorites after vote sync', (tester) async {
    final store = SessionStore()..partnerVotesReceived = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Home(store: store, go: (_) {}),
      ),
    );

    expect(find.text('View shared favorites'), findsOneWidget);
  });

  testWidgets('home lets each name group resume separately', (tester) async {
    NameCategory? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Home(
          store: SessionStore(),
          go: (_) {},
          choose: (category) => selected = category,
        ),
      ),
    );

    await tester.tap(find.text('Continue choosing boy names'));
    expect(selected, NameCategory.boys);
  });

  testWidgets('sync has an exit back to home', (tester) async {
    var exited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SyncVotes(
          store: SessionStore(),
          done: () {},
          scan: () {},
          back: () => exited = true,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Back'));
    expect(exited, isTrue);
  });

  testWidgets('custom-name sync reports bidirectional status', (tester) async {
    final store = SessionStore()..partnerParticipantId = 'partner';
    await tester.pumpWidget(
      MaterialApp(
        home: SyncVotes(store: store, custom: true, done: () {}, scan: () {}),
      ),
    );
    expect(find.textContaining('Both phones must exchange'), findsOneWidget);
    expect(find.textContaining('Your code: not sent'), findsOneWidget);
  });

  testWidgets('home offers an in-progress Face-off resume action', (
    tester,
  ) async {
    final store = SessionStore();
    for (final candidate in store.candidates.take(2)) {
      store.votes[candidate.id] = VoteValue.yes;
      store.partnerVotes[candidate.id] = VoteValue.yes;
    }
    store.startFaceoff();
    await tester.pumpWidget(
      MaterialApp(
        home: Home(store: store, go: (_) {}),
      ),
    );

    expect(find.text('Resume Face-off'), findsOneWidget);
  });

  testWidgets('results shows at most ten names per category', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = SessionStore();
    store.categories
      ..clear()
      ..add(NameCategory.girls);
    final names = List.generate(11, (index) => 'Name $index');
    store.faceoffNames[NameCategory.girls] = names;
    store.faceoffScores[NameCategory.girls] = {
      for (var index = 0; index < names.length; index++) names[index]: index,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Results(store: store, home: () {}),
      ),
    );

    expect(find.byType(CircleAvatar), findsNWidgets(10));
  });
}
