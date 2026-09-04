import 'dart:async';

import 'package:flutter/services.dart';

import 'banxa_payments_platform.dart';
import 'messages.g.dart';
import 'models.dart';

/// Default [BanxaPaymentsPlatform] backed by Pigeon HostApi / FlutterApi.
class MethodChannelBanxaPayments extends BanxaPaymentsPlatform
    implements BanxaPaymentsFlutterApi {
  MethodChannelBanxaPayments({BanxaPaymentsHostApi? api})
      : _api = api ?? BanxaPaymentsHostApi();

  final BanxaPaymentsHostApi _api;
  final StreamController<BanxaCheckoutEvent> _events =
      StreamController<BanxaCheckoutEvent>.broadcast();
  bool _flutterApiReady = false;

  void _ensureFlutterApi() {
    if (_flutterApiReady) {
      return;
    }
    BanxaPaymentsFlutterApi.setUp(this);
    _flutterApiReady = true;
  }

  @override
  Stream<BanxaCheckoutEvent> get checkoutEvents {
    _ensureFlutterApi();
    return _events.stream;
  }

  @override
  void onCheckoutEvent(CheckoutEventMessage event) {
    final type = event.type;
    switch (type) {
      case 'completed':
        final fields = <String, String>{
          for (final entry in (event.data ?? {}).entries)
            if (entry.key != null &&
                entry.key!.isNotEmpty &&
                entry.value != null &&
                entry.value!.isNotEmpty)
              entry.key!: entry.value!,
        };
        _events.add(BanxaCheckoutCompleted.fromFields(fields));
      case 'failed':
        _events.add(
          BanxaCheckoutFailed(event.errorMessage ?? 'Checkout failed'),
        );
      case 'dismissed':
        _events.add(const BanxaCheckoutDismissed());
      default:
        _events.add(
          const BanxaCheckoutFailed('Unknown checkout event type'),
        );
    }
  }

  @override
  Future<void> configureCheckout({
    String? applePayMerchantIdentifier,
    String? applePayMerchantName,
  }) {
    return _guard(
      () => _api.configureCheckout(
        CheckoutConfigMessage(
          applePayMerchantIdentifier: applePayMerchantIdentifier,
          applePayMerchantName: applePayMerchantName,
        ),
      ),
    );
  }

  @override
  Future<bool> isNativePaymentMethodAvailable(String paymentMethodId) =>
      _guard(() => _api.isNativePaymentMethodAvailable(paymentMethodId));

  @override
  Future<void> presentPrimerCheckout({
    required String clientToken,
    required String paymentMethodId,
  }) {
    return _guard(
      () => _api.presentPrimerCheckout(clientToken, paymentMethodId),
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    _ensureFlutterApi();
    try {
      return await action();
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }
}

BanxaPaymentsException _mapPlatformException(PlatformException e) {
  return switch (e.code) {
    'checkout_failed' => CheckoutFailedException(e.message),
    _ => UnknownException(e.message ?? e.code),
  };
}
