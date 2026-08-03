# NameThatBaby

An offline, private Flutter prototype for two partners to independently choose names, exchange choices in person, and compare shared names.

## Run

```sh
/tmp/flutter/bin/flutter pub get
/tmp/flutter/bin/flutter run
/tmp/flutter/bin/flutter test
python3 tools/name_data/build_database.py
python3 tools/name_data/validate_database.py assets/data/names.sqlite assets/data/manifest.json
```

The app targets iOS and Android. It makes no runtime network request and Android requests no Internet permission. `assets/data/names.sqlite` currently contains a deterministic development fixture for all 15 supported countries; it must be replaced with reviewed official downloads before public distribution. Licensing review remains required.

Data coverage: US and NL remain development fixtures. CA, DK, NO, SE, FR, ES, IT, AT, GB and IE use cached official imports; BE is a single national 2015–2024 aggregate, DE is the documented GfdS national fallback, and AU round-robins NSW and Queensland equally rather than claiming national coverage. Redistribution review remains required.
