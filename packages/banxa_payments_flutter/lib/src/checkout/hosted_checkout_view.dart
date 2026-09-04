import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'checkout_event_hub.dart';
import 'checkout_launch.dart';
import 'checkout_url_matcher.dart';
import 'hosted_checkout_session.dart';

/// Banxa hosted checkout, for orders that come back without a `nativeToken`.
///
/// The first URL must be `https` on a Banxa-owned host. Later navigations may
/// leave Banxa (3DS, wallets) but must stay on `https`. Outcomes are published
/// on [BanxaPayments.checkoutEvents]; this widget never pops itself. Dispose
/// before a terminal URL emits `dismissed`. A hung first load emits `failed`
/// after [CheckoutUrlMatcher.loadTimeout].
class BanxaHostedCheckoutView extends StatefulWidget {
  const BanxaHostedCheckoutView({
    super.key,
    required this.checkout,
    @visibleForTesting this.loadTimeout,
  });

  final BanxaHostedCheckoutRequired checkout;

  /// Override for tests. Defaults to [CheckoutUrlMatcher.loadTimeout].
  final Duration? loadTimeout;

  @override
  State<BanxaHostedCheckoutView> createState() =>
      _BanxaHostedCheckoutViewState();
}

class _BanxaHostedCheckoutViewState extends State<BanxaHostedCheckoutView> {
  WebViewController? _controller;
  late final HostedCheckoutSession _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _session = HostedCheckoutSession(
      checkout: widget.checkout,
      loadTimeout: widget.loadTimeout ?? CheckoutUrlMatcher.loadTimeout,
      onEvent: BanxaCheckoutEventHub.instance.emit,
    );

    if (!_session.isInitialUrlAllowed) {
      _loading = false;
      _session.emit(
        const BanxaCheckoutFailed('Checkout URL is not a Banxa https host'),
      );
      return;
    }

    _session.startTimeout();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_session.handleUrl(request.url)) {
              return NavigationDecision.prevent;
            }
            if (!CheckoutUrlMatcher.allowNavigation(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) {
              _session.handleUrl(url);
            }
          },
          onPageStarted: (_) => _setLoading(true),
          onPageFinished: (_) {
            _session.cancelTimeout();
            _setLoading(false);
          },
          onWebResourceError: (error) {
            _session.cancelTimeout();
            _setLoading(false);
            if (error.isForMainFrame ?? true) {
              _session.emit(const BanxaCheckoutFailed('Checkout failed'));
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkout.checkoutUrl));
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _setLoading(bool value) {
    if (mounted && _loading != value) {
      setState(() => _loading = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      children: [
        if (controller != null) WebViewWidget(controller: controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
