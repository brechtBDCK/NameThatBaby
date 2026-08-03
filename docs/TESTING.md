# Testing

Run formatter, analyzer, Flutter tests and database validation as listed in the README.

## Golden tests

Core screen baselines live in `test/goldens/`. Review visual changes and update
them intentionally with:

```sh
/tmp/flutter/bin/flutter test --update-goldens test/golden_test.dart
```

## Physical-device release checklist

- Install fresh builds on one iPhone and one Android phone, then enable airplane mode before first launch.
- Create a session, scan the invite on the second phone, scan pairing confirmation back, and compare the six-digit confirmation code.
- Make different No/Maybe/Yes choices; exchange multi-frame updates in both directions and confirm the shortlist matches.
- Add a custom name on each phone, synchronize it, complete Face-off rounds, and confirm the same final rankings.
- Deny camera access, verify the recovery guidance, grant access in Settings, and complete a scan.
- Interrupt a multi-frame scan and a QR display, force-close both apps, reopen them, and confirm state/pairings resume unchanged.
- Check default and maximum system text size, light appearance, and reduced-motion settings.
- Confirm Android backup/data extraction is disabled and the iOS session database is excluded from backup.
- Use Delete session on both phones; reopen the app and verify no old session, secret, votes, or results are available.
