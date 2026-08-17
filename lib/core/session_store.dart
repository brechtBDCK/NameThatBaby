import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'domain.dart';
import 'qr_protocol.dart';

typedef CandidateLoader =
    Future<List<Candidate>> Function(
      Set<String> countries,
      Set<NameCategory> categories,
      int seed,
    );

abstract interface class SessionSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Encrypted session state, kept separately from the secure-storage key.
abstract interface class SessionStateStore {
  Future<String?> read();
  Future<void> write(String state);
  Future<void> delete();
}

/// Reads the pre-v3 preference record only long enough to migrate it.
abstract interface class LegacySessionStateStore {
  Future<String?> read();
  Future<void> delete();
}

class SharedPreferencesLegacySessionStateStore
    implements LegacySessionStateStore {
  static const _key = 'namethatbaby.session.state.v1';

  @override
  Future<void> delete() async =>
      (await SharedPreferences.getInstance()).remove(_key);

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);
}

class SecureSessionSecretStore implements SessionSecretStore {
  SecureSessionSecretStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(synchronizable: false),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class EncryptedSqliteSessionStateStore implements SessionStateStore {
  EncryptedSqliteSessionStateStore(this._secrets);

  static const _key = 'namethatbaby.session.state.encryption-key.v1';
  static const _databaseFileName = 'namethatbaby-session-v1.sqlite';
  static const _aad = 'NameThatBaby session state v1';
  static final _algorithm = AesGcm.with256bits();
  final SessionSecretStore _secrets;

  @override
  Future<void> delete() async {
    final database = await _open();
    try {
      await database.delete('session_state', where: 'id = 1');
    } finally {
      await database.close();
    }
    await _secrets.delete(_key);
  }

  @override
  Future<String?> read() async {
    final database = await _open();
    try {
      final rows = await database.query('session_state', where: 'id = 1');
      if (rows.isEmpty) return null;
      final key = await _readKey();
      if (key == null) throw const FormatException('Missing state key.');
      final envelope = (jsonDecode(rows.single['payload']! as String) as Map)
          .cast<String, Object?>();
      final clear = await _algorithm.decrypt(
        SecretBox(
          base64Url.decode(envelope['ciphertext']! as String),
          nonce: base64Url.decode(envelope['nonce']! as String),
          mac: Mac(base64Url.decode(envelope['tag']! as String)),
        ),
        secretKey: SecretKeyData(base64Url.decode(key)),
        aad: utf8.encode(_aad),
      );
      return utf8.decode(clear);
    } finally {
      await database.close();
    }
  }

  @override
  Future<void> write(String state) async {
    final key = await _readKey() ?? await _createKey();
    final box = await _algorithm.encrypt(
      utf8.encode(state),
      secretKey: SecretKeyData(base64Url.decode(key)),
      aad: utf8.encode(_aad),
    );
    final database = await _open();
    try {
      await database.insert('session_state', {
        'id': 1,
        'payload': jsonEncode({
          'nonce': base64Url.encode(box.nonce),
          'tag': base64Url.encode(box.mac.bytes),
          'ciphertext': base64Url.encode(box.cipherText),
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } finally {
      await database.close();
    }
  }

  Future<Database> _open() async {
    final path = '${await getDatabasesPath()}/$_databaseFileName';
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (database, _) => database.execute(
        'CREATE TABLE session_state (id INTEGER PRIMARY KEY CHECK (id = 1), payload TEXT NOT NULL)',
      ),
    );
    if (Platform.isIOS) {
      await _backupChannel.invokeMethod<void>('exclude', path);
    }
    return database;
  }

  Future<String?> _readKey() => _secrets.read(_key);

  Future<String> _createKey() async {
    final key = base64Url.encode(await QrProtocol.newSecret());
    await _secrets.write(_key, key);
    return key;
  }
}

const _backupChannel = MethodChannel('namethatbaby/backup');

class SessionStore extends ChangeNotifier {
  SessionStore({
    SessionSecretStore? secrets,
    SessionStateStore? state,
    LegacySessionStateStore? legacyState,
    CandidateLoader? candidateLoader,
    this.datasetHash = 'development-fixture-v1',
  }) : _secrets = secrets ?? SecureSessionSecretStore() {
    _state = state ?? EncryptedSqliteSessionStateStore(_secrets);
    _legacyState = legacyState ?? SharedPreferencesLegacySessionStateStore();
    _candidateLoader = candidateLoader;
  }

  static const _secretKey = 'namethatbaby.session.secret.v1';
  static const _stateVersion = 3;
  final SessionSecretStore _secrets;
  late final SessionStateStore _state;
  late final LegacySessionStateStore _legacyState;
  late final CandidateLoader? _candidateLoader;
  final String datasetHash;
  final Set<String> countries = {'US', 'FR', 'NL'};
  final Set<NameCategory> categories = {NameCategory.girls, NameCategory.boys};
  final Map<int, VoteValue> votes = {};
  final Map<int, VoteValue> partnerVotes = {};
  final List<int> history = [];
  final List<String> customGirls = [];
  final List<String> customBoys = [];
  final Map<String, String> privateNotes = {};
  List<Candidate> candidates = _candidates();
  int seed = 20260731;
  String sessionId = '';
  String localParticipantId = '';
  String? partnerParticipantId;
  List<int>? _secret;
  bool paired = false;
  bool partnerVotesReceived = false;
  bool customNamesSent = false;
  bool partnerCustomNamesReceived = false;
  bool get customNamesConverged =>
      !hasPartner || (customNamesSent && partnerCustomNamesReceived);
  bool get isSaving => _writesPending > 0;
  String? restoreError;
  // Seven is the documented maximum number of comparisons per entry before
  // targeted boundary tie-breaks are needed.
  static const faceoffRoundCount = 7;
  int faceoffRound = 0;
  int faceoffPairIndex = 0;
  NameCategory? faceoffCategory;
  final Map<NameCategory, List<String>> faceoffNames = {};
  final Map<NameCategory, Map<String, int>> faceoffScores = {};
  final Map<NameCategory, Map<String, int>> faceoffUnanimousWins = {};
  final Map<NameCategory, Map<String, int>> faceoffSeedTiers = {};
  final Map<NameCategory, Map<String, int>> faceoffComparisons = {};
  final Map<NameCategory, Map<String, int>> faceoffLeftCounts = {};
  final Map<NameCategory, Map<String, int>> faceoffRightCounts = {};
  final Map<NameCategory, Set<String>> faceoffPrevious = {};
  final Set<NameCategory> faceoffCompleted = {};
  final Map<NameCategory, List<List<String>>> faceoffTopTenHistory = {};
  final Map<NameCategory, List<String>> faceoffTieBreakEntries = {};
  List<Pairing> faceoffPairings = [];
  final Map<String, String?> localFaceoffVotes = {};
  final Map<String, String?> partnerFaceoffVotes = {};
  final List<String> faceoffVoteHistory = [];
  int outgoingSequence = 0;
  final Set<String> appliedEventIds = {};
  final Map<String, int> highestAcceptedSequence = {};
  Future<void> _persistTail = Future.value();
  int _writesPending = 0;

  List<Candidate> get enabled => candidates
      .where((candidate) => categories.contains(candidate.category))
      .toList();
  List<Candidate> remaining(NameCategory category) => enabled
      .where(
        (candidate) =>
            candidate.category == category && !votes.containsKey(candidate.id),
      )
      .toList();
  Candidate? get current => currentFor();
  Candidate? currentFor([NameCategory? category]) => enabled
      .cast<Candidate?>()
      .firstWhere(
        (candidate) =>
            candidate != null &&
            (category == null || candidate.category == category) &&
            !votes.containsKey(candidate.id),
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
  bool get hasPartner => partnerParticipantId != null;
  bool get canEditSelection => !paired && votes.isEmpty;
  Future<String?> confirmationCode() async {
    final partner = partnerParticipantId;
    if (!hasSession || partner == null) return null;
    return QrProtocol.confirmationCode(
      secret: _secret!,
      firstParticipantId: localParticipantId,
      secondParticipantId: partner,
    );
  }

  Future<void> restore() async {
    try {
      var encoded = await _state.read();
      final migratingLegacyState = encoded == null;
      encoded ??= await _legacyState.read();
      if (encoded == null) return;
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
      privateNotes
        ..clear()
        ..addAll(
          ((state['privateNotes'] as Map?) ?? const {}).map(
            (key, value) => MapEntry(key as String, value as String),
          ),
        );
      seed = state['seed'] as int;
      sessionId = state['sessionId'] as String;
      // State version 1 had no participant identity. Preserve its choices and
      // create a new local identity; the user will pair again before syncing.
      localParticipantId =
          state['localParticipantId'] as String? ??
          await QrProtocol.newIdentifier();
      partnerParticipantId = state['partnerParticipantId'] as String?;
      paired = state['paired'] as bool;
      partnerVotesReceived = state['partnerVotesReceived'] as bool;
      customNamesSent = state['customNamesSent'] as bool? ?? !hasPartner;
      partnerCustomNamesReceived =
          state['partnerCustomNamesReceived'] as bool? ?? !hasPartner;
      _restoreFaceoff(state);
      outgoingSequence = state['outgoingSequence'] as int;
      appliedEventIds
        ..clear()
        ..addAll(
          (state['appliedEventIds'] as List? ?? const []).cast<String>(),
        );
      highestAcceptedSequence
        ..clear()
        ..addAll(
          ((state['highestAcceptedSequence'] as Map?) ?? const {}).map(
            (key, value) => MapEntry(key as String, value as int),
          ),
        );
      final storedSecret = await _secrets.read(_secretKey);
      if (storedSecret != null) _secret = base64Url.decode(storedSecret);
      if (hasSession) await _loadCandidates();
      if (migratingLegacyState) {
        await _persist();
        await _legacyState.delete();
      }
    } on Object {
      restoreError =
          'This session could not be opened. Your saved data has not been deleted.';
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  Future<void> ensureSession() async {
    if (hasSession) return;
    _secret = await QrProtocol.newSecret();
    sessionId = await QrProtocol.newIdentifier();
    localParticipantId = await QrProtocol.newIdentifier();
    seed = _secret!.fold<int>(
      0,
      (value, byte) => (value * 31 + byte) & 0x7fffffff,
    );
    await _loadCandidates();
    await _secrets.write(_secretKey, base64Url.encode(_secret!));
    await _persist();
    notifyListeners();
  }

  Future<void> toggleCountry(String code) async {
    if (countries.contains(code) && countries.length > 1) {
      countries.remove(code);
    } else {
      countries.add(code);
    }
    if (hasSession) await _loadCandidates();
    await _changed();
  }

  Future<void> toggleCategory(NameCategory category) async {
    if (categories.contains(category) && categories.length > 1) {
      categories.remove(category);
    } else {
      categories.add(category);
    }
    if (hasSession) await _loadCandidates();
    await _changed();
  }

  Future<void> vote(VoteValue value) async {
    final candidate = current;
    if (candidate == null) return;
    votes[candidate.id] = value;
    history.add(candidate.id);
    await _changed();
  }

  Future<void> undo() async {
    if (history.isEmpty) return;
    votes.remove(history.removeLast());
    await _changed();
  }

  void join() {
    paired = true;
    _changed();
  }

  void importVotes() {
    partnerVotesReceived = true;
    _changed();
  }

  bool get faceoffStarted => faceoffNames.isNotEmpty;
  bool get canStartFaceoff => faceoffStarted
      ? faceoffNames.values.any((names) => names.length >= 2)
      : customNamesConverged &&
            categories.any(
              (category) => _faceoffEntries(category).names.length >= 2,
            );
  bool get faceoffDone =>
      faceoffStarted && faceoffCompleted.containsAll(faceoffNames.keys);
  Pairing? get currentFaceoff => faceoffPairIndex < faceoffPairings.length
      ? faceoffPairings[faceoffPairIndex]
      : null;
  bool get faceoffRoundReady =>
      faceoffStarted &&
      faceoffPairings.isNotEmpty &&
      faceoffPairIndex >= faceoffPairings.length;
  bool get faceoffTieBreakActive =>
      faceoffCategory != null &&
      faceoffTieBreakEntries.containsKey(faceoffCategory);

  Future<void> startFaceoff() async {
    if (faceoffStarted || !customNamesConverged) return;
    final before = _faceoffSnapshot();
    for (final category in categories) {
      final entries = _faceoffEntries(category);
      if (entries.names.length >= 2) {
        final names = entries.names;
        faceoffNames[category] = names;
        faceoffScores[category] = {for (final name in names) name: 0};
        faceoffUnanimousWins[category] = {for (final name in names) name: 0};
        faceoffSeedTiers[category] = entries.seedTiers;
        faceoffComparisons[category] = {for (final name in names) name: 0};
        faceoffLeftCounts[category] = {for (final name in names) name: 0};
        faceoffRightCounts[category] = {for (final name in names) name: 0};
        faceoffPrevious[category] = {};
        faceoffTopTenHistory[category] = [];
      }
    }
    faceoffRound = 0;
    _prepareNextCategory();
    try {
      await _changed();
    } catch (_) {
      _restoreFaceoff(before);
      notifyListeners();
      rethrow;
    }
  }

  ({List<String> names, Map<String, int> seedTiers}) _faceoffEntries(
    NameCategory category,
  ) {
    final names = <String>[];
    final seen = <String>{};
    final seedTiers = <String, int>{};
    for (final candidate in enabled.where(
      (candidate) => candidate.category == category,
    )) {
      final mine = votes[candidate.id];
      final partner = partnerVotes[candidate.id];
      if (mine != null &&
          partner != null &&
          matchTier(mine, partner) != MatchTier.rejected &&
          seen.add(normalizeName(candidate.name))) {
        names.add(candidate.name);
        seedTiers[candidate.name] =
            mine == VoteValue.yes && partner == VoteValue.yes
            ? 3
            : mine == VoteValue.maybe && partner == VoteValue.maybe
            ? 1
            : 2;
      }
    }
    final custom = category == NameCategory.girls ? customGirls : customBoys;
    for (final name in custom) {
      if (seen.add(normalizeName(name))) {
        names.add(name);
        seedTiers[name] = 2;
      }
    }
    return (names: names, seedTiers: seedTiers);
  }

  Future<void> chooseFaceoff(String? winner) async {
    final pairing = currentFaceoff;
    if (pairing == null || faceoffCategory == null || faceoffDone) return;
    if (winner != null && winner != pairing.left && winner != pairing.right) {
      throw ArgumentError.value(winner, 'winner', 'is not in this pairing');
    }
    localFaceoffVotes[_faceoffVoteKey(pairing)] = winner;
    faceoffVoteHistory.add(_faceoffVoteKey(pairing));
    faceoffPairIndex++;
    if (!hasPartner && faceoffPairIndex >= faceoffPairings.length) {
      _applyFaceoffRound(localFaceoffVotes);
    }
    await _changed();
  }

  Future<void> undoFaceoffVote() async {
    if (!hasPartner || faceoffVoteHistory.isEmpty || faceoffPairIndex == 0) {
      return;
    }
    final key = faceoffVoteHistory.removeLast();
    localFaceoffVotes.remove(key);
    faceoffPairIndex--;
    await _changed();
  }

  List<FaceoffResult> results(NameCategory category) {
    final scores = faceoffScores[category] ?? const <String, int>{};
    return rankFaceoff(
      faceoffNames[category] ?? const [],
      scores,
      opponentsScores: _opponentScores(category),
      unanimousWins: faceoffUnanimousWins[category] ?? const {},
      seedTiers: faceoffSeedTiers[category] ?? const {},
      seed: seed,
    );
  }

  Map<String, int> _opponentScores(NameCategory category) {
    final scores = faceoffScores[category] ?? const <String, int>{};
    final opponentScores = <String, int>{
      for (final name in faceoffNames[category] ?? const <String>[]) name: 0,
    };
    for (final pairing in faceoffPrevious[category] ?? const <String>{}) {
      final names = pairing.split('|');
      if (names.length != 2) continue;
      opponentScores[names[0]] =
          (opponentScores[names[0]] ?? 0) + (scores[names[1]] ?? 0);
      opponentScores[names[1]] =
          (opponentScores[names[1]] ?? 0) + (scores[names[0]] ?? 0);
    }
    return opponentScores;
  }

  Future<bool> addCustom(String name, Set<NameCategory> selected) async {
    if (!isValidCustomName(name)) return false;
    for (final category in selected) {
      final list = category == NameCategory.girls ? customGirls : customBoys;
      if (list.length >= 25 ||
          list.map(normalizeName).contains(normalizeName(name))) {
        return false;
      }
      list.add(name.trim());
    }
    customNamesSent = false;
    await _changed();
    return true;
  }

  Future<bool> removeCustom(String name, NameCategory category) async {
    if (faceoffStarted) return false;
    final list = category == NameCategory.girls ? customGirls : customBoys;
    final index = list.indexWhere(
      (value) => normalizeName(value) == normalizeName(name),
    );
    if (index < 0) return false;
    list.removeAt(index);
    customNamesSent = false;
    await _changed();
    return true;
  }

  Future<void> setPrivateNote(
    NameCategory category,
    String name,
    String note,
  ) async {
    final key = '${category.name}:${normalizeName(name)}';
    if (note.trim().isEmpty) {
      privateNotes.remove(key);
    } else {
      privateNotes[key] = note.trim();
    }
    await _changed();
  }

  String privateNote(NameCategory category, String name) =>
      privateNotes['${category.name}:${normalizeName(name)}'] ?? '';

  String invitePayload() {
    if (!hasSession) {
      throw StateError('Create a session before displaying an invite.');
    }
    return QrProtocol.encodeInvite({
      'v': QrProtocol.version,
      'type': 'invite',
      'session': sessionId,
      'creator': localParticipantId,
      'hash': datasetHash,
      'countries': countries.toList()..sort(),
      'categories': categories.map((category) => category.name).toList(),
      'seed': seed,
      'secret': base64Url.encode(_secret!),
    });
  }

  Future<void> importInvite(String text) async {
    final invite = QrProtocol.decodeInvite(text);
    if (invite['hash'] != datasetHash) {
      throw const QrProtocolError(
        'Both phones need the same NameThatBaby data version.',
      );
    }
    final secret = invite['secret'];
    final importedSession = invite['session'];
    final creator = invite['creator'];
    if (secret is! String ||
        importedSession is! String ||
        creator is! String ||
        creator.isEmpty ||
        secret.length > 100) {
      throw const QrProtocolError('This pairing code is missing session data.');
    }
    _secret = base64Url.decode(secret);
    if (_secret!.length != 32) {
      throw const QrProtocolError('This pairing code has an invalid key.');
    }
    sessionId = importedSession;
    localParticipantId = await QrProtocol.newIdentifier();
    partnerParticipantId = creator;
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
    await _loadCandidates();
    await _secrets.write(_secretKey, secret);
    await _persist();
    notifyListeners();
  }

  Future<String> voteUpdatePayload() async {
    if (!hasSession) throw StateError('No pairing session exists.');
    outgoingSequence++;
    final data = <String, Object?>{
      'votes': votes.map((id, value) => MapEntry('$id', value.name)),
    };
    final packet = await QrProtocol.encrypt(
      secret: _secret!,
      sessionId: sessionId,
      sourceParticipantId: localParticipantId,
      eventType: 'choosing_votes',
      sequence: outgoingSequence,
      payload: data,
    );
    await _persist();
    return packet;
  }

  /// A separate event keeps the Face-off entry set explicit and auditable.
  Future<String> customNamesUpdatePayload() async {
    if (!hasSession || !hasPartner) {
      throw StateError(
        'Pair with your partner before synchronizing custom names.',
      );
    }
    outgoingSequence++;
    final packet = await QrProtocol.encrypt(
      secret: _secret!,
      sessionId: sessionId,
      sourceParticipantId: localParticipantId,
      eventType: 'custom_names',
      sequence: outgoingSequence,
      payload: {'girls': customGirls, 'boys': customBoys},
    );
    customNamesSent = true;
    await _persist();
    notifyListeners();
    return packet;
  }

  Future<void> importCustomNamesUpdate(String text) async {
    if (!hasSession) {
      throw const QrProtocolError('Pair this phone before importing updates.');
    }
    final decoded = await QrProtocol.decrypt(
      secret: _secret!,
      sessionId: sessionId,
      encoded: text,
    );
    if (decoded['type'] != 'custom_names') {
      throw const QrProtocolError('This is not a custom-name update.');
    }
    final source = decoded['source'] as String;
    final sequence = decoded['sequence'] as int;
    _validatePartnerEvent(source, sequence);
    final payload = decoded['payload'] as Map<String, Object?>;
    final girls = _mergeCustomNames(
      existing: customGirls,
      imported: payload['girls'],
    );
    final boys = _mergeCustomNames(
      existing: customBoys,
      imported: payload['boys'],
    );
    final oldGirls = [...customGirls];
    final oldBoys = [...customBoys];
    final oldPartner = partnerParticipantId;
    final oldReceived = partnerCustomNamesReceived;
    final oldApplied = Set<String>.from(appliedEventIds);
    final oldHighest = Map<String, int>.from(highestAcceptedSequence);
    try {
      customGirls
        ..clear()
        ..addAll(girls);
      customBoys
        ..clear()
        ..addAll(boys);
      partnerParticipantId ??= source;
      partnerCustomNamesReceived = true;
      _acceptEvent(source, sequence);
      await _persist();
    } catch (_) {
      customGirls
        ..clear()
        ..addAll(oldGirls);
      customBoys
        ..clear()
        ..addAll(oldBoys);
      partnerParticipantId = oldPartner;
      partnerCustomNamesReceived = oldReceived;
      appliedEventIds
        ..clear()
        ..addAll(oldApplied);
      highestAcceptedSequence
        ..clear()
        ..addAll(oldHighest);
      rethrow;
    }
    notifyListeners();
  }

  Future<String> pairAcceptPayload() async {
    if (!hasSession || partnerParticipantId == null) {
      throw StateError('Scan a pairing invitation before accepting it.');
    }
    outgoingSequence++;
    final packet = await QrProtocol.encrypt(
      secret: _secret!,
      sessionId: sessionId,
      sourceParticipantId: localParticipantId,
      eventType: 'pair_accept',
      sequence: outgoingSequence,
      payload: {'participant': localParticipantId},
    );
    await _persist();
    return packet;
  }

  Future<void> importPairAccept(String text) async {
    if (!hasSession) {
      throw const QrProtocolError(
        'Create a session before accepting a partner.',
      );
    }
    final decoded = await QrProtocol.decrypt(
      secret: _secret!,
      sessionId: sessionId,
      encoded: text,
    );
    if (decoded['type'] != 'pair_accept') {
      throw const QrProtocolError('This is not a pairing confirmation.');
    }
    final source = decoded['source'] as String;
    final sequence = decoded['sequence'] as int;
    _validatePartnerEvent(source, sequence);
    final payload = decoded['payload'] as Map<String, Object?>;
    if (payload['participant'] != source) {
      throw const QrProtocolError('This pairing confirmation is invalid.');
    }
    final oldPartner = partnerParticipantId;
    final oldPaired = paired;
    final oldApplied = Set<String>.from(appliedEventIds);
    final oldHighest = Map<String, int>.from(highestAcceptedSequence);
    try {
      partnerParticipantId = source;
      paired = true;
      _acceptEvent(source, sequence);
      await _persist();
    } catch (_) {
      partnerParticipantId = oldPartner;
      paired = oldPaired;
      appliedEventIds
        ..clear()
        ..addAll(oldApplied);
      highestAcceptedSequence
        ..clear()
        ..addAll(oldHighest);
      rethrow;
    }
    notifyListeners();
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
    if (decoded['type'] != 'choosing_votes') {
      throw const QrProtocolError('This is not a choosing update.');
    }
    final sequence = decoded['sequence'] as int;
    final source = decoded['source'] as String;
    _validatePartnerEvent(source, sequence);
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
    final oldVotes = Map<int, VoteValue>.from(partnerVotes);
    final oldPartner = partnerParticipantId;
    final oldReceived = partnerVotesReceived;
    final oldApplied = Set<String>.from(appliedEventIds);
    final oldHighest = Map<String, int>.from(highestAcceptedSequence);
    try {
      partnerVotes
        ..clear()
        ..addAll(nextPartnerVotes);
      partnerParticipantId ??= source;
      _acceptEvent(source, sequence);
      partnerVotesReceived = true;
      await _persist();
    } catch (_) {
      partnerVotes
        ..clear()
        ..addAll(oldVotes);
      partnerParticipantId = oldPartner;
      partnerVotesReceived = oldReceived;
      appliedEventIds
        ..clear()
        ..addAll(oldApplied);
      highestAcceptedSequence
        ..clear()
        ..addAll(oldHighest);
      rethrow;
    }
    notifyListeners();
  }

  Future<String> faceoffUpdatePayload() async {
    if (!hasSession || !faceoffRoundReady || faceoffCategory == null) {
      throw StateError('Finish this Face-off round before synchronizing it.');
    }
    outgoingSequence++;
    final packet = await QrProtocol.encrypt(
      secret: _secret!,
      sessionId: sessionId,
      sourceParticipantId: localParticipantId,
      eventType: 'faceoff_votes',
      sequence: outgoingSequence,
      payload: {
        'round': faceoffRound,
        'category': faceoffCategory!.name,
        'pairings': faceoffPairings
            .map((pairing) => [pairing.left, pairing.right])
            .toList(),
        'votes': localFaceoffVotes,
      },
    );
    await _persist();
    return packet;
  }

  Future<void> importFaceoffUpdate(String text) async {
    if (!hasSession || !faceoffRoundReady || faceoffCategory == null) {
      throw const QrProtocolError('Finish your current Face-off round first.');
    }
    final decoded = await QrProtocol.decrypt(
      secret: _secret!,
      sessionId: sessionId,
      encoded: text,
    );
    if (decoded['type'] != 'faceoff_votes') {
      throw const QrProtocolError('This is not a Face-off update.');
    }
    final source = decoded['source'] as String;
    final sequence = decoded['sequence'] as int;
    _validatePartnerEvent(source, sequence);
    final payload = decoded['payload'] as Map<String, Object?>;
    if (payload['round'] != faceoffRound ||
        payload['category'] != faceoffCategory!.name ||
        !_samePairings(payload['pairings'])) {
      throw const QrProtocolError('Your Face-off rounds are out of sync.');
    }
    final imported = payload['votes'];
    if (imported is! Map || imported.length != faceoffPairings.length) {
      throw const QrProtocolError('This update has invalid Face-off votes.');
    }
    final nextVotes = <String, String?>{};
    for (final pairing in faceoffPairings) {
      final key = _faceoffVoteKey(pairing);
      final choice = imported[key];
      if (choice != null && choice != pairing.left && choice != pairing.right) {
        throw const QrProtocolError('This update has invalid Face-off votes.');
      }
      if (!imported.containsKey(key)) {
        throw const QrProtocolError('This update is missing a Face-off vote.');
      }
      nextVotes[key] = choice as String?;
    }
    // One write commits the imported votes and their derived scoring together.
    final faceoffBefore = _faceoffSnapshot();
    final oldPartner = partnerParticipantId;
    final oldApplied = Set<String>.from(appliedEventIds);
    final oldHighest = Map<String, int>.from(highestAcceptedSequence);
    final oldPartnerVotes = Map<String, String?>.from(partnerFaceoffVotes);
    try {
      partnerFaceoffVotes
        ..clear()
        ..addAll(nextVotes);
      partnerParticipantId ??= source;
      _acceptEvent(source, sequence);
      _applyFaceoffRound(nextVotes);
      await _persist();
    } catch (_) {
      _restoreFaceoff(faceoffBefore);
      partnerFaceoffVotes
        ..clear()
        ..addAll(oldPartnerVotes);
      partnerParticipantId = oldPartner;
      appliedEventIds
        ..clear()
        ..addAll(oldApplied);
      highestAcceptedSequence
        ..clear()
        ..addAll(oldHighest);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> reset() async {
    restoreError = null;
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
    privateNotes.clear();
    appliedEventIds.clear();
    highestAcceptedSequence.clear();
    sessionId = '';
    localParticipantId = '';
    partnerParticipantId = null;
    _secret = null;
    paired = false;
    partnerVotesReceived = false;
    customNamesSent = false;
    partnerCustomNamesReceived = false;
    faceoffRound = 0;
    faceoffPairIndex = 0;
    faceoffCategory = null;
    faceoffNames.clear();
    faceoffScores.clear();
    faceoffUnanimousWins.clear();
    faceoffSeedTiers.clear();
    faceoffComparisons.clear();
    faceoffLeftCounts.clear();
    faceoffRightCounts.clear();
    faceoffPrevious.clear();
    faceoffCompleted.clear();
    faceoffTopTenHistory.clear();
    faceoffTieBreakEntries.clear();
    faceoffPairings = [];
    localFaceoffVotes.clear();
    partnerFaceoffVotes.clear();
    faceoffVoteHistory.clear();
    outgoingSequence = 0;
    await _state.delete();
    await _legacyState.delete();
    await _secrets.delete(_secretKey);
    notifyListeners();
  }

  Future<void> _changed() async {
    _writesPending++;
    notifyListeners();
    try {
      await _persist();
    } finally {
      _writesPending--;
      notifyListeners();
    }
  }

  Future<void> _loadCandidates() async {
    final loader = _candidateLoader;
    if (loader == null) return;
    final loaded = await loader(countries, categories, seed);
    if (loaded.isEmpty) {
      throw StateError('The bundled data has no names for this selection.');
    }
    candidates = loaded;
  }

  List<String> _mergeCustomNames({
    required Iterable<String> existing,
    required Object? imported,
  }) {
    if (imported is! List || imported.length > 25) {
      throw const QrProtocolError('This update has invalid custom names.');
    }
    final merged = [...existing];
    final keys = merged.map(normalizeName).toSet();
    for (final value in imported) {
      if (value is! String || !isValidCustomName(value)) {
        throw const QrProtocolError('This update has invalid custom names.');
      }
      final name = value.trim();
      if (keys.add(normalizeName(name))) merged.add(name);
    }
    if (merged.length > 25) {
      throw const QrProtocolError(
        'This update contains too many custom names.',
      );
    }
    merged.sort((a, b) {
      final key = normalizeName(a).compareTo(normalizeName(b));
      return key != 0 ? key : a.compareTo(b);
    });
    return merged;
  }

  void _validatePartnerEvent(String source, int sequence) {
    if (source == localParticipantId) {
      throw const QrProtocolError(
        'This is your own update, not your partner\'s.',
      );
    }
    if (partnerParticipantId != null && source != partnerParticipantId) {
      throw const QrProtocolError(
        'This update was created by a different partner.',
      );
    }
    if (appliedEventIds.contains('$source:$sequence')) {
      throw const QrProtocolError('This update was already imported.');
    }
    if (sequence <= (highestAcceptedSequence[source] ?? 0)) {
      throw const QrProtocolError(
        'This update is older than your latest partner update.',
      );
    }
  }

  void _acceptEvent(String source, int sequence) {
    appliedEventIds.add('$source:$sequence');
    highestAcceptedSequence[source] = sequence;
  }

  String _faceoffVoteKey(Pairing pairing) =>
      '${faceoffCategory!.name}:$faceoffRound:${pairKey(pairing.left, pairing.right)}';

  bool _samePairings(Object? value) {
    if (value is! List || value.length != faceoffPairings.length) return false;
    for (var index = 0; index < value.length; index++) {
      final wire = value[index];
      final local = faceoffPairings[index];
      if (wire is! List ||
          wire.length != 2 ||
          wire[0] != local.left ||
          wire[1] != local.right) {
        return false;
      }
    }
    return true;
  }

  void _applyFaceoffRound(Map<String, String?> partnerChoices) {
    final category = faceoffCategory!;
    for (final pairing in faceoffPairings) {
      final key = _faceoffVoteKey(pairing);
      final mine = localFaceoffVotes[key];
      final partner = partnerChoices[key];
      if (mine != null && partner != null) {
        faceoffComparisons[category]![pairing.left] =
            faceoffComparisons[category]![pairing.left]! + 1;
        faceoffComparisons[category]![pairing.right] =
            faceoffComparisons[category]![pairing.right]! + 1;
        if (mine == partner) {
          faceoffScores[category]![mine] = faceoffScores[category]![mine]! + 3;
          faceoffUnanimousWins[category]![mine] =
              faceoffUnanimousWins[category]![mine]! + 1;
        } else {
          faceoffScores[category]![mine] = faceoffScores[category]![mine]! + 1;
          faceoffScores[category]![partner] =
              faceoffScores[category]![partner]! + 1;
        }
      }
      faceoffPrevious[category]!.add(pairKey(pairing.left, pairing.right));
    }
    localFaceoffVotes.clear();
    partnerFaceoffVotes.clear();
    faceoffVoteHistory.clear();
    final wasTieBreak = faceoffTieBreakEntries.remove(category) != null;
    if (wasTieBreak) {
      faceoffCompleted.add(category);
    } else {
      faceoffTopTenHistory[category]!.add(
        results(category).map((result) => result.name).toList(),
      );
      if (shouldFinishFaceoff(
        entryCount: faceoffNames[category]!.length,
        comparisonCounts: faceoffComparisons[category]!.values,
        topTenHistory: faceoffTopTenHistory[category]!,
        completedRounds: faceoffRound + 1,
        maximumComparisons: faceoffRoundCount,
      )) {
        final ties = boundaryTieBreakEntries(
          faceoffNames[category]!,
          faceoffScores[category]!,
          opponentsScores: _opponentScores(category),
          unanimousWins: faceoffUnanimousWins[category]!,
          seedTiers: faceoffSeedTiers[category]!,
          seed: seed,
        );
        if (ties.length >= 2) {
          faceoffTieBreakEntries[category] = ties;
        } else {
          faceoffCompleted.add(category);
        }
      }
    }
    _prepareNextCategory(after: category);
  }

  Future<void> _persist() {
    final encoded = jsonEncode({
      'stateVersion': _stateVersion,
      'countries': countries.toList(),
      'categories': categories.map((value) => value.name).toList(),
      'votes': votes.map((key, value) => MapEntry('$key', value.name)),
      'partnerVotes': partnerVotes.map(
        (key, value) => MapEntry('$key', value.name),
      ),
      'history': history,
      'customGirls': customGirls,
      'customBoys': customBoys,
      'privateNotes': privateNotes,
      'seed': seed,
      'sessionId': sessionId,
      'localParticipantId': localParticipantId,
      'partnerParticipantId': partnerParticipantId,
      'paired': paired,
      'partnerVotesReceived': partnerVotesReceived,
      'customNamesSent': customNamesSent,
      'partnerCustomNamesReceived': partnerCustomNamesReceived,
      'faceoffRound': faceoffRound,
      'faceoffPairIndex': faceoffPairIndex,
      'faceoffCategory': faceoffCategory?.name,
      'faceoffNames': faceoffNames.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'faceoffScores': faceoffScores.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'faceoffUnanimousWins': faceoffUnanimousWins.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'faceoffSeedTiers': faceoffSeedTiers.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'faceoffComparisons': faceoffComparisons.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'faceoffLeftCounts': faceoffLeftCounts.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'faceoffRightCounts': faceoffRightCounts.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'faceoffPrevious': faceoffPrevious.map(
        (key, value) => MapEntry(key.name, value.toList()),
      ),
      'faceoffCompleted': faceoffCompleted.map((value) => value.name).toList(),
      'faceoffTopTenHistory': faceoffTopTenHistory.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'faceoffTieBreakEntries': faceoffTieBreakEntries.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'faceoffPairings': faceoffPairings
          .map((pairing) => [pairing.left, pairing.right])
          .toList(),
      'localFaceoffVotes': localFaceoffVotes,
      'partnerFaceoffVotes': partnerFaceoffVotes,
      'faceoffVoteHistory': faceoffVoteHistory,
      'outgoingSequence': outgoingSequence,
      'appliedEventIds': appliedEventIds.toList(),
      'highestAcceptedSequence': highestAcceptedSequence,
    });
    final write = _persistTail.then((_) => _state.write(encoded));
    _persistTail = write.catchError((_) {});
    return write;
  }

  Map<String, Object?> _faceoffSnapshot() =>
      (jsonDecode(
                jsonEncode({
                  'faceoffRound': faceoffRound,
                  'faceoffPairIndex': faceoffPairIndex,
                  'faceoffCategory': faceoffCategory?.name,
                  'faceoffNames': faceoffNames.map(
                    (key, value) => MapEntry(key.name, value),
                  ),
                  'faceoffScores': faceoffScores.map(
                    (key, value) => MapEntry(key.name, value),
                  ),
                  'faceoffUnanimousWins': faceoffUnanimousWins.map(
                    (key, value) => MapEntry(key.name, value),
                  ),
                  'faceoffSeedTiers': faceoffSeedTiers.map(
                    (key, value) => MapEntry(key.name, value),
                  ),
                  'faceoffComparisons': faceoffComparisons.map(
                    (key, value) => MapEntry(key.name, value),
                  ),
                  'faceoffLeftCounts': faceoffLeftCounts.map(
                    (key, value) => MapEntry(key.name, value),
                  ),
                  'faceoffRightCounts': faceoffRightCounts.map(
                    (key, value) => MapEntry(key.name, value),
                  ),
                  'faceoffPrevious': faceoffPrevious.map(
                    (key, value) => MapEntry(key.name, value.toList()),
                  ),
                  'faceoffCompleted': faceoffCompleted
                      .map((value) => value.name)
                      .toList(),
                  'faceoffTopTenHistory': faceoffTopTenHistory.map(
                    (key, value) => MapEntry(key.name, value),
                  ),
                  'faceoffTieBreakEntries': faceoffTieBreakEntries.map(
                    (key, value) => MapEntry(key.name, value),
                  ),
                  'faceoffPairings': faceoffPairings
                      .map((pairing) => [pairing.left, pairing.right])
                      .toList(),
                  'localFaceoffVotes': localFaceoffVotes,
                  'partnerFaceoffVotes': partnerFaceoffVotes,
                  'faceoffVoteHistory': faceoffVoteHistory,
                }),
              )
              as Map)
          .cast<String, Object?>();

  void _prepareNextCategory({NameCategory? after}) {
    final ordered = NameCategory.values
        .where((category) => (faceoffNames[category]?.length ?? 0) >= 2)
        .toList();
    if (ordered.isEmpty || faceoffCompleted.containsAll(ordered)) {
      faceoffCategory = null;
      faceoffPairings = [];
      faceoffPairIndex = 0;
      return;
    }
    final afterIndex = after == null ? -1 : ordered.indexOf(after);
    NameCategory? next;
    for (var offset = 1; offset <= ordered.length; offset++) {
      final index = (afterIndex + offset) % ordered.length;
      final candidate = ordered[index];
      if (faceoffCompleted.contains(candidate)) continue;
      if (after != null && afterIndex + offset >= ordered.length) {
        faceoffRound++;
      }
      next = candidate;
      break;
    }
    if (next == null ||
        (faceoffRound >= faceoffRoundCount &&
            !faceoffTieBreakEntries.containsKey(next))) {
      faceoffCategory = null;
      faceoffPairings = [];
      faceoffPairIndex = 0;
      return;
    }
    faceoffCategory = next;
    faceoffPairIndex = 0;
    faceoffPairings = scheduleRound(
      faceoffTieBreakEntries[faceoffCategory] ?? faceoffNames[faceoffCategory]!,
      faceoffScores[faceoffCategory]!,
      faceoffPrevious[faceoffCategory]!,
      seed: seed + faceoffRound,
      comparisons: faceoffComparisons[faceoffCategory]!,
      leftCounts: faceoffLeftCounts[faceoffCategory]!,
      rightCounts: faceoffRightCounts[faceoffCategory]!,
      seedTiers: faceoffSeedTiers[faceoffCategory]!,
    );
    for (final pairing in faceoffPairings) {
      faceoffLeftCounts[faceoffCategory]![pairing.left] =
          faceoffLeftCounts[faceoffCategory]![pairing.left]! + 1;
      faceoffRightCounts[faceoffCategory]![pairing.right] =
          faceoffRightCounts[faceoffCategory]![pairing.right]! + 1;
    }
  }

  void _restoreFaceoff(Map<String, Object?> state) {
    faceoffRound = (state['faceoffRound'] as int?) ?? 0;
    faceoffPairIndex = (state['faceoffPairIndex'] as int?) ?? 0;
    final categoryName = state['faceoffCategory'] as String?;
    faceoffCategory = categoryName == null
        ? null
        : NameCategory.values.byName(categoryName);
    faceoffNames.clear();
    for (final entry in ((state['faceoffNames'] as Map?) ?? const {}).entries) {
      faceoffNames[NameCategory.values.byName(entry.key as String)] =
          (entry.value as List).cast<String>();
    }
    faceoffScores.clear();
    for (final entry
        in ((state['faceoffScores'] as Map?) ?? const {}).entries) {
      faceoffScores[NameCategory.values.byName(
        entry.key as String,
      )] = (entry.value as Map).map(
        (key, value) => MapEntry(key as String, value as int),
      );
    }
    _restoreFaceoffCounters(state['faceoffComparisons'], faceoffComparisons);
    _restoreFaceoffCounters(state['faceoffLeftCounts'], faceoffLeftCounts);
    _restoreFaceoffCounters(state['faceoffRightCounts'], faceoffRightCounts);
    _restoreFaceoffCounters(
      state['faceoffUnanimousWins'],
      faceoffUnanimousWins,
    );
    _restoreFaceoffCounters(state['faceoffSeedTiers'], faceoffSeedTiers);
    faceoffPrevious.clear();
    for (final entry
        in ((state['faceoffPrevious'] as Map?) ?? const {}).entries) {
      faceoffPrevious[NameCategory.values.byName(entry.key as String)] =
          (entry.value as List).cast<String>().toSet();
    }
    faceoffCompleted
      ..clear()
      ..addAll(
        (state['faceoffCompleted'] as List? ?? const []).map(
          (value) => NameCategory.values.byName(value as String),
        ),
      );
    faceoffTopTenHistory.clear();
    for (final entry
        in ((state['faceoffTopTenHistory'] as Map?) ?? const {}).entries) {
      faceoffTopTenHistory[NameCategory.values.byName(
        entry.key as String,
      )] = (entry.value as List)
          .map((value) => (value as List).cast<String>())
          .toList();
    }
    for (final category in faceoffNames.keys) {
      faceoffTopTenHistory.putIfAbsent(category, () => []);
    }
    faceoffTieBreakEntries.clear();
    for (final entry
        in ((state['faceoffTieBreakEntries'] as Map?) ?? const {}).entries) {
      faceoffTieBreakEntries[NameCategory.values.byName(entry.key as String)] =
          (entry.value as List).cast<String>();
    }
    faceoffPairings = ((state['faceoffPairings'] as List?) ?? const []).map((
      value,
    ) {
      final names = (value as List).cast<String>();
      return Pairing(names[0], names[1]);
    }).toList();
    localFaceoffVotes
      ..clear()
      ..addAll(
        ((state['localFaceoffVotes'] as Map?) ?? const {}).map(
          (key, value) => MapEntry(key as String, value as String?),
        ),
      );
    partnerFaceoffVotes
      ..clear()
      ..addAll(
        ((state['partnerFaceoffVotes'] as Map?) ?? const {}).map(
          (key, value) => MapEntry(key as String, value as String?),
        ),
      );
    faceoffVoteHistory
      ..clear()
      ..addAll(
        (state['faceoffVoteHistory'] as List? ?? const []).cast<String>(),
      );
  }

  void _restoreFaceoffCounters(
    Object? raw,
    Map<NameCategory, Map<String, int>> target,
  ) {
    target.clear();
    for (final entry in ((raw as Map?) ?? const {}).entries) {
      target[NameCategory.values.byName(
        entry.key as String,
      )] = (entry.value as Map).map(
        (key, value) => MapEntry(key as String, value as int),
      );
    }
    for (final category in faceoffNames.keys) {
      target.putIfAbsent(
        category,
        () => {for (final name in faceoffNames[category]!) name: 0},
      );
    }
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
