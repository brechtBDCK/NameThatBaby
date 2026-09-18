# NameThatBaby — final-mile Codex goal

Use this as a new Codex goal in the repository `brechtBDCK/NameThatBaby`.

## Role

Act as the senior Flutter engineer responsible for taking the current repository from a strong offline prototype to a credible Android beta candidate, while preserving the path to iOS. Work directly from the current `main` branch and the repository documentation. Do not reimplement features that already work.

## Product goal

NameThatBaby is an English-only, iOS-and-Android app for two partners to choose baby names privately. It must work without an account, backend, hosting, analytics, advertising, remote configuration, or runtime network access.

Each partner independently:

1. selects one or more supported Western countries;
2. reviews deterministic girl and boy candidate pools based on the 150 most relevant names from 2015–2024;
3. votes **No**, **Maybe**, or **Yes**;
4. exchanges encrypted state locally by scanning QR codes;
5. advances names for which both partners voted Yes or Maybe;
6. may add multiple custom names to either category;
7. independently votes in the final same-category face-off / Swiss-style phase; and
8. receives matching final top-10 girl and boy lists.

Country selection only controls candidate inclusion. No selected country has more weight than another. The installed app and bundled name database must remain fully local.

## Current baseline — verify, do not blindly trust

At the start of this goal, inspect the actual current branch, `AGENTS.md`, `README.md`, `docs/`, `pubspec.yaml`, platform projects, tests, workflow files, and recent commits. Record the current commit SHA in the final report.

The repository was last independently audited at commit `61267b60de97d536df17b6668a49bd8da7ed4719`. At that point:

- the principal create/join, QR pairing, choosing, synchronization, custom-name, face-off, result, persistence, recovery, and privacy flows existed;
- the repository had substantial unit, widget, golden, protocol, persistence, data-adapter, and simulated two-device tests;
- the Python data suite passed 17 tests and bundled database validation passed;
- the first GitHub Actions `Verify` run failed at `dart format`, causing every later Flutter/test/build step to be skipped;
- no physical phone was connected;
- the Android application ID and iOS bundle ID were still `com.example.namethatbaby` placeholders;
- production signing was intentionally not configured;
- US and NL still used development fixtures; AU covered NSW and Queensland rather than all Australia; source redistribution review remained open;
- the new ambience audio started automatically, looped indefinitely, and had no visible opt-out or lifecycle policy; and
- `lib/main.dart` and `lib/core/session_store.dart` were very large, increasing change risk.

Re-check all of these facts because the branch may have changed. If a fact is no longer true, follow the current repository rather than this snapshot.

## Working constraint: no phone is connected

This is **not** a blocker for source-level work. Complete every safe task that can be proven with source inspection, CI, unit/widget/golden/integration simulation, Android builds, manifest inspection, and documentation.

Do not repeatedly wait for, poll for, or claim success on a physical device. Do not mark the whole goal blocked merely because a phone is absent. Instead:

- maintain a clearly separated `DEFERRED_DEVICE_VERIFICATION.md` checklist;
- mark only device-dependent checks as `NOT RUN — device unavailable`;
- finish and report all source-verifiable work; and
- stop with exact commands and test scenarios for the owner to run later.

Do not attempt iOS compilation on Linux. Prepare iOS-safe source changes and a macOS/iPhone verification checklist, and accurately mark them unverified.

## Priority order

Work in the following order. Do not start later phases while an earlier phase has an actionable failure, unless the failure genuinely requires external input.

### Phase 1 — restore a trustworthy green baseline

1. Fetch the current branch and inspect repository status without discarding user changes.
2. Read and follow `AGENTS.md`.
3. Run formatting in write mode if necessary, review the diff, and fix the current CI formatting failure.
4. Run the complete verification sequence below.
5. Inspect the latest GitHub Actions result. If CI differs from local results, diagnose the actual CI logs and fix the root cause.
6. Make CI fail clearly and early, but ensure it still exercises formatting, analysis, Flutter tests, Python adapter tests, database validation, debug and release Android builds, and merged-manifest checks for forbidden network permissions.

Do not paper over a failure with exclusions, blanket ignores, weakened assertions, or removal of meaningful checks.

