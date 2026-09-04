import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;

import 'api/banxa_api_client.dart';
import 'api/parsers.dart';
import 'checkout/checkout_event_hub.dart';
import 'checkout/checkout_launch.dart';
import 'checkout/checkout_url_matcher.dart';
import 'sdk_state.dart';

/// App-facing Banxa payments API.
///
/// Call [configure] once per process, fetch catalog data, then [startPayment]
/// and subscribe to [checkoutEvents] for completed / failed / dismissed.
///
/// All partner-api traffic is issued from Dart, so it shows up in the DevTools
/// network view and can be intercepted by supplying your own [http.Client].
class BanxaPayments {
  BanxaPayments._();

  static BanxaApiClient get _api =>
      BanxaSdkState.client ?? (throw const SdkNotConfiguredException());

  /// Supply [httpClient] to intercept, log or mock partner-api traffic.
  ///
  /// Throws [MissingCredentialsException] if [BanxaConfig.apiKey] or
  /// [BanxaConfig.partnerId] is blank. Native configure failures surface as
  /// [CheckoutFailedException] or [UnknownException].
  static Future<void> configure(
    BanxaConfig config, {
    http.Client? httpClient,
  }) async {
    final missing = <String>[
      if (config.apiKey.trim().isEmpty) 'apiKey',
      if (config.partnerId.trim().isEmpty) 'partnerId',
    ];
    if (missing.isNotEmpty) {
      throw MissingCredentialsException(missing);
    }

    BanxaSdkState.client?.close();
    BanxaSdkState.client = BanxaApiClient(config: config, httpClient: httpClient);
    await BanxaPaymentsPlatform.instance.configureCheckout(
      applePayMerchantIdentifier: config.applePayMerchantIdentifier,
      applePayMerchantName: config.applePayMerchantName,
    );
    BanxaCheckoutEventHub.instance.attachPlatform();
  }

  /// Completed / failed / dismissed outcomes from native Primer checkout and
  /// from [BanxaHostedCheckoutView].
  static Stream<BanxaCheckoutEvent> get checkoutEvents =>
      BanxaCheckoutEventHub.instance.stream;

  /// `GET /countries`.
  ///
  /// Throws [SdkNotConfiguredException], [UnauthorizedException],
  /// [ValidationException], [ServerException], [NetworkException], or
  /// [UnknownException].
  static Future<List<Country>> fetchCountries() async =>
      parseCountries(await _api.get('/countries'));

  /// `GET /fiats/{buy|sell}`.
  ///
  /// Throws [SdkNotConfiguredException], [UnauthorizedException],
  /// [ValidationException], [ServerException], [NetworkException], or
  /// [UnknownException].
  static Future<List<Fiat>> fetchFiats({required OrderType orderType}) async =>
      parseFiats(await _api.get('/fiats/${orderType.wireValue}'));

  /// `GET /crypto/{buy|sell}`.
  ///
  /// Throws [SdkNotConfiguredException], [UnauthorizedException],
  /// [ValidationException], [ServerException], [NetworkException], or
  /// [UnknownException].
  static Future<List<Crypto>> fetchCrypto({
    required OrderType orderType,
  }) async =>
      parseCrypto(await _api.get('/crypto/${orderType.wireValue}'));

  /// `GET /payment-methods/{buy|sell}`.
  ///
  /// Throws [SdkNotConfiguredException], [UnauthorizedException],
  /// [ValidationException], [ServerException], [NetworkException], or
  /// [UnknownException].
  static Future<List<PaymentMethod>> fetchPaymentMethods({
    required OrderType orderType,
    String? fiat,
  }) async =>
      parsePaymentMethods(
        await _api.get(
          '/payment-methods/${orderType.wireValue}',
          query: {'fiat': fiat},
        ),
      );

