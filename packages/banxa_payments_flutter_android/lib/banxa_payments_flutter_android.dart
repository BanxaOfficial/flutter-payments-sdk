import 'package:banxa_payments_flutter_platform_interface/method_channel.dart';
import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';

/// Android dartPluginClass — registers the default method-channel platform.
class BanxaPaymentsFlutterAndroid {
  static void registerWith() {
    BanxaPaymentsPlatform.instance = MethodChannelBanxaPayments();
  }
}
