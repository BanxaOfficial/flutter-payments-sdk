import 'dart:async';

import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';

/// Single stream of checkout outcomes, whether they come from native Primer
/// or from the Dart hosted-checkout WebView.
class BanxaCheckoutEventHub {
  BanxaCheckoutEventHub._();

  static final BanxaCheckoutEventHub instance = BanxaCheckoutEventHub._();

  final StreamController<BanxaCheckoutEvent> _controller =
      StreamController<BanxaCheckoutEvent>.broadcast();
  StreamSubscription<BanxaCheckoutEvent>? _platformSubscription;

  Stream<BanxaCheckoutEvent> get stream {
    attachPlatform();
    return _controller.stream;
  }

  /// Listen to the current [BanxaPaymentsPlatform.instance]. Call after
  /// [BanxaPayments.configure] and whenever tests swap the platform instance.
  void attachPlatform() {
    _platformSubscription?.cancel();
    _platformSubscription =
        BanxaPaymentsPlatform.instance.checkoutEvents.listen(_controller.add);
  }

  void emit(BanxaCheckoutEvent event) => _controller.add(event);

  /// Drops the platform subscription so a new [BanxaPaymentsPlatform.instance]
  /// can be attached.
  Future<void> detachPlatform() async {
    await _platformSubscription?.cancel();
    _platformSubscription = null;
  }
}
