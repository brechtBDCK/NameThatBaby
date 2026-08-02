import 'package:flutter_test/flutter_test.dart';
import 'package:name_that_baby/core/qr_frames.dart';

void main() {
  test('multi-frame payload reassembles in any order', () async {
    final frames = await QrFrameCodec.frame(
      'x' * 3000,
      maximumFrameLength: 400,
    );
    expect(frames.length, greaterThan(1));
    final collector = QrFrameCollector();
    String? result;
    for (final frame in frames.reversed) {
      result = await collector.add(frame) ?? result;
    }
    expect(result, 'x' * 3000);
  });

  test('mixed frame sets are rejected', () async {
    final first = await QrFrameCodec.frame('a' * 1000, maximumFrameLength: 400);
    final second = await QrFrameCodec.frame(
      'b' * 1000,
      maximumFrameLength: 400,
    );
    final collector = QrFrameCollector();
    await collector.add(first.first);
    await expectLater(
      collector.add(second.first),
      throwsA(isA<QrFrameError>()),
    );
  });
}
