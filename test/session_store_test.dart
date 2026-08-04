import 'package:flutter_test/flutter_test.dart';
import 'package:name_that_baby/core/domain.dart';
import 'package:name_that_baby/core/qr_protocol.dart';
import 'package:name_that_baby/core/session_store.dart';

class MemorySecrets implements SessionSecretStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class MemoryState implements SessionStateStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String state) async => value = state;
}

class DelayedState extends MemoryState {
  int writes = 0;

  @override
  Future<void> write(String state) async {
    writes++;
    // The first mutation takes longer: an unsafe fire-and-forget implementation
    // would let it overwrite the newer snapshot.
    await Future<void>.delayed(Duration(milliseconds: writes == 1 ? 20 : 1));
    value = state;
  }
}

class FailingState extends MemoryState {
  bool failWrites = false;

  @override
  Future<void> write(String state) {
    if (failWrites) return Future<void>.error(StateError('disk unavailable'));
    return super.write(state);
  }
}

class MemoryLegacyState implements LegacySessionStateStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;
}

SessionStore testStore({
  MemorySecrets? secrets,
  MemoryState? state,
  String datasetHash = 'development-fixture-v1',
}) => SessionStore(
  secrets: secrets ?? MemorySecrets(),
  state: state ?? MemoryState(),
  datasetHash: datasetHash,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupt encrypted state is retained for explicit recovery', () async {
    final state = MemoryState()..value = '{not valid json';
    final store = testStore(state: state);

    await store.restore();

    expect(store.restoreError, isNotNull);
    expect(state.value, isNotNull);
  });

  test('legacy preferences state is encrypted then removed', () async {
    final secrets = MemorySecrets();
    final original = MemoryState();
    final writer = testStore(secrets: secrets, state: original);
    await writer.ensureSession();
    final legacy = MemoryLegacyState()..value = original.value;
    final encrypted = MemoryState();
    final restored = SessionStore(
      secrets: secrets,
      state: encrypted,
      legacyState: legacy,
    );

    await restored.restore();

    expect(restored.hasSession, isTrue);
    expect(encrypted.value, isNotNull);
    expect(legacy.value, isNull);
  });

  test('queued persistence retains the newest vote and undo', () async {
    final state = DelayedState();
    final secrets = MemorySecrets();
    final store = testStore(secrets: secrets, state: state);
    await store.ensureSession();
    final first = store.current!;
    await store.vote(VoteValue.yes);
    await store.undo();
    await store.vote(VoteValue.maybe);

    final resumed = testStore(secrets: secrets, state: state);
    await resumed.restore();
    expect(resumed.votes[first.id], VoteValue.maybe);
    expect(resumed.history, [first.id]);
  });

  test('queued persistence retains the newest Face-off state', () async {
    final state = DelayedState();
    final secrets = MemorySecrets();
    final store = testStore(secrets: secrets, state: state);
    for (final candidate in store.candidates.where(
      (candidate) => candidate.rank <= 2,
    )) {
      store.votes[candidate.id] = VoteValue.yes;
      store.partnerVotes[candidate.id] = VoteValue.yes;
    }
    store.startFaceoff();
    await store.chooseFaceoff(store.currentFaceoff!.left);
    final resumed = testStore(secrets: secrets, state: state);
    await resumed.restore();
    expect(resumed.faceoffStarted, isTrue);
    expect(resumed.faceoffRound, store.faceoffRound);
    expect(resumed.faceoffScores, store.faceoffScores);
  });

  test('private result notes survive a persisted resume', () async {
    final secrets = MemorySecrets();
    final state = MemoryState();
    final store = testStore(secrets: secrets, state: state);
    await store.ensureSession();
    await store.setPrivateNote(
      NameCategory.girls,
      'Elena',
      'Ask about family spelling',
    );
    final resumed = testStore(secrets: secrets, state: state);
    await resumed.restore();
    expect(
      resumed.privateNote(NameCategory.girls, 'Elena'),
      'Ask about family spelling',
    );
  });

  test('imports reject duplicate, stale, and wrong-partner packets', () async {
    final creator = testStore();
    await creator.ensureSession();
    final partner = testStore();
    await partner.importInvite(creator.invitePayload());
    await creator.importPairAccept(await partner.pairAcceptPayload());
    final first = await partner.voteUpdatePayload();
    await partner.vote(VoteValue.yes);
    final newest = await partner.voteUpdatePayload();
    await creator.importVoteUpdate(newest);
    await expectLater(
      creator.importVoteUpdate(newest),
      throwsA(isA<QrProtocolError>()),
    );
    await expectLater(
      creator.importVoteUpdate(first),
      throwsA(isA<QrProtocolError>()),
    );

    final stranger = testStore();
    await stranger.importInvite(creator.invitePayload());
    await expectLater(
      creator.importVoteUpdate(await stranger.voteUpdatePayload()),
      throwsA(isA<QrProtocolError>()),
    );
  });

  test('a failed import restores the existing choosing state', () async {
    final secrets = MemorySecrets();
    final state = FailingState();
    final creator = testStore(secrets: secrets, state: state);
    await creator.ensureSession();
    final partner = testStore();
    await partner.importInvite(creator.invitePayload());
    await creator.importPairAccept(await partner.pairAcceptPayload());
    final before = Map<int, VoteValue>.from(creator.partnerVotes);
    state.failWrites = true;
    await expectLater(
      creator.importVoteUpdate(await partner.voteUpdatePayload()),
      throwsA(isA<StateError>()),
    );
    expect(creator.partnerVotes, before);
    expect(creator.partnerVotesReceived, isFalse);
  });

  test('a failed import retains the last accepted replay boundary', () async {
    final state = FailingState();
    final creator = testStore(state: state);
    await creator.ensureSession();
    final partner = testStore();
    await partner.importInvite(creator.invitePayload());
    await creator.importPairAccept(await partner.pairAcceptPayload());
    final first = await partner.voteUpdatePayload();
    await creator.importVoteUpdate(first);
    await partner.vote(VoteValue.yes);
    state.failWrites = true;

    await expectLater(
      creator.importVoteUpdate(await partner.voteUpdatePayload()),
      throwsA(isA<StateError>()),
    );

    expect(creator.highestAcceptedSequence[partner.localParticipantId], 2);
  });

  test('a failed pairing acceptance leaves no partial partner state', () async {
    final state = FailingState();
    final creator = testStore(state: state);
    await creator.ensureSession();
    final partner = testStore();
    await partner.importInvite(creator.invitePayload());
    state.failWrites = true;

    await expectLater(
      creator.importPairAccept(await partner.pairAcceptPayload()),
      throwsA(isA<StateError>()),
    );

    expect(creator.partnerParticipantId, isNull);
    expect(creator.paired, isFalse);
    expect(creator.highestAcceptedSequence, isEmpty);
  });

  test('Face-off setup is not retained when its initial write fails', () async {
    final state = FailingState();
    final store = testStore(state: state);
    await store.addCustom('Robin', {NameCategory.girls});
    await store.addCustom('Arden', {NameCategory.girls});
    state.failWrites = true;

    await expectLater(store.startFaceoff(), throwsA(isA<StateError>()));

    expect(store.faceoffStarted, isFalse);
  });

  test('a failed Face-off import restores the active round', () async {
    final state = FailingState();
    final first = testStore(state: state);
    await first.ensureSession();
    final second = testStore();
    await second.importInvite(first.invitePayload());
    await first.importPairAccept(await second.pairAcceptPayload());
    await first.importCustomNamesUpdate(
      await second.customNamesUpdatePayload(),
    );
    await second.importCustomNamesUpdate(
      await first.customNamesUpdatePayload(),
    );
    for (final store in [first, second]) {
      for (final candidate in store.candidates.where(
        (candidate) => candidate.rank <= 2,
      )) {
        store.votes[candidate.id] = VoteValue.yes;
        store.partnerVotes[candidate.id] = VoteValue.yes;
      }
      store.startFaceoff();
      while (store.currentFaceoff != null) {
        await store.chooseFaceoff(store.currentFaceoff!.left);
      }
    }
    final round = first.faceoffRound;
    final pairings = [...first.faceoffPairings];
    state.failWrites = true;
    await expectLater(
      first.importFaceoffUpdate(await second.faceoffUpdatePayload()),
      throwsA(isA<StateError>()),
    );
    expect(first.faceoffRound, round);
    expect(
      first.faceoffPairings.map(
        (pairing) => pairKey(pairing.left, pairing.right),
      ),
      pairings.map((pairing) => pairKey(pairing.left, pairing.right)),
    );
    expect(first.partnerFaceoffVotes, isEmpty);
  });

  test('faceoff uses shared shortlist and produces category rankings', () {
    final store = testStore();
    for (final candidate in store.candidates.where(
      (candidate) => candidate.rank <= 2,
    )) {
      store.votes[candidate.id] = VoteValue.yes;
      store.partnerVotes[candidate.id] = VoteValue.yes;
    }

    store.startFaceoff();

    expect(store.faceoffNames[NameCategory.girls], ['Elena', 'Nora']);
    expect(store.faceoffNames[NameCategory.boys], ['Leo', 'Noah']);
    while (!store.faceoffDone) {
      store.chooseFaceoff(store.currentFaceoff!.left);
    }

    expect(store.results(NameCategory.girls).first.score, greaterThan(0));
    expect(store.results(NameCategory.boys).first.score, greaterThan(0));
    expect(store.faceoffRound, SessionStore.faceoffRoundCount - 1);
  });

  test('rejected names do not enter faceoff', () {
    final store = testStore();
    final candidate = store.candidates.first;
    store.votes[candidate.id] = VoteValue.yes;
    store.partnerVotes[candidate.id] = VoteValue.no;

    store.startFaceoff();

    expect(store.faceoffNames, isEmpty);
    expect(store.faceoffDone, isFalse);
  });

  test('faceoff requires two names in one category', () {
    final store = testStore();
    final candidate = store.candidates.first;
    store.votes[candidate.id] = VoteValue.yes;
    store.partnerVotes[candidate.id] = VoteValue.yes;

    expect(store.canStartFaceoff, isFalse);
    store.startFaceoff();

    expect(store.faceoffStarted, isFalse);
  });

  test('a custom name can enter both category lists', () async {
    final store = testStore();

    expect(await store.addCustom('Robin', NameCategory.values.toSet()), isTrue);
    expect(await store.addCustom('Arden', NameCategory.values.toSet()), isTrue);
    store.startFaceoff();

    expect(store.faceoffNames[NameCategory.girls], contains('Robin'));
    expect(store.faceoffNames[NameCategory.boys], contains('Robin'));
  });

  test('custom names can be removed only before Face-off starts', () async {
    final store = testStore();
    await store.addCustom('Robin', {NameCategory.girls});
    expect(await store.removeCustom('Robin', NameCategory.girls), isTrue);
    await store.addCustom('Robin', {NameCategory.girls});
    await store.addCustom('Arden', {NameCategory.girls});
    store.startFaceoff();
    expect(await store.removeCustom('Robin', NameCategory.girls), isFalse);
  });

  test(
    'encrypted updates merge valid custom names without duplication',
    () async {
      final creator = testStore();
      await creator.ensureSession();
      final partner = testStore();
      await partner.importInvite(creator.invitePayload());
      expect(await partner.addCustom('Robin', {NameCategory.girls}), isTrue);
      await creator.importCustomNamesUpdate(
        await partner.customNamesUpdatePayload(),
      );

      expect(creator.customGirls, ['Robin']);
      expect(creator.customBoys, isEmpty);
    },
  );

  test(
    'paired devices derive identical Face-off scores after round exchange',
    () async {
      final first = testStore();
      await first.ensureSession();
      final second = testStore();
      await second.importInvite(first.invitePayload());
      first.partnerParticipantId = second.localParticipantId;
      await first.importCustomNamesUpdate(
        await second.customNamesUpdatePayload(),
      );
      await second.importCustomNamesUpdate(
        await first.customNamesUpdatePayload(),
      );
      for (final store in [first, second]) {
        for (final candidate in store.candidates.where(
          (candidate) => candidate.rank <= 2,
        )) {
          store.votes[candidate.id] = VoteValue.yes;
          store.partnerVotes[candidate.id] = VoteValue.yes;
        }
        store.startFaceoff();
        while (store.currentFaceoff != null) {
          await store.chooseFaceoff(store.currentFaceoff!.left);
        }
        expect(store.faceoffRoundReady, isTrue);
      }

      final firstPacket = await first.faceoffUpdatePayload();
      final secondPacket = await second.faceoffUpdatePayload();
      await first.importFaceoffUpdate(secondPacket);
      await second.importFaceoffUpdate(firstPacket);

      expect(
        first.faceoffScores[NameCategory.girls],
        second.faceoffScores[NameCategory.girls],
      );
      expect(first.faceoffScores[NameCategory.girls]!.values, contains(3));
    },
  );

  test(
    'invite rejects a phone with a different bundled dataset hash',
    () async {
      final creator = testStore(datasetHash: 'dataset-a');
      await creator.ensureSession();
      final partner = testStore(datasetHash: 'dataset-b');

      await expectLater(
        partner.importInvite(creator.invitePayload()),
        throwsA(isA<QrProtocolError>()),
      );
    },
  );

  test('pair acceptance establishes matching confirmation codes', () async {
    final creator = testStore();
    await creator.ensureSession();
    final partner = testStore();
    await partner.importInvite(creator.invitePayload());

    await creator.importPairAccept(await partner.pairAcceptPayload());
    await creator.importCustomNamesUpdate(
      await partner.customNamesUpdatePayload(),
    );
    await partner.importCustomNamesUpdate(
      await creator.customNamesUpdatePayload(),
    );

    expect(await creator.confirmationCode(), await partner.confirmationCode());
  });

  test('a paired device can undo an unsynchronized Face-off choice', () async {
    final creator = testStore();
    await creator.ensureSession();
    final partner = testStore();
    await partner.importInvite(creator.invitePayload());
    await creator.importPairAccept(await partner.pairAcceptPayload());
    await creator.importCustomNamesUpdate(
      await partner.customNamesUpdatePayload(),
    );
    await partner.importCustomNamesUpdate(
      await creator.customNamesUpdatePayload(),
    );
    for (final candidate in creator.candidates.where(
      (candidate) => candidate.rank <= 2,
    )) {
      creator.votes[candidate.id] = VoteValue.yes;
      creator.partnerVotes[candidate.id] = VoteValue.yes;
    }
    creator.startFaceoff();
    final pairing = creator.currentFaceoff!;

    await creator.chooseFaceoff(pairing.left);
    await creator.undoFaceoffVote();

    expect(creator.currentFaceoff!.left, pairing.left);
    expect(creator.localFaceoffVotes, isEmpty);
  });
}
