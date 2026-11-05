import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../checkout/checkout_url_matcher.dart';
import 'hosted_kyc_session.dart';
import 'kyc_bridge_script.dart';
import 'kyc_models.dart';

/// Banxa hosted KYC, for verifying a customer before any order exists.
///
/// The session URL must be `https` on a Banxa-owned host and not expired,
/// otherwise [onEvent] receives [BanxaKycFailed] and nothing loads. Outcomes
/// arrive on [onEvent]; this widget never pops itself. Dispose it before the
/// flow ends and you get [BanxaKycDismissed].
///
/// The flow captures documents and liveness video, so the host app must
/// declare camera and microphone usage (see the README).
class BanxaHostedKycView extends StatefulWidget {
  const BanxaHostedKycView({
    super.key,
    required this.session,
    required this.onEvent,
    this.returnUrl,
    this.allowedOrigins = const [],
    @visibleForTesting this.loadTimeout,
  });

  final KycSession session;
  final ValueChanged<BanxaKycEvent> onEvent;

  /// The `returnUrl` the session was created with.
  final String? returnUrl;

  /// Extra origins trusted on top of the session URL's own.
  final List<String> allowedOrigins;

  /// Override for tests. Defaults to [CheckoutUrlMatcher.loadTimeout].
  final Duration? loadTimeout;

  @override
  State<BanxaHostedKycView> createState() => _BanxaHostedKycViewState();
}

class _BanxaHostedKycViewState extends State<BanxaHostedKycView> {
  WebViewController? _controller;
  late final HostedKycSession _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _session = HostedKycSession(
      session: widget.session,
      returnUrl: widget.returnUrl,
      allowedOrigins: widget.allowedOrigins,
      onEvent: (event) => widget.onEvent(event),
      loadTimeout: widget.loadTimeout ?? CheckoutUrlMatcher.loadTimeout,
    );

    final failure = _session.preflight(
      iosVersion: Platform.isIOS ? Platform.operatingSystemVersion : null,
    );
    if (failure != null) {
      _loading = false;
      // Deferred past this build so the app can setState in onEvent.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _session.finish(BanxaKycFailed(failure)),
      );
      return;
    }

    _session.startTimeout();
    _controller = _createController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        kycBridgeChannelName,
        onMessageReceived: (message) =>
            _session.handleBridgeMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              _session.handleNavigation(
                request.url,
                isMainFrame: request.isMainFrame,
              )
                  ? NavigationDecision.prevent
                  : NavigationDecision.navigate,
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) {
              _session.handleNavigation(url, isMainFrame: true);
            }
          },
          onPageStarted: (_) => _setLoading(true),
          onPageFinished: _onPageFinished,
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              _setLoading(false);
              _session.finish(
                BanxaKycFailed(
                  BanxaKycFailureReason.loadFailed,
                  code: '${error.errorCode}',
                  message: error.description,
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.session.redirectUrl));
  }

  WebViewController _createController() {
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: _onPermissionRequest,
    );
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
    return controller;
  }

  Future<void> _onPermissionRequest(WebViewPermissionRequest request) async {
    final currentUrl = await _controller?.currentUrl();
    if (_session.shouldGrantPermission(
      currentUrl: currentUrl,
      types: request.types,
    )) {
      await request.grant();
    } else {
      await request.deny();
    }
  }

  Future<void> _onPageFinished(String url) async {
    _session.cancelTimeout();
    _setLoading(false);
    if (_session.isAcceptedUrl(url)) {
      await _controller?.runJavaScript(
        kycBridgeScript(nonce: _session.nonce),
      );
    }
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
