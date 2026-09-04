import 'dart:async';

import 'package:banxa_payments_flutter/banxa_payments_flutter.dart';
import 'package:flutter/material.dart';

/// Hosts [BanxaHostedCheckoutView] for orders without a `nativeToken`.
///
/// The SDK only reports outcomes; closing the route is the app's job, so this
/// screen pops itself once checkout reaches a terminal state.
class HostedCheckoutScreen extends StatefulWidget {
  const HostedCheckoutScreen({super.key, required this.checkout});

  final BanxaHostedCheckoutRequired checkout;

  @override
  State<HostedCheckoutScreen> createState() => _HostedCheckoutScreenState();
}

class _HostedCheckoutScreenState extends State<HostedCheckoutScreen> {
  StreamSubscription<BanxaCheckoutEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = BanxaPayments.checkoutEvents.listen((event) {
      // `dismissed` is what this route emits on its way out; ignore it here.
      if (event is BanxaCheckoutDismissed || !mounted) {
        return;
      }
      Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: BanxaHostedCheckoutView(checkout: widget.checkout),
    );
  }
}
