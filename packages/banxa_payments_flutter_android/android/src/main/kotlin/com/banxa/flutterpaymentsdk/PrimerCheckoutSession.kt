package com.banxa.flutterpaymentsdk

/**
 * Hands the Primer client token to [PrimerCheckoutActivity] without putting it
 * in an Intent extra (those can show up in debug traces).
 *
 * [listener] is the plugin instance that started checkout, so multiple Flutter
 * engines do not share a single slot that can be clobbered and then missed.
 */
internal object PrimerCheckoutSession {
  @Volatile
  var clientToken: String? = null

  @Volatile
  var paymentMethodId: String? = null

  @Volatile
  var listener: PrimerCheckoutListener? = null

  fun takeClientToken(): String? {
    val token = clientToken
    clientToken = null
    return token
  }
}
