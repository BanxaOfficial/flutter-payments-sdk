import 'package:banxa_payments_flutter/banxa_payments_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<BanxaKycEvent>> pumpKyc(
    WidgetTester tester,
    KycSession session,
  ) async {
    final events = <BanxaKycEvent>[];
    await tester.pumpWidget(
      MaterialApp(
        home: BanxaHostedKycView(session: session, onEvent: events.add),
      ),
    );
    return events;
  }

  testWidgets('a non-Banxa session URL fails without mounting a WebView',
      (tester) async {
    final events = await pumpKyc(
      tester,
      const KycSession(
        redirectUrl: 'https://evil.example/phish',
        expiresAt: '2999-01-01T00:00:00+00:00',
      ),
    );

    expect(
      (events.single as BanxaKycFailed).reason,
      BanxaKycFailureReason.invalidSessionUrl,
    );
    expect(find.byType(WebViewWidget), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an expired session fails without mounting a WebView',
      (tester) async {
    final events = await pumpKyc(
      tester,
      const KycSession(
        redirectUrl: 'https://partner.banxa-sandbox.com/kyc/abc',
        expiresAt: '2000-01-01T00:00:00+00:00',
      ),
    );

    expect(
      (events.single as BanxaKycFailed).reason,
      BanxaKycFailureReason.sessionExpired,
    );
    expect(find.byType(WebViewWidget), findsNothing);
  });

  testWidgets('a failed preflight is not followed by dismissed on dispose',
      (tester) async {
    final events = await pumpKyc(
      tester,
      const KycSession(
        redirectUrl: 'https://evil.example/phish',
        expiresAt: '2999-01-01T00:00:00+00:00',
      ),
    );

    await tester.pumpWidget(const SizedBox());

    expect(events.single, isA<BanxaKycFailed>());
  });
}
