package com.banxa.flutterpaymentsdk

/**
 * Checkout outcome callbacks implemented by the Flutter plugin.
 */
internal interface PrimerCheckoutListener {
  fun onCompleted(data: Map<String, String>)
  fun onFailed(message: String)
  fun onDismissed()
}
