import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'core/domain.dart';
import 'core/qr_frames.dart';
import 'core/qr_protocol.dart';
import 'core/session_store.dart';
import 'data/bundled_name_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final manifest =
      (jsonDecode(await rootBundle.loadString('assets/data/manifest.json'))
              as Map)
          .cast<String, Object?>();
  final repository = BundledNameRepository();
  final store = SessionStore(
    datasetHash: manifest['sqlite_sha256']! as String,
    candidateLoader: (countries, categories, seed) => repository.candidatePool(
      countries: countries,
      categories: categories,
      seed: seed,
    ),
  );
  await store.restore();
  runApp(NameThatBaby(store: store));
}

class Palette {
  static const cream = Color(0xfff6f0e4);
  static const surface = Color(0xfffff9ef);
  static const forest = Color(0xff244b38);
  static const terra = Color(0xffc65d3b);
  static const sky = Color(0xffafcedb);
  static const gold = Color(0xffd79a29);
}

class NameThatBaby extends StatelessWidget {
  const NameThatBaby({super.key, required this.store});
  final SessionStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NameThatBaby',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Palette.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Palette.forest,
        surface: Palette.surface,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: Palette.forest,
        displayColor: Palette.forest,
      ),
    ),
    home: AnimatedBuilder(
      animation: store,
      builder: (context, child) => AppShell(store: store),
    ),
  );
}

enum AppPage {
  welcome,
  setup,
  invite,
  scan,
  pairAccept,
  scanPairAccept,
  scanUpdate,
  home,
  choosing,
  sync,
  shortlist,
  custom,
  faceoff,
  results,
  privacy,
  dataSources,
  recovery,
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final SessionStore store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppPage page = widget.store.restoreError != null
      ? AppPage.recovery
      : widget.store.hasSession
      ? AppPage.home
      : AppPage.welcome;
  void go(AppPage value) => setState(() => page = value);
  @override
  Widget build(BuildContext context) {
    switch (page) {
      case AppPage.welcome:
        return Welcome(
          create: () => go(AppPage.setup),
          join: () => go(AppPage.scan),
        );
      case AppPage.setup:
        return Setup(
          store: widget.store,
          done: () async {
            await widget.store.ensureSession();
            widget.store.join();
            go(AppPage.invite);
          },
        );
      case AppPage.invite:
        return Invite(
          store: widget.store,
          done: () => go(AppPage.home),
          scanAcceptance: () => go(AppPage.scanPairAccept),
        );
      case AppPage.scan:
        return ScanInvite(
          store: widget.store,
          done: () => go(AppPage.pairAccept),
          back: () => go(AppPage.welcome),
        );
      case AppPage.pairAccept:
        return PairAccept(store: widget.store, done: () => go(AppPage.home));
      case AppPage.scanPairAccept:
        return ScanPairAccept(
          store: widget.store,
          done: () => go(AppPage.home),
          back: () => go(AppPage.invite),
        );
      case AppPage.scanUpdate:
        return ScanUpdate(
          store: widget.store,
          done: () => go(AppPage.sync),
          back: () => go(AppPage.sync),
        );
      case AppPage.home:
        return Home(store: widget.store, go: go);
      case AppPage.choosing:
        return Choosing(
          store: widget.store,
          done: () =>
              go(widget.store.choosingDone ? AppPage.sync : AppPage.home),
          back: () => go(AppPage.home),
        );
      case AppPage.sync:
        return SyncVotes(
          store: widget.store,
          done: () => go(AppPage.shortlist),
          scan: () => go(AppPage.scanUpdate),
        );
      case AppPage.shortlist:
        return Shortlist(
          store: widget.store,
          custom: () => go(AppPage.custom),
          faceoff: () {
            widget.store.startFaceoff();
            go(AppPage.faceoff);
          },
        );
      case AppPage.custom:
        return CustomNames(
          store: widget.store,
          done: () {
            widget.store.startFaceoff();
            go(AppPage.faceoff);
          },
        );
      case AppPage.faceoff:
        return Faceoff(store: widget.store, done: () => go(AppPage.results));
      case AppPage.results:
        return Results(store: widget.store, home: () => go(AppPage.home));
      case AppPage.privacy:
        return Privacy(store: widget.store, back: () => go(AppPage.home));
      case AppPage.dataSources:
        return DataSources(back: () => go(AppPage.home));
      case AppPage.recovery:
        return Recovery(store: widget.store, done: () => go(AppPage.welcome));
    }
  }
}

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

