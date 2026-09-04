package com.banxa.flutterpaymentsdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger

/**
 * Flutter plugin entry point for Primer native checkout (Android).
 *
 * Partner-api networking happens in Dart; this plugin only presents Primer and
 * forwards checkout outcomes.
 */
class BanxaPaymentsFlutterAndroidPlugin :
  FlutterPlugin,
  ActivityAware,
  BanxaPaymentsHostApi,
  PrimerCheckoutListener {

  private var flutterApi: BanxaPaymentsFlutterApi? = null
  private var activity: Activity? = null
  private var appContext: Context? = null
  private val mainHandler = Handler(Looper.getMainLooper())

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    setup(binding.binaryMessenger)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    BanxaPaymentsHostApi.setUp(binding.binaryMessenger, null)
    flutterApi = null
    appContext = null
    if (PrimerCheckoutSession.listener === this) {
      PrimerCheckoutSession.listener = null
      PrimerCheckoutSession.clientToken = null
      PrimerCheckoutSession.paymentMethodId = null
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  private fun setup(messenger: BinaryMessenger) {
    BanxaPaymentsHostApi.setUp(messenger, this)
    flutterApi = BanxaPaymentsFlutterApi(messenger)
  }

  /**
   * Primer configuration is per-checkout on Android, and the Apple Pay
   * settings in [config] are iOS-only, so there is nothing to install here.
   */
  override fun configureCheckout(config: CheckoutConfigMessage, callback: (Result<Unit>) -> Unit) {
    callback(Result.success(Unit))
  }

  override fun isNativePaymentMethodAvailable(paymentMethodId: String): Boolean =
    NativePaymentAvailability.isAvailable(
      paymentMethodId,
      hasPlayServices = hasGooglePlayServices(),
    )

  override fun presentPrimerCheckout(
    clientToken: String,
    paymentMethodId: String,
    callback: (Result<Unit>) -> Unit,
  ) {
    val host = activity
    if (host == null) {
      callback(
        Result.failure(
          FlutterError(
            "checkout_failed",
            "No Android Activity available to present checkout",
            null,
          ),
        ),
      )
      return
    }

    val result = runCatching {
      PaymentMethodMapper.primerType(paymentMethodId)
      PrimerCheckoutSession.clientToken = clientToken
      PrimerCheckoutSession.paymentMethodId = paymentMethodId
      PrimerCheckoutSession.listener = this
      host.startActivity(Intent(host, PrimerCheckoutActivity::class.java))
    }
    callback(
      result.fold(
        onSuccess = { Result.success(Unit) },
        onFailure = { error ->
          PrimerCheckoutSession.clientToken = null
          PrimerCheckoutSession.paymentMethodId = null
          if (PrimerCheckoutSession.listener === this) {
            PrimerCheckoutSession.listener = null
          }
          Result.failure(
            FlutterError(
              "checkout_failed",
              error.message ?: "Failed to present Primer checkout",
              null,
            ),
          )
        },
      ),
    )
  }

  override fun onCompleted(data: Map<String, String>) {
    emitEvent(
      CheckoutEventMessage(
        type = "completed",
        errorMessage = null,
        data = data.mapKeys { entry -> entry.key as String? },
      ),
    )
  }

  override fun onFailed(message: String) {
    emitEvent(
      CheckoutEventMessage(
        type = "failed",
        errorMessage = message,
        data = null,
      ),
    )
  }

  override fun onDismissed() {
    emitEvent(
      CheckoutEventMessage(
        type = "dismissed",
        errorMessage = null,
        data = null,
      ),
    )
  }

  private fun emitEvent(event: CheckoutEventMessage) {
    mainHandler.post {
      flutterApi?.onCheckoutEvent(event) { /* ignore ack errors */ }
    }
  }

  private fun hasGooglePlayServices(): Boolean {
    val context = appContext ?: activity ?: return false
    return try {
      context.packageManager.getPackageInfo("com.google.android.gms", 0)
      true
    } catch (_: Exception) {
      false
    }
  }
}
