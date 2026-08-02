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

  test('a custom name can enter both category lists', () {
    final store = testStore();

    expect(store.addCustom('Robin', NameCategory.values.toSet()), isTrue);
    store.startFaceoff();

    expect(store.faceoffNames[NameCategory.girls], contains('Robin'));
    expect(store.faceoffNames[NameCategory.boys], contains('Robin'));
  });

  test(
    'encrypted updates merge valid custom names without duplication',
    () async {
      final creator = testStore();
      await creator.ensureSession();
      final partner = testStore();
      await partner.importInvite(creator.invitePayload());
      expect(partner.addCustom('Robin', {NameCategory.girls}), isTrue);

      await creator.importVoteUpdate(await partner.voteUpdatePayload());

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
      for (final store in [first, second]) {
        for (final candidate in store.candidates.where(
          (candidate) => candidate.rank <= 2,
        )) {
          store.votes[candidate.id] = VoteValue.yes;
          store.partnerVotes[candidate.id] = VoteValue.yes;
        }
        store.startFaceoff();
        while (store.currentFaceoff != null) {
          store.chooseFaceoff(store.currentFaceoff!.left);
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

    expect(await creator.confirmationCode(), await partner.confirmationCode());
  });

  test('a paired device can undo an unsynchronized Face-off choice', () async {
    final creator = testStore();
    await creator.ensureSession();
    final partner = testStore();
    await partner.importInvite(creator.invitePayload());
    await creator.importPairAccept(await partner.pairAcceptPayload());
    for (final candidate in creator.candidates.where(
      (candidate) => candidate.rank <= 2,
    )) {
      creator.votes[candidate.id] = VoteValue.yes;
      creator.partnerVotes[candidate.id] = VoteValue.yes;
    }
    creator.startFaceoff();
    final pairing = creator.currentFaceoff!;

    creator.chooseFaceoff(pairing.left);
    creator.undoFaceoffVote();

    expect(creator.currentFaceoff!.left, pairing.left);
    expect(creator.localFaceoffVotes, isEmpty);
  });
}
