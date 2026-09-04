import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';

/// Wire (partner-api v2 camelCase JSON) -> Dart models.

List<Country> parseCountries(dynamic json) =>
    _list(json).map(_country).toList();

List<Fiat> parseFiats(dynamic json) => _list(json).map(_fiat).toList();

List<Crypto> parseCrypto(dynamic json) => _list(json).map(_crypto).toList();

List<PaymentMethod> parsePaymentMethods(dynamic json) =>
    _list(json).map(_paymentMethod).toList();

/// The quotes endpoint may return a single object or an array.
List<Quote> parseQuotes(dynamic json) {
  if (json is List) {
    return _list(json).map(_quote).toList();
  }
  if (json is Map) {
    return [_quote(json.cast<String, dynamic>())];
  }
  return const [];
}

EligibilityResponse parseEligibility(dynamic json) {
  final map = _map(json);
  return EligibilityResponse(
    id: _string(map['id']),
    paymentReady: map['paymentReady'] is bool ? map['paymentReady'] as bool : null,
    kycRequirements: _stringList(map['kycRequirements']),
    message: _string(map['message']),
  );
}

CreateOrderResponse parseOrder(dynamic json) {
  final map = _map(json);
  return CreateOrderResponse(
    id: _string(map['id']) ?? '',
    externalCustomerId: _string(map['externalCustomerId']),
    externalOrderId: _string(map['externalOrderId']),
    orderType: _string(map['orderType']),
    fiat: _string(map['fiat']),
    fiatAmount: _string(map['fiatAmount']),
    crypto: _string(map['crypto']),
    cryptoAmount: _string(map['cryptoAmount']),
    walletAddress: _string(map['walletAddress']),
    walletAddressTag: _string(map['walletAddressTag']),
    paymentMethodId: _string(map['paymentMethodId']),
    paymentMethodType: _string(map['paymentMethodType']),
    status: _string(map['status']),
    createdAt: _string(map['createdAt']),
    updatedAt: _string(map['updatedAt']),
    checkoutUrl: _string(map['checkoutUrl']),
    nativeToken: _string(map['nativeToken']),
    blockchain: _string(map['blockchain']),
  );
}

/// Shared body for POST /buy, POST /sell and POST /eligibility.
Map<String, dynamic> createOrderBody(CreateOrderRequest request) {
  final missing = <FieldError>[
    if (request.crypto.trim().isEmpty)
      const FieldError(field: 'crypto', messages: ['required']),
    if (request.fiat.trim().isEmpty)
      const FieldError(field: 'fiat', messages: ['required']),
    if (request.fiatAmount.trim().isEmpty)
      const FieldError(field: 'fiatAmount', messages: ['required']),
    if (request.walletAddress.trim().isEmpty)
      const FieldError(field: 'walletAddress', messages: ['required']),
    if (request.email.trim().isEmpty)
      const FieldError(field: 'email', messages: ['required']),
    if (request.redirectUrl.trim().isEmpty)
      const FieldError(field: 'redirectUrl', messages: ['required']),
  ];
  if (missing.isNotEmpty) {
    throw ValidationException(missing, 'Missing required order fields');
  }

  return {
    'crypto': request.crypto,
    'fiat': request.fiat,
    'fiatAmount': request.fiatAmount,
    'walletAddress': request.walletAddress,
    'email': request.email,
    'redirectUrl': request.redirectUrl,
    if (request.id != null) 'id': request.id,
    if (request.paymentMethodId != null)
      'paymentMethodId': request.paymentMethodId,
    if (request.blockchain != null) 'blockchain': request.blockchain,
    if (request.cryptoAmount != null) 'cryptoAmount': request.cryptoAmount,
    if (request.walletAddressTag != null)
      'walletAddressTag': request.walletAddressTag,
    if (request.subPartnerId != null) 'subPartnerId': request.subPartnerId,
    if (request.metadata != null) 'metadata': request.metadata,
    if (request.externalCustomerId != null)
      'externalCustomerId': request.externalCustomerId,
    if (request.externalOrderId != null)
      'externalOrderId': request.externalOrderId,
    if (request.discountCode != null) 'discountCode': request.discountCode,
  };
}

