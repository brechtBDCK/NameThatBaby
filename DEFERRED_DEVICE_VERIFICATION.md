# Deferred device verification

No physical device was connected during source verification. Every item below
is **NOT RUN — device unavailable** until manually checked. Do not record QR
payloads, votes, names, keys, or screenshots containing them in Git.

## First command when an Android phone is available

```sh
adb devices
/tmp/flutter/bin/flutter run -d <ANDROID_DEVICE_ID>
```

For WSL wireless debugging, pair/connect using current Android Settings values,
then use the ID reported by `adb devices`; never reuse a stale IP or port.

## One Android phone smoke test

- [ ] Clean-install debug APK with airplane mode enabled. Welcome, setup,
  bundled data disclosure, country/category selection, and choosing work.
- [ ] Complete No, Maybe, Yes, Undo, progress/remaining counts, force-close,
  and resume in both categories.
- [ ] Deny Camera, confirm recovery copy, grant it in Android Settings, and
  reopen scanning.
- [ ] Delete session, relaunch, and confirm no old recoverable session remains.
- [ ] Check default and maximum practical font size, TalkBack focus/labels,
  48dp targets, and reduced-motion behavior.

## Two Android phones QR round trip

- [ ] Pair, compare confirmation codes, then exchange votes in both directions.
- [ ] Scan multi-frame transfer out of order and with a duplicate; progress is
  bounded and app accepts only complete matching transfer.
- [ ] Exchange custom names in both categories, complete independent Face-off
  ballots, and confirm identical final lists.
- [ ] Force-close once during QR display and once during multi-frame scanning;
  resume safely without accepting stale data.

## Android/iPhone round trip on macOS

- [ ] Build/sign iOS with `<IOS_BUNDLE_ID>` and `<APPLE_TEAM_ID>` supplied.
- [ ] Repeat pairing, vote, custom-name, and Face-off QR convergence with one
  Android and one iPhone.

## Platform/lifecycle checks

- [ ] Keep app backgrounded/inactive during choosing, scanning, and Face-off;
  resume without lost/duplicated decisions.
- [ ] Confirm no ambience plays: beta ships no background loop. Choice feedback
  must not prevent other audio playback.
- [ ] Inspect Android backup/device-transfer settings and iOS backup exclusion
  for encrypted session state.
- [ ] Verify clean install, upgrade from prior beta, and airplane-mode full flow.