class Welcome extends StatelessWidget {
  const Welcome({super.key, required this.create, required this.join});
  final VoidCallback create, join;
  @override
  Widget build(BuildContext context) => Shell(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(Icons.local_florist, size: 86, color: Palette.terra),
        const SizedBox(height: 16),
        Text(
          'NameThatBaby',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'Find the name you both love.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20),
        ),
        const Spacer(),
        FilledButton(
          onPressed: create,
          child: const Text('Create a naming session'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: join, child: const Text('Join partner')),
        const SizedBox(height: 18),
        const Center(
          child: Chip(
            avatar: Icon(Icons.lock_outline),
            label: Text('Private & offline'),
          ),
        ),
      ],
    ),
  );
}

class Setup extends StatelessWidget {
  const Setup({super.key, required this.store, required this.done});
  final SessionStore store;
  final Future<void> Function() done;
  static const countries = {
    'US': 'United States',
    'CA': 'Canada',
    'BE': 'Belgium',
    'NL': 'Netherlands',
    'DK': 'Denmark',
    'NO': 'Norway',
    'SE': 'Sweden',
    'DE': 'Germany',
    'FR': 'France',
    'ES': 'Spain',
    'IT': 'Italy',
    'AT': 'Austria',
    'GB': 'United Kingdom',
    'IE': 'Ireland',
    'AU': 'Australia',
  };
  @override
  Widget build(BuildContext context) => Shell(
    child: ListView(
      children: [
        Text(
          'Choose your name pool',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        const Text(
          'Each selected country contributes equally. Latest 10 complete years · 150 names per category.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: countries.entries
              .map(
                (entry) => FilterChip(
                  label: Text(entry.value),
                  selected: store.countries.contains(entry.key),
                  onSelected: (_) => store.toggleCountry(entry.key),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 22),
        const Text(
          'Names to explore',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ...NameCategory.values.map(
          (category) => CheckboxListTile(
            value: store.categories.contains(category),
            onChanged: (_) => store.toggleCategory(category),
            title: Text(category == NameCategory.girls ? 'Girls' : 'Boys'),
          ),
        ),
        FilledButton(
          onPressed: done,
          child: const Text('Create private session'),
        ),
      ],
    ),
  );
}

class Invite extends StatelessWidget {
  const Invite({
    super.key,
    required this.store,
    required this.done,
    required this.scanAcceptance,
  });
  final SessionStore store;
  final VoidCallback done, scanAcceptance;
  @override
  Widget build(BuildContext context) => Shell(
    child: Center(
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            'Pair your phones',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Show this code to your partner. Nothing is uploaded.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: store.invitePayload(),
              version: QrVersions.auto,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Palette.forest,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Palette.forest,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Confirmation: ${store.sessionId.substring(0, 6).toUpperCase()}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: scanAcceptance,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan partner confirmation'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: done, child: const Text('Continue choosing')),
        ],
      ),
    ),
  );
}

class PairAccept extends StatefulWidget {
  const PairAccept({super.key, required this.store, required this.done});
  final SessionStore store;
  final VoidCallback done;

  @override
  State<PairAccept> createState() => _PairAcceptState();
}

class _PairAcceptState extends State<PairAccept> {
  late final Future<String> packet = widget.store.pairAcceptPayload();

  @override
  Widget build(BuildContext context) => Shell(
    child: FutureBuilder<String>(
      future: packet,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Confirm your pairing',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Have your partner scan this confirmation code before you start choosing.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: snapshot.data!,
                version: QrVersions.auto,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: widget.done, child: const Text('Continue')),
          ],
        );
      },
    ),
  );
}

