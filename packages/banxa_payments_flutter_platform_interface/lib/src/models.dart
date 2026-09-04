/// Shared Dart models for banxa_payments_flutter.
///
/// Field names match partner-api v2 camelCase JSON.
library;

/// Target Banxa partner-api environment.
enum BanxaEnvironment {
  sandbox,
  preprod,
  production;

  String get wireValue => name;

  static BanxaEnvironment fromWire(String value) {
    return BanxaEnvironment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError.value(value, 'environment'),
    );
  }

  /// Base host for partner-api. Path is `{host}/{partnerId}/v2`.
  String get baseHost {
    switch (this) {
      case BanxaEnvironment.sandbox:
        return 'https://api.banxa-sandbox.com';
      case BanxaEnvironment.preprod:
        return 'https://api.banxa-preprod.com';
      case BanxaEnvironment.production:
        return 'https://api.banxa.com';
    }
  }
}

/// Buy or sell order.
enum OrderType {
  buy,
  sell;

  String get wireValue => name;
}

/// Runtime credentials and environment. Supply from the host app; never bundle
/// keys in the SDK.
class BanxaConfig {
  const BanxaConfig({
    required this.apiKey,
    required this.partnerId,
    this.environment = BanxaEnvironment.sandbox,
    this.applePayMerchantIdentifier,
    this.applePayMerchantName,
  });

  final String apiKey;
  final String partnerId;
  final BanxaEnvironment environment;

  /// Apple Pay merchant identifier, e.g. `merchant.com.example`. Primer
  /// refuses Apple Pay without it, so leaving this null disables Apple Pay.
  /// Must match the app's `com.apple.developer.in-app-payments` entitlement.
  final String? applePayMerchantIdentifier;

  /// Fallback name for the Apple Pay sheet, used only when the Primer client
  /// session does not carry a merchant name.
  final String? applePayMerchantName;

  String get baseUrl => '${environment.baseHost}/$partnerId/v2';
}

/// Subdivision of a [Country].
class CountryState {
  const CountryState({required this.id, required this.description});

  final String id;
  final String description;
}

/// Catalog country.
class Country {
  const Country({
    required this.id,
    required this.description,
    this.states = const [],
  });

  final String id;
  final String description;
  final List<CountryState> states;
}

/// Payment method listed on a [Fiat].
class FiatPaymentMethod {
  const FiatPaymentMethod({
    required this.id,
    this.name,
    this.minimum,
    this.maximum,
  });

  final String id;
  final String? name;
  final String? minimum;
  final String? maximum;
}

/// Catalog fiat currency.
class Fiat {
  const Fiat({
    required this.id,
    this.description,
    this.symbol,
    this.supportedPaymentMethods = const [],
  });

  final String id;
  final String? description;
  final String? symbol;
  final List<FiatPaymentMethod> supportedPaymentMethods;
}

/// Chain on which a [Crypto] can settle.
class Blockchain {
  const Blockchain({
    required this.id,
    this.description,
    this.isDefaultBlockchain,
    this.address,
    this.network,
    this.minimum,
    this.unsupportedCountries = const {},
  });

  final String id;
  final String? description;
  final bool? isDefaultBlockchain;
  final String? address;
  final String? network;
  final String? minimum;

  /// Country -> restricted states.
  final Map<String, List<String>> unsupportedCountries;
}

/// Catalog cryptocurrency.
class Crypto {
  const Crypto({
    required this.id,
    this.description,
    this.blockchains = const [],
  });

  final String id;
  final String? description;
  final List<Blockchain> blockchains;
}

/// Catalog payment method. [id] is a Banxa slug such as `debit-credit-card`.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    this.name,
    this.description,
    this.supportedFiats = const [],
  });

  final String id;
  final String? name;
  final String? description;
  final List<String> supportedFiats;
}

/// Query for `GET /quotes/{buy|sell}`.
class QuoteRequest {
  const QuoteRequest({
    required this.paymentMethodId,
    required this.crypto,
    required this.blockchain,
    required this.fiat,
    this.fiatAmount,
    this.cryptoAmount,
    this.externalCustomerId,
    this.ipAddress,
    this.discountCode,
  });

