package com.banxa.flutterpaymentsdk

import org.junit.Assert.assertEquals
import org.junit.Test

class PaymentMethodMapperTest {
  @Test
  fun mapsCardAliases() {
    assertEquals("PAYMENT_CARD", PaymentMethodMapper.primerType("debit-credit-card"))
    assertEquals("PAYMENT_CARD", PaymentMethodMapper.primerType("card"))
    assertEquals("PAYMENT_CARD", PaymentMethodMapper.primerType("CREDIT-CARD"))
  }

  @Test
  fun mapsWallets() {
    assertEquals("APPLE_PAY", PaymentMethodMapper.primerType("apple-pay"))
    assertEquals("GOOGLE_PAY", PaymentMethodMapper.primerType("google-pay"))
  }

  @Test
  fun passesThroughUnknownOrPrimerValues() {
    assertEquals("PAYMENT_CARD", PaymentMethodMapper.primerType("PAYMENT_CARD"))
    assertEquals("ideal-bank-transfer", PaymentMethodMapper.primerType("ideal-bank-transfer"))
  }
}
