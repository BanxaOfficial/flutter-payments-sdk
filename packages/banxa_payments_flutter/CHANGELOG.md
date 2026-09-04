# Changelog

## 0.1.0

- First **preview** of `banxa_payments_flutter`: partner-api v2 catalog/order
  APIs, Primer native checkout (iOS 2.49.0, Android 3.0.0-beta.2), and hosted
  checkout in a Flutter WebView.
- Requires Dart `>=3.12.2` and Flutter `>=3.44.9`.
- Minimum iOS is **15.0**. PrimerSDK's own floor is 13.1; Flutter 3.47 enforces
  15.0, so 15.0 is declared for every supported Flutter.
- Do not treat this as general availability. Android Primer is still a beta
  pin. Pin `banxa_payments_flutter: 0.1.0` rather than a caret range.
- Hosted checkout loads only `https` Banxa hosts; checkout events are typed
  (`paymentId` / `orderId` / `status`) and do not include raw URLs.
- `CreateOrderResponse.paymentMethodId` is a `String?`, matching create/catalog
  slugs (numeric wire values are stringified).
