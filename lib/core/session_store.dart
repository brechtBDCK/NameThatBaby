import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';
import 'qr_protocol.dart';

class SessionStore extends ChangeNotifier {
  SessionStore({FlutterSecureStorage? secrets})
    : _secrets = secrets ?? const FlutterSecureStorage();

  static const _stateKey = 'namethatbaby.session.state.v1';
  static const _secretKey = 'namethatbaby.session.secret.v1';
  final FlutterSecureStorage _secrets;
  final Set<String> countries = {'US', 'FR', 'NL'};
  final Set<NameCategory> categories = {NameCategory.girls, NameCategory.boys};
  final Map<int, VoteValue> votes = {};
  final Map<int, VoteValue> partnerVotes = {};
  final List<int> history = [];
  final List<String> customGirls = [];
  final List<String> customBoys = [];
  late final List<Candidate> candidates = _candidates();
  int seed = 20260731;
  String sessionId = '';
  List<int>? _secret;
  bool paired = false;
  bool partnerVotesReceived = false;
  int faceoffIndex = 0;
  int outgoingSequence = 0;
  final Set<int> appliedSequences = {};

  List<Candidate> get enabled => candidates
      .where((candidate) => categories.contains(candidate.category))
      .toList();
  List<Candidate> remaining(NameCategory category) => enabled
      .where(
        (candidate) =>
            candidate.category == category && !votes.containsKey(candidate.id),
      )
      .toList();
  Candidate? get current => enabled.cast<Candidate?>().firstWhere(
    (candidate) => candidate != null && !votes.containsKey(candidate.id),
    orElse: () => null,
  );
  double progress(NameCategory category) {
    final total = enabled
        .where((candidate) => candidate.category == category)
        .length;
    return total == 0 ? 0 : 1 - remaining(category).length / total;
  }

