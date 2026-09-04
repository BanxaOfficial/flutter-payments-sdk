import 'dart:async';

import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';

import 'checkout_launch.dart';
import 'checkout_url_matcher.dart';

/// Testable hosted-checkout state machine (no WebView).
class HostedCheckoutSession {
  HostedCheckoutSession({
    required this.checkout,
    required this.onEvent,
    this.loadTimeout = CheckoutUrlMatcher.loadTimeout,
  });

  final BanxaHostedCheckoutRequired checkout;
  final void Function(BanxaCheckoutEvent event) onEvent;
  final Duration loadTimeout;

  bool terminalEventSent = false;
  Timer? _timeout;

  bool get isInitialUrlAllowed =>
      CheckoutUrlMatcher.isAllowedInitialCheckoutUrl(checkout.checkoutUrl);

  void startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(loadTimeout, () {
      emit(const BanxaCheckoutFailed('Checkout page timed out'));
    });
  }

  void cancelTimeout() {
    _timeout?.cancel();
    _timeout = null;
  }

  /// Returns true when navigation should be cancelled (terminal URL).
  bool handleUrl(String url) {
    switch (CheckoutUrlMatcher.outcome(
      url,
      redirectUrl: checkout.redirectUrl,
    )) {
      case CheckoutOutcome.completed:
        emit(CheckoutUrlMatcher.completedFromUrl(url));
        return true;
      case CheckoutOutcome.failed:
        emit(const BanxaCheckoutFailed('Checkout failed'));
        return true;
      case CheckoutOutcome.cancelled:
        emit(const BanxaCheckoutDismissed());
        return true;
      case CheckoutOutcome.none:
        return false;
    }
  }

  void emit(BanxaCheckoutEvent event) {
    if (terminalEventSent) {
      return;
    }
    terminalEventSent = true;
    cancelTimeout();
    onEvent(event);
  }

  void dispose() {
    cancelTimeout();
    if (!terminalEventSent) {
      emit(const BanxaCheckoutDismissed());
    }
  }
}
