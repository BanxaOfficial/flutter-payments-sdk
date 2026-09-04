import 'sdk_state.dart';
import 'checkout/checkout_event_hub.dart';

/// Test-only reset. Not part of the public barrel export.
Future<void> resetBanxaPaymentsForTest() async {
  BanxaSdkState.reset();
  await BanxaCheckoutEventHub.instance.detachPlatform();
}
