import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:name_that_baby/core/qr_protocol.dart';

void main() {
  const secret = [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
  ];

  test('invite round trip validates protocol framing', () {
    final encoded = QrProtocol.encodeInvite({
      'v': QrProtocol.version,
      'type': 'invite',
      'session': 'test',
    });
    expect(QrProtocol.decodeInvite(encoded)['session'], 'test');
    expect(
      () => QrProtocol.decodeInvite('not a qr packet'),
      throwsA(isA<QrProtocolError>()),
    );
  });

  test('encrypted update authenticates and rejects tampering', () async {
    final packet = await QrProtocol.encrypt(
      secret: secret,
      sessionId: 'session',
      sourceParticipantId: 'partner-a',
      eventType: 'choosing_votes',
      sequence: 1,
      payload: {
        'votes': {'1': 'yes'},
      },
    );
    final decoded = await QrProtocol.decrypt(
      secret: secret,
      sessionId: 'session',
      encoded: packet,
    );
    expect(decoded['type'], 'choosing_votes');
    expect(decoded['source'], 'partner-a');
    expect((decoded['payload'] as Map<String, Object?>)['votes'], {'1': 'yes'});
    await expectLater(
      QrProtocol.decrypt(secret: secret, sessionId: 'other', encoded: packet),
      throwsA(isA<QrProtocolError>()),
    );
  });

  test('a version-one invite asks the user to renew pairing', () {
    final encoded = QrProtocol.encodeInvite({
      'v': 1,
      'type': 'invite',
      'session': 'legacy',
    });
    expect(
      () => QrProtocol.decodeInvite(encoded),
      throwsA(isA<QrProtocolError>()),
    );
  });

  test('changing an authenticated sender identifier is rejected', () async {
    final packet = await QrProtocol.encrypt(
      secret: secret,
      sessionId: 'session',
      sourceParticipantId: 'partner-a',
      eventType: 'choosing_votes',
      sequence: 1,
      payload: const {'votes': {}},
    );
    final decoded = jsonDecode(utf8.decode(base64Url.decode(packet))) as Map;
    decoded['source'] = 'partner-b';
    final altered = base64Url.encode(utf8.encode(jsonEncode(decoded)));

    await expectLater(
      QrProtocol.decrypt(
        secret: secret,
        sessionId: 'session',
        encoded: altered,
      ),
      throwsA(isA<QrProtocolError>()),
    );
  });

  test('confirmation code is shared regardless of participant order', () async {
    final first = await QrProtocol.confirmationCode(
      secret: secret,
      firstParticipantId: 'a',
      secondParticipantId: 'b',
    );
    final second = await QrProtocol.confirmationCode(
      secret: secret,
      firstParticipantId: 'b',
      secondParticipantId: 'a',
    );
    expect(first, second);
    expect(first, hasLength(6));
  });
}
