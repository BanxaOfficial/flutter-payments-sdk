import 'package:banxa_payments_flutter/banxa_payments_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('invalid checkout URL shows no spinner', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BanxaHostedCheckoutView(
          checkout: BanxaHostedCheckoutRequired(
            CreateOrderResponse(id: 'o1'),
            checkoutUrl: 'https://evil.example/phish',
            redirectUrl: 'https://example.com/redirect',
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
