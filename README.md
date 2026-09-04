# banxa_payments_flutter

**Preview (0.1.0).** Flutter plugin for Banxa partner-api v2: catalog and orders,
native checkout (Primer), and hosted checkout in a WebView.

Pin **`0.1.0`**. Do not use a caret range until GA. Android native checkout still
uses Primer Checkout `3.0.0-beta.2`. Support: [support@banxa.com](mailto:support@banxa.com).

## Requirements

| Constraint | Value |
|------------|--------|
| Dart | `>=3.12.2 <4.0.0` |
| Flutter | `>=3.44.9` |
| iOS | **15.0+** |
| Android | **minSdk 24+** |

Set the iOS deployment target to 15.0 in Xcode. After `flutter pub get` /
`flutter test` / `flutter analyze`, build once with Flutter before opening the
iOS project in Xcode (`flutter build ios --config-only`), or Xcode may still
show a 13.0 minimum and fail to resolve this plugin.

Primer adds native binary size. Measure with `flutter build appbundle --analyze-size`
and an iOS archive if that matters for your app.

TLS only (`https`). This SDK does not certificate-pin.

### Permissions

The plugin merges `INTERNET` on Android. Hosted checkout and Primer may open the
camera or photo library — declare these in the **host app**:

**iOS** (`Info.plist`): `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`,
and `NSMicrophoneUsageDescription` if you enable video KYC.

**Android** (`AndroidManifest.xml`): `android.permission.CAMERA`.

Missing iOS usage strings crash when capture starts.

## Install

```yaml
dependencies:
  banxa_payments_flutter: 0.1.0
```

```sh
flutter pub add banxa_payments_flutter:0.1.0
```

Do not depend on `banxa_payments_flutter_ios`, `_android`, or
`_platform_interface` directly.

## Configure

Call once per process. Re-calling replaces the HTTP client and rebinds checkout
listeners. Pass your own `http.Client` to intercept traffic if you need to.

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

| Environment | Host |
|-------------|------|
| sandbox | `https://api.banxa-sandbox.com` |
| production | `https://api.banxa.com` |

Requests go to `{host}/{partnerId}/v2` with `x-api-key` and
`Content-Type: application/json`.

## Catalog and checkout

`startPayment` creates the order, then presents Primer when a `nativeToken` is
present and the method can run on the device. Otherwise you get
`BanxaHostedCheckoutRequired` and show `BanxaHostedCheckoutView`. If there is
neither a usable native route nor a Banxa `https` checkout URL, it throws
`NativeCheckoutNotEligibleException`.

`checkEligibility` is opt-in (`paymentReady` / `kycRequirements`).
`startPayment` does not call `/eligibility`.

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
      // success — `status` may be null on Android
    case BanxaCheckoutFailed(:final message):
      // error
    case BanxaCheckoutDismissed():
      // sheet closed (may also follow completed/failed)
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

`BanxaHostedCheckoutView` reports on `checkoutEvents` and never pops itself.
Dispose it without a terminal URL and you get `dismissed`. A hung first page
emits `failed` after 30s. Primer may emit `dismissed` after `completed`/`failed`
— treat those as distinct.

The first hosted URL must be `https` on a Banxa host (`*.banxa.com`,
`*.banxa-sandbox.com`, `*.banxa-preprod.com`). Later navigations may go to
bank/wallet `https` pages (3DS). JavaScript is on for the hosted UI; there is
no JS bridge into your app.

## Apple Pay and Google Pay

Apple Pay needs a merchant identifier and the matching
`com.apple.developer.in-app-payments` entitlement (Xcode → Signing &
Capabilities → Apple Pay):

```dart
await BanxaPayments.configure(
  const BanxaConfig(
    apiKey: 'YOUR_KEY',
    partnerId: 'YOUR_PARTNER',
    applePayMerchantIdentifier: 'merchant.com.yourcompany.yourapp',
    applePayMerchantName: 'Your Store', // optional
  ),
);
```

**Apple Pay does not run on the simulator.** Without a merchant id, on
simulator, on a device with no usable card, or on Android, `startPayment`
returns `BanxaHostedCheckoutRequired` instead of presenting Primer.

Google Pay is unavailable when Google Play services are missing; the same
hosted fallback applies.
