import Foundation
import PassKit
import PrimerCore
import PrimerSDK

/// Bridges Primer iOS SDK 2.49.0 delegate callbacks to BanxaPaymentsFlutterApi.
final class PrimerBridge: NSObject, PrimerDelegate {
  private weak var flutterApi: BanxaPaymentsFlutterApi?
  private let callbackQueue = DispatchQueue.main
  private var applePayMerchantIdentifier: String?

  init(flutterApi: BanxaPaymentsFlutterApi?) {
    self.flutterApi = flutterApi
  }

  func updateFlutterApi(_ api: BanxaPaymentsFlutterApi?) {
    flutterApi = api
  }

  func configurePrimer(applePayMerchantIdentifier: String?, applePayMerchantName: String?) {
    let merchantIdentifier = applePayMerchantIdentifier?.isEmpty == false
      ? applePayMerchantIdentifier
      : nil
    self.applePayMerchantIdentifier = merchantIdentifier

    let applePayOptions = merchantIdentifier.map {
      PrimerApplePayOptions(merchantIdentifier: $0, merchantName: applePayMerchantName)
    }
    let settings = PrimerSettings(
      paymentMethodOptions: PrimerPaymentMethodOptions(applePayOptions: applePayOptions)
    )
    Primer.shared.configure(settings: settings, delegate: self)
  }

  /// Primer drops Apple Pay from the session when the device cannot pay, so
  /// presenting it would fail with an opaque error. Checking up front lets
  /// Dart fall back to hosted checkout.
  func isPaymentMethodAvailable(banxaPaymentMethodId: String) -> Bool {
    guard PaymentMethodMapper.primerType(forBanxaPaymentMethodId: banxaPaymentMethodId)
      == "APPLE_PAY"
    else {
      return true
    }
    return applePayMerchantIdentifier != nil && PKPaymentAuthorizationController.canMakePayments()
  }

  func presentPaymentMethod(banxaPaymentMethodId: String, clientToken: String) {
    let primerType = PaymentMethodMapper.primerType(forBanxaPaymentMethodId: banxaPaymentMethodId)
    Primer.shared.showPaymentMethod(
      primerType,
      intent: .checkout,
      clientToken: clientToken
    )
  }

  // MARK: - PrimerDelegate

  func primerDidCompleteCheckoutWithData(_ data: PrimerCheckoutData) {
    var payload: [String?: String?] = [:]
    if let paymentId = data.payment?.id {
      payload["paymentId"] = paymentId
    }
    if let orderId = data.payment?.orderId {
      payload["orderId"] = orderId
    }
    if let status = data.payment?.status {
      payload["status"] = status
    }
    emit(CheckoutEventMessage(type: "completed", errorMessage: nil, data: payload))
    Primer.shared.dismiss()
  }

  func primerDidFailWithError(
    _ error: Error,
    data: PrimerCheckoutData?,
    decisionHandler: @escaping ((PrimerErrorDecision) -> Void)
  ) {
    emit(
      CheckoutEventMessage(
        type: "failed",
        errorMessage: error.localizedDescription,
        data: nil
      )
    )
    decisionHandler(.fail(withErrorMessage: nil))
    Primer.shared.dismiss()
  }

  func primerDidDismiss() {
    emit(CheckoutEventMessage(type: "dismissed", errorMessage: nil, data: nil))
  }

  private func emit(_ event: CheckoutEventMessage) {
    callbackQueue.async { [weak self] in
      self?.flutterApi?.onCheckoutEvent(event: event) { _ in }
    }
  }
}
