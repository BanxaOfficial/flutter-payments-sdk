package com.banxa.flutterpaymentsdk

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativePaymentAvailabilityTest {
  @Test
  fun applePayIsNeverAvailable() {
    assertFalse(NativePaymentAvailability.isAvailable("apple-pay", true))
  }

  @Test
  fun googlePayRequiresPlayServices() {
    assertTrue(NativePaymentAvailability.isAvailable("google-pay", true))
    assertFalse(NativePaymentAvailability.isAvailable("google-pay", false))
  }

  @Test
  fun cardsAreAvailable() {
    assertTrue(NativePaymentAvailability.isAvailable("debit-credit-card", false))
  }
}