  final String paymentMethodId;
  final String crypto;
  final String blockchain;
  final String fiat;
  final String? fiatAmount;
  final String? cryptoAmount;
  final String? externalCustomerId;
  final String? ipAddress;
  final String? discountCode;
}

/// Pre-discount amounts on a [QuoteDiscount].
class QuoteOriginalAmounts {
  const QuoteOriginalAmounts({
    this.originalCryptoAmount,
    this.originalNetworkFee,
    this.originalProcessingFee,
    this.originalFiatAmount,
  });

  final String? originalCryptoAmount;
  final String? originalNetworkFee;
  final String? originalProcessingFee;
  final String? originalFiatAmount;
}

/// Discount applied to a [Quote].
class QuoteDiscount {
  const QuoteDiscount({this.originalQuote, this.discountCode});

  final QuoteOriginalAmounts? originalQuote;
  final String? discountCode;
}

/// Price quote for a payment method / pair.
class Quote {
  const Quote({
    this.paymentMethodId,
    this.cryptoAmount,
    this.fiatAmount,
    this.processingFee,
    this.networkFee,
    this.discount,
  });

  final String? paymentMethodId;
  final String? cryptoAmount;
  final String? fiatAmount;
  final String? processingFee;
  final String? networkFee;
  final QuoteDiscount? discount;
}

/// Body for `POST /buy`, `POST /sell`, and `POST /eligibility`.
///
/// [paymentMethodId] is the catalog slug (string), matching native Banxa SDKs.
class CreateOrderRequest {
  const CreateOrderRequest({
    required this.orderType,
    required this.crypto,
    required this.fiat,
    required this.fiatAmount,
    required this.walletAddress,
    required this.email,
    required this.redirectUrl,
    this.id,
    this.paymentMethodId,
    this.blockchain,
    this.cryptoAmount,
    this.walletAddressTag,
    this.subPartnerId,
    this.metadata,
    this.externalCustomerId,
    this.externalOrderId,
    this.discountCode,
  });

  final OrderType orderType;
  final String crypto;
  final String fiat;
  final String fiatAmount;
  final String walletAddress;
  final String email;
  final String redirectUrl;
  final String? id;
  final String? paymentMethodId;
  final String? blockchain;
  final String? cryptoAmount;
  final String? walletAddressTag;
  final String? subPartnerId;
  final String? metadata;
  final String? externalCustomerId;
  final String? externalOrderId;
  final String? discountCode;
}

/// Created order, including checkout routing fields.
///
/// [paymentMethodId] is a string so it matches [CreateOrderRequest] and catalog
/// slugs. Numeric wire values are stringified.
class CreateOrderResponse {
  const CreateOrderResponse({
    required this.id,
    this.externalCustomerId,
    this.externalOrderId,
    this.orderType,
    this.fiat,
    this.fiatAmount,
    this.crypto,
    this.cryptoAmount,
    this.walletAddress,
    this.walletAddressTag,
    this.paymentMethodId,
    this.paymentMethodType,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.checkoutUrl,
    this.nativeToken,
    this.blockchain,
  });

  final String id;
  final String? externalCustomerId;
  final String? externalOrderId;
  final String? orderType;
  final String? fiat;
  final String? fiatAmount;
  final String? crypto;
  final String? cryptoAmount;
  final String? walletAddress;
  final String? walletAddressTag;
  final String? paymentMethodId;
  final String? paymentMethodType;
  final String? status;
  final String? createdAt;
  final String? updatedAt;
  final String? checkoutUrl;
  final String? nativeToken;
  final String? blockchain;
}

/// Result of `POST /eligibility`.
///
/// Use [paymentReady] and [kycRequirements] if you need to gate checkout
/// yourself. `BanxaPayments.startPayment` does not call this endpoint.
class EligibilityResponse {
  const EligibilityResponse({
    this.id,
    this.paymentReady,
    this.kycRequirements = const [],
    this.message,
  });