  /// `GET /quotes/{buy|sell}`.
  ///
  /// Throws [SdkNotConfiguredException], [UnauthorizedException],
  /// [ValidationException], [ServerException], [NetworkException], or
  /// [UnknownException].
  static Future<List<Quote>> fetchQuotes({
    required OrderType orderType,
    required QuoteRequest request,
  }) async =>
      parseQuotes(
        await _api.get(
          '/quotes/${orderType.wireValue}',
          query: quoteQuery(request),
        ),
      );

  /// `POST /eligibility`. Optional pre-check; [startPayment] does not call it.
  ///
  /// Throws [SdkNotConfiguredException], [ValidationException],
  /// [UnauthorizedException], [ServerException], [NetworkException], or
  /// [UnknownException].
  static Future<EligibilityResponse> checkEligibility(
    CreateOrderRequest request,
  ) async =>
      parseEligibility(
        await _api.post('/eligibility', createOrderBody(request)),
      );

  /// `POST /buy` or `POST /sell` without presenting checkout.
  ///
  /// Throws [SdkNotConfiguredException], [ValidationException],
  /// [UnauthorizedException], [ServerException], [NetworkException], or
  /// [UnknownException].
  static Future<CreateOrderResponse> createOrder(
    CreateOrderRequest request,
  ) async =>
      parseOrder(
        await _api.post(orderPath(request.orderType), createOrderBody(request)),
      );

  /// Creates the order and launches checkout.
  ///
  /// Returns [BanxaPrimerCheckoutLaunched] once native Primer has been
  /// presented, or [BanxaHostedCheckoutRequired] when the app must show
  /// [BanxaHostedCheckoutView] — either because the order has no
  /// `nativeToken`, or because the payment method cannot run on this device.
  /// Throws [NativeCheckoutNotEligibleException] when neither route is
  /// available, or the hosted URL is not `https` on a Banxa host.
  /// Also throws the same HTTP exceptions as [createOrder].
  static Future<BanxaCheckoutLaunch> startPayment(
    CreateOrderRequest request,
  ) async {
    final body = createOrderBody(request);
    final order = parseOrder(
      await _api.post(orderPath(request.orderType), body),
    );

    final token = order.nativeToken;
    final paymentMethodId = request.paymentMethodId;
    String? unavailableNativeMethod;

    if (token != null &&
        token.isNotEmpty &&
        paymentMethodId != null &&
        paymentMethodId.isNotEmpty) {
      final platform = BanxaPaymentsPlatform.instance;
      if (await platform.isNativePaymentMethodAvailable(paymentMethodId)) {
        await platform.presentPrimerCheckout(
          clientToken: token,
          paymentMethodId: paymentMethodId,
        );
        return BanxaPrimerCheckoutLaunched(order);
      }
      unavailableNativeMethod = paymentMethodId;
    }

    final checkoutUrl = order.checkoutUrl;
    if (checkoutUrl != null &&
        CheckoutUrlMatcher.isAllowedInitialCheckoutUrl(checkoutUrl)) {
      return BanxaHostedCheckoutRequired(
        order,
        checkoutUrl: checkoutUrl,
        redirectUrl: request.redirectUrl,
      );
    }

    throw NativeCheckoutNotEligibleException(
      unavailableNativeMethod == null
          ? null
          : '$unavailableNativeMethod cannot be presented on this device '
              'and the order has no usable Banxa checkoutUrl to fall back to.',
    );
  }

  /// Optional mid-flow Primer session patch (`POST /primer/session`).
  ///
  /// Throws [SdkNotConfiguredException], [UnauthorizedException],
  /// [ValidationException], [ServerException], [NetworkException], or
  /// [UnknownException].
  static Future<void> updatePrimerSession({
    required String primerToken,
    required bool savedCard,
    Map<String, String>? additionalFields,
  }) =>
      _api.postExpectingEmpty('/primer/session', {
        'primerToken': primerToken,
        'savedCard': savedCard,
        ...?additionalFields,
      });
}
