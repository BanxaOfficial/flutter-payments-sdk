# banxa_payments_flutter

**Preview (0.1.0).** Flutter plugin for Banxa partner-api v2 catalog/order APIs
and Primer native checkout (iOS + Android).

## Status

Native checkout phase is in place on iOS and Android:

- Catalog + order APIs (`configure`, fetch*, `checkEligibility`, `createOrder`)
- `startPayment` → create order → Primer when `nativeToken` is present and the method works on the device, otherwise hosted checkout in a Flutter WebView (https Banxa hosts only)
- Checkout outcomes via `Stream<BanxaCheckoutEvent>` (`completed` / `failed` / `dismissed`)
- No usable route → `NativeCheckoutNotEligibleException`
- `checkEligibility` is opt-in. Call it yourself if you need `paymentReady` / `kycRequirements`; `startPayment` does not call `/eligibility`.

| Platform | Primer SDK | Presentation |
|----------|------------|--------------|
| iOS | `PrimerSDK` 2.49.0 (SPM or CocoaPods) | `Primer.shared.showPaymentMethod` |
| Android | `io.primer:checkout` **3.0.0-beta.2** (preview) | Dedicated `PrimerCheckoutActivity` + Compose sheet (methods from the Primer client session) |

## Partner app requirements

| Constraint | Value |
|------------|--------|
| Dart | `>=3.12.2 <4.0.0` |
| Flutter | `>=3.44.9` |
| iOS | **15.0+** (Flutter's deployment target from 3.47) |
| Android | **minSdk 24+** (Primer Checkout 3.x) |

Primer and Primer3DS add native binary size. Measure with
`flutter build appbundle --analyze-size` / an iOS archive before committing to
the SDK in a size-sensitive app.

TLS: all Banxa API hosts and the initial hosted-checkout URL are `https` only.
There is no certificate pinning in this SDK.

### Permissions (KYC / document capture)

The plugin itself only merges `INTERNET` on Android. Hosted checkout and Primer
may open the camera or photo library. Partners must declare:

**iOS** (`Info.plist`):

- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSMicrophoneUsageDescription` (if video KYC is enabled)

**Android** (`AndroidManifest.xml`):

- `android.permission.CAMERA`

The example app includes these. Missing iOS usage strings crash when capture
starts.

## Where the code runs

All partner-api v2 traffic is issued from Dart with `package:http`, so requests
appear in the DevTools network view and can be intercepted by passing your own
`http.Client` to `configure`. The platform channel is only used to present
Primer and to report checkout outcomes; the native side does no networking.


## Packages

| Package | Role |
|---------|------|
| `packages/banxa_payments_flutter` | App-facing API, partner-api HTTP client, hosted checkout WebView |
| `packages/banxa_payments_flutter_platform_interface` | Checkout platform interface + Pigeon schema |
| `packages/banxa_payments_flutter_ios` | iOS Primer bridge (SPM + CocoaPods) |
| `packages/banxa_payments_flutter_android` | Android Primer bridge (`com.banxa.flutterpaymentsdk`) |
| `example/` | Sandbox demo app |

## Setup

```dart
import 'package:banxa_payments_flutter/banxa_payments_flutter.dart';

await BanxaPayments.configure(
  const BanxaConfig(
    apiKey: 'YOUR_KEY',
    partnerId: 'YOUR_PARTNER',
    environment: BanxaEnvironment.sandbox,
  ),
);
```

Call `configure` once per process. Re-calling replaces the HTTP client and
rebinds checkout event listeners.

Auth header used by native clients: `x-api-key` + `Content-Type: application/json`.  
Base URL: `{host}/{partnerId}/v2` where host is:

| Environment | Host |
|-------------|------|
| sandbox | `https://api.banxa-sandbox.com` |
| preprod | `https://api.banxa-preprod.com` |
| production | `https://api.banxa.com` |

## Catalog + checkout

```dart
final countries = await BanxaPayments.fetchCountries();
final fiats = await BanxaPayments.fetchFiats(orderType: OrderType.buy);
final cryptos = await BanxaPayments.fetchCrypto(orderType: OrderType.buy);
final methods = await BanxaPayments.fetchPaymentMethods(
  orderType: OrderType.buy,
  fiat: 'USD',
);

BanxaPayments.checkoutEvents.listen((event) {
  switch (event) {
    case BanxaCheckoutCompleted(:final paymentId, :final orderId, :final status):
      // success
    case BanxaCheckoutFailed(:final message):
      // error
    case BanxaCheckoutDismissed():
      // user closed sheet (may also follow completed/failed)
  }
});

final launch = await BanxaPayments.startPayment(
  const CreateOrderRequest(
    orderType: OrderType.buy,
    crypto: 'ETH',
    fiat: 'USD',
    fiatAmount: '50',
    walletAddress: '0x…',
    email: 'user@example.com',
    redirectUrl: 'https://example.com/redirect',
    paymentMethodId: 'debit-credit-card',
    blockchain: 'ETH',
  ),
);

switch (launch) {
  case BanxaPrimerCheckoutLaunched():
    // Primer is on screen; wait for checkoutEvents.
  case BanxaHostedCheckoutRequired():
    // No nativeToken: show the hosted flow wherever suits the app.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Checkout')),
          body: BanxaHostedCheckoutView(checkout: launch),
        ),
      ),
    );
}
```

`startPayment` creates the order and then either presents Primer natively or hands back a `BanxaHostedCheckoutRequired` for the app to display. It also falls back to the hosted flow when the payment method cannot run on the current device — see [Apple Pay](#apple-pay). It throws `NativeCheckoutNotEligibleException` when no route is left: the order has neither a `nativeToken` nor a Banxa `https` `checkoutUrl`, or the method is unavailable and there is no usable `checkoutUrl`.

`BanxaHostedCheckoutView` reports outcomes on `checkoutEvents` and never pops itself, so the host route decides when to close; disposing it without reaching a terminal URL emits `dismissed`. A hung first page emits `failed` after 30s. Primer likewise may emit `dismissed` after `completed`/`failed` — keep them distinguishable. See `example/lib/hosted_checkout_screen.dart` for a route that closes itself on a terminal event.

Hosted checkout: the first URL must be `https` on a Banxa-owned host (`*.banxa.com`, `*.banxa-sandbox.com`, `*.banxa-preprod.com`). Later navigations may go to bank/wallet https pages (3DS). JavaScript is enabled for the hosted UI; there is no JS bridge into the host app.

## Example app

Runners for iOS and Android are already in `example/`. From a clean checkout:

```bash
cd example
cp .env.example .env   # then fill keys; do not commit .env
flutter run --dart-define-from-file=.env
```

`--dart-define=BANXA_*` also works and wins over a from-file define for the same
key if both are passed (Flutter last-write-wins — prefer one source).

If platform folders are missing (unusual):

```bash
flutter create . --project-name banxa_payments_flutter_example --org com.banxa --platforms=ios,android
```

## Apple Pay

Apple Pay needs a merchant identifier, which Primer rejects checkout without:

```dart
await BanxaPayments.configure(
  const BanxaConfig(
    apiKey: 'YOUR_KEY',
    partnerId: 'YOUR_PARTNER',
    applePayMerchantIdentifier: 'merchant.com.yourcompany.yourapp',
    // Optional; Primer prefers the merchant name from the client session.
    applePayMerchantName: 'Your Store',
  ),
);
```

The host app must also declare the matching `com.apple.developer.in-app-payments`
entitlement (Xcode → Signing & Capabilities → Apple Pay). The example app reads
`BANXA_APPLE_PAY_MERCHANT_ID` / `BANXA_APPLE_PAY_MERCHANT_NAME` from
`--dart-define`, but the entitlement still has to be added in Xcode.

**Apple Pay cannot run on the simulator.** Primer removes it from the session
whenever `PKPaymentAuthorizationController.canMakePayments()` is false, so
presenting it would fail with an opaque error. `startPayment` therefore asks the
platform whether the method is usable first, via
`BanxaPaymentsPlatform.isNativePaymentMethodAvailable`, and returns
`BanxaHostedCheckoutRequired` instead when it is not. Apple Pay reports
unavailable when the merchant identifier is missing, on the simulator, on a
device with no usable card, and always on Android.

Google Pay on Android is unavailable when Google Play services are missing.

Note for maintainers: `PrimerApplePayOptions` lives in Primer's `PrimerCore`
module, which `PrimerSDK` does not re-export, so `PrimerBridge.swift` imports
both and the podspec depends on both. Swift Package Manager only vends the
`PrimerSDK` product; `PrimerCore` is linked through that product.

## Pigeon

```bash
cd packages/banxa_payments_flutter_platform_interface
dart run pigeon --input pigeons/messages.dart
```

## Primer versions

| Platform | SDK | Version |
|----------|-----|---------|
| iOS | `PrimerSDK` (SPM or CocoaPods) | `2.49.0` |
| Android | `io.primer:checkout` / `io.primer:android` | `3.0.0-beta.2` (**preview**) |

These are different major generations; the Flutter plugin targets each platform’s native API surface independently. Android checkout has been compiled against the beta; confirm a card payment on a real device before any partner GA.

## Still confirm against sandbox

1. **Quote `discount` sub-shape** — promo injection.
2. **`POST /primer/session` field set** — implemented with `primerToken` + `savedCard` + passthrough map.
3. Android Primer Compose checkout on a real device/emulator. `Payment` there exposes only `id` and `orderId`, so completed events carry no `status` on Android.

## Release, support, rollback

- **0.x is preview.** Do not publish to pub.dev until Android Primer is on a stable pin and this CI is green on the tagged commit.
- **Staged rollout:** internal Banxa app → one design-partner → general availability.
- **Pinning:** until packages are on a registry, depend on a git commit SHA. After publish, depend on `banxa_payments_flutter: 0.1.0` (or a later version) so you can roll back by pinning the previous version with no code change.
- **Support:** Banxa partner integrations — `support@banxa.com`.

## iOS packaging

Both Swift Package Manager and CocoaPods are supported, from one source tree:

```
packages/banxa_payments_flutter_ios/ios/
├── banxa_payments_flutter_ios.podspec           # CocoaPods
└── banxa_payments_flutter_ios/
    ├── Package.swift                            # Swift Package Manager
    └── Sources/banxa_payments_flutter_ios/*.swift
```

Minimum iOS is **15.0**, the deployment target Flutter enforces from 3.47
onward. PrimerSDK's own Swift Package floor is lower (13.1), so Flutter is the
binding constraint; 15.0 is declared unconditionally so the floor is the same on
every supported Flutter. Keep the podspec's `source_files` and Package.swift's target
pointed at the same `Sources/` directory, and keep the Pigeon `swiftOut` path in
`pigeons/messages.dart` in sync if the layout ever moves.

### The 15.0 minimum and Swift Package Manager

Host apps must set `IPHONEOS_DEPLOYMENT_TARGET` to 15.0 or higher. Flutter
generates a `FlutterGeneratedPluginSwiftPackage` that depends on this plugin and
declares Flutter's default minimum, then raises it to the Xcode project's
deployment target — but only from inside the `flutter` iOS build pipeline.
`flutter pub get`, `flutter test` and `flutter analyze` regenerate that manifest
back to the default, so building straight from Xcode afterwards fails with:

```
The package product 'banxa-payments-flutter-ios' requires minimum platform
version 15.0 for the iOS platform, but this target supports 13.0
```

Let the Flutter tool configure the project first, then build in Xcode:

```bash
flutter build ios --config-only --simulator
```

## Android toolchain

The example and the Android plugin are built with Gradle 8.14.3, AGP 8.11.1 and
Kotlin 2.2.20; Compose uses the `org.jetbrains.kotlin.plugin.compose` plugin,
which replaced `composeOptions.kotlinCompilerExtensionVersion` in Kotlin 2.0.

## Hard constraints

- No dependency on other Banxa mobile SDK repos (`ios-payment-sdk`, `android-payments-sdk`, etc.).
