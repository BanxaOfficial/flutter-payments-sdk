# Changelog

## 0.1.0

- First preview of `banxa_payments_flutter`: partner-api v2 catalog/order APIs,
  Primer native checkout (iOS 2.49.0, Android 3.0.0-beta.2), and hosted
  checkout in a Flutter WebView.
- Requires Dart `>=3.12.2` and Flutter `>=3.44.9`.
- Minimum iOS is **15.0**, the deployment target Flutter enforces from 3.47
  onward. PrimerSDK's own floor is 13.1, so Flutter is the binding constraint.
  15.0 is declared for every supported Flutter so the floor does not shift
  between 3.44 and 3.47.
- **Preview only.** Android Primer is still a beta dependency; do not treat
  this as general availability. Packages are unpublished (`publish_to: none`)
  and consumed from this monorepo via path dependencies until a registry
  release exists.
- Hosted checkout loads only `https` Banxa hosts; checkout events are typed
  (`paymentId` / `orderId` / `status`) and do not include raw URLs.
- `CreateOrderResponse.paymentMethodId` is a `String?`, matching create/catalog
  slugs (numeric wire values are stringified).