class ScanPairAccept extends StatefulWidget {
  const ScanPairAccept({
    super.key,
    required this.store,
    required this.done,
    required this.back,
  });
  final SessionStore store;
  final VoidCallback done, back;

  @override
  State<ScanPairAccept> createState() => _ScanPairAcceptState();
}

class _ScanPairAcceptState extends State<ScanPairAccept> {
  var importing = false;
  String? error;

  Future<void> scan(BarcodeCapture capture) async {
    if (importing) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;
    setState(() => importing = true);
    try {
      await widget.store.importPairAccept(value);
      if (mounted) widget.done();
    } on QrProtocolError catch (exception) {
      if (mounted) {
        setState(() {
          importing = false;
          error = exception.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Shell(
    back: widget.back,
    child: Column(
      children: [
        Text(
          'Scan partner confirmation',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text('This securely completes your private pairing.'),
        const SizedBox(height: 18),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: MobileScanner(onDetect: scan, errorBuilder: scannerError),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    ),
  );
}

class ScanInvite extends StatefulWidget {
  const ScanInvite({
    super.key,
    required this.store,
    required this.done,
    required this.back,
  });
  final SessionStore store;
  final VoidCallback done, back;
  @override
  State<ScanInvite> createState() => _ScanInviteState();
}

class _ScanInviteState extends State<ScanInvite> {
  bool importing = false;
  String? error;
  Future<void> scan(BarcodeCapture capture) async {
    if (importing) {
      return;
    }
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) {
      return;
    }
    setState(() => importing = true);
    try {
      await widget.store.importInvite(value);
      if (mounted) {
        widget.done();
      }
    } on QrProtocolError catch (exception) {
      if (mounted) {
        setState(() {
          importing = false;
          error = exception.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Shell(
    back: widget.back,
    child: Column(
      children: [
        Text(
          'Scan partner code',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text('Point your camera at the pairing code.'),
        const SizedBox(height: 18),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: MobileScanner(onDetect: scan, errorBuilder: scannerError),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    ),
  );
}

class ScanUpdate extends StatefulWidget {
  const ScanUpdate({
    super.key,
    required this.store,
    required this.done,
    required this.back,
  });
  final SessionStore store;
  final VoidCallback done, back;
  @override
  State<ScanUpdate> createState() => _ScanUpdateState();
}

class _ScanUpdateState extends State<ScanUpdate> {
  bool importing = false;
  String? error;
  final frames = QrFrameCollector();
  Future<void> scan(BarcodeCapture capture) async {
    if (importing) {
      return;
    }
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) {
      return;
    }
    setState(() => importing = true);
    try {
      final packet = await frames.add(value);
      if (packet == null) {
        if (mounted) {
          setState(() {
            importing = false;
            error = 'Frame scanned. Keep scanning the remaining frames.';
          });
        }
        return;
      }
      await widget.store.importVoteUpdate(packet);
      if (mounted) {
        widget.done();
      }
    } on QrProtocolError catch (exception) {
      if (mounted) {
        setState(() {
          importing = false;
          error = exception.message;
        });
      }
    } on QrFrameError catch (exception) {
      if (mounted) {
        setState(() {
          importing = false;
          error = exception.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Shell(
    back: widget.back,
    child: Column(
      children: [
        Text(
          'Scan partner update',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text('Scan the encrypted vote code your partner displays.'),
        const SizedBox(height: 18),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: MobileScanner(onDetect: scan, errorBuilder: scannerError),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    ),
  );
}

class Home extends StatelessWidget {
  const Home({super.key, required this.store, required this.go});
  final SessionStore store;
  final void Function(AppPage) go;
  @override
  Widget build(BuildContext context) => Shell(
    child: ListView(
      children: [
        Text(
          'NameThatBaby',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        const Text('Find the name you both love.'),
        const SizedBox(height: 22),
        ...NameCategory.values
            .where(store.categories.contains)
            .map(
              (category) => ProgressCard(
                category: category,
                progress: store.progress(category),
                remaining: store.remaining(category).length,
              ),
            ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => go(AppPage.choosing),
          child: Text(
            store.choosingDone ? 'Choices complete' : 'Continue choosing',
          ),
        ),
        if (store.choosingDone)
          OutlinedButton(
            onPressed: () => go(AppPage.sync),
            child: const Text('Synchronize choices'),
          ),
        if (store.partnerVotesReceived)
          FilledButton.tonalIcon(
            onPressed: () => go(AppPage.shortlist),
            icon: const Icon(Icons.favorite_outline),
            label: const Text('View shared favorites'),
          ),
        if (store.faceoffStarted && !store.faceoffDone)
          FilledButton.tonalIcon(
            onPressed: () => go(AppPage.faceoff),
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Resume Face-off'),
          ),
        if (store.faceoffDone)
          FilledButton.tonalIcon(
            onPressed: () => go(AppPage.results),
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('View final results'),
          ),
        ListTile(
          leading: Icon(
            store.hasPartner ? Icons.people_alt_outlined : Icons.qr_code_2,
          ),
          title: Text(
            store.hasPartner ? 'Partner paired' : 'Waiting for partner',
          ),
          subtitle: Text(
            store.hasPartner
                ? 'Exchange encrypted codes when you are ready.'
                : 'Show your pairing code to connect privately.',
          ),
          onTap: store.hasPartner ? null : () => go(AppPage.invite),
        ),
        if (store.hasPartner)
          FutureBuilder<String?>(
            future: store.confirmationCode(),
            builder: (context, snapshot) => ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Pairing confirmation'),
              subtitle: Text(
                snapshot.hasData
                    ? 'Check that both phones show ${snapshot.data}.'
                    : 'Loading confirmation code…',
              ),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Private & offline'),
          onTap: () => go(AppPage.privacy),
        ),
        ListTile(
          leading: const Icon(Icons.storage_outlined),
          title: const Text('Name data & coverage'),
          subtitle: const Text('Bundled sources on this device'),
          onTap: () => go(AppPage.dataSources),
        ),
      ],
    ),
  );
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.category,
    required this.progress,
    required this.remaining,
  });

  final NameCategory category;
  final double progress;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final girls = category == NameCategory.girls;
    final color = girls ? Palette.terra : Palette.forest;
    final label = girls ? 'Girls' : 'Boys';
    final percent = (progress * 100).round();
    return Semantics(
      label: '$label, $percent percent complete, $remaining names left',
      child: Card(
        elevation: 0,
        color: girls ? const Color(0xffffe8d9) : const Color(0xffe1f0f3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: color.withValues(alpha: 0.16),
                        color: color,
                      ),
                    ),
                    Text('$percent%', style: TextStyle(color: color)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label · $percent% complete',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$remaining names left'),
                  ],
                ),
              ),
              Icon(Icons.spa_outlined, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class Choosing extends StatelessWidget {
  const Choosing({
    super.key,
    required this.store,
    required this.done,
    this.back,
  });
  final SessionStore store;
  final VoidCallback done;
  final VoidCallback? back;
  @override
  Widget build(BuildContext context) {
    final candidate = store.current;
    if (candidate == null) {
      return Shell(
        back: back,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration, size: 64, color: Palette.gold),
              const Text(
                'Your choices are ready',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: done,
                child: const Text('Synchronize with partner'),
              ),
            ],
          ),
        ),
      );
    }
    final categoryLabel = candidate.category == NameCategory.girls
        ? 'Girls'
        : 'Boys';
    return Shell(
      back: back,
      child: Column(
        children: [
          Text(
            '$categoryLabel · ${store.remaining(candidate.category).length} names left',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 350) return;
                HapticFeedback.selectionClick();
                store.vote(velocity < 0 ? VoteValue.no : VoteValue.yes);
              },
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > -350) return;
                HapticFeedback.selectionClick();
                store.vote(VoteValue.maybe);
              },
              child: Semantics(
                label:
                    '${candidate.name}, ${candidate.category == NameCategory.girls ? 'girls' : 'boys'}, ${store.remaining(candidate.category).length} names remaining. Swipe left for No, up for Maybe, or right for Yes.',
                child: Card(
                  color: Palette.surface,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.spa, color: Palette.forest),
                        const SizedBox(height: 16),
                        Text(
                          candidate.name,
                          style: Theme.of(context).textTheme.displayLarge!
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 16),
                        Text(candidate.countries.join(' · ')),
                        const SizedBox(height: 6),
                        Text(
                          'Ranked #${candidate.rank} in your selected pool',
                          style: TextStyle(
                            color: Palette.forest.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Decision(
                icon: Icons.close,
                label: 'No',
                color: Palette.terra,
                onTap: () => store.vote(VoteValue.no),
              ),
              Decision(
                icon: Icons.question_mark,
                label: 'Maybe',
                color: Palette.gold,
                onTap: () => store.vote(VoteValue.maybe),
              ),
              Decision(
                icon: Icons.favorite,
                label: 'Yes',
                color: Palette.forest,
                onTap: () => store.vote(VoteValue.yes),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: store.history.isEmpty ? null : store.undo,
            icon: const Icon(Icons.undo),
            label: const Text('Undo last decision'),
          ),
        ],
      ),
    );
  }
}

class Decision extends StatelessWidget {
  const Decision({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      IconButton.filled(
        onPressed: onTap,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: Palette.surface,
          foregroundColor: color,
          minimumSize: const Size(64, 64),
        ),
      ),
      Text(
        label.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    ],
  );
}

class SyncVotes extends StatefulWidget {
  const SyncVotes({
    super.key,
    required this.store,
    required this.done,
    required this.scan,
  });
  final SessionStore store;
  final VoidCallback done, scan;
  @override
  State<SyncVotes> createState() => _SyncVotesState();
}

class _SyncVotesState extends State<SyncVotes> {
  List<String>? frames;
  var frameIndex = 0;
  String? error;
  Future<void> make() async {
    try {
      setState(() {
        frames = null;
        frameIndex = 0;
      });
      final value = await widget.store.voteUpdatePayload();
      final framed = await QrFrameCodec.frame(value);
      if (mounted) {
        setState(() => frames = framed);
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to create a protected update.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Shell(
    child: ListView(
      children: [
        Text(
          'Synchronize choices',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        const Text(
          'Show your encrypted update to your partner, then scan theirs.',
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: make, child: const Text('Create my vote code')),
        if (frames != null)
          Container(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: frames![frameIndex],
              version: QrVersions.auto,
            ),
          ),
        if ((frames?.length ?? 0) > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Frame ${frameIndex + 1} of ${frames!.length}'),
              TextButton(
                onPressed: () => setState(
                  () => frameIndex = (frameIndex + 1) % frames!.length,
                ),
                child: const Text('Next frame'),
              ),
            ],
          ),
        OutlinedButton(
          onPressed: widget.scan,
          child: const Text('Scan partner code'),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        if (widget.store.partnerVotesReceived)
          FilledButton(
            onPressed: widget.done,
            child: const Text('View shared favorites'),
          ),
      ],
    ),
  );
}

class Shortlist extends StatelessWidget {
  const Shortlist({
    super.key,
    required this.store,
    required this.custom,
    required this.faceoff,
  });
  final SessionStore store;
  final VoidCallback custom, faceoff;
  @override
  Widget build(BuildContext context) {
    final entries = store.enabled.where((candidate) {
      final mine = store.votes[candidate.id];
      final partner = store.partnerVotes[candidate.id];
      return mine != null &&
          partner != null &&
          matchTier(mine, partner) != MatchTier.rejected;
    }).toList();
    final strong = entries
        .where(
          (candidate) =>
              matchTier(
                store.votes[candidate.id]!,
                store.partnerVotes[candidate.id]!,
              ) ==
              MatchTier.strong,
        )
        .length;
    return Shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Shared favorites',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
          ),
          Text('$strong strong · ${entries.length - strong} consider'),
          Expanded(
            child: ListView(
              children: entries
                  .map(
                    (entry) => Card(
                      child: ListTile(
                        title: Text(entry.name),
                        subtitle: Text(entry.countries.join(', ')),
                        trailing: Chip(
                          label: Text(
                            matchTier(
                                      store.votes[entry.id]!,
                                      store.partnerVotes[entry.id]!,
                                    ) ==
                                    MatchTier.strong
                                ? 'Strong'
                                : 'Consider',
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          OutlinedButton(
            onPressed: custom,
            child: const Text('Add custom names'),
          ),
          FilledButton(
            onPressed: store.canStartFaceoff ? faceoff : null,
            child: Text(
              store.canStartFaceoff
                  ? 'Start Face-off'
                  : 'Add two names to start Face-off',
            ),
          ),
        ],
      ),
    );
  }
}

class CustomNames extends StatefulWidget {
  const CustomNames({super.key, required this.store, required this.done});
  final SessionStore store;
  final VoidCallback done;
  @override
  State<CustomNames> createState() => _CustomNamesState();
}

class _CustomNamesState extends State<CustomNames> {
  final controller = TextEditingController();
  final selected = <NameCategory>{NameCategory.girls};
  var error = '';
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Shell(
    child: ListView(
      children: [
        Text(
          'Add a name',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        const Text('Available only for Face-off.'),
        TextField(
          controller: controller,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: 'Name',
            errorText: error.isEmpty ? null : error,
          ),
        ),
        const Text('Add to'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: NameCategory.values
              .map(
                (category) => FilterChip(
                  label: Text(
                    category == NameCategory.girls ? 'Girls' : 'Boys',
                  ),
                  selected: selected.contains(category),
                  onSelected: (value) {
                    if (!value && selected.length == 1) return;
                    setState(() {
                      value
                          ? selected.add(category)
                          : selected.remove(category);
                    });
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            if (widget.store.addCustom(controller.text, selected)) {
              controller.clear();
              setState(() => error = '');
            } else {
              setState(
                () => error =
                    'Use a unique name with letters (up to 40 characters).',
              );
            }
          },
          child: const Text('Add name'),
        ),
        _CustomList(
          label: 'Girls',
          names: widget.store.customGirls,
          remove: (name) => setState(
            () => widget.store.removeCustom(name, NameCategory.girls),
          ),
        ),
        _CustomList(
          label: 'Boys',
          names: widget.store.customBoys,
          remove: (name) => setState(
            () => widget.store.removeCustom(name, NameCategory.boys),
          ),
        ),
        FilledButton(
          onPressed: widget.store.canStartFaceoff ? widget.done : null,
          child: Text(
            widget.store.canStartFaceoff
                ? 'Continue to Face-off'
                : 'Add two names to continue',
          ),
        ),
      ],
    ),
  );
}

class _CustomList extends StatelessWidget {
  const _CustomList({
    required this.label,
    required this.names,
    required this.remove,
  });
  final String label;
  final List<String> names;
  final ValueChanged<String> remove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Text('$label: '),
        ...names.map(
          (name) => InputChip(label: Text(name), onDeleted: () => remove(name)),
        ),
      ],
    ),
  );
}

class Faceoff extends StatelessWidget {
  const Faceoff({super.key, required this.store, required this.done});
  final SessionStore store;
  final VoidCallback done;
  @override
  Widget build(BuildContext context) {
    if (store.faceoffDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) => done());
    }
    if (store.faceoffRoundReady) {
      return FaceoffRoundSync(store: store, done: done);
    }
    final pairing = store.currentFaceoff;
    final category = store.faceoffCategory;
    if (pairing == null || category == null) {
      return Shell(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.list_alt, size: 64, color: Palette.gold),
              const SizedBox(height: 12),
              const Text(
                'Add at least two shared names',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Face-off needs two names in the same list.'),
              const SizedBox(height: 20),
              FilledButton(onPressed: done, child: const Text('View results')),
            ],
          ),
        ),
      );
    }

    return Shell(
      child: Column(
        children: [
          Text(
            store.faceoffTieBreakActive
                ? 'Face-off · targeted tie-break'
                : 'Face-off · round ${store.faceoffRound + 1} of ${SessionStore.faceoffRoundCount}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            '${category == NameCategory.girls ? 'Girls' : 'Boys'} · pairing ${store.faceoffPairIndex + 1} of ${store.faceoffPairings.length}',
          ),
          const SizedBox(height: 8),
          const Text('Choose the name you both prefer, or skip if undecided.'),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ChoiceCard(
                  name: pairing.left,
                  onTap: () => store.chooseFaceoff(pairing.left),
                ),
              ),
              const Padding(padding: EdgeInsets.all(12), child: Text('or')),
              Expanded(
                child: ChoiceCard(
                  name: pairing.right,
                  onTap: () => store.chooseFaceoff(pairing.right),
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: store.faceoffVoteHistory.isEmpty
                ? null
                : store.undoFaceoffVote,
            icon: const Icon(Icons.undo),
            label: const Text('Undo my last choice'),
          ),
          OutlinedButton.icon(
            onPressed: () => store.chooseFaceoff(null),
            icon: const Icon(Icons.skip_next),
            label: const Text('Skip this pairing'),
          ),
        ],
      ),
    );
  }
}

class FaceoffRoundSync extends StatefulWidget {
  const FaceoffRoundSync({super.key, required this.store, required this.done});

  final SessionStore store;
  final VoidCallback done;

  @override
  State<FaceoffRoundSync> createState() => _FaceoffRoundSyncState();
}

class _FaceoffRoundSyncState extends State<FaceoffRoundSync> {
  List<String>? frames;
  var frameIndex = 0;
  String? error;
  var scanning = false;
  var importing = false;
  final collector = QrFrameCollector();

  @override
  void initState() {
    super.initState();
    makePacket();
  }

  Future<void> makePacket() async {
    try {
      final value = await widget.store.faceoffUpdatePayload();
      final framed = await QrFrameCodec.frame(value);
      if (mounted) setState(() => frames = framed);
    } on Object catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to create this protected round update.');
      }
    }
  }

  Future<void> scan(BarcodeCapture capture) async {
    if (importing) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;
    setState(() => importing = true);
    try {
      final packet = await collector.add(value);
      if (packet == null) {
        if (mounted) {
          setState(() {
            importing = false;
            error = 'Frame scanned. Keep scanning the remaining frames.';
          });
        }
        return;
      }
      await widget.store.importFaceoffUpdate(packet);
      if (mounted) setState(() => scanning = false);
    } on QrProtocolError catch (exception) {
      if (mounted) {
        setState(() {
          importing = false;
          error = exception.message;
        });
      }
    } on QrFrameError catch (exception) {
      if (mounted) {
        setState(() {
          importing = false;
          error = exception.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Shell(
    child: ListView(
      children: [
        Text(
          'Round ready to sync',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        const Text(
          'Your choices stay private until both phones exchange this round.',
        ),
        if (frames != null)
          Container(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: frames![frameIndex],
              version: QrVersions.auto,
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        if ((frames?.length ?? 0) > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Frame ${frameIndex + 1} of ${frames!.length}'),
              TextButton(
                onPressed: () => setState(
                  () => frameIndex = (frameIndex + 1) % frames!.length,
                ),
                child: const Text('Next frame'),
              ),
            ],
          ),
        FilledButton.icon(
          onPressed: () => setState(() {
            scanning = !scanning;
            error = null;
          }),
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(scanning ? 'Close scanner' : 'Scan partner round'),
        ),
        if (scanning)
          SizedBox(
            height: 300,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: MobileScanner(
                  onDetect: scan,
                  errorBuilder: scannerError,
                ),
              ),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    ),
  );
}

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({super.key, required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        name,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    ),
  );
}

class Results extends StatelessWidget {
  const Results({super.key, required this.home, required this.store});
  final VoidCallback home;
  final SessionStore store;
  @override
  Widget build(BuildContext context) => Shell(
    child: ListView(
      children: [
        Text(
          'Your shared top names',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        const Text('Face-off wins decide each list.'),
        ...NameCategory.values.where(store.categories.contains).expand((
          category,
        ) {
          final results = store.results(category).take(10).toList();
          return [
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(
                category == NameCategory.girls ? 'Girls' : 'Boys',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (results.isEmpty) const Text('No shared names yet.'),
            ...results.asMap().entries.map(
              (entry) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Palette.gold,
                    child: Text('${entry.key + 1}'),
                  ),
                  title: Text(entry.value.name),
                  trailing: Text(
                    '${entry.value.score} ${entry.value.score == 1 ? 'point' : 'points'}',
                  ),
                ),
              ),
            ),
          ];
        }),
        FilledButton(onPressed: home, child: const Text('Back to home')),
      ],
    ),
  );
}

class Privacy extends StatelessWidget {
  const Privacy({super.key, required this.store, required this.back});
  final SessionStore store;
  final VoidCallback back;
  @override
  Widget build(BuildContext context) => Shell(
    child: ListView(
      children: [
        Text(
          'Private by design',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        const Text(
          'Your choices stay on your phones. There is no account and no server. Name lists are included with the app. You share a session only by showing and scanning codes with your partner.',
        ),
        const ListTile(
          leading: Icon(Icons.wifi_off),
          title: Text('No runtime network'),
        ),
        const ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Encrypted session key in secure storage'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete this session?'),
                content: const Text(
                  'This removes your choices, matches, Face-off state, and local session key from this phone. This cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep session'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete session'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await store.reset();
              back();
            }
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete local session'),
        ),
        TextButton(onPressed: back, child: const Text('Back')),
      ],
    ),
  );
}

class DataSources extends StatelessWidget {
  const DataSources({super.key, required this.back});
  final VoidCallback back;

  Future<Map<String, Object?>> _manifest() async {
    final text = await rootBundle.loadString('assets/data/manifest.json');
    return (jsonDecode(text) as Map).cast<String, Object?>();
  }

  @override
  Widget build(BuildContext context) => Shell(
    back: back,
    child: FutureBuilder<Map<String, Object?>>(
      future: _manifest(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('The bundled data manifest could not be read.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final manifest = snapshot.data!;
        final fixture = manifest['contains_fixture_coverage'] == true;
        final countries = (manifest['countries'] as List).cast<Map>();
        return ListView(
          children: [
            Text(
              'Name data & coverage',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              fixture
                  ? 'This build includes some fixture data. It is not ready for release use.'
                  : 'All listed data is bundled with this app and available offline.',
            ),
            const SizedBox(height: 12),
            ...countries.map((entry) {
              final country = entry.cast<String, Object?>();
              final years = (country['covered_years'] as List).join('–');
              return Card(
                child: ListTile(
                  title: Text(country['code']! as String),
                  subtitle: Text('${country['provider']} · $years'),
                  trailing: const Icon(Icons.info_outline),
                ),
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'Source licensing and redistribution remain under review.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        );
      },
    ),
  );
}

class Recovery extends StatelessWidget {
  const Recovery({super.key, required this.store, required this.done});
  final SessionStore store;
  final VoidCallback done;

  @override
  Widget build(BuildContext context) => Shell(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Palette.terra),
          const SizedBox(height: 16),
          Text(
            'Session needs recovery',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            store.restoreError ?? 'The saved session could not be opened.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete unrecoverable session?'),
                  content: const Text(
                    'This removes the local session and its key from this phone. It cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete session'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await store.reset();
                done();
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete local session'),
          ),
        ],
      ),
    ),
  );
}
