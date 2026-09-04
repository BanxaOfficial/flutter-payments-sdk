// Pigeon schema - single source of truth for the Dart <-> native contract.
//
// Generate with (from this package root):
//   dart run pigeon --input pigeons/messages.dart
//
// Partner-api v2 networking lives in Dart (banxa_payments_flutter), so this
// channel only covers presenting native Primer checkout and reporting its
// outcome.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    swiftOut:
        '../banxa_payments_flutter_ios/ios/banxa_payments_flutter_ios/Sources/banxa_payments_flutter_ios/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    kotlinOut:
        '../banxa_payments_flutter_android/android/src/main/kotlin/com/banxa/flutterpaymentsdk/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.banxa.flutterpaymentsdk',
    ),
  ),
)

/// type: "completed" | "failed" | "dismissed"
class CheckoutEventMessage {
  String? type;
  String? errorMessage;
  Map<String?, String?>? data;
}

/// Native-only settings. Partner-api credentials never cross the channel.
class CheckoutConfigMessage {
  /// Apple Pay merchant identifier, e.g. `merchant.com.example`. Primer
  /// rejects Apple Pay without it.
  String? applePayMerchantIdentifier;

  /// Fallback merchant name for the Apple Pay sheet. Primer prefers the value
  /// from the client session.
  String? applePayMerchantName;
}

@HostApi()
abstract class BanxaPaymentsHostApi {
  /// Installs the Primer settings + delegate. Called from
  /// `BanxaPayments.configure`.
  @async
  void configureCheckout(CheckoutConfigMessage config);

  /// Whether this device can present [paymentMethodId] through native Primer.
  /// Apple Pay needs a configured merchant identifier plus a device that can
  /// pay, so it is false on the simulator and on Android.
  bool isNativePaymentMethodAvailable(String paymentMethodId);

  /// Presents Primer for an order that returned a `nativeToken`.
  /// Returns once checkout is launched; outcomes arrive on
  /// [BanxaPaymentsFlutterApi.onCheckoutEvent].
  @async
  void presentPrimerCheckout(String clientToken, String paymentMethodId);
}

@FlutterApi()
abstract class BanxaPaymentsFlutterApi {
  void onCheckoutEvent(CheckoutEventMessage event);
}
