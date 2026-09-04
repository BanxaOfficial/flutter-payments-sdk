package com.banxa.flutterpaymentsdk

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import io.primer.checkout.PrimerTheme
import io.primer.checkout.api.checkout.PrimerCheckoutSheet
import io.primer.checkout.api.checkout.rememberPrimerCheckoutController
import io.primer.checkout.api.state.PrimerCheckoutEvent

/**
 * Hosts Primer Checkout Compose UI in its own Activity (not a Flutter PlatformView).
 * Mirrors the Compose sheet integration used against `io.primer:checkout:3.0.0-beta.2`.
 * The Banxa payment method id is stored on [PrimerCheckoutSession]; this sheet
 * still presents whatever methods the Primer client session includes.
 */
class PrimerCheckoutActivity : ComponentActivity() {
  private var terminalEventSent = false

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val clientToken = PrimerCheckoutSession.takeClientToken()
    if (clientToken.isNullOrBlank()) {
      emitFailed("Missing Primer client token")
      finish()
      return
    }

    setContent {
      val checkout = rememberPrimerCheckoutController(clientToken = clientToken)
      PrimerCheckoutSheet(
        theme = PrimerTheme(),
        checkout = checkout,
        onDismiss = {
          emitDismissed()
          finish()
        },
        onEvent = { event ->
          when (event) {
            is PrimerCheckoutEvent.Success -> {
              val payment = event.checkoutData.payment
              emitCompleted(
                buildMap {
                  payment?.id?.let { put("paymentId", it) }
                  payment?.orderId?.let { put("orderId", it) }
                },
              )
              finish()
            }
            is PrimerCheckoutEvent.Failure -> {
              emitFailed(event.error.description)
              finish()
            }
          }
        },
      )
    }
  }

  override fun onDestroy() {
    // If the activity is destroyed without a terminal Primer callback, treat as dismiss.
    if (isFinishing && !terminalEventSent) {
      emitDismissed()
    }
    super.onDestroy()
  }

  private fun emitCompleted(data: Map<String, String>) {
    if (terminalEventSent) return
    terminalEventSent = true
    PrimerCheckoutSession.listener?.onCompleted(data)
  }

  private fun emitFailed(message: String) {
    if (terminalEventSent) return
    terminalEventSent = true
    PrimerCheckoutSession.listener?.onFailed(message)
  }

  private fun emitDismissed() {
    if (terminalEventSent) return
    terminalEventSent = true
    PrimerCheckoutSession.listener?.onDismissed()
  }
}
