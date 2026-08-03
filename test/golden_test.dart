import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:name_that_baby/app/theme.dart';
import 'package:name_that_baby/core/domain.dart';
import 'package:name_that_baby/core/session_store.dart';
import 'package:name_that_baby/main.dart';

class _MemoryState implements SessionStateStore {
  @override
  Future<void> delete() async {}

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String state) async {}
}

SessionStore _store() => SessionStore(state: _MemoryState());

Widget _screen(
  Widget child, {
  double textScale = 1,
  bool reducedMotion = false,
}) => MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Palette.cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.forest,
      surface: Palette.surface,
    ),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: Palette.forest,
      displayColor: Palette.forest,
    ),
  ),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reducedMotion,
    ),
    child: child,
  ),
);

Future<void> _golden(
  WidgetTester tester,
  String name,
  Widget child, {
  required Size size,
  double textScale = 1,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _screen(child, textScale: textScale, reducedMotion: reducedMotion),
  );
  await tester.pump();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void _sharedVotes(SessionStore store, {int count = 3}) {
  for (final candidate in store.candidates.take(count)) {
    store.votes[candidate.id] = VoteValue.yes;
    store.partnerVotes[candidate.id] = VoteValue.yes;
  }
}

void main() {
  testWidgets('Home compact phone, large text, reduced motion', (tester) async {
    await _golden(
      tester,
      'home_compact_large_text',
      Home(store: _store(), go: (_) {}),
      size: const Size(320, 568),
      textScale: 1.3,
      reducedMotion: true,
    );
  });

  testWidgets('Choosing iPhone', (tester) async {
    await _golden(
      tester,
      'choosing_iphone',
      Choosing(store: _store(), done: () {}),
      size: const Size(390, 844),
    );
  });

  testWidgets('Shared shortlist Android', (tester) async {
    final store = _store();
    _sharedVotes(store);
    await _golden(
      tester,
      'shortlist_android',
      Shortlist(store: store, custom: () {}, faceoff: () {}),
      size: const Size(412, 915),
    );
  });

  testWidgets('Add custom names iPhone', (tester) async {
    final store = _store()
      ..customGirls.add('Arden')
      ..customBoys.add('River');
    await _golden(
      tester,
      'custom_names_iphone',
      CustomNames(store: store, done: () {}),
      size: const Size(390, 844),
    );
  });

  testWidgets('Face-off Android', (tester) async {
    final store = _store();
    _sharedVotes(store, count: 3);
    store.startFaceoff();
    await _golden(
      tester,
      'faceoff_android',
      Faceoff(store: store, done: () {}),
      size: const Size(412, 915),
    );
  });

  testWidgets('Final results iPhone', (tester) async {
    final store = _store();
    _sharedVotes(store, count: 3);
    store.startFaceoff();
    while (!store.faceoffDone) {
      store.chooseFaceoff(store.currentFaceoff!.left);
    }
    await _golden(
      tester,
      'results_iphone',
      Results(store: store, home: () {}),
      size: const Size(390, 844),
    );
  });
}
