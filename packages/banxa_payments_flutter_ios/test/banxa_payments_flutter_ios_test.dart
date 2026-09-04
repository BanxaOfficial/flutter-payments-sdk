import 'package:banxa_payments_flutter_ios/banxa_payments_flutter_ios.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plugin dart class is present', () {
    expect(BanxaPaymentsFlutterIos.registerWith, isA<Function>());
  });
}
