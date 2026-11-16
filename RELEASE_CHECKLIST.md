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

- [x] **Android application ID** is `com.vivekjasani.idleminersim` (was
      `com.example.idle_miner_sim`, which Google Play rejects). Permanent from
      the first Play upload; Firebase registers the Android app under it.
- [x] **iOS bundle ID** is `com.vivekjasani.idleminersim` (tests:
      `…RunnerTests`). Register it in your Apple Developer account when you
      enrol.
- [x] **Home-screen name**: "Idle Miner Sim" on Android and iOS.
- [x] **App icon**: gold fan + SimCoin on navy; Android adaptive icon,
      Android 13 themed (monochrome) icon, all iOS sizes. Checked on a phone.
- [x] **Splash screen**: navy with the fan + coin, including the Android 12+
      splash API and iOS. Checked on a phone.
- [x] **Notification icon**: white fan silhouette tinted gold, kept in
      release builds by `res/raw/keep.xml`. Checked on a phone.
- To change the artwork: edit `tool/brand_assets_test.dart`, then run
  `flutter test tool/brand_assets_test.dart`,
  `dart run flutter_launcher_icons` and
  `dart run flutter_native_splash:create`.
- [ ] Store artwork: 512×512 Play icon (use `assets/branding/app_icon.png`
      scaled down) and the 1024×500 feature graphic, when you write the
      listing.

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
- [x] **`pubspec.lock` committed** and CI pinned to the local Flutter version
      (3.41.6), so CI and release builds use exactly what was tested. When you
      upgrade Flutter, fix new analyzer findings locally, then bump
      `flutter-version` in `.github/workflows/ci.yml`.
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
- [x] **Firebase** project `idle-miner-sim` (Spark plan, Firestore in
      asia-south1, Anonymous + Google sign-in) **(M3)**
- [ ] **AdMob** and **RevenueCat** accounts **(M6)**.

## 4. Features still to decide or build

The app is currently **local-only**. Decide which of these the first release
needs; the store forms in section 5 depend on the answer.

- [x] **Accounts + cloud save** code: guest by default, Google sign-in,
      merge keeps the higher lifetime coins, in-app **account deletion**
      (Apple and Google both require it) **(M3)**. Still to do:
  - [x] Tested on a real phone (Android 17, debug build): guest backup,
        Google sign-in, **uninstall → reinstall → sign in restores
        progress**, sign-out + sign back in, delete account (old data not
        restored afterwards).
  - [x] **Firestore rules deployed** to `idle-miner-sim`. Redeploy after any
        rules change: `firebase deploy --only firestore:rules --project
        idle-miner-sim`.
  - [ ] Repeat the sign-in and restore test with the **signed release
        build** from the Play internal test track (uses a different key,
        see below).
  - [ ] Add the **release** and **Play App Signing** SHA-1/SHA-256 to the
        Firebase Android app, or Google sign-in fails in store builds (only
        the debug key is registered now).
  - [ ] **iOS**: on a Mac, add `GoogleService-Info.plist` and the
        `REVERSED_CLIENT_ID` URL scheme for Google sign-in.
  - [ ] **Sign in with Apple**: the App Store requires it (or an equivalent
        private login) when an app offers Google sign-in. Needs the Apple
        Developer account.
  - [ ] **Google Play also needs a web link** where players can request
        account deletion without the app (e.g. a page or form on your
        privacy-policy site).
  - [ ] Restrict the Firebase API keys to your app IDs in Google Cloud
        console and turn on **App Check** (Play Integrity / App Attest).
        The keys in `lib/firebase_options.dart` are identifiers, not
        secrets, but this stops other apps from using your quota.
- [x] **Leaderboard with server validation** code **(M4)**: the
      `validateSync` Cloud Function caps every score at what could really have
      been earned (server clock, paid-for rigs); clients can never write
      `scores` (emulator-tested); top 100 + your rank in the app. Still to do:
  - [ ] Upgrade the Firebase project to **Blaze** (pay-as-you-go; has a free
        monthly allowance) and set a **budget alert** in Google Cloud.
  - [ ] Deploy: `firebase deploy --only functions,firestore:rules
        --project idle-miner-sim`. Until then the app shows "The leaderboard
        is not live yet."
  - [ ] Test on a phone and on a second device: score appears, rank is
        right, a clock moved forward doesn't raise the score. (Today the app
        correctly shows "The leaderboard is not live yet.")
  - [ ] **Player names are public** on the leaderboard: decide on name
        moderation (block list or reporting) before launch, and mention the
        public name in the privacy policy.
  - [ ] Turn on **App Check** enforcement for the function
        (`enforceAppCheck: true`) once App Check is set up.
- [ ] **Ads + purchases** (AdMob rewarded boost, RevenueCat Remove Ads,
      Restore Purchases, ATT prompt on iOS, UMP consent in the EU) **(M6)**.
      Build on **test IDs**; swap to live IDs only at release.
- [x] **Crashlytics** (crash reports, release builds only) and **Remote
      Config** (tune the economy without an update; values range-checked,
      applied on the next launch) **(M7)**. Still to do:
  - [x] Balance parameter deployed (Remote Config version 1, same values
        as the built-in defaults). Tune it in the Firebase console, or edit
        `remoteconfig.template.json` and run
        `firebase deploy --only remoteconfig --project idle-miner-sim`.
  - [ ] Open **Crashlytics** in the Firebase console once and check that a
        test crash from a release build shows up.
- [x] **Onboarding screen** showing the "this is a game" disclaimer on first
      launch (Skip can't bypass it; Settings → How to play reopens it).
- [ ] **Daily reward day boundary**: days currently roll over at **00:00 UTC**
      (05:30 in India). Decide whether that's fine or should follow the
      player's local midnight (harder to keep cheat-resistant).

## 5. Store policy, privacy and listing

- [ ] **Re-check current Google Play and App Store policy** on crypto-themed
      and simulated-mining apps right before submitting; wording rules change.
      Keep: no "withdraw", "cash out", "earn real crypto/USDT" anywhere — not in
      the app, listing, screenshots or ads.
- [ ] **Disclaimer** ("All coins are virtual… not financial advice") in the
      **store description**. Already in the app: onboarding, Mine and Settings.
- [ ] **Privacy policy URL** (required by both stores). Describe exactly what
      is stored: game progress on the device **and in Firebase** (tied to an
      account ID, plus email and name if the player signs in with Google);
      how to delete it. Update again when AdMob/RevenueCat are added.
- [ ] **Google Play Data safety form** and **Apple App Privacy labels** —
      must match what the SDKs collect. Since M3: user ID, email/name (Google
      sign-in), and game progress, linked to the account, not used for
      tracking; deletion available in-app. Since M7: **crash logs and
      diagnostics** (Crashlytics, release builds). **(M8)**
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
- [x] **Notifications** on Android 17: permission asked after the first
      claim (not on launch), test reminder arrives. Debug test button is
      behind `kDebugMode` (hidden in profile/release builds, confirmed).
- [ ] Still to check: a scheduled reminder survives a **phone reboot**, and
      the iOS permission prompt (needs a Mac).
- [x] Light / dark / system appearance, new design, gameplay, "while you
      were away", rewards and haptics checked on the phone.
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
- [x] Disclaimer shown on the first-launch intro, Mine and Settings screens
- [x] Firebase config files and keystores are git-ignored, so they can't leak
      into the public repo
- [x] CI runs format + analyze + tests on every push
