import Foundation

/// Maps Banxa partner-api `paymentMethodId` values to Primer Drop-In type strings.
enum PaymentMethodMapper {
  static func primerType(forBanxaPaymentMethodId id: String) -> String {
    switch id.lowercased() {
    case "debit-credit-card", "credit-card", "card", "primercc":
      return "PAYMENT_CARD"
    case "apple-pay":
      return "APPLE_PAY"
    case "google-pay":
      return "GOOGLE_PAY"
    case "paypal":
      return "PAYPAL"
    case "klarna", "klarna-paynow":
      return "KLARNA"
    default:
      // Pass through already-Primer values (e.g. PAYMENT_CARD).
      return id
    }
  }
}
