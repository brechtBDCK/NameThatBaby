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
      'v': 1,
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
    expect((decoded['payload'] as Map<String, Object?>)['votes'], {'1': 'yes'});
    await expectLater(
      QrProtocol.decrypt(secret: secret, sessionId: 'other', encoded: packet),
      throwsA(isA<QrProtocolError>()),
    );
  });
}