### Phase 2 — harden recent platform and audio changes

Audit the newly added Android/iOS ambience implementation and make it product-safe.

Required behavior:

- ambience must never be mandatory for app operation;
- provide an obvious in-app sound on/off control, defaulting to **off** unless an existing documented product decision explicitly says otherwise;
- persist only the local preference;
- respect app lifecycle: do not continue ambient playback when the app is backgrounded or inactive;
- release native player resources correctly;
- avoid interfering with other audio unnecessarily;
- keep widget tests and unsupported platforms functional;
- add focused Dart tests for preference/control behavior and platform-channel failure handling where practical; and
- document the behavior.

If the simplest, safest beta choice is to remove ambience until after device testing, do so and explain why. Do not add a networked media dependency.

Also remove duplicate or ambiguous scanner error/placeholder implementations if they exist, keeping one tested and accessible recovery experience.

### Phase 3 — release configuration without guessing owner decisions

Audit:

- Android namespace/application ID;
- iOS bundle identifiers;
- app display names;
- semantic version/build number;
- minimum/target platform versions;
- app icon and splash assets;
- Android release signing configuration; and
- iOS signing/provisioning expectations.

Do **not** invent irreversible identifiers or credentials. Where owner input is required, use explicit placeholders:

- Android application ID: `<ANDROID_APPLICATION_ID>`
- iOS bundle ID: `<IOS_BUNDLE_ID>`
- Android keystore/key alias: `<ANDROID_SIGNING_VALUES>`
- Apple team ID: `<APPLE_TEAM_ID>`
- release version/build: `<VERSION_NAME>+<BUILD_NUMBER>`

Keep secrets, keystores, `key.properties`, provisioning profiles, QR contents, and user data out of Git. Add a concise `docs/RELEASE_CONFIGURATION.md` explaining exactly what the owner must choose and how to configure it locally. A debug APK may still use the development identifiers until values are supplied, but the repository must not imply that the app is store-ready.

### Phase 4 — product-flow correctness and maintainability

Prove these invariants with tests:

- selected countries are equal candidate sources and deterministic;
- the app produces no more than the intended 150-name candidate pool per category, with deterministic deduplication across countries;
- No never advances; Maybe and Yes both advance only when both partners have an advancing vote;
- girls only face girls and boys only face boys;
- multiple custom girl and boy names synchronize correctly;
- partners vote independently in the final phase;
- interrupted/multi-frame/out-of-order/duplicate QR transfers are safe and bounded;
- both devices converge on identical final top-10 lists;
- encrypted persisted sessions migrate without silent data loss; and
- delete-session removes recoverable application state.

Refactor only where it lowers immediate risk. In particular, split `lib/main.dart` and `lib/core/session_store.dart` into cohesive feature/state units incrementally, keeping behavior and tests stable after each move. Avoid a broad rewrite or new state-management framework.

### Phase 5 — UI, accessibility, and offline privacy review

Keep the established warm botanical visual direction. Review all principal screens at compact Android and iPhone-like sizes, normal and large text, and with semantics enabled.

Address concrete issues involving:

- overflow and keyboard avoidance;
- progress clarity and remaining-name counts;
- visible and semantic No/Maybe/Yes controls;
- non-gesture alternatives to swiping;
- camera-denial recovery;
- QR multi-frame progress and cancellation;
- destructive delete confirmation;
- minimum touch-target sizes;
- contrast, focus order, labels, and reduced motion; and
- consistency of custom names, shortlist, face-off, and results.

Update goldens only after reviewing the rendered change. Never mass-regenerate goldens to hide a regression.

Statically verify the installed Android app requests no Internet or network-state permission. Search production Dart/native code for runtime HTTP clients, telemetry, crash reporting, ads, analytics, remote config, or cloud backup behavior. Preserve encrypted local storage and backup exclusions. Document any claim that still requires a real device.

### Phase 6 — data readiness and truthful disclosure

Validate the bundled database, manifest hashes, reproducibility tests, attribution, source URLs, coverage years, retrieval metadata, and licensing-review status.

Do not silently replace official data with scraped third-party lists. For US and NL, use official cached inputs only if they are legitimately available in the working environment. Otherwise keep fixtures clearly labelled and keep public-release readiness blocked on replacement. For AU, retain truthful NSW/Queensland disclosure until broader coverage is added.

