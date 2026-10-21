import 'dart:convert';

import 'package:banxa_payments_flutter/src/kyc/hosted_kyc_session.dart';
import 'package:banxa_payments_flutter/src/kyc/kyc_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _sessionUrl = 'https://partner.banxa-sandbox.com/kyc/abc';
const _origin = 'https://partner.banxa-sandbox.com';
const _nonce = 'nonce-123';

void main() {
  late List<BanxaKycEvent> events;

  setUp(() => events = []);

  HostedKycSession session({
    String url = _sessionUrl,
    String expiresAt = '2026-09-23T11:00:00+00:00',
    String? returnUrl = 'myapp://kyc-done',
    List<String> allowedOrigins = const [],
    DateTime? now,
    Duration loadTimeout = const Duration(seconds: 30),
  }) {
    return HostedKycSession(
      session: KycSession(redirectUrl: url, expiresAt: expiresAt),
      returnUrl: returnUrl,
      allowedOrigins: allowedOrigins,
      onEvent: events.add,
      nonce: _nonce,
      now: () => now ?? DateTime.utc(2026, 9, 23, 10),
      loadTimeout: loadTimeout,
    );
  }

  String message({
    String type = kycCompleteMessageType,
    String nonce = _nonce,
    String origin = _origin,
    Map<String, Object?> extra = const {},
  }) {
    return jsonEncode({
      'nonce': nonce,
      'origin': origin,
      'type': type,
      ...extra,
    });
  }

  group('bridge messages', () {
    test('a valid completion message emits completed via the message channel',
        () {
      session().handleBridgeMessage(message(extra: {'status': 'submitted'}));

      final completed = events.single as BanxaKycCompleted;
      expect(completed.status, 'submitted');
      expect(completed.channel, BanxaKycChannel.message);
    });

    test('a completion message without a status reports complete', () {
      session().handleBridgeMessage(message());

      expect((events.single as BanxaKycCompleted).status, 'complete');
    });

    test('a wrong nonce is rejected as not coming from the main frame', () {
      session().handleBridgeMessage(message(nonce: 'forged'));

      final rejected = events.single as BanxaKycMessageRejected;
      expect(rejected.reason, BanxaKycRejectionReason.frame);
      expect(rejected.type, kycCompleteMessageType);
    });

    test('an unknown origin is rejected', () {
      session().handleBridgeMessage(message(origin: 'https://evil.example'));

      final rejected = events.single as BanxaKycMessageRejected;
      expect(rejected.reason, BanxaKycRejectionReason.origin);
      expect(rejected.origin, 'https://evil.example');
    });

    test('an origin from allowedOrigins is accepted', () {
      session(allowedOrigins: ['https://verify.banxa.com/'])
          .handleBridgeMessage(message(origin: 'https://verify.banxa.com'));

      expect(events.single, isA<BanxaKycCompleted>());
    });

    test('banxa:error reports a flow error and does not end the session', () {
      final kyc = session();

      kyc.handleBridgeMessage(
        message(
          type: 'banxa:error',
          extra: {'code': 42, 'message': 'Camera unavailable'},
        ),
      );
      kyc.handleBridgeMessage(message());

      final failed = events.first as BanxaKycFailed;
      expect(failed.reason, BanxaKycFailureReason.flowError);
      expect(failed.code, '42');
      expect(failed.message, 'Camera unavailable');
      expect(events.last, isA<BanxaKycCompleted>());
    });

    test('ready and loading are relayed with a default status', () {
      final kyc = session();

      kyc.handleBridgeMessage(message(type: 'banxa:ready'));
      kyc.handleBridgeMessage(message(type: 'banxa:loading'));

      expect((events.first as BanxaKycReady).status, 'ready');
      expect((events.last as BanxaKycLoading).status, 'loading');
    });

    test('non-banxa messages and malformed payloads are ignored', () {
      final kyc = session();

      kyc.handleBridgeMessage(message(type: 'other:thing'));
      kyc.handleBridgeMessage('not json');
      kyc.handleBridgeMessage('[1, 2]');

      expect(events, isEmpty);
    });
  });

  group('navigation', () {
    test('the return deep link is prevented and completes the session', () {
      final kyc = session();

      expect(
        kyc.handleNavigation('myapp://kyc-done?status=ok', isMainFrame: true),
        isTrue,
      );

      final completed = events.single as BanxaKycCompleted;
      expect(completed.channel, BanxaKycChannel.returnUrl);
      expect(completed.status, 'complete');
    });

    test('an https return URL is prevented and completes the session', () {
      final kyc = session(returnUrl: 'https://partner.example.com/done');

      expect(
        kyc.handleNavigation(
          'https://partner.example.com/done/',
          isMainFrame: true,
        ),
        isTrue,
      );
      expect(events.single, isA<BanxaKycCompleted>());
    });

    test('a sub-frame navigation never counts as the return URL', () {
      final kyc = session(returnUrl: 'https://partner.example.com/done');

      expect(
        kyc.handleNavigation(
          'https://partner.example.com/done',
          isMainFrame: false,
        ),
        isFalse,
      );
      expect(events, isEmpty);
    });

    test('main-frame navigations must be https', () {
      final kyc = session();

      expect(
        kyc.handleNavigation('http://partner.banxa.com/kyc', isMainFrame: true),
        isTrue,
      );
      expect(
        kyc.handleNavigation('https://sumsub.com/idensic', isMainFrame: true),
        isFalse,
      );
      expect(events, isEmpty);
    });

    test('sub-frames may load non-https documents such as about:blank', () {
      expect(
        session().handleNavigation('about:blank', isMainFrame: false),
        isFalse,
      );
    });
  });

  test('completion fires once across both channels', () {
    final kyc = session();

    kyc.handleBridgeMessage(message());
    kyc.handleNavigation('myapp://kyc-done', isMainFrame: true);
    kyc.handleBridgeMessage(message());

    expect(events, hasLength(1));
    expect((events.single as BanxaKycCompleted).channel, BanxaKycChannel.message);
  });

  group('preflight', () {
    test('a valid session on a supported device passes', () {
      expect(session().preflight(iosVersion: null), isNull);
      expect(session().preflight(iosVersion: '14.3'), isNull);
      expect(session().preflight(iosVersion: 'Version 17.5 (Build 21F79)'), isNull);
    });

    test('a non-Banxa session URL is refused', () {
      expect(
        session(url: 'https://evil.example/kyc').preflight(iosVersion: null),
        BanxaKycFailureReason.invalidSessionUrl,
      );
      expect(
        session(url: 'http://partner.banxa.com/kyc').preflight(iosVersion: null),
        BanxaKycFailureReason.invalidSessionUrl,
      );
    });

    test('an expired session is refused', () {
      expect(
        session(now: DateTime.utc(2026, 9, 23, 11)).preflight(iosVersion: null),
        BanxaKycFailureReason.sessionExpired,
      );
    });

    test('an unparseable expiry does not block the session', () {
      expect(
        session(expiresAt: 'soon').preflight(iosVersion: null),
        isNull,
      );
    });

    test('iOS below 14.3 is refused', () {
      expect(
        session().preflight(iosVersion: '14.2'),
        BanxaKycFailureReason.unsupportedOsVersion,
      );
      expect(
        session().preflight(iosVersion: 'Version 13.1.2 (Build 17A860)'),
        BanxaKycFailureReason.unsupportedOsVersion,
      );
    });

    test('an unreadable iOS version does not block the session', () {
      expect(session().preflight(iosVersion: 'unknown'), isNull);
    });
  });

  group('media permission', () {
    const media = {
      WebViewPermissionResourceType.camera,
      WebViewPermissionResourceType.microphone,
    };

    test('camera and microphone are granted on an accepted origin', () {
      expect(
        session().shouldGrantPermission(
          currentUrl: '$_origin/kyc/step-2',
          types: media,
        ),
        isTrue,
      );
    });

    test('media is denied once the page has left the accepted origins', () {
      expect(
        session().shouldGrantPermission(
          currentUrl: 'https://evil.example/',
          types: media,
        ),
        isFalse,
      );
      expect(
        session().shouldGrantPermission(currentUrl: null, types: media),
        isFalse,
      );
    });
  });

  test('the bridge is only injected on accepted origins', () {
    final kyc = session(allowedOrigins: ['https://verify.banxa.com']);

    expect(kyc.isAcceptedUrl('$_origin/kyc'), isTrue);
    expect(kyc.isAcceptedUrl('https://verify.banxa.com/step'), isTrue);
    expect(kyc.isAcceptedUrl('https://sumsub.com/'), isFalse);
    expect(kyc.isAcceptedUrl('myapp://kyc-done'), isFalse);
  });

  group('lifecycle', () {
    test('dispose before a terminal event emits dismissed', () {
      session().dispose();

      expect(events.single, isA<BanxaKycDismissed>());
    });

    test('dispose after completion emits nothing more', () {
      final kyc = session();

      kyc.handleBridgeMessage(message());
      kyc.dispose();

      expect(events.single, isA<BanxaKycCompleted>());
    });

    test('load timeout emits failed', () async {
      final kyc = session(loadTimeout: const Duration(milliseconds: 20));

      kyc.startTimeout();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        (events.single as BanxaKycFailed).reason,
        BanxaKycFailureReason.loadTimeout,
      );
    });
  });
}
