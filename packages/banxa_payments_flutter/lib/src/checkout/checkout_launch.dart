import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';

/// Outcome of `BanxaPayments.startPayment`: the order was created, and either
/// native Primer checkout was presented or the app must show hosted checkout.
sealed class BanxaCheckoutLaunch {
  const BanxaCheckoutLaunch(this.order);

  final CreateOrderResponse order;
}

/// Primer was presented natively. Outcomes arrive on
/// `BanxaPayments.checkoutEvents`.
///
/// On iOS this is a single payment method (`showPaymentMethod`). On Android
/// Primer Checkout 3.x presents the methods from the client session (the
/// requested Banxa method is still recorded natively).
final class BanxaPrimerCheckoutLaunched extends BanxaCheckoutLaunch {
  const BanxaPrimerCheckoutLaunched(super.order);
}

/// The order has no usable native path, so checkout has to run in a WebView.
/// Show `BanxaHostedCheckoutView` with this value. [checkoutUrl] is always
/// `https` on a Banxa-owned host.
final class BanxaHostedCheckoutRequired extends BanxaCheckoutLaunch {
  const BanxaHostedCheckoutRequired(
    super.order, {
    required this.checkoutUrl,
    this.redirectUrl,
  });

  final String checkoutUrl;
  final String? redirectUrl;
}
