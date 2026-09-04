import 'package:banxa_payments_flutter_example/env.dart';
import 'package:banxa_payments_flutter_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('example app renders configure controls', (tester) async {
    await ExampleEnv.load();
    await tester.pumpWidget(const BanxaExampleApp());

    expect(find.text('Banxa Payments'), findsOneWidget);
    expect(find.text('Configure'), findsOneWidget);
    expect(find.text('Start payment'), findsOneWidget);
    expect(find.text('Fiat'), findsOneWidget);
    expect(find.text('Wallet address'), findsOneWidget);
  });
}
