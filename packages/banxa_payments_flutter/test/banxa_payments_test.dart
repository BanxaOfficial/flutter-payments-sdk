import 'dart:async';
import 'dart:convert';

import 'package:banxa_payments_flutter/banxa_payments_flutter.dart';
import 'package:banxa_payments_flutter/src/test_hooks.dart';
import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPlatform extends BanxaPaymentsPlatform
    with MockPlatformInterfaceMixin {
  final events = StreamController<BanxaCheckoutEvent>.broadcast();
  int configureCount = 0;
  String? configuredApplePayMerchantId;
  String? presentedClientToken;
  String? presentedPaymentMethodId;
  bool nativeMethodAvailable = true;

  @override
  Stream<BanxaCheckoutEvent> get checkoutEvents => events.stream;

  @override
  Future<void> configureCheckout({
    String? applePayMerchantIdentifier,
    String? applePayMerchantName,
  }) async {
    configureCount++;
    configuredApplePayMerchantId = applePayMerchantIdentifier;
  }

  @override
  Future<bool> isNativePaymentMethodAvailable(String paymentMethodId) async =>
      nativeMethodAvailable;

  @override
  Future<void> presentPrimerCheckout({
    required String clientToken,
    required String paymentMethodId,
  }) async {
    presentedClientToken = clientToken;
    presentedPaymentMethodId = paymentMethodId;
  }
}

const _request = CreateOrderRequest(
  orderType: OrderType.buy,
  crypto: 'ETH',
  fiat: 'USD',
  fiatAmount: '50',
  walletAddress: '0xabc',
  email: 'user@example.com',
  redirectUrl: 'https://example.com/redirect',
  paymentMethodId: 'debit-credit-card',
);

/// Answers `/eligibility` with an empty object and `/buy` with [order].
MockClient _ordersRespondingWith(Map<String, dynamic> order) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/eligibility')) {
      return http.Response('{}', 200);
    }
    return http.Response(jsonEncode(order), 200);
  });
}

Future<void> _configure(MockClient client) {
  return BanxaPayments.configure(
    const BanxaConfig(
      apiKey: 'key',
      partnerId: 'partner',
      environment: BanxaEnvironment.sandbox,
    ),
    httpClient: client,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlatform platform;

  setUp(() async {
    await resetBanxaPaymentsForTest();
    platform = _MockPlatform();
    BanxaPaymentsPlatform.instance = platform;
  });

  tearDown(() async {
    await platform.events.close();
  });

  test('configure installs native checkout', () async {
    await _configure(MockClient((_) async => http.Response('[]', 200)));

    expect(platform.configureCount, 1);
  });

  test('configure rejects blank credentials', () async {
    expect(
      () => BanxaPayments.configure(
        const BanxaConfig(apiKey: '', partnerId: 'partner'),
      ),
      throwsA(isA<MissingCredentialsException>()),
    );
  });

  test('calls before configure throw SdkNotConfiguredException', () {
    expect(
      BanxaPayments.fetchCountries,
      throwsA(isA<SdkNotConfiguredException>()),
    );
  });

  test('startPayment presents Primer when the order has a nativeToken',
      () async {
    await _configure(
      _ordersRespondingWith({'id': 'o1', 'nativeToken': 'client-token'}),
    );

    final launch = await BanxaPayments.startPayment(_request);

    expect(launch, isA<BanxaPrimerCheckoutLaunched>());
    expect(launch.order.id, 'o1');
    expect(platform.presentedClientToken, 'client-token');
    expect(platform.presentedPaymentMethodId, 'debit-credit-card');
  });

  test('startPayment falls back to hosted checkout without a nativeToken',
      () async {
    await _configure(
      _ordersRespondingWith({
        'id': 'o2',
        'checkoutUrl': 'https://checkout.banxa-sandbox.com/o2',
      }),
    );

    final launch = await BanxaPayments.startPayment(_request);

    expect(launch, isA<BanxaHostedCheckoutRequired>());
    final hosted = launch as BanxaHostedCheckoutRequired;
    expect(hosted.checkoutUrl, 'https://checkout.banxa-sandbox.com/o2');
    expect(hosted.redirectUrl, 'https://example.com/redirect');
    expect(platform.presentedClientToken, isNull);
  });

  test('startPayment throws when neither checkout route is available',
      () async {
    await _configure(_ordersRespondingWith({'id': 'o3'}));

    await expectLater(
      BanxaPayments.startPayment(_request),
      throwsA(isA<NativeCheckoutNotEligibleException>()),
    );
  });

  test('configure forwards the Apple Pay merchant identifier to native',
      () async {
    await BanxaPayments.configure(
      const BanxaConfig(
        apiKey: 'key',
        partnerId: 'partner',
        applePayMerchantIdentifier: 'merchant.com.example',
      ),
      httpClient: MockClient((_) async => http.Response('[]', 200)),
    );

    expect(platform.configuredApplePayMerchantId, 'merchant.com.example');
  });

  test(
      'startPayment uses hosted checkout when the method is unavailable '
      'on the device', () async {
    platform.nativeMethodAvailable = false;
    await _configure(
      _ordersRespondingWith({
        'id': 'o5',
        'nativeToken': 'client-token',
        'checkoutUrl': 'https://checkout.banxa-sandbox.com/o5',
      }),
    );

    final launch = await BanxaPayments.startPayment(_request);

    expect(launch, isA<BanxaHostedCheckoutRequired>());
    expect(platform.presentedClientToken, isNull);
  });

  test('startPayment explains an unavailable method with no hosted fallback',
      () async {
    platform.nativeMethodAvailable = false;
    await _configure(
      _ordersRespondingWith({'id': 'o6', 'nativeToken': 'client-token'}),
    );

    await expectLater(
      BanxaPayments.startPayment(_request),
      throwsA(
        isA<NativeCheckoutNotEligibleException>().having(
          (e) => e.message,
          'message',
          contains('debit-credit-card'),
        ),
      ),
    );
  });

  test('startPayment still creates the order when eligibility is unused',
      () async {
    await _configure(
      MockClient((request) async {
        if (request.url.path.endsWith('/eligibility')) {
          return http.Response('{"message":"nope"}', 500);
        }
        return http.Response('{"id":"o4","nativeToken":"tok"}', 200);
      }),
    );

    final launch = await BanxaPayments.startPayment(_request);

    expect(launch, isA<BanxaPrimerCheckoutLaunched>());
  });

  test('startPayment rejects a non-Banxa hosted checkout URL', () async {
    await _configure(
      _ordersRespondingWith({
        'id': 'o7',
        'checkoutUrl': 'https://evil.example/phish',
      }),
    );

    await expectLater(
      BanxaPayments.startPayment(_request),
      throwsA(isA<NativeCheckoutNotEligibleException>()),
    );
  });

  test('checkoutEvents surfaces native events', () async {
    await _configure(MockClient((_) async => http.Response('[]', 200)));
    final received = <BanxaCheckoutEvent>[];
    final sub = BanxaPayments.checkoutEvents.listen(received.add);

    platform.events.add(const BanxaCheckoutCompleted(paymentId: 'p1'));
    await Future<void>.delayed(Duration.zero);

    expect(received.single, isA<BanxaCheckoutCompleted>());
    await sub.cancel();
  });
}
