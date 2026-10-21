# Changelog

## 0.1.3

- remove android classpath forcing kotlin version 2.2.20

## 0.1.2

- Primer iOS is a range, **>=2.49.0 <3.0.0**, in both Swift Package Manager and
  CocoaPods. Host apps can pin any 2.x in that range. Primer 3.x is not allowed.

## 0.1.1

- iOS plugin floor is **13.1** (PrimerSDK). Flutter **3.44.9** host apps can
  target iOS 13.1. Flutter **3.47+** still compiles the host app at **15.0**;
  that is Flutter’s deployment target, not this plugin’s.

## 0.1.0

- First **preview** of `banxa_payments_flutter`: partner-api v2 catalog/order
  APIs, Primer native checkout (iOS 2.49.0, Android 3.0.0-beta.2), and hosted
  checkout in a Flutter WebView.
- Requires Dart `>=3.12.2` and Flutter `>=3.44.9`.
- Do not treat this as general availability. Android Primer is still a beta
  pin. Pin an exact version rather than a caret range.
- Hosted checkout loads only `https` Banxa hosts; checkout events are typed
  (`paymentId` / `orderId` / `status`) and do not include raw URLs.
- `CreateOrderResponse.paymentMethodId` is a `String?`, matching create/catalog
  slugs (numeric wire values are stringified).
