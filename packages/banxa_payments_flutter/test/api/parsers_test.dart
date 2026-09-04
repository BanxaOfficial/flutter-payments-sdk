import 'dart:convert';

import 'package:banxa_payments_flutter/src/api/parsers.dart';
import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseCountries reads nested states', () {
    final countries = parseCountries(
      jsonDecode('''
        [{"id":"AU","description":"Australia",
          "states":[{"id":"VIC","description":"Victoria"}]}]
      '''),
    );

    expect(countries, hasLength(1));
    expect(countries.single.id, 'AU');
    expect(countries.single.states.single.description, 'Victoria');
  });

  test('parseCrypto keeps unsupportedCountries as a typed map', () {
    final cryptos = parseCrypto(
      jsonDecode('''
        [{"id":"ETH","blockchains":[
          {"id":"ETH","unsupportedCountries":{"US":["NY","TX"]}}
        ]}]
      '''),
    );

    expect(
      cryptos.single.blockchains.single.unsupportedCountries,
      {'US': ['NY', 'TX']},
    );
  });

  test('parseQuotes accepts a single object or an array', () {
    expect(parseQuotes(jsonDecode('{"fiatAmount":"50"}')), hasLength(1));
    expect(parseQuotes(jsonDecode('[{"fiatAmount":"50"}]')), hasLength(1));
  });

  test('parseQuotes maps the misspelled orginalNetworkFee wire key', () {
    final quotes = parseQuotes(
      jsonDecode('''
        {"discount":{"discountCode":"PROMO",
          "originalQuote":{"orginalNetworkFee":"1.50"}}}
      '''),
    );

    expect(
      quotes.single.discount?.originalQuote?.originalNetworkFee,
      '1.50',
    );
  });

  test('parseOrder reads a numeric paymentMethodId as a string', () {
    final order = parseOrder(
      jsonDecode('{"id":"o1","paymentMethodId":42,"nativeToken":"tok"}'),
    );

    expect(order.id, 'o1');
    expect(order.paymentMethodId, '42');
    expect(order.nativeToken, 'tok');
  });

  test('createOrderBody omits nulls and keeps required fields', () {
    final body = createOrderBody(
      const CreateOrderRequest(
        orderType: OrderType.buy,
        crypto: 'ETH',
        fiat: 'USD',
        fiatAmount: '50',
        walletAddress: '0xabc',
        email: 'user@example.com',
        redirectUrl: 'https://example.com/redirect',
        paymentMethodId: 'debit-credit-card',
      ),
    );

    expect(body['crypto'], 'ETH');
    expect(body['paymentMethodId'], 'debit-credit-card');
    expect(body.containsKey('cryptoAmount'), isFalse);
  });

  test('createOrderBody rejects blank required fields', () {
    expect(
      () => createOrderBody(
        const CreateOrderRequest(
          orderType: OrderType.buy,
          crypto: '',
          fiat: 'USD',
          fiatAmount: '50',
          walletAddress: '0xabc',
          email: 'user@example.com',
          redirectUrl: 'https://example.com/redirect',
        ),
      ),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors.single.field,
          'field',
          'crypto',
        ),
      ),
    );
  });

  test('orderPath switches on order type', () {
    expect(orderPath(OrderType.buy), '/buy');
    expect(orderPath(OrderType.sell), '/sell');
  });
}