  final String? id;
  final bool? paymentReady;
  final List<String> kycRequirements;
  final String? message;
}

/// Checkout lifecycle event from Primer or hosted checkout.
sealed class BanxaCheckoutEvent {
  const BanxaCheckoutEvent();
}

/// Payment completed. Identifiers come from Primer or hosted-checkout query
/// parameters — never a raw URL.
class BanxaCheckoutCompleted extends BanxaCheckoutEvent {
  const BanxaCheckoutCompleted({
    this.paymentId,
    this.orderId,
    this.status,
  });

  /// Builds from Primer / query keys `paymentId`, `orderId`, `status`
  /// (and `payment_id` / `order_id` aliases). Other keys are ignored.
  factory BanxaCheckoutCompleted.fromFields(Map<String, String> fields) {
    String? pick(String key, [String? alt]) {
      final value = fields[key] ?? (alt == null ? null : fields[alt]);
      if (value == null || value.isEmpty) {
        return null;
      }
      return value;
    }

    return BanxaCheckoutCompleted(
      paymentId: pick('paymentId', 'payment_id'),
      orderId: pick('orderId', 'order_id'),
      status: pick('status'),
    );
  }

  final String? paymentId;
  final String? orderId;
  final String? status;
}

/// Payment failed. [message] is a short reason, not a URL.
class BanxaCheckoutFailed extends BanxaCheckoutEvent {
  const BanxaCheckoutFailed([this.message = 'Checkout failed']);

  final String message;
}

/// User closed checkout, or the hosted WebView was disposed before a terminal
/// URL. May also follow [BanxaCheckoutCompleted] / [BanxaCheckoutFailed].
class BanxaCheckoutDismissed extends BanxaCheckoutEvent {
  const BanxaCheckoutDismissed();
}

/// Field-level API validation error.
class FieldError {
  const FieldError({required this.field, required this.messages});

  final String field;
  final List<String> messages;
}

/// Typed failure from catalog, order, or checkout APIs.
sealed class BanxaPaymentsException implements Exception {
  const BanxaPaymentsException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// HTTP 401.
class UnauthorizedException extends BanxaPaymentsException {
  const UnauthorizedException([super.message = 'Unauthorized']);
}

/// HTTP 400 or 422.
class ValidationException extends BanxaPaymentsException {
  const ValidationException(this.errors, [String? message])
      : super(message ?? 'Validation failed');

  final List<FieldError> errors;
}

/// Other non-success HTTP status.
class ServerException extends BanxaPaymentsException {
  const ServerException(this.statusCode, [String? message])
      : super(message ?? 'Server error ($statusCode)');

  final int statusCode;
}

/// Transport failure, including TLS errors and timeouts.
class NetworkException extends BanxaPaymentsException {
  const NetworkException([super.message = 'Network error']);
}

/// [BanxaConfig.apiKey] or [BanxaConfig.partnerId] was blank.
class MissingCredentialsException extends BanxaPaymentsException {
  MissingCredentialsException(this.fields)
      : super('Missing credentials: ${fields.join(', ')}');

  final List<String> fields;
}

/// A catalog or checkout method was called before `BanxaPayments.configure`.
class SdkNotConfiguredException extends BanxaPaymentsException {
  const SdkNotConfiguredException()
      : super('BanxaPayments.configure must be called first');
}

/// Native Primer presentation failed.
class CheckoutFailedException extends BanxaPaymentsException {
  const CheckoutFailedException([String? reason])
      : super(reason ?? 'Checkout failed');
}

/// Order has no usable native Primer path and no valid hosted `checkoutUrl`.
class NativeCheckoutNotEligibleException extends BanxaPaymentsException {
  const NativeCheckoutNotEligibleException([String? reason])
      : super(
          reason ??
              'Order is not eligible for native or hosted checkout '
                  '(nativeToken and checkoutUrl are both missing).',
        );
}

/// Unexpected local failure (for example JSON decode).
class UnknownException extends BanxaPaymentsException {
  const UnknownException(super.message);
}
