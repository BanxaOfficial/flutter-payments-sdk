package com.banxa.flutterpaymentsdk

/**
 * Whether a Banxa payment method can be presented through native Primer on
 * Android. Apple Pay is never available; Google Pay needs Play services.
 */
internal object NativePaymentAvailability {
  fun isAvailable(paymentMethodId: String, hasPlayServices: Boolean): Boolean {
    return when (PaymentMethodMapper.primerType(paymentMethodId)) {
      "APPLE_PAY" -> false
      "GOOGLE_PAY" -> hasPlayServices
      else -> true
    }
  }
}
