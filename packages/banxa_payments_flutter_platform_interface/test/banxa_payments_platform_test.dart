import 'dart:async';

import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPlatform extends BanxaPaymentsPlatform
    with MockPlatformInterfaceMixin {
  final controller = StreamController<BanxaCheckoutEvent>.broadcast();

  @override
  Stream<BanxaCheckoutEvent> get checkoutEvents => controller.stream;

  @override
  Future<void> configureCheckout({
    String? applePayMerchantIdentifier,
    String? applePayMerchantName,
  }) async {}

  @override
  Future<bool> isNativePaymentMethodAvailable(String paymentMethodId) async =>
      true;

  @override
  Future<void> presentPrimerCheckout({
    required String clientToken,
    required String paymentMethodId,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BanxaPaymentsPlatform mock', () {
    late _MockPlatform mock;

    setUp(() {
      mock = _MockPlatform();
      BanxaPaymentsPlatform.instance = mock;
    });

    tearDown(() async {
      await mock.controller.close();
    });

    test('checkoutEvents demultiplexes completed / failed / dismissed', () async {
      final events = <BanxaCheckoutEvent>[];
      final sub = BanxaPaymentsPlatform.instance.checkoutEvents.listen(events.add);

      mock.controller.add(const BanxaCheckoutCompleted(paymentId: 'p1'));
      mock.controller.add(const BanxaCheckoutFailed('boom'));
      mock.controller.add(const BanxaCheckoutDismissed());
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(3));
      expect(events[0], isA<BanxaCheckoutCompleted>());
      expect((events[0] as BanxaCheckoutCompleted).paymentId, 'p1');
      expect(events[1], isA<BanxaCheckoutFailed>());
      expect((events[1] as BanxaCheckoutFailed).message, 'boom');
      expect(events[2], isA<BanxaCheckoutDismissed>());

      await sub.cancel();
    });

    test('BanxaConfig resolves sandbox base URL', () {
      const config = BanxaConfig(
        apiKey: 'key',
        partnerId: 'partner',
        environment: BanxaEnvironment.sandbox,
      );
      expect(config.baseUrl, 'https://api.banxa-sandbox.com/partner/v2');
    });
  });
}
