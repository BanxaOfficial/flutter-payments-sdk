import 'dart:io';

import 'package:banxa_payments_flutter/src/api/banxa_api_client.dart';
import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _config = BanxaConfig(
  apiKey: 'test-key',
  partnerId: 'partner',
  environment: BanxaEnvironment.sandbox,
);

BanxaApiClient _clientReturning(
  http.Response response, {
  void Function(http.Request)? onRequest,
}) {
  return BanxaApiClient(
    config: _config,
    httpClient: MockClient((request) async {
      onRequest?.call(request);
      return response;
    }),
  );
}

void main() {
  test('GET hits {host}/{partnerId}/v2 with the api key header', () async {
    late http.Request captured;
    final client = _clientReturning(
      http.Response('[]', 200),
      onRequest: (request) => captured = request,
    );

    await client.get('/countries');

    expect(
      captured.url.toString(),
      'https://api.banxa-sandbox.com/partner/v2/countries',
    );
    expect(captured.headers['x-api-key'], 'test-key');
    expect(captured.headers['Content-Type'], 'application/json');
  });

  test('GET drops null and empty query parameters', () async {
    late http.Request captured;
    final client = _clientReturning(
      http.Response('[]', 200),
      onRequest: (request) => captured = request,
    );

    await client.get(
      '/payment-methods/buy',
      query: {'fiat': 'USD', 'ipAddress': null, 'discountCode': ''},
    );

    expect(captured.url.queryParameters, {'fiat': 'USD'});
  });

  test('401 maps to UnauthorizedException', () async {
    final client = _clientReturning(http.Response('', 401));

    expect(
      () => client.get('/countries'),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('422 maps to ValidationException with field errors', () async {
    final client = _clientReturning(
      http.Response(
        '{"message":"Invalid","errors":{"fiat":["unsupported"]}}',
        422,
      ),
    );

    await expectLater(
      client.post('/buy', const {}),
      throwsA(
        isA<ValidationException>()
            .having((e) => e.message, 'message', 'Invalid')
            .having((e) => e.errors.single.field, 'field', 'fiat')
            .having((e) => e.errors.single.messages, 'messages', ['unsupported']),
      ),
    );
  });

  test('500 maps to ServerException carrying the status code', () async {
    final client = _clientReturning(
      http.Response('{"message":"Boom"}', 500),
    );

    await expectLater(
      client.get('/countries'),
      throwsA(
        isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.message, 'message', 'Boom'),
      ),
    );
  });

  test('TLS failures map to NetworkException', () async {
    final client = BanxaApiClient(
      config: _config,
      httpClient: MockClient((_) async => throw const HandshakeException('tls')),
    );

    await expectLater(
      client.get('/countries'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('transport failures map to NetworkException', () async {
    final client = BanxaApiClient(
      config: _config,
      httpClient: MockClient((_) async => throw http.ClientException('offline')),
    );

    await expectLater(
      client.get('/countries'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('unparseable success body maps to UnknownException', () async {
    final client = _clientReturning(http.Response('not json', 200));

    await expectLater(
      client.get('/countries'),
      throwsA(isA<UnknownException>()),
    );
  });

  test('postExpectingEmpty tolerates an empty 204 body', () async {
    final client = _clientReturning(http.Response('', 204));

    await expectLater(
      client.postExpectingEmpty('/primer/session', const {'savedCard': true}),
      completes,
    );
  });
}
