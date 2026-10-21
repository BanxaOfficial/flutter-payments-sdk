import 'package:banxa_payments_flutter/banxa_payments_flutter.dart';
import 'package:flutter/material.dart';

/// Hosts [BanxaHostedKycView] for a session created up front.
///
/// The SDK only reports outcomes; closing the route is the app's job, so this
/// screen pops itself once the flow completes or fails. On Android, grant the
/// camera and microphone runtime permissions before opening it, or document
/// capture fails inside the page.
class HostedKycScreen extends StatelessWidget {
  const HostedKycScreen({
    super.key,
    required this.session,
    required this.onEvent,
    this.returnUrl,
  });

  final KycSession session;
  final String? returnUrl;
  final ValueChanged<BanxaKycEvent> onEvent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify identity'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: BanxaHostedKycView(
        session: session,
        returnUrl: returnUrl,
        onEvent: (event) {
          onEvent(event);
          final ends = event is BanxaKycCompleted ||
              (event is BanxaKycFailed &&
                  event.reason != BanxaKycFailureReason.flowError);
          if (ends) {
            Navigator.of(context).maybePop();
          }
        },
      ),
    );
  }
}
