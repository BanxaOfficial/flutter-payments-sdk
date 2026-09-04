import Flutter
import UIKit

/// Flutter plugin entry point. Kept `@objc public` so GeneratedPluginRegistrant can see it.
/// HostApi lives on an internal type because Pigeon Swift types are internal.
///
/// Partner-api networking happens in Dart; this plugin only presents Primer
/// and forwards checkout outcomes.
@objc(BanxaPaymentsFlutterIosPlugin)
public class BanxaPaymentsFlutterIosPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let impl = BanxaPaymentsHostApiImpl()
    BanxaPaymentsHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: impl)
    let flutterApi = BanxaPaymentsFlutterApi(binaryMessenger: registrar.messenger())
    impl.attach(flutterApi: flutterApi)
  }
}

final class BanxaPaymentsHostApiImpl: BanxaPaymentsHostApi {
  /// PrimerBridge only holds this weakly, so the plugin owns it.
  private var flutterApi: BanxaPaymentsFlutterApi?
  private var primerBridge: PrimerBridge?

  func attach(flutterApi: BanxaPaymentsFlutterApi) {
    self.flutterApi = flutterApi
    primerBridge = PrimerBridge(flutterApi: flutterApi)
  }

  func configureCheckout(
    config: CheckoutConfigMessage,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    onMain(completion) { bridge in
      bridge.configurePrimer(
        applePayMerchantIdentifier: config.applePayMerchantIdentifier,
        applePayMerchantName: config.applePayMerchantName
      )
    }
  }

  func isNativePaymentMethodAvailable(paymentMethodId: String) throws -> Bool {
    guard let primerBridge else {
      throw PigeonError(
        code: "checkout_failed",
        message: "Primer bridge is not attached",
        details: nil
      )
    }
    return primerBridge.isPaymentMethodAvailable(banxaPaymentMethodId: paymentMethodId)
  }

  func presentPrimerCheckout(
    clientToken: String,
    paymentMethodId: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    onMain(completion) { bridge in
      bridge.presentPaymentMethod(
        banxaPaymentMethodId: paymentMethodId,
        clientToken: clientToken
      )
    }
  }

  private func onMain(
    _ completion: @escaping (Result<Void, Error>) -> Void,
    _ body: @escaping (PrimerBridge) -> Void
  ) {
    DispatchQueue.main.async {
      guard let bridge = self.primerBridge else {
        completion(
          .failure(
            PigeonError(
              code: "checkout_failed",
              message: "Primer bridge is not attached",
              details: nil
            )
          )
        )
        return
      }
      body(bridge)
      completion(.success(()))
    }
  }
}