Reconcile `README.md`, `docs/DATA_SOURCES.md`, `docs/DECISIONS.md`, the manifest, and in-app data-source copy so they agree exactly. Never describe fixture or partial-national coverage as release-ready national data.

### Phase 7 — prepare deferred physical verification

Create or update `DEFERRED_DEVICE_VERIFICATION.md` with checkboxes, expected results, and exact commands. Separate:

1. one Android phone smoke test;
2. two-phone Android QR round trip;
3. Android/iPhone cross-platform QR round trip on macOS;
4. lifecycle/background/audio checks;
5. fresh install and upgrade/persistence checks;
6. camera deny/grant/retry;
7. airplane-mode first launch and full completion;
8. force-close during QR display and multi-frame scan;
9. maximum text size, TalkBack/VoiceOver, and reduced motion;
10. backup exclusion inspection; and
11. delete-session forensic sanity check.

Include the WSL wireless-ADB commands, but use `<ANDROID_DEVICE_ID>` rather than a stale IP/port. Do not report these checks as passed until a human or connected device actually runs them.

## Verification commands

Use the repository’s configured Flutter SDK path when present; otherwise use `flutter`/`dart` from `PATH`. Run at minimum:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
python3 -m unittest discover -s tools/name_data/tests -p 'test_*.py'
python3 tools/name_data/validate_database.py assets/data/names.sqlite assets/data/manifest.json
flutter build apk --debug
flutter build apk --release
git diff --check
```

After each Android build, inspect the merged manifest and final APK permissions. The app must not request `android.permission.INTERNET` or `android.permission.ACCESS_NETWORK_STATE`.

If a command cannot run, quote the command, explain the exact environmental reason, and continue with independent checks. “No phone connected” is not a reason to skip formatter, analyzer, tests, builds, manifest inspection, or CI.

## Change discipline

- Preserve unrelated user changes and work in small, reviewable commits.
- Use descriptive commit messages, not `.`.
- Never commit generated build outputs, caches, credentials, raw source archives, QR payloads, or user/session data.
- Do not change the QR protocol or persisted schema casually. If a change is necessary, version it, maintain backward compatibility where feasible, add migration/compatibility tests, and update architecture decisions.
- Do not add a server, API, login, analytics, ads, remote config, or runtime data download.
- Do not weaken encryption or deterministic convergence.
- Do not spend time on store marketing assets before CI, configuration, product correctness, and truthful data readiness are addressed.
- Ask the owner only when a decision is genuinely irreversible or materially product-defining. Group questions rather than repeatedly stopping.

## Definition of done for this phone-free goal

This goal is complete when:

- the latest local verification and GitHub Actions workflow are green;
- the audio decision is safe, controllable, lifecycle-aware, and tested, or ambience is removed;
- source-verifiable product invariants have focused coverage;
- production code remains offline and Android manifests contain no forbidden network permissions;
- documentation and in-app data disclosures match the bundled manifest;
- release identifiers/signing choices are clearly isolated as owner-supplied placeholders rather than guessed;
- current UI/golden/accessibility checks pass without obvious overflow regressions;
- the remaining physical Android/iOS checks are captured in one exact deferred checklist; and
- the final report distinguishes **passed**, **not run**, **owner decision required**, and **public-release blocker**.

Do not call the app “finished” or “store-ready” while US/NL fixtures, redistribution review, release identifiers/signing, physical two-device verification, or iOS-on-macOS verification remain unresolved.

## Final report format

At completion, provide:

1. current commit/branch and concise outcome;
2. files changed and why;
3. tests/builds/checks actually run with pass/fail status;
4. CI run link and status;
5. risks or regressions found and how they were handled;
6. deferred device checks with the exact first command to run when a phone is available;
7. owner decisions still required, using the placeholders above; and
8. a candid readiness assessment for:
   - source-complete prototype,
   - Android internal beta,
   - cross-platform beta, and
   - public store release.

Continue autonomously through all safe source-level work. Pause only for an actual permission boundary, an unavailable credential, an irreversible identifier/signing choice, or a genuinely product-defining ambiguity.
