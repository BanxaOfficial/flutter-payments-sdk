import 'package:banxa_payments_flutter/src/checkout/checkout_url_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('status path on a Banxa host is completed', () {
    expect(
      CheckoutUrlMatcher.outcome('https://checkout.banxa.com/status/abc'),
      CheckoutOutcome.completed,
    );
  });

  test('error and failure paths on a Banxa host are failed', () {
    expect(
      CheckoutUrlMatcher.outcome('https://checkout.banxa.com/error/x'),
      CheckoutOutcome.failed,
    );
    expect(
      CheckoutUrlMatcher.outcome('https://checkout.banxa.com/failure'),
      CheckoutOutcome.failed,
    );
  });

  test('cancel path on a Banxa host is cancelled', () {
    expect(
      CheckoutUrlMatcher.outcome('https://checkout.banxa.com/cancel/'),
      CheckoutOutcome.cancelled,
    );
  });

  test('substring markers on a non-Banxa host are ignored', () {
    expect(
      CheckoutUrlMatcher.outcome('https://evil.example/?q=/status/abc'),
      CheckoutOutcome.none,
    );
    expect(
      CheckoutUrlMatcher.outcome('https://example.com/cancel/'),
      CheckoutOutcome.none,
    );
  });

  test('redirect url path match is completed', () {
    expect(
      CheckoutUrlMatcher.outcome(
        'https://example.com/redirect?orderId=1',
        redirectUrl: 'https://example.com/redirect',
      ),
      CheckoutOutcome.completed,
    );
  });

  test('a url that merely starts with the redirect path is not terminal', () {
    expect(
      CheckoutUrlMatcher.outcome(
        'https://example.com/redirect-not-really',
        redirectUrl: 'https://example.com/redirect',
      ),
      CheckoutOutcome.none,
    );
  });

  test('intermediate checkout urls are not terminal', () {
    expect(
      CheckoutUrlMatcher.outcome(
        'https://checkout.banxa.com/order/123',
        redirectUrl: 'https://example.com/redirect',
      ),
      CheckoutOutcome.none,
    );
  });

  test('initial load must be https on a Banxa host', () {
    expect(
      CheckoutUrlMatcher.isAllowedInitialCheckoutUrl(
        'https://checkout.banxa-sandbox.com/o2',
      ),
      isTrue,
    );
    expect(
      CheckoutUrlMatcher.isAllowedInitialCheckoutUrl(
        'http://checkout.banxa.com/o2',
      ),
      isFalse,
    );
    expect(
      CheckoutUrlMatcher.isAllowedInitialCheckoutUrl(
        'https://evil.example/o2',
      ),
      isFalse,
    );
  });

  test('in-flow https navigation is allowed for 3DS hosts', () {
    expect(
      CheckoutUrlMatcher.allowNavigation('https://acs.bank.example/3ds'),
      isTrue,
    );
    expect(
      CheckoutUrlMatcher.allowNavigation('http://acs.bank.example/3ds'),
      isFalse,
    );
  });

  test('completedFromUrl uses query fields only', () {
    final event = CheckoutUrlMatcher.completedFromUrl(
      'https://example.com/redirect?orderId=1&status=complete&paymentId=p1',
    );
    expect(event.orderId, '1');
    expect(event.status, 'complete');
    expect(event.paymentId, 'p1');
  });
}
