# Release configuration

NameThatBaby is not store-ready until owner supplies following values. Current
`com.example.namethatbaby` Android/iOS identifiers and debug release signing
are development-only.

| Owner value | Current source | Required action |
| --- | --- | --- |
| `<ANDROID_APPLICATION_ID>` | `com.example.namethatbaby` | Set Android `namespace`, `applicationId`, Kotlin package path, tests, and any deep-link configuration together. |
| `<IOS_BUNDLE_ID>` | `com.example.namethatbaby` | Set Xcode `PRODUCT_BUNDLE_IDENTIFIER`, provisioning profile, and Apple App ID together on macOS. |
| `<VERSION_NAME>+<BUILD_NUMBER>` | `1.0.0+1` | Set `pubspec.yaml` immediately before a release build. |
| `<ANDROID_SIGNING_VALUES>` | Debug signing only | Create an owner-held keystore; supply its path, alias, and passwords through ignored local configuration or environment variables. Never commit them. |
| `<APPLE_TEAM_ID>` | Unset | Set in Xcode with the chosen bundle ID and provisioning profile. |
| Production icon source | Flutter default launcher assets | Supply licensed source artwork, then generate/review every Android density and iOS asset size. |

## Android signing

Keep `android/key.properties`, keystores, certificates, and passwords outside
Git. Do not change the release signing block until all Android owner values
above are supplied. Debug APKs remain valid for internal device testing.

## Platform facts to re-check before release

- Android currently compiles/targets Flutter defaults and requires only camera.
  Its manifest removes Internet and network-state permissions and disables
  backup/device-transfer extraction.
- iOS display name is `NameThatBaby`; camera purpose text explains local QR
  scanning. Build/sign/archive verification requires macOS and Xcode.
- No bundled ambience is shipped for beta. Choice feedback uses platform click
  and haptic feedback only; revisit background audio after lifecycle testing.
