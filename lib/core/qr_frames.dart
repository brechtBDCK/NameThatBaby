import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'qr_protocol.dart';

class QrFrameError implements Exception {
  const QrFrameError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Splits an already encrypted QR payload into bounded, independently labelled
/// frames. The encrypted packet is still authenticated after reassembly.
class QrFrameCodec {
  QrFrameCodec._();

  static const _prefix = 'NTB3F';
  static const maxFrames = 16;
  static const _headerAllowance = 100;

  static Future<List<String>> frame(
    String packet, {
    int maximumFrameLength = 1200,
  }) async {
    if (packet.length <= maximumFrameLength) return [packet];
    final chunkLength = maximumFrameLength - _headerAllowance;
    if (chunkLength < 100) {
      throw const QrFrameError('QR frame limit is too small.');
    }
    final total = (packet.length / chunkLength).ceil();
    if (total > maxFrames) {
      throw const QrFrameError('This update is too large to transfer by QR.');
    }
    final id = (await QrProtocol.newIdentifier()).substring(0, 10);
    final digest = base64Url
        .encode((await Sha256().hash(utf8.encode(packet))).bytes)
        .replaceAll('=', '');
    return [
      for (var index = 0; index < total; index++)
        '$_prefix|$id|$index|$total|$digest|${packet.substring(index * chunkLength, (index + 1) * chunkLength > packet.length ? packet.length : (index + 1) * chunkLength)}',
    ];
  }
}

/// Stateful reassembly for a single scan session. Returns null until complete.
class QrFrameCollector {
  String? _id;
  String? _digest;
  int? _total;
  final _parts = <int, String>{};

  Future<String?> add(String frame) async {
    if (!frame.startsWith('${QrFrameCodec._prefix}|')) return frame;
    final values = frame.split('|');
    if (values.length != 6) {
      throw const QrFrameError('This QR frame is damaged or incomplete.');
    }
    final index = int.tryParse(values[2]);
    final total = int.tryParse(values[3]);
    if (index == null ||
        total == null ||
        total < 2 ||
        total > QrFrameCodec.maxFrames ||
        index < 0 ||
        index >= total ||
        values[1].isEmpty ||
        values[4].isEmpty) {
      throw const QrFrameError('This QR frame has invalid metadata.');
    }
    if (_id == null) {
      _id = values[1];
      _digest = values[4];
      _total = total;
    } else if (_id != values[1] || _digest != values[4] || _total != total) {
      throw const QrFrameError('This frame belongs to a different update.');
    }
    _parts[index] = values[5];
    if (_parts.length != total) return null;
    final packet = List.generate(total, (index) => _parts[index]!).join();
    final digest = base64Url
        .encode((await Sha256().hash(utf8.encode(packet))).bytes)
        .replaceAll('=', '');
    if (digest != _digest) {
      throw const QrFrameError('The scanned QR frames do not match.');
    }
    reset();
    return packet;
  }

  void reset() {
    _id = null;
    _digest = null;
    _total = null;
    _parts.clear();
  }
}
