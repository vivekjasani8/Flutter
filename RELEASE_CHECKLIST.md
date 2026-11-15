# Store release checklist

Everything that must be done **before publishing Idle Miner Sim to Google Play
or the App Store**. None of it blocks local development: the app builds, runs
and saves on a phone today. Work through this list when you decide to release.

Legend: `[ ]` to do · `[x]` done · **(M#)** = the [ROADMAP.md](ROADMAP.md)
milestone that covers it.

> Tip: do **section 1 first**, before giving the app to any tester. Changing the
> app ID later installs as a *different* app, so testers would lose their local
> progress, and Firebase/AdMob registrations are tied to the ID.

---

## 1. App identity (do first)

- [ ] **Change the Android application ID** from `com.example.idle_miner_sim`
      (Google Play rejects `com.example.*`). Edit `namespace` and
      `applicationId` in `android/app/build.gradle.kts` and move
      `MainActivity.kt` out of `kotlin/com/example/...` to match.
      Example: `com.vivekjasani.idleminersim`.
- [ ] **Change the iOS bundle ID** from `com.example.idleMinerSim`
      (`PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj`,
      or in Xcode → Runner → Signing & Capabilities).
- [ ] **Home-screen name**: `android:label` in
      `android/app/src/main/AndroidManifest.xml` is `idle_miner_sim`; set it to
      `Idle Miner Sim`. Same for `CFBundleDisplayName` in `ios/Runner/Info.plist`.
- [ ] **App icon**: replace the default Flutter icons (e.g. with the
      `flutter_launcher_icons` package) for Android and iOS, including the
      Android 13 themed (monochrome) icon.
- [ ] **Splash screen**: replace the default white launch screen (e.g.
      `flutter_native_splash`).
- [ ] **Notification icon**: reminders currently use the launcher icon
      (`@mipmap/ic_launcher` in `lib/state/reminder_scheduler.dart`). Android
      expects a small white-on-transparent icon; add one (e.g.
      `res/drawable/ic_notification`) or it may show as a grey square.

## 2. Signing and builds

- [ ] **Android release signing**: the `release` build type currently uses the
      **debug** key (`signingConfig = signingConfigs.getByName("debug")` in
      `android/app/build.gradle.kts`). Create an upload keystore, load it from a
      `key.properties` file, and enable **Play App Signing**.
      `*.keystore`, `*.jks` are already git-ignored — also ignore `key.properties`,
      and back the keystore up somewhere safe (losing it blocks updates).
- [ ] **Build an App Bundle**: `flutter build appbundle --release`, then install
      the release build on a real phone and play through it once (release
      builds can behave differently from debug).
- [ ] **Version numbers**: bump `version:` in `pubspec.yaml` (`0.1.0+1`) for
      every upload; the `+N` build number must always increase.
- [ ] **Commit `pubspec.lock`**: it is currently in `.gitignore`. For an app (not
      a package) it should be committed so CI and release builds use exactly the
      dependency versions you tested.
- [ ] **iOS build**: needs a Mac or a macOS CI runner (Codemagic or GitHub
      Actions) and an Apple Developer account. The iOS project has **never been
      built or run yet** — expect some setup (signing, CocoaPods, notification
      permission strings). **(M8)**
- [ ] **CI release workflows** that produce a signed AAB and an iOS build and
      upload to Play internal testing / TestFlight. **(M8)**

## 3. Accounts you need (and their lead time)

- [ ] **Google Play Console** — $25 one-time. New personal accounts must run a
      closed test with testers for a period before production access; check the
      current requirement and start early.
- [ ] **Apple Developer Program** — $99/year. Enrolment can take days; it is the
      long pole for iOS. **(M8)**
- [ ] Only if you add online features: **Firebase** project **(M3)**,
      **AdMob** and **RevenueCat** accounts **(M6)**.

## 4. Features still to decide or build

The app is currently **local-only**. Decide which of these the first release
needs; the store forms in section 5 depend on the answer.

- [ ] **Accounts + cloud save** (Firebase Auth/Firestore) **(M3)**. If you add
      accounts, Apple **requires in-app account deletion**.
- [ ] **Leaderboard with server validation** **(M4)**. Without it, do not show
      any ranking: a local-only game can be cheated by moving the phone's clock
      forward (earnings are capped at 8 h per jump, but still).
- [ ] **Ads + purchases** (AdMob rewarded boost, RevenueCat Remove Ads,
      Restore Purchases, ATT prompt on iOS, UMP consent in the EU) **(M6)**.
      Build on **test IDs**; swap to live IDs only at release.
- [ ] **Crashlytics** (crash reports) and **Remote Config** (tune the economy
      without an update) **(M7)**.
- [ ] **Onboarding screen** showing the "this is a game" disclaimer on first
      launch — the roadmap guardrails require it on onboarding, Settings and the
      store page. Settings already shows it; onboarding does not exist yet.
- [ ] **Daily reward day boundary**: days currently roll over at **00:00 UTC**
      (05:30 in India). Decide whether that's fine or should follow the
      player's local midnight (harder to keep cheat-resistant).

## 5. Store policy, privacy and listing

- [ ] **Re-check current Google Play and App Store policy** on crypto-themed
      and simulated-mining apps right before submitting; wording rules change.
      Keep: no "withdraw", "cash out", "earn real crypto/USDT" anywhere — not in
      the app, listing, screenshots or ads.
- [ ] **Disclaimer** ("All coins are virtual… not financial advice") in the
      store description, onboarding and Settings.
- [ ] **Privacy policy URL** (required by both stores, even for a local-only
      app). Describe exactly what is stored (today: game progress on the device
      only) and update it when Firebase/AdMob/RevenueCat are added.
- [ ] **Google Play Data safety form** and **Apple App Privacy labels** —
      must match what the SDKs collect. Local-only today = no data collected;
      ads/analytics/accounts change that. **(M8)**
- [ ] **Content rating** questionnaire (IARC) on Play; age rating on Apple.
      Answer the simulated-gambling/crypto questions carefully.
- [ ] **Target audience**: not designed for children (avoid Families policy
      unless you intend it).
- [ ] **Store listing**: title, short + full description, phone screenshots,
      Play feature graphic (1024×500), app icon (512×512), support email.

## 6. Quality pass before release **(M7)**

- [x] Smooth in a **profile** (release-speed) build on a real Android phone;
      hidden tabs don't rebuild or animate. **Re-check** in the final signed
      release build, and on a low-end phone if you can borrow one.
- [ ] Battery use while open over ~30 min (the game ticks once per second).
- [x] **Accessibility**: screen-reader labels, text contrast and tap targets
      pass Flutter's guideline checks on every tab; layouts tested at 2× font
      on a small phone; "Remove animations" respected. Still worth a manual
      pass with **TalkBack** (Android) and **VoiceOver** (iOS) before release.
- [ ] **Notifications**: permission is asked at a sensible moment (not on
      launch); reminders fire on Android 13+ after a reboot; iOS permission
      prompt works. Remove or keep hidden any **debug-only** test buttons
      (they must be behind `kDebugMode`).
- [ ] `dart format`, `flutter analyze` (zero warnings) and `flutter test` all
      green in CI.
- [ ] **Save compatibility**: if `GameState` fields change, bump
      `GameState.schemaVersion` and keep `fromJson` able to read old saves so
      updates never wipe a player's progress.

## 7. Launch **(M9)**

- [ ] Internal testing → closed testing → **staged rollout** (start at a low
      percentage) on Play; TestFlight → App Review on iOS.
- [ ] Watch crash-free sessions and day-1 / day-7 retention in the first week;
      keep a hotfix branch ready.

---

### Already done

- [x] Pure-Dart game engine with tests; JSON save format with a schema version
      **(M0–M1)**
- [x] Cheat fix: daily reward can't be re-claimed by setting the clock back **(M1)**
- [x] Local save/restore, offline earnings, four screens **(M2)**
- [x] Daily streak claim, achievements grid, opt-in local reminders; permission
      asked after the first claim or offline collect, not on launch; test
      reminder button is debug-only **(M5)**
- [x] Mining animation, rolling balance, haptics (with a Settings switch),
      accessibility and performance pass; balances always round down so they
      never look affordable when they aren't **(M7, offline part)**
- [x] Disclaimer shown on the Mine and Settings screens
- [x] Firebase config files and keystores are git-ignored, so they can't leak
      into the public repo
- [x] CI runs format + analyze + tests on every push