Map<String, String?> quoteQuery(QuoteRequest request) => {
      'paymentMethodId': request.paymentMethodId,
      'crypto': request.crypto,
      'blockchain': request.blockchain,
      'fiat': request.fiat,
      'fiatAmount': request.fiatAmount,
      'cryptoAmount': request.cryptoAmount,
      'externalCustomerId': request.externalCustomerId,
      'ipAddress': request.ipAddress,
      'discountCode': request.discountCode,
    };

String orderPath(OrderType orderType) =>
    orderType == OrderType.sell ? '/sell' : '/buy';

Country _country(Map<String, dynamic> map) => Country(
      id: _string(map['id']) ?? '',
      description: _string(map['description']) ?? '',
      states: _list(map['states'])
          .map(
            (s) => CountryState(
              id: _string(s['id']) ?? '',
              description: _string(s['description']) ?? '',
            ),
          )
          .toList(),
    );

Fiat _fiat(Map<String, dynamic> map) => Fiat(
      id: _string(map['id']) ?? '',
      description: _string(map['description']),
      symbol: _string(map['symbol']),
      supportedPaymentMethods: _list(map['supportedPaymentMethods'])
          .map(
            (p) => FiatPaymentMethod(
              id: _string(p['id']) ?? '',
              name: _string(p['name']),
              minimum: _string(p['minimum']),
              maximum: _string(p['maximum']),
            ),
          )
          .toList(),
    );

Crypto _crypto(Map<String, dynamic> map) => Crypto(
      id: _string(map['id']) ?? '',
      description: _string(map['description']),
      blockchains: _list(map['blockchains']).map(_blockchain).toList(),
    );

Blockchain _blockchain(Map<String, dynamic> map) {
  final unsupported = map['unsupportedCountries'];
  return Blockchain(
    id: _string(map['id']) ?? '',
    description: _string(map['description']),
    isDefaultBlockchain: map['isDefaultBlockchain'] is bool
        ? map['isDefaultBlockchain'] as bool
        : null,
    address: _string(map['address']),
    network: _string(map['network']),
    minimum: _string(map['minimum']),
    unsupportedCountries: unsupported is Map
        ? {
            for (final entry in unsupported.entries)
              '${entry.key}': _stringList(entry.value),
          }
        : const {},
  );
}

PaymentMethod _paymentMethod(Map<String, dynamic> map) => PaymentMethod(
      id: _string(map['id']) ?? '',
      name: _string(map['name']),
      description: _string(map['description']),
      supportedFiats: _stringList(map['supportedFiats']),
    );

Quote _quote(Map<String, dynamic> map) {
  final discount = map['discount'];
  return Quote(
    paymentMethodId: _string(map['paymentMethodId']),
    cryptoAmount: _string(map['cryptoAmount']),
    fiatAmount: _string(map['fiatAmount']),
    processingFee: _string(map['processingFee']),
    networkFee: _string(map['networkFee']),
    discount: discount is Map ? _discount(discount.cast<String, dynamic>()) : null,
  );
}

QuoteDiscount _discount(Map<String, dynamic> map) {
  final original = map['originalQuote'];
  return QuoteDiscount(
    discountCode: _string(map['discountCode']),
    originalQuote: original is Map
        ? _originalAmounts(original.cast<String, dynamic>())
        : null,
  );
}

QuoteOriginalAmounts _originalAmounts(Map<String, dynamic> map) =>
    QuoteOriginalAmounts(
      originalCryptoAmount: _string(map['originalCryptoAmount']),
      // Wire key is misspelled `orginalNetworkFee` in partner-api.
      originalNetworkFee:
          _string(map['orginalNetworkFee']) ?? _string(map['originalNetworkFee']),
      originalProcessingFee: _string(map['originalProcessingFee']),
      originalFiatAmount: _string(map['originalFiatAmount']),
    );

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

List<String> _stringList(dynamic value) =>
    value is List ? value.whereType<String>().toList() : const [];

String? _string(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value is String ? value : '$value';
  return text.isEmpty ? null : text;
}
