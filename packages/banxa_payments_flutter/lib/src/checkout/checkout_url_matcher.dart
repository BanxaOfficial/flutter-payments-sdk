import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';

/// Terminal states Banxa hosted checkout signals through navigation URLs.
enum CheckoutOutcome { completed, failed, cancelled, none }

/// Hosted-checkout URL policy: Banxa hosts for the initial load, https for
/// in-flow redirects (3DS / wallets), path-segment outcomes only on Banxa
/// hosts or the partner [redirectUrl].
abstract final class CheckoutUrlMatcher {
  static const Duration loadTimeout = Duration(seconds: 30);

  static const _banxaHosts = <String>{
    'banxa.com',
    'banxa-sandbox.com',
    'banxa-preprod.com',
  };

  /// True when [url] is https on a Banxa-owned host. Used for the first load.
  static bool isAllowedInitialCheckoutUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !_isHttps(uri) || uri.host.isEmpty) {
      return false;
    }
    return isBanxaHost(uri.host);
  }

  /// In-flow navigations: https only. Bank ACS / PayPal hosts must be allowed
  /// or 3DS breaks. `http` and non-URL schemes are blocked.
  static bool allowNavigation(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && _isHttps(uri);
  }

  static bool isBanxaHost(String host) {
    final value = host.toLowerCase();
    for (final root in _banxaHosts) {
      if (value == root || value.endsWith('.$root')) {
        return true;
      }
    }
    return false;
  }

  static CheckoutOutcome outcome(String url, {String? redirectUrl}) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return CheckoutOutcome.none;
    }

    if (_matchesRedirect(uri, redirectUrl)) {
      return CheckoutOutcome.completed;
    }

    if (!isBanxaHost(uri.host)) {
      return CheckoutOutcome.none;
    }

    final segments = uri.pathSegments.map((s) => s.toLowerCase()).toList();
    if (segments.contains('status')) {
      return CheckoutOutcome.completed;
    }
    if (segments.contains('error') || segments.contains('failure')) {
      return CheckoutOutcome.failed;
    }
    if (segments.contains('cancel')) {
      return CheckoutOutcome.cancelled;
    }
    return CheckoutOutcome.none;
  }

  /// Typed completion payload from query parameters only (no raw URL).
  static BanxaCheckoutCompleted completedFromUrl(String url) {
    final parsed = Uri.tryParse(url);
    return BanxaCheckoutCompleted.fromFields(parsed?.queryParameters ?? const {});
  }

  static bool _isHttps(Uri uri) => uri.scheme.toLowerCase() == 'https';

  static bool _matchesRedirect(Uri uri, String? redirectUrl) {
    if (redirectUrl == null || redirectUrl.isEmpty) {
      return false;
    }
    final expected = Uri.tryParse(redirectUrl);
    if (expected == null || expected.host.isEmpty) {
      return false;
    }
    if (uri.scheme.toLowerCase() != expected.scheme.toLowerCase()) {
      return false;
    }
    if (uri.host.toLowerCase() != expected.host.toLowerCase()) {
      return false;
    }
    final actualPath = uri.path.endsWith('/') && uri.path.length > 1
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    final expectedPath = expected.path.endsWith('/') && expected.path.length > 1
        ? expected.path.substring(0, expected.path.length - 1)
        : expected.path;
    return actualPath == expectedPath ||
        actualPath.startsWith('$expectedPath/');
  }
}
