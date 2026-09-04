import 'package:banxa_payments_flutter_platform_interface/method_channel.dart';
import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';

/// iOS dartPluginClass — registers the default method-channel platform.
class BanxaPaymentsFlutterIos {
  static void registerWith() {
    BanxaPaymentsPlatform.instance = MethodChannelBanxaPayments();
  }
}
