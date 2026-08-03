import 'package:flutter_test/flutter_test.dart';
import 'package:name_that_baby/core/domain.dart';
import 'package:name_that_baby/core/session_store.dart';

class _MemorySecrets implements SessionSecretStore {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _MemoryState implements SessionStateStore {
  String? value;
  @override
  Future<void> delete() async => value = null;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String state) async => value = state;
}

SessionStore _device() =>
    SessionStore(secrets: _MemorySecrets(), state: _MemoryState());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'two devices converge after QR voting and every Face-off round',
    runTwoDeviceSimulation,
  );
}

Future<void> runTwoDeviceSimulation() async {
  final first = _device();
  await first.ensureSession();
  final second = _device();
  await second.importInvite(first.invitePayload());
  await first.importPairAccept(await second.pairAcceptPayload());

  expect(
    first.candidates.map(
      (candidate) =>
          '${candidate.id}:${candidate.name}:${candidate.category.name}',
    ),
    second.candidates.map(
      (candidate) =>
          '${candidate.id}:${candidate.name}:${candidate.category.name}',
    ),
  );
  for (var index = 0; index < first.candidates.length; index++) {
    final id = first.candidates[index].id;
    first.votes[id] = VoteValue.yes;
    second.votes[id] = index.isEven ? VoteValue.yes : VoteValue.maybe;
  }
  // Product order: choosing sync, then each partner adds locally, then both
  // custom-name packets are exchanged before Face-off can snapshot entries.
  expect(await first.addCustom('Robin', NameCategory.values.toSet()), isTrue);
  expect(await second.addCustom('Arden', NameCategory.values.toSet()), isTrue);
  await first.importVoteUpdate(await second.voteUpdatePayload());
  await second.importVoteUpdate(await first.voteUpdatePayload());
  await first.importCustomNamesUpdate(await second.customNamesUpdatePayload());
  await second.importCustomNamesUpdate(await first.customNamesUpdatePayload());

  for (final device in [first, second]) {
    device.startFaceoff();
  }
  expect(
    first.faceoffPairings.map(pairKeyFromPairing),
    second.faceoffPairings.map(pairKeyFromPairing),
  );

  while (!first.faceoffDone) {
    for (final device in [first, second]) {
      while (device.currentFaceoff != null) {
        await device.chooseFaceoff(device.currentFaceoff!.left);
      }
    }
    final firstPacket = await first.faceoffUpdatePayload();
    final secondPacket = await second.faceoffUpdatePayload();
    // Deliberately alternate import order; convergence must not depend on it.
    await second.importFaceoffUpdate(firstPacket);
    await first.importFaceoffUpdate(secondPacket);
  }

  for (final category in NameCategory.values) {
    expect(
      first.results(category).map((result) => result.name),
      second.results(category).map((result) => result.name),
    );
    expect(first.faceoffScores[category], second.faceoffScores[category]);
  }
}

String pairKeyFromPairing(Pairing pairing) =>
    pairKey(pairing.left, pairing.right);
