import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app/theme.dart';
import 'app/shell.dart';
import 'core/domain.dart';
import 'core/qr_frames.dart';
import 'core/qr_protocol.dart';
import 'core/session_store.dart';
import 'data/bundled_name_repository.dart';
import 'features/home/progress_card.dart';

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

Widget scannerPlaceholder(BuildContext context) => const CameraRecovery();

Widget scannerError(BuildContext context, MobileScannerException error) =>
    const CameraRecovery();

class CameraRecovery extends StatelessWidget {
  const CameraRecovery({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Camera unavailable. Allow camera access, then close and reopen the scanner.',
    child: ColoredBox(
      color: Palette.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 44,
              color: Palette.forest,
            ),
            const SizedBox(height: 12),
            const Text(
              'Camera access is needed to scan a code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Allow camera access when Android asks. If you denied it, enable Camera in Android Settings, then close and reopen this scanner.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class NameThatBaby extends StatelessWidget {
  const NameThatBaby({super.key, required this.store});
  final SessionStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NameThatBaby',
    debugShowCheckedModeBanner: false,
    theme: nameThatBabyTheme(),
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
  scanCustomUpdate,
  home,
  choosing,
  sync,
  customSync,
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
  var editingSetup = false;
  NameCategory? choosingCategory;
  void go(AppPage value) => setState(() => page = value);
  @override
  Widget build(BuildContext context) {
    switch (page) {
      case AppPage.welcome:
        return Welcome(
          create: () {
            editingSetup = false;
            go(AppPage.setup);
          },
          join: () => go(AppPage.scan),
        );
      case AppPage.setup:
        return Setup(
          store: widget.store,
          back: editingSetup ? () => go(AppPage.home) : null,
          done: () async {
            await widget.store.ensureSession();
            go(editingSetup ? AppPage.home : AppPage.invite);
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
      case AppPage.scanCustomUpdate:
        return ScanUpdate(
          store: widget.store,
          custom: true,
          done: () => go(AppPage.customSync),
          back: () => go(AppPage.customSync),
        );
      case AppPage.customSync:
        return SyncVotes(
          store: widget.store,
          custom: true,
          done: () async {
            await widget.store.startFaceoff();
            go(AppPage.faceoff);
          },
          scan: () => go(AppPage.scanCustomUpdate),
        );
      case AppPage.home:
        return Home(
          store: widget.store,
          go: go,
          choose: (category) {
            choosingCategory = category;
            go(AppPage.choosing);
          },
          editSelection: () {
            editingSetup = true;
            go(AppPage.setup);
          },
        );
      case AppPage.choosing:
        return Choosing(
          store: widget.store,
          category: choosingCategory,
          done: () =>
              go(widget.store.choosingDone ? AppPage.sync : AppPage.home),
          back: () => go(AppPage.home),
        );
      case AppPage.sync:
        return SyncVotes(
          store: widget.store,
          done: () => go(AppPage.shortlist),
          scan: () => go(AppPage.scanUpdate),
          back: () => go(AppPage.home),
        );
      case AppPage.shortlist:
        return Shortlist(
          store: widget.store,
          custom: () => go(AppPage.custom),
          faceoff: () {
            go(AppPage.custom);
          },
        );
      case AppPage.custom:
        return CustomNames(
          store: widget.store,
          done: () {
            go(AppPage.customSync);
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

class Welcome extends StatelessWidget {
  const Welcome({super.key, required this.create, required this.join});
  final VoidCallback create, join;
  @override
  Widget build(BuildContext context) => Shell(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const BrandMark(size: 96),
        const SizedBox(height: 16),
        Text(
          'NameThatBaby',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
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
  const Setup({super.key, required this.store, required this.done, this.back});
  final SessionStore store;
  final Future<void> Function() done;
  final VoidCallback? back;
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
    back: back,
    child: ListView(
      children: [
        Text(
          'Choose your name pool',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
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
          child: Text(
            store.hasSession ? 'Save selection' : 'Create private session',
          ),
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
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session summary',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Countries: ${widget.store.countries.map((code) => Setup.countries[code] ?? code).join(', ')}',
                    ),
                    Text(
                      'Categories: ${widget.store.categories.map((category) => category == NameCategory.girls ? 'Girls' : 'Boys').join(', ')}',
                    ),
                    Text(
                      'Candidates: ${widget.store.categories.map((category) => '${widget.store.enabled.where((candidate) => candidate.category == category).length} ${category == NameCategory.girls ? 'Girls' : 'Boys'}').join(' · ')}',
                    ),
                    Text(
                      'Dataset edition: ${widget.store.datasetHash.substring(0, 12)}',
                    ),
                  ],
                ),
              ),
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
            child: MobileScanner(
              onDetect: scan,
              errorBuilder: scannerError,
              placeholderBuilder: scannerPlaceholder,
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
            child: MobileScanner(
              onDetect: scan,
              errorBuilder: scannerError,
              placeholderBuilder: scannerPlaceholder,
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

class ScanUpdate extends StatefulWidget {
  const ScanUpdate({
    super.key,
    required this.store,
    required this.done,
    required this.back,
    this.custom = false,
  });
  final SessionStore store;
  final VoidCallback done, back;
  final bool custom;
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
      if (widget.custom) {
        await widget.store.importCustomNamesUpdate(packet);
      } else {
        await widget.store.importVoteUpdate(packet);
      }
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
          widget.custom ? 'Scan custom-name update' : 'Scan partner update',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          widget.custom
              ? 'Scan the encrypted custom-name code your partner displays.'
              : 'Scan the encrypted vote code your partner displays.',
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: MobileScanner(
              onDetect: scan,
              errorBuilder: scannerError,
              placeholderBuilder: scannerPlaceholder,
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

class Home extends StatelessWidget {
  const Home({
    super.key,
    required this.store,
    required this.go,
    this.choose,
    this.editSelection,
  });
  final SessionStore store;
  final void Function(AppPage) go;
  final ValueChanged<NameCategory>? choose;
  final VoidCallback? editSelection;
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
        for (final category in NameCategory.values.where(
          store.categories.contains,
        ))
          FilledButton(
            onPressed: store.remaining(category).isEmpty
                ? null
                : () {
                    if (choose != null) {
                      choose!(category);
                    } else {
                      go(AppPage.choosing);
                    }
                  },
            child: Text(
              'Continue choosing ${category == NameCategory.girls ? 'girl' : 'boy'} names',
            ),
          ),
        if (store.choosingDone)
          OutlinedButton(
            onPressed: () => go(AppPage.sync),
            child: const Text('Synchronize choices'),
          ),
        if (store.canEditSelection)
          OutlinedButton.icon(
            onPressed: editSelection,
            icon: const Icon(Icons.tune),
            label: const Text('Adjust countries and name types'),
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

class Choosing extends StatefulWidget {
  const Choosing({
    super.key,
    required this.store,
    required this.done,
    this.back,
    this.category,
  });
  final SessionStore store;
  final VoidCallback done;
  final VoidCallback? back;
  final NameCategory? category;

  @override
  State<Choosing> createState() => _ChoosingState();
}

class _ChoosingState extends State<Choosing> {
  Offset _slide = Offset.zero;
  var _choosing = false;

  Future<void> _vote(VoteValue vote) async {
    if (_choosing || widget.store.isSaving) return;
    setState(() {
      _choosing = true;
      _slide = switch (vote) {
        VoteValue.no => const Offset(-1.3, 0),
        VoteValue.maybe => const Offset(0, 1.3),
        VoteValue.yes => const Offset(1.3, 0),
      };
    });
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
    await Future<void>.delayed(const Duration(seconds: 1));
    await widget.store.vote(vote);
    if (mounted) {
      setState(() {
        _slide = Offset.zero;
        _choosing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final candidate = store.currentFor(widget.category);
    if (candidate == null) {
      return Shell(
        back: widget.back,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration, size: 64, color: Palette.gold),
              Text(
                store.choosingDone
                    ? 'Your choices are ready'
                    : 'This group is complete',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.done,
                child: Text(
                  store.choosingDone
                      ? 'Synchronize with partner'
                      : 'Choose another group',
                ),
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
      back: widget.back,
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
                if (_choosing || store.isSaving) return;
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 350) return;
                _vote(velocity < 0 ? VoteValue.no : VoteValue.yes);
              },
              onVerticalDragEnd: (details) {
                if (_choosing || store.isSaving) return;
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < 350) return;
                _vote(VoteValue.maybe);
              },
              child: Semantics(
                label:
                    '${candidate.name}, ${candidate.category == NameCategory.girls ? 'girls' : 'boys'}, ${store.remaining(candidate.category).length} names remaining. Swipe left for No, down for Maybe, or right for Yes.',
                child: AnimatedSlide(
                  offset: _slide,
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOutCubic,
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
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Decision(
                icon: Icons.close,
                label: 'No',
                color: Palette.terra,
                onTap: _choosing || store.isSaving
                    ? null
                    : () => _vote(VoteValue.no),
              ),
              Decision(
                icon: Icons.question_mark,
                label: 'Maybe',
                color: Palette.gold,
                onTap: _choosing || store.isSaving
                    ? null
                    : () => _vote(VoteValue.maybe),
              ),
              Decision(
                icon: Icons.favorite,
                label: 'Yes',
                color: Palette.forest,
                onTap: _choosing || store.isSaving
                    ? null
                    : () => _vote(VoteValue.yes),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: store.history.isEmpty || store.isSaving || _choosing
                ? null
                : store.undo,
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
  final VoidCallback? onTap;
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
    this.back,
    this.custom = false,
  });
  final SessionStore store;
  final VoidCallback done, scan;
  final VoidCallback? back;
  final bool custom;
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
      final value = widget.custom
          ? await widget.store.customNamesUpdatePayload()
          : await widget.store.voteUpdatePayload();
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
    back: widget.back,
    child: ListView(
      children: [
        Text(
          widget.custom ? 'Synchronize custom names' : 'Synchronize choices',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          widget.custom
              ? 'Both phones must exchange a custom-name code before Face-off starts.'
              : 'This is separate from connecting phones: exchange your encrypted choices, then scan theirs.',
        ),
        if (widget.custom)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.store.customNamesConverged
                  ? 'Both phones are up to date. Face-off can begin.'
                  : 'Your code: ${widget.store.customNamesSent ? 'ready' : 'not sent'} · Partner code: ${widget.store.partnerCustomNamesReceived ? 'received' : 'waiting'}',
              semanticsLabel: widget.store.customNamesConverged
                  ? 'Custom names synchronized on both phones.'
                  : 'Custom-name synchronization is still in progress.',
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: make,
          child: Text(
            widget.custom
                ? 'Create my custom-name code'
                : 'Create my vote code',
          ),
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
          ),
        if ((frames?.length ?? 0) > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Frame ${frameIndex + 1} of ${frames!.length} · scan each one.',
              ),
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
        if (widget.custom
            ? widget.store.customNamesConverged
            : widget.store.partnerVotesReceived)
          FilledButton(
            onPressed: widget.done,
            child: Text(
              widget.custom ? 'Start Face-off' : 'View shared favorites',
            ),
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
    entries.sort((left, right) {
      final leftTier = matchTier(
        store.votes[left.id]!,
        store.partnerVotes[left.id]!,
      );
      final rightTier = matchTier(
        store.votes[right.id]!,
        store.partnerVotes[right.id]!,
      );
      final tier = rightTier.index.compareTo(leftTier.index);
      return tier != 0
          ? tier
          : normalizeName(left.name).compareTo(normalizeName(right.name));
    });
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
              children: [
                for (final category in NameCategory.values.where(
                  store.categories.contains,
                )) ...[
                  Builder(
                    builder: (context) {
                      final categoryEntries = entries
                          .where((entry) => entry.category == category)
                          .toList();
                      final categoryStrong = categoryEntries
                          .where(
                            (entry) =>
                                matchTier(
                                  store.votes[entry.id]!,
                                  store.partnerVotes[entry.id]!,
                                ) ==
                                MatchTier.strong,
                          )
                          .length;
                      return Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Text(
                          '${category == NameCategory.girls ? 'Girls' : 'Boys'} · $categoryStrong Strong · ${categoryEntries.length - categoryStrong} Consider',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      );
                    },
                  ),
                  for (final entry in entries.where(
                    (entry) => entry.category == category,
                  ))
                    Card(
                      child: ListTile(
                        title: Text(entry.name),
                        subtitle: Text(
                          '${entry.countries.join(', ')} · You: ${store.votes[entry.id]!.name} · Partner: ${store.partnerVotes[entry.id]!.name}',
                        ),
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
                ],
              ],
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
          onPressed: () async {
            if (await widget.store.addCustom(controller.text, selected)) {
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
          remove: (name) async {
            await widget.store.removeCustom(name, NameCategory.girls);
            if (mounted) setState(() {});
          },
        ),
        _CustomList(
          label: 'Boys',
          names: widget.store.customBoys,
          remove: (name) async {
            await widget.store.removeCustom(name, NameCategory.boys);
            if (mounted) setState(() {});
          },
        ),
        FilledButton(
          onPressed: widget.done,
          child: Text(
            widget.store.hasPartner
                ? 'Synchronize custom names'
                : 'Continue to Face-off',
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
                  onTap: store.isSaving
                      ? null
                      : () => store.chooseFaceoff(pairing.left),
                ),
              ),
              const Padding(padding: EdgeInsets.all(12), child: Text('or')),
              Expanded(
                child: ChoiceCard(
                  name: pairing.right,
                  onTap: store.isSaving
                      ? null
                      : () => store.chooseFaceoff(pairing.right),
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: store.faceoffVoteHistory.isEmpty || store.isSaving
                ? null
                : store.undoFaceoffVote,
            icon: const Icon(Icons.undo),
            label: const Text('Undo my last choice'),
          ),
          OutlinedButton.icon(
            onPressed: store.isSaving ? null : () => store.chooseFaceoff(null),
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
                  placeholderBuilder: scannerPlaceholder,
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
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Choose $name',
    child: InkWell(
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
            ...results.asMap().entries.map((entry) {
              final name = entry.value.name;
              final custom =
                  (category == NameCategory.girls
                          ? store.customGirls
                          : store.customBoys)
                      .map(normalizeName)
                      .contains(normalizeName(name));
              final candidate = store.enabled.cast<Candidate?>().firstWhere(
                (value) =>
                    value != null &&
                    value.category == category &&
                    normalizeName(value.name) == normalizeName(name),
                orElse: () => null,
              );
              final tier = candidate == null
                  ? 'Custom entry'
                  : matchTier(
                          store.votes[candidate.id]!,
                          store.partnerVotes[candidate.id]!,
                        ) ==
                        MatchTier.strong
                  ? 'Strong match'
                  : 'Consider match';
              return Card(
                child: ListTile(
                  onTap: () => _editPrivateNote(context, category, name),
                  leading: CircleAvatar(
                    backgroundColor: Palette.gold,
                    child: Text('${entry.key + 1}'),
                  ),
                  title: Text(custom ? '$name · Custom' : name),
                  subtitle: Text(
                    '${candidate?.countries.join(', ') ?? 'Added locally'} · $tier${store.privateNote(category, name).isEmpty ? '' : ' · Note saved'}',
                  ),
                  trailing: Text(
                    '${entry.value.score} ${entry.value.score == 1 ? 'point' : 'points'}',
                  ),
                ),
              );
            }),
          ];
        }),
        FilledButton(onPressed: home, child: const Text('Back to home')),
      ],
    ),
  );

  Future<void> _editPrivateNote(
    BuildContext context,
    NameCategory category,
    String name,
  ) async {
    final controller = TextEditingController(
      text: store.privateNote(category, name),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Private note for $name'),
        content: TextField(
          controller: controller,
          maxLength: 280,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Only on this phone'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Save note'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await store.setPrivateNote(category, name, controller.text);
    }
    controller.dispose();
  }
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
                  subtitle: Text(
                    '${country['provider']} · $years\n${country['coverage_limitations']}${country['provider'].toString().contains('fixture') ? ' · Fixture' : ''}',
                  ),
                  isThreeLine: true,
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
