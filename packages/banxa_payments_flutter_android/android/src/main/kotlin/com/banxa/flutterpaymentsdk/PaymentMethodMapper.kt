package com.banxa.flutterpaymentsdk

/**
 * Maps Banxa partner-api `paymentMethodId` values to Primer type identifiers.
 *
 * Android Primer Checkout 3.x presents methods from the client session; the
 * mapped type is still useful for logging / future show-method APIs and for
 * parity with the iOS Drop-In path.
 */
object PaymentMethodMapper {
  fun primerType(banxaPaymentMethodId: String): String =
    when (banxaPaymentMethodId.lowercase()) {
      "debit-credit-card", "credit-card", "card", "primercc" -> "PAYMENT_CARD"
      "apple-pay" -> "APPLE_PAY"
      "google-pay" -> "GOOGLE_PAY"
      "paypal" -> "PAYPAL"
      "klarna", "klarna-paynow" -> "KLARNA"
      else -> banxaPaymentMethodId
    }
}
