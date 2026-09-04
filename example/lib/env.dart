/// Compile-time `--dart-define` / `--dart-define-from-file`.
///
/// Do not ship `.env` as a Flutter asset — that embeds keys in the binary.
/// Environment defaults to `sandbox` if unset.
class ExampleEnv {
  ExampleEnv._();

  static const apiKey = String.fromEnvironment('BANXA_API_KEY');
  static const partnerId = String.fromEnvironment('BANXA_PARTNER_ID');
  static const _definedEnvironment =
      String.fromEnvironment('BANXA_ENVIRONMENT');
  static const applePayMerchantId =
      String.fromEnvironment('BANXA_APPLE_PAY_MERCHANT_ID');
  static const applePayMerchantName =
      String.fromEnvironment('BANXA_APPLE_PAY_MERCHANT_NAME');

  static String get environmentName =>
      _definedEnvironment.isEmpty ? 'sandbox' : _definedEnvironment;
}
