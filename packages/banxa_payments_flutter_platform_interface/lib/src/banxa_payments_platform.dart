import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_banxa_payments.dart';
import 'models.dart';

/// Native surface of the plugin: presenting Primer checkout and reporting its
/// outcome. Partner-api networking lives in Dart, in `banxa_payments_flutter`.
abstract class BanxaPaymentsPlatform extends PlatformInterface {
  BanxaPaymentsPlatform() : super(token: _token);

  static final Object _token = Object();

  static BanxaPaymentsPlatform? _instance;

  static BanxaPaymentsPlatform get instance =>
      _instance ??= MethodChannelBanxaPayments();

  static set instance(BanxaPaymentsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Only the Apple Pay settings reach native; credentials stay in Dart.
  Future<void> configureCheckout({
    String? applePayMerchantIdentifier,
    String? applePayMerchantName,
  }) {
    throw UnimplementedError('configureCheckout() has not been implemented.');
  }

  /// Whether [paymentMethodId] can be presented natively on this device.
  /// False for Apple Pay on Android, on the iOS simulator, and without a
  /// merchant identifier; false for Google Pay when Play services are missing.
  Future<bool> isNativePaymentMethodAvailable(String paymentMethodId) {
    throw UnimplementedError(
      'isNativePaymentMethodAvailable() has not been implemented.',
    );
  }

  /// Presents Primer for an order that returned a `nativeToken`.
  /// Outcomes arrive on [checkoutEvents].
  Future<void> presentPrimerCheckout({
    required String clientToken,
    required String paymentMethodId,
  }) {
    throw UnimplementedError(
      'presentPrimerCheckout() has not been implemented.',
    );
  }

  Stream<BanxaCheckoutEvent> get checkoutEvents {
    throw UnimplementedError('checkoutEvents has not been implemented.');
  }
}
