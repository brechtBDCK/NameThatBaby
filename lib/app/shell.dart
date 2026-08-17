import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'theme.dart';

class Shell extends StatelessWidget {
  const Shell({super.key, required this.child, this.back});
  final Widget child;
  final VoidCallback? back;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: back == null
        ? null
        : AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: back,
              tooltip: 'Back',
            ),
          ),
    body: SafeArea(
      child: Stack(
        children: [
          const Positioned(
            top: -10,
            left: -8,
            child: ExcludeSemantics(
              child: IgnorePointer(child: BotanicalSprig(flip: false)),
            ),
          ),
          const Positioned(
            right: -8,
            bottom: -10,
            child: ExcludeSemantics(
              child: IgnorePointer(child: BotanicalSprig(flip: true)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: child,
          ),
        ],
      ),
    ),
  );
}

class BotanicalSprig extends StatelessWidget {
  const BotanicalSprig({super.key, required this.flip});
  final bool flip;

  @override
  Widget build(BuildContext context) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.diagonal3Values(flip ? -1 : 1, flip ? -1 : 1, 1),
    child: CustomPaint(size: const Size(128, 128), painter: _SprigPainter()),
  );
}

/// App mark from the NameThatBaby visual identity: two leaves and a seed.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size),
    painter: _BrandMarkPainter(),
  );
}

Widget scannerError(
  BuildContext context,
  MobileScannerException error,
) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.no_photography_outlined,
          size: 48,
          color: Palette.terra,
        ),
        const SizedBox(height: 12),
        Text(
          error.errorCode == MobileScannerErrorCode.permissionDenied
              ? 'Camera access is turned off. Enable camera access for NameThatBaby in your phone settings, then try again.'
              : 'The camera scanner is unavailable. Close this screen and try again.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  ),
);

class _SprigPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = Palette.forest.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final leaf = Paint()..color = Palette.forest.withValues(alpha: 0.5);
    final berry = Paint()..color = Palette.gold.withValues(alpha: 0.7);
    final path = Path()
      ..moveTo(-4, size.height + 4)
      ..quadraticBezierTo(50, 66, 112, 12);
    canvas.drawPath(path, stem);
    for (final point in <Offset>[
      const Offset(24, 88),
      const Offset(48, 64),
      const Offset(72, 42),
      const Offset(94, 25),
    ]) {
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(-0.7);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 14, height: 30),
        leaf,
      );
      canvas.restore();
    }
    canvas.drawCircle(const Offset(80, 34), 5, berry);
    canvas.drawCircle(const Offset(101, 16), 4, berry);
  }

  @override
  bool shouldRepaint(covariant _SprigPainter oldDelegate) => false;
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 96;
    canvas.scale(scale, scale);
    final terra = Paint()..color = Palette.terra;
    final forest = Paint()..color = Palette.forest;
    final gold = Paint()..color = Palette.gold;
    final leftLeaf = Path()
      ..moveTo(43, 66)
      ..cubicTo(17, 57, 13, 28, 27, 13)
      ..cubicTo(49, 24, 61, 45, 43, 66)
      ..close();
    final rightLeaf = Path()
      ..moveTo(47, 67)
      ..cubicTo(51, 35, 69, 22, 84, 21)
      ..cubicTo(89, 49, 72, 68, 47, 67)
      ..close();
    canvas.drawPath(leftLeaf, terra);
    canvas.drawPath(rightLeaf, forest);
    canvas.drawCircle(const Offset(62, 13), 11, gold);
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) => false;
}
