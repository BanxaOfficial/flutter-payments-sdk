import 'package:banxa_payments_flutter/src/checkout/hosted_checkout_session.dart';
import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:banxa_payments_flutter/src/checkout/checkout_launch.dart';

void main() {
  BanxaHostedCheckoutRequired checkout({
    String url = 'https://checkout.banxa-sandbox.com/order',
    String redirect = 'https://example.com/redirect',
  }) {
    return BanxaHostedCheckoutRequired(
      const CreateOrderResponse(id: 'o1'),
      checkoutUrl: url,
      redirectUrl: redirect,
    );
  }

  test('dispose before a terminal URL emits dismissed', () {
    final events = <BanxaCheckoutEvent>[];
    final session = HostedCheckoutSession(
      checkout: checkout(),
      onEvent: events.add,
    );

    session.dispose();

    expect(events, hasLength(1));
    expect(events.single, isA<BanxaCheckoutDismissed>());
  });

  test('Banxa status path emits typed completed and not the raw URL', () {
    final events = <BanxaCheckoutEvent>[];
    final session = HostedCheckoutSession(
      checkout: checkout(),
      onEvent: events.add,
    );

    expect(
      session.handleUrl(
        'https://checkout.banxa.com/status/abc?orderId=99&paymentId=p',
      ),
      isTrue,
    );

    final completed = events.single as BanxaCheckoutCompleted;
    expect(completed.orderId, '99');
    expect(completed.paymentId, 'p');
  });

  test('load timeout emits failed', () async {
    final events = <BanxaCheckoutEvent>[];
    final session = HostedCheckoutSession(
      checkout: checkout(),
      onEvent: events.add,
      loadTimeout: const Duration(milliseconds: 20),
    );

    session.startTimeout();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(events.single, isA<BanxaCheckoutFailed>());
    expect((events.single as BanxaCheckoutFailed).message, contains('timed out'));
  });
}
