import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:webview_flutter/webview_flutter.dart';

import '../checkout/checkout_url_matcher.dart';
import 'kyc_models.dart';

/// Testable hosted-KYC state machine (no WebView).
///
/// Completion arrives on two channels, and whichever lands first wins: the
/// page navigating to [returnUrl], or a `banxa:kyc-complete` message forwarded
/// by the bridge script. `webview_flutter` does not say which frame sent a
/// message, so a message is only trusted when it carries this session's
/// [nonce], which only the main-frame bridge knows.
class HostedKycSession {
  HostedKycSession({
    required this.session,
    required this.onEvent,
    this.returnUrl,
    List<String> allowedOrigins = const [],
    String? nonce,
    DateTime Function()? now,
    this.loadTimeout = CheckoutUrlMatcher.loadTimeout,
  })  : nonce = nonce ?? _generateNonce(),
        _now = now ?? DateTime.now,
        acceptedOrigins = {
          ?_originOf(session.redirectUrl),
          for (final origin in allowedOrigins) ?_originOf(origin),
        };

  static const _minimumIosVersion = (14, 3);

  static const _mediaTypes = {
    WebViewPermissionResourceType.camera,
    WebViewPermissionResourceType.microphone,
  };

  final KycSession session;
  final String? returnUrl;
  final void Function(BanxaKycEvent event) onEvent;
  final String nonce;
  final Duration loadTimeout;
  final Set<String> acceptedOrigins;
  final DateTime Function() _now;

  bool terminalEventSent = false;
  Timer? _timeout;

  /// Returns why the session must not load, or null when it can.
  BanxaKycFailureReason? preflight({required String? iosVersion}) {
    if (!CheckoutUrlMatcher.isAllowedInitialCheckoutUrl(session.redirectUrl)) {
      return BanxaKycFailureReason.invalidSessionUrl;
    }
    final expiry = session.expirationDate;
    if (expiry != null && !expiry.isAfter(_now())) {
      return BanxaKycFailureReason.sessionExpired;
    }
    if (iosVersion != null && _isBelowMinimumIos(iosVersion)) {
      return BanxaKycFailureReason.unsupportedOsVersion;
    }
    return null;
  }

  /// Returns true when the navigation must be prevented.
  bool handleNavigation(String url, {required bool isMainFrame}) {
    if (!isMainFrame) {
      return false;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && CheckoutUrlMatcher.matchesReturnUrl(uri, returnUrl)) {
      finish(
        const BanxaKycCompleted(
          status: 'complete',
          channel: BanxaKycChannel.returnUrl,
        ),
      );
      return true;
    }
    return !CheckoutUrlMatcher.allowNavigation(url);
  }

  /// Handles a raw payload from the bridge script's JavaScript channel.
  void handleBridgeMessage(String raw) {
    if (terminalEventSent) {
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) {
      return;
    }
    final type = decoded['type'];
    if (type is! String || !type.startsWith('banxa:')) {
      return;
    }

    final origin = _text(decoded['origin']);
    if (decoded['nonce'] != nonce) {
      // Announced rather than dropped: a silent rejection looks the same as
      // the flow never posting, which leaves nothing to debug.
      onEvent(
        BanxaKycMessageRejected(
          reason: BanxaKycRejectionReason.frame,
          type: type,
          origin: origin,
        ),
      );
      return;
    }
    if (origin == null || !acceptedOrigins.contains(origin)) {
      onEvent(
        BanxaKycMessageRejected(
          reason: BanxaKycRejectionReason.origin,
          type: type,
          origin: origin,
        ),
      );
      return;
    }

    final status = _text(decoded['status']);
    switch (type) {
      case kycCompleteMessageType:
        finish(
          BanxaKycCompleted(
            status: status ?? 'complete',
            channel: BanxaKycChannel.message,
          ),
        );
      case kycErrorMessageType:
        onEvent(
          BanxaKycFailed(
            BanxaKycFailureReason.flowError,
            code: _text(decoded['code']),
            message: _text(decoded['message']),
          ),
        );
      case kycReadyMessageType:
        onEvent(BanxaKycReady(status: status ?? 'ready'));
      case kycLoadingMessageType:
        onEvent(BanxaKycLoading(status: status ?? 'loading'));
    }
  }

  /// Returns whether [url] is on an accepted origin.
  bool isAcceptedUrl(String? url) {
    final origin = _originOf(url);
    return origin != null && acceptedOrigins.contains(origin);
  }

  /// Returns whether the page may use the camera and microphone.
  bool shouldGrantPermission({
    required String? currentUrl,
    required Set<WebViewPermissionResourceType> types,
  }) =>
      types.isNotEmpty &&
      types.every(_mediaTypes.contains) &&
      isAcceptedUrl(currentUrl);

  void startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(loadTimeout, () {
      finish(const BanxaKycFailed(BanxaKycFailureReason.loadTimeout));
    });
  }

  void cancelTimeout() {
    _timeout?.cancel();
    _timeout = null;
  }

  /// Emits [event] and ends the session. Later terminal events are ignored.
  void finish(BanxaKycEvent event) {
    if (terminalEventSent) {
      return;
    }
    terminalEventSent = true;
    cancelTimeout();
    onEvent(event);
  }

  void dispose() {
    cancelTimeout();
    finish(const BanxaKycDismissed());
  }

  static bool _isBelowMinimumIos(String version) {
    final match = RegExp(r'(\d+)\.(\d+)').firstMatch(version);
    if (match == null) {
      return false;
    }
    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    final (minMajor, minMinor) = _minimumIosVersion;
    return major < minMajor || (major == minMajor && minor < minMinor);
  }

  static String? _originOf(String? url) {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      return null;
    }
    return uri.origin;
  }

  static String? _text(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value is String ? value : '$value';
    return text.isEmpty ? null : text;
  }

  static String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}