  bool get choosingDone => current == null;
  bool get hasSession => sessionId.isNotEmpty && _secret != null;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_stateKey);
    if (encoded == null) return;
    try {
      final state = (jsonDecode(encoded) as Map).cast<String, Object?>();
      countries
        ..clear()
        ..addAll((state['countries'] as List).cast<String>());
      categories
        ..clear()
        ..addAll(
          (state['categories'] as List).map(
            (value) => NameCategory.values.byName(value as String),
          ),
        );
      votes
        ..clear()
        ..addAll(
          (state['votes'] as Map).map(
            (key, value) => MapEntry(
              int.parse(key as String),
              VoteValue.values.byName(value as String),
            ),
          ),
        );
      partnerVotes
        ..clear()
        ..addAll(
          ((state['partnerVotes'] as Map?) ?? const {}).map(
            (key, value) => MapEntry(
              int.parse(key as String),
              VoteValue.values.byName(value as String),
            ),
          ),
        );
      history
        ..clear()
        ..addAll((state['history'] as List).cast<int>());
      customGirls
        ..clear()
        ..addAll((state['customGirls'] as List).cast<String>());
      customBoys
        ..clear()
        ..addAll((state['customBoys'] as List).cast<String>());
      seed = state['seed'] as int;
      sessionId = state['sessionId'] as String;
      paired = state['paired'] as bool;
      partnerVotesReceived = state['partnerVotesReceived'] as bool;
      faceoffIndex = state['faceoffIndex'] as int;
      outgoingSequence = state['outgoingSequence'] as int;
      appliedSequences
        ..clear()
        ..addAll((state['appliedSequences'] as List).cast<int>());
      final storedSecret = await _secrets.read(key: _secretKey);
      if (storedSecret != null) _secret = base64Url.decode(storedSecret);
    } catch (_) {
      await reset();
    }
    notifyListeners();
  }

  Future<void> ensureSession() async {
    if (hasSession) return;
    _secret = await QrProtocol.newSecret();
    sessionId = base64Url.encode(_secret!.sublist(0, 9)).replaceAll('=', '');
    seed = _secret!.fold<int>(
      0,
      (value, byte) => (value * 31 + byte) & 0x7fffffff,
    );
    await _secrets.write(key: _secretKey, value: base64Url.encode(_secret!));
    await _persist();
    notifyListeners();
  }

  void toggleCountry(String code) {
    if (countries.contains(code) && countries.length > 1) {
      countries.remove(code);
    } else {
      countries.add(code);
    }
    _changed();
  }

  void toggleCategory(NameCategory category) {
    if (categories.contains(category) && categories.length > 1) {
      categories.remove(category);
    } else {
      categories.add(category);
    }
    _changed();
  }

  void vote(VoteValue value) {
    final candidate = current;
    if (candidate == null) return;
    votes[candidate.id] = value;
    history.add(candidate.id);
    _changed();
  }

  void undo() {
    if (history.isEmpty) return;
    votes.remove(history.removeLast());
    _changed();
  }

  void join() {
    paired = true;
    _changed();
  }

  void importVotes() {
    partnerVotesReceived = true;
    _changed();
  }

  void advanceFaceoff() {
    faceoffIndex++;
    _changed();
  }

  bool addCustom(String name, Set<NameCategory> selected) {
    if (!isValidCustomName(name)) return false;
    for (final category in selected) {
      final list = category == NameCategory.girls ? customGirls : customBoys;
      if (list.length >= 25 ||
          list.map(normalizeName).contains(normalizeName(name))) {
        return false;
      }
      list.add(name.trim());
    }
    _changed();
    return true;
  }

  String invitePayload() {
    if (!hasSession) {
      throw StateError('Create a session before displaying an invite.');
    }
    return QrProtocol.encodeInvite({
      'v': QrProtocol.version,
      'type': 'invite',
      'session': sessionId,
      'hash': 'development-fixture-v1',
      'countries': countries.toList()..sort(),
      'categories': categories.map((category) => category.name).toList(),
      'seed': seed,
      'secret': base64Url.encode(_secret!),
    });
  }

  Future<void> importInvite(String text) async {
    final invite = QrProtocol.decodeInvite(text);
    if (invite['hash'] != 'development-fixture-v1') {
      throw const QrProtocolError(
        'Both phones need the same NameThatBaby data version.',
      );
    }
    final secret = invite['secret'];
    final importedSession = invite['session'];
    if (secret is! String ||
        importedSession is! String ||
        secret.length > 100) {
      throw const QrProtocolError('This pairing code is missing session data.');
    }
    _secret = base64Url.decode(secret);
    if (_secret!.length != 32) {
      throw const QrProtocolError('This pairing code has an invalid key.');
    }
    sessionId = importedSession;
    seed = invite['seed'] as int;
    countries
      ..clear()
      ..addAll((invite['countries'] as List).cast<String>());
    categories
      ..clear()
      ..addAll(
        (invite['categories'] as List).map(
          (value) => NameCategory.values.byName(value as String),
        ),
      );
    paired = true;
    await _secrets.write(key: _secretKey, value: secret);
    await _persist();
    notifyListeners();
  }

  Future<String> voteUpdatePayload() async {
    if (!hasSession) throw StateError('No pairing session exists.');
    outgoingSequence++;
    final data = <String, Object?>{
      'votes': votes.map((id, value) => MapEntry('$id', value.name)),
      'customGirls': customGirls,
      'customBoys': customBoys,
    };
    final packet = await QrProtocol.encrypt(
      secret: _secret!,
      sessionId: sessionId,
      eventType: 'choosing_votes',
      sequence: outgoingSequence,
      payload: data,
    );
    await _persist();
    return packet;
  }

  Future<void> importVoteUpdate(String text) async {
    if (!hasSession) {
      throw const QrProtocolError('Pair this phone before importing updates.');
    }
    final decoded = await QrProtocol.decrypt(
      secret: _secret!,
      sessionId: sessionId,
      encoded: text,
    );
    final sequence = decoded['sequence'] as int;
    if (appliedSequences.contains(sequence)) {
      throw const QrProtocolError('This update was already imported.');
    }
    final payload = decoded['payload'] as Map<String, Object?>;
    final importedVotes = payload['votes'];
    if (importedVotes is! Map || importedVotes.length > candidates.length) {
      throw const QrProtocolError('This update has invalid vote data.');
    }
    final nextPartnerVotes = <int, VoteValue>{};
    for (final entry in importedVotes.entries) {
      final id = int.tryParse(entry.key.toString());
      if (id == null ||
          !candidates.any((candidate) => candidate.id == id) ||
          entry.value is! String) {
        throw const QrProtocolError('This update refers to an unknown name.');
      }
      nextPartnerVotes[id] = VoteValue.values.byName(entry.value as String);
    }
    partnerVotes
      ..clear()
      ..addAll(nextPartnerVotes);
    appliedSequences.add(sequence);
    partnerVotesReceived = true;
    await _persist();
    notifyListeners();
  }

  Future<void> reset() async {
    countries
      ..clear()
      ..addAll({'US', 'FR', 'NL'});
    categories
      ..clear()
      ..addAll(NameCategory.values);
    votes.clear();
    partnerVotes.clear();
    history.clear();
    customGirls.clear();
    customBoys.clear();
    appliedSequences.clear();
    sessionId = '';
    _secret = null;
    paired = false;
    partnerVotesReceived = false;
    faceoffIndex = 0;
    outgoingSequence = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
    await _secrets.delete(key: _secretKey);
    notifyListeners();
  }

  void _changed() {
    unawaited(_persist());
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _stateKey,
      jsonEncode({
        'countries': countries.toList(),
        'categories': categories.map((value) => value.name).toList(),
        'votes': votes.map((key, value) => MapEntry('$key', value.name)),
        'partnerVotes': partnerVotes.map(
          (key, value) => MapEntry('$key', value.name),
        ),
        'history': history,
        'customGirls': customGirls,
        'customBoys': customBoys,
        'seed': seed,
        'sessionId': sessionId,
        'paired': paired,
        'partnerVotesReceived': partnerVotesReceived,
        'faceoffIndex': faceoffIndex,
        'outgoingSequence': outgoingSequence,
        'appliedSequences': appliedSequences.toList(),
      }),
    );
  }
}

List<Candidate> _candidates() {
  const girls = [
    'Elena',
    'Nora',
    'Olivia',
    'Sofia',
    'Amélie',
    'Mila',
    'Clara',
    'Lucia',
    'Iris',
    'Ava',
    'Emma',
    'Léa',
  ];
  const boys = [
    'Leo',
    'Noah',
    'Arthur',
    'Oliver',
    'Luca',
    'Hugo',
    'Felix',
    'Milo',
    'Oscar',
    'Theo',
    'Louis',
    'Adam',
  ];
  final all = <Candidate>[];
  var id = 1;
  for (final category in NameCategory.values) {
    final names = category == NameCategory.girls ? girls : boys;
    for (var index = 0; index < names.length; index++) {
      all.add(
        Candidate(
          id++,
          names[index],
          category,
          ['US', 'FR', 'NL'].sublist(0, index % 3 + 1),
          index + 1,
        ),
      );
    }
  }
  return all;
}
