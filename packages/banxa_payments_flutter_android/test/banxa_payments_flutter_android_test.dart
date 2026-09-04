import 'package:banxa_payments_flutter_android/banxa_payments_flutter_android.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plugin dart class is present', () {
    expect(BanxaPaymentsFlutterAndroid.registerWith, isA<Function>());
  });
}
