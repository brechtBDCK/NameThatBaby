import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'core/domain.dart';
import 'core/qr_protocol.dart';
import 'core/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SessionStore();
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
  scanUpdate,
  home,
  choosing,
  sync,
  shortlist,
  custom,
  faceoff,
  results,
  privacy,
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final SessionStore store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppPage page = widget.store.hasSession ? AppPage.home : AppPage.welcome;
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
        return Invite(store: widget.store, done: () => go(AppPage.home));
      case AppPage.scan:
        return ScanInvite(
          store: widget.store,
          done: () => go(AppPage.home),
          back: () => go(AppPage.welcome),
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
          faceoff: () => go(AppPage.faceoff),
        );
      case AppPage.custom:
        return CustomNames(
          store: widget.store,
          done: () => go(AppPage.faceoff),
        );
      case AppPage.faceoff:
        return Faceoff(store: widget.store, done: () => go(AppPage.results));
      case AppPage.results:
        return Results(home: () => go(AppPage.home));
      case AppPage.privacy:
        return Privacy(store: widget.store, back: () => go(AppPage.home));
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: child,
      ),
    ),
  );
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
  const Invite({super.key, required this.store, required this.done});
  final SessionStore store;
  final VoidCallback done;
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
          FilledButton(onPressed: done, child: const Text('Continue choosing')),
        ],
      ),
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
            child: MobileScanner(onDetect: scan),
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
      await widget.store.importVoteUpdate(value);
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
            child: MobileScanner(onDetect: scan),
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
              (category) => Card(
                color: category == NameCategory.girls
                    ? const Color(0xffffe8d9)
                    : const Color(0xffe1f0f3),
                child: ListTile(
                  leading: SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      value: store.progress(category),
                      color: category == NameCategory.girls
                          ? Palette.terra
                          : Palette.forest,
                    ),
                  ),
                  title: Text(
                    category == NameCategory.girls ? 'Girls' : 'Boys',
                  ),
                  subtitle: Text(
                    '${(store.progress(category) * 100).round()}% complete · ${store.remaining(category).length} left',
                  ),
                ),
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
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Private & offline'),
          onTap: () => go(AppPage.privacy),
        ),
      ],
    ),
  );
}

class Choosing extends StatelessWidget {
  const Choosing({super.key, required this.store, required this.done});
  final SessionStore store;
  final VoidCallback done;
  @override
  Widget build(BuildContext context) {
    final candidate = store.current;
    if (candidate == null) {
      return Shell(
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
    return Shell(
      child: Column(
        children: [
          Text('${store.remaining(candidate.category).length} names left'),
          const SizedBox(height: 16),
          Expanded(
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
                      style: Theme.of(context).textTheme.displayLarge!.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(candidate.countries.join(' · ')),
                  ],
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
  String? packet;
  String? error;
  Future<void> make() async {
    try {
      setState(() => packet = null);
      final value = await widget.store.voteUpdatePayload();
      if (mounted) {
        setState(() => packet = value);
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
        if (packet != null)
          Container(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(16),
            child: QrImageView(data: packet!, version: QrVersions.auto),
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
          FilledButton(onPressed: faceoff, child: const Text('Start Face-off')),
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
  var girls = true;
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
        SwitchListTile(
          value: girls,
          onChanged: (value) => setState(() => girls = value),
          title: Text(girls ? 'Girls' : 'Boys'),
        ),
        FilledButton(
          onPressed: () {
            if (widget.store.addCustom(controller.text, {
              girls ? NameCategory.girls : NameCategory.boys,
            })) {
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
        Text('Girls: ${widget.store.customGirls.join(', ')}'),
        Text('Boys: ${widget.store.customBoys.join(', ')}'),
        FilledButton(
          onPressed: widget.done,
          child: const Text('Continue to Face-off'),
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
    const entries = ['Elena', 'Nora', 'Leo', 'Arthur'];
    final left = entries[store.faceoffIndex % entries.length];
    final right = entries[(store.faceoffIndex + 1) % entries.length];
    void choose() {
      store.advanceFaceoff();
      if (store.faceoffIndex >= 6) done();
    }

    return Shell(
      child: Column(
        children: [
          Text(
            'Face-off · round ${store.faceoffIndex ~/ 2 + 1}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800),
          ),
          const Text('Disagreements keep both names in contention.'),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ChoiceCard(name: left, onTap: choose),
              ),
              const Padding(padding: EdgeInsets.all(12), child: Text('or')),
              Expanded(
                child: ChoiceCard(name: right, onTap: choose),
              ),
            ],
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: choose,
            icon: const Icon(Icons.skip_next),
            label: const Text('Skip this pairing'),
          ),
        ],
      ),
    );
  }
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
  const Results({super.key, required this.home});
  final VoidCallback home;
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
        const Text('Face-off scores decide this list.'),
        ...['Elena', 'Nora', 'Olivia', 'Leo', 'Arthur'].asMap().entries.map(
          (entry) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Palette.gold,
                child: Text('${entry.key + 1}'),
              ),
              title: Text(entry.value),
            ),
          ),
        ),
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
            await store.reset();
            back();
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete local session'),
        ),
        TextButton(onPressed: back, child: const Text('Back')),
      ],
    ),
  );
}
