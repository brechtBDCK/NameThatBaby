# NameThatBaby

An offline, private Flutter prototype for two partners to independently choose names, exchange choices in person, and compare shared names.

## Run locally

```sh
/tmp/flutter/bin/flutter pub get
/tmp/flutter/bin/flutter run
```

For the Android beta loop in WSL, use Flutter 3.44.8, Java 21, Android SDK platform/build-tools 36, and an accepted Android SDK license. With a physical phone connected through ADB or wireless debugging, run:

```sh
/tmp/flutter/bin/flutter devices
/tmp/flutter/bin/flutter build apk --debug
/tmp/flutter/bin/flutter run -d <android-device-id>
```

The app targets iOS and Android. It makes no runtime network request and Android requests no Internet permission. `assets/data/names.sqlite` is a compact deterministic runtime ranking database. It contains cached source imports where available and development fixtures only for US and NL; it must not be released before those gaps and source licensing are reviewed.

## Verify

```sh
/tmp/flutter/bin/dart format --output=none --set-exit-if-changed .
/tmp/flutter/bin/flutter analyze
/tmp/flutter/bin/flutter test
python3 -m unittest discover -s tools/name_data/tests -p 'test_*.py'
python3 tools/name_data/validate_database.py assets/data/names.sqlite assets/data/manifest.json
/tmp/flutter/bin/flutter build apk --debug
/tmp/flutter/bin/flutter build apk --release
git diff --check
```

GitHub Actions runs this same verification on pushes to `main` and pull requests. It uses build-time package downloads only; the installed app remains fully offline.

Production signing is intentionally not configured in the repository. Keep keystores, provisioning profiles, and `android/key.properties` local and supply them only after the application identifiers and signing decisions are provided.

See [release configuration](docs/RELEASE_CONFIGURATION.md) for owner-supplied
identifiers, signing, versioning, and icon requirements. Device-dependent
checks are tracked in [DEFERRED_DEVICE_VERIFICATION.md](DEFERRED_DEVICE_VERIFICATION.md).

Data coverage: US and NL remain development fixtures. CA, DK, NO, SE, FR, ES, IT, AT, GB and IE use cached official imports; BE is a single national 2015–2024 aggregate, DE is the documented GfdS national fallback, and AU round-robins NSW and Queensland equally rather than claiming national coverage. Redistribution review remains required.
