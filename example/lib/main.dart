import 'dart:async';

import 'package:banxa_payments_flutter/banxa_payments_flutter.dart';
import 'package:banxa_payments_flutter_example/env.dart';
import 'package:banxa_payments_flutter_example/hosted_checkout_screen.dart';
import 'package:flutter/material.dart';

/// Credentials: `--dart-define=BANXA_*` or `--dart-define-from-file=.env`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BanxaExampleApp());
}

class BanxaExampleApp extends StatelessWidget {
  const BanxaExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Banxa Payments Example',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _log = <String>[];
  StreamSubscription<BanxaCheckoutEvent>? _sub;
  bool _configured = false;
  bool _busy = false;
  OrderType _orderType = OrderType.buy;

  final _fiat = TextEditingController(text: 'USD');
  final _crypto = TextEditingController(text: 'ETH');
  final _blockchain = TextEditingController(text: 'ETH');
  final _fiatAmount = TextEditingController(text: '50');
  final _cryptoAmount = TextEditingController();
  final _paymentMethodId = TextEditingController(text: 'debit-credit-card');
  final _walletAddress =
      TextEditingController(text: '0x0000000000000000000000000000000000000000');
  final _walletAddressTag = TextEditingController();
  final _email = TextEditingController(text: 'example@banxa.com');
  final _redirectUrl =
      TextEditingController(text: 'https://example.com/redirect');
  final _id = TextEditingController();
  final _externalCustomerId = TextEditingController();
  final _externalOrderId = TextEditingController();
  final _subPartnerId = TextEditingController();
  final _discountCode = TextEditingController();
  final _metadata = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sub = BanxaPayments.checkoutEvents.listen((event) {
      setState(() {
        switch (event) {
          case BanxaCheckoutCompleted(
              :final paymentId,
              :final orderId,
              :final status
            ):
            _log.add(
              'completed paymentId=$paymentId orderId=$orderId status=$status',
            );
          case BanxaCheckoutFailed(:final message):
            _log.add('failed: $message');
          case BanxaCheckoutDismissed():
            _log.add('dismissed');
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _fiat.dispose();
    _crypto.dispose();
    _blockchain.dispose();
    _fiatAmount.dispose();
    _cryptoAmount.dispose();
    _paymentMethodId.dispose();
    _walletAddress.dispose();
    _walletAddressTag.dispose();
    _email.dispose();
    _redirectUrl.dispose();
    _id.dispose();
    _externalCustomerId.dispose();
    _externalOrderId.dispose();
    _subPartnerId.dispose();
    _discountCode.dispose();
    _metadata.dispose();
    super.dispose();
  }

  BanxaEnvironment get _environment =>
      BanxaEnvironment.fromWire(ExampleEnv.environmentName);

  Future<void> _configure() async {
    if (ExampleEnv.apiKey.isEmpty || ExampleEnv.partnerId.isEmpty) {
      setState(() {
        _log.add(
          'Missing BANXA_API_KEY / BANXA_PARTNER_ID. '
          'Pass --dart-define or --dart-define-from-file=.env.',
        );
      });
      return;
    }
    try {
      await BanxaPayments.configure(
        BanxaConfig(
          apiKey: ExampleEnv.apiKey,
          partnerId: ExampleEnv.partnerId,
          environment: _environment,
          applePayMerchantIdentifier: _optionalValue(
            ExampleEnv.applePayMerchantId,
          ),
          applePayMerchantName: _optionalValue(
            ExampleEnv.applePayMerchantName,
          ),
        ),
      );
      setState(() {
        _configured = true;
        _log.add('configured (${_environment.name})');
      });
    } catch (e) {
      setState(() => _log.add('configure error: $e'));
    }
  }

  Future<void> _fetchCountries() async {
    try {
      final countries = await BanxaPayments.fetchCountries();
      setState(() => _log.add('countries: ${countries.length}'));
    } catch (e) {
      setState(() => _log.add('fetchCountries error: $e'));
    }
  }

  Future<void> _fetchFiats() async {
    try {
      final fiats = await BanxaPayments.fetchFiats(orderType: _orderType);
      setState(() => _log.add('fiats: ${fiats.length}'));
    } catch (e) {
      setState(() => _log.add('fetchFiats error: $e'));
    }
  }

  CreateOrderRequest _orderRequest() {
    return CreateOrderRequest(
      orderType: _orderType,
      crypto: _crypto.text.trim(),
      fiat: _fiat.text.trim(),
      fiatAmount: _fiatAmount.text.trim(),
      walletAddress: _walletAddress.text.trim(),
      email: _email.text.trim(),
      redirectUrl: _redirectUrl.text.trim(),
      paymentMethodId: _optional(_paymentMethodId),
      blockchain: _optional(_blockchain),
      cryptoAmount: _optional(_cryptoAmount),
      walletAddressTag: _optional(_walletAddressTag),
      id: _optional(_id),
      externalCustomerId: _optional(_externalCustomerId),
      externalOrderId: _optional(_externalOrderId),
      subPartnerId: _optional(_subPartnerId),
      discountCode: _optional(_discountCode),
      metadata: _optional(_metadata),
    );
  }

  static String? _optional(TextEditingController controller) =>
      _optionalValue(controller.text);

  static String? _optionalValue(String raw) {
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _startPayment() async {
    setState(() => _busy = true);
    try {
      final launch = await BanxaPayments.startPayment(_orderRequest());
      switch (launch) {
        case BanxaPrimerCheckoutLaunched():
          setState(
            () => _log.add('primer presented for order ${launch.order.id}'),
          );
        case BanxaHostedCheckoutRequired():
          setState(
            () => _log.add('hosted checkout for order ${launch.order.id}'),
          );
          await _showHostedCheckout(launch);
      }
    } catch (e) {
      setState(() => _log.add('startPayment error: $e'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showHostedCheckout(BanxaHostedCheckoutRequired checkout) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HostedCheckoutScreen(checkout: checkout),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banxa Payments')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(
            _configured ? 'SDK configured' : 'SDK not configured',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _configure,
            child: const Text('Configure'),
          ),
          FilledButton(
            onPressed: _configured ? _fetchCountries : null,
            child: const Text('Fetch countries'),
          ),
          FilledButton(
            onPressed: _configured ? _fetchFiats : null,
            child: const Text('Fetch fiats'),
          ),
          const SizedBox(height: 16),
          Text('Order', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<OrderType>(
            segments: const [
              ButtonSegment(value: OrderType.buy, label: Text('Buy')),
              ButtonSegment(value: OrderType.sell, label: Text('Sell')),
            ],
            selected: {_orderType},
            onSelectionChanged: (value) {
              setState(() => _orderType = value.first);
            },
          ),
          _field(_fiat, 'Fiat', 'USD'),
          _field(_crypto, 'Crypto', 'ETH'),
          _field(_blockchain, 'Blockchain', 'ETH'),
          _field(_fiatAmount, 'Fiat amount', '50', keyboard: TextInputType.number),
          _field(_cryptoAmount, 'Crypto amount (optional)', '0.01'),
          _field(_paymentMethodId, 'Payment method ID', 'debit-credit-card'),
          _field(_walletAddress, 'Wallet address', '0x…'),
          _field(_walletAddressTag, 'Wallet address tag (optional)', ''),
          _field(_email, 'Email', 'user@example.com', keyboard: TextInputType.emailAddress),
          _field(_redirectUrl, 'Redirect URL', 'https://example.com/redirect'),
          ExpansionTile(
            title: const Text('Optional identifiers'),
            children: [
              _field(_id, 'Order id', ''),
              _field(_externalCustomerId, 'External customer id', ''),
              _field(_externalOrderId, 'External order id', ''),
              _field(_subPartnerId, 'Sub-partner id', ''),
              _field(_discountCode, 'Discount code', ''),
              _field(_metadata, 'Metadata', ''),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _configured && !_busy ? _startPayment : null,
            child: Text(_busy ? 'Starting…' : 'Start payment'),
          ),
          const SizedBox(height: 16),
          Text('Event log', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._log.reversed.map((line) => Text(line)),
        ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        enabled: _configured,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
