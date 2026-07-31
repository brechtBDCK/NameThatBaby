import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class QrProtocolError implements Exception {
  const QrProtocolError(this.message);
  final String message;
  @override
  String toString() => message;
}

class QrProtocol {
  QrProtocol._();

  static const version = 1;
  static final _algorithm = AesGcm.with256bits();

  static Future<List<int>> newSecret() async =>
      SecretKeyData.random(length: 32).bytes;

  static String encodeInvite(Map<String, Object?> invite) {
    return base64Url.encode(utf8.encode(jsonEncode(invite)));
  }

  static Map<String, Object?> decodeInvite(String text) {
    try {
      final decoded = jsonDecode(utf8.decode(base64Url.decode(text)));
      if (decoded is! Map) throw const FormatException();
      final value = decoded.cast<String, Object?>();
      if (value['v'] != version || value['type'] != 'invite') {
        throw const QrProtocolError('This is not a compatible pairing code.');
      }
      return value;
    } on QrProtocolError {
      rethrow;
    } catch (_) {
      throw const QrProtocolError(
        'This pairing code is damaged or incomplete.',
      );
    }
  }

  static Future<String> encrypt({
    required List<int> secret,
    required String sessionId,
    required String eventType,
    required int sequence,
    required Map<String, Object?> payload,
  }) async {
    final body = utf8.encode(jsonEncode(payload));
    final box = await _algorithm.encrypt(
      body,
      secretKey: SecretKeyData(secret),
      aad: utf8.encode('$version|$sessionId|$eventType|$sequence'),
    );
    return base64Url.encode(
      utf8.encode(
        jsonEncode({
          'v': version,
          'type': eventType,
          'session': sessionId,
          'sequence': sequence,
          'nonce': base64Url.encode(box.nonce),
          'tag': base64Url.encode(box.mac.bytes),
          'ciphertext': base64Url.encode(box.cipherText),
        }),
      ),
    );
  }

  static Future<Map<String, Object?>> decrypt({
    required List<int> secret,
    required String sessionId,
    required String encoded,
  }) async {
    try {
      final raw = jsonDecode(utf8.decode(base64Url.decode(encoded)));
      if (raw is! Map) throw const FormatException();
      final envelope = raw.cast<String, Object?>();
      final eventType = envelope['type'];
      final sequence = envelope['sequence'];
      if (envelope['v'] != version ||
          envelope['session'] != sessionId ||
          eventType is! String ||
          sequence is! int) {
        throw const QrProtocolError(
          'This update belongs to a different session.',
        );
      }
      final box = SecretBox(
        base64Url.decode(envelope['ciphertext']! as String),
        nonce: base64Url.decode(envelope['nonce']! as String),
        mac: Mac(base64Url.decode(envelope['tag']! as String)),
      );
      final clear = await _algorithm.decrypt(
        box,
        secretKey: SecretKeyData(secret),
        aad: utf8.encode('$version|$sessionId|$eventType|$sequence'),
      );
      final payload = jsonDecode(utf8.decode(clear));
      if (payload is! Map) throw const FormatException();
      return {
        'type': eventType,
        'sequence': sequence,
        'payload': payload.cast<String, Object?>(),
      };
    } on QrProtocolError {
      rethrow;
    } catch (_) {
      throw const QrProtocolError('This update could not be authenticated.');
    }
  }
}
