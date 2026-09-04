import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:banxa_payments_flutter_platform_interface/banxa_payments_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;

/// HTTP client for partner-api v2.
///
/// Auth: `x-api-key` + `Content-Type: application/json`.
/// Base URL: `{host}/{partnerId}/v2`.
class BanxaApiClient {
  BanxaApiClient({
    required this.config,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  })  : _http = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  final BanxaConfig config;
  final Duration timeout;
  final http.Client _http;
  final bool _ownsHttpClient;

  void close() {
    if (_ownsHttpClient) {
      _http.close();
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    final response = await _send(
      (client) => client.get(_uri(path, query), headers: _headers),
    );
    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await _send(
      (client) => client.post(
        _uri(path, const {}),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  /// POST that only validates the HTTP status; an empty body is accepted.
  Future<void> postExpectingEmpty(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(
      (client) => client.post(
        _uri(path, const {}),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    _throwIfError(response);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': config.apiKey,
      };

  Uri _uri(String path, Map<String, String?> query) {
    final normalised = path.startsWith('/') ? path : '/$path';
    final base = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base$normalised');
    final params = {
      for (final entry in query.entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          entry.key: entry.value!,
    };
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  Future<http.Response> _send(
    Future<http.Response> Function(http.Client) request,
  ) async {
    try {
      return await request(_http).timeout(timeout);
    } on TimeoutException {
      throw NetworkException('Request timed out after ${timeout.inSeconds}s');
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on IOException catch (e) {
      throw NetworkException('$e');
    }
  }

  dynamic _decode(http.Response response) {
    _throwIfError(response);
    if (response.body.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } on FormatException catch (e) {
      throw UnknownException('Failed to decode response: ${e.message}');
    }
  }

  void _throwIfError(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return;
    }
    final body = _BanxaErrorBody.parse(response.body);
    switch (status) {
      case 401:
        throw const UnauthorizedException();
      case 400:
      case 422:
        throw ValidationException(body.fieldErrors, body.message);
      default:
        throw ServerException(status, body.message);
    }
  }
}

class _BanxaErrorBody {
  const _BanxaErrorBody(this.message, this.fieldErrors);

  final String? message;
  final List<FieldError> fieldErrors;

  static _BanxaErrorBody parse(String body) {
    if (body.trim().isEmpty) {
      return const _BanxaErrorBody(null, []);
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return const _BanxaErrorBody(null, []);
      }
      final message = decoded['message'];
      final errors = decoded['errors'];
      return _BanxaErrorBody(
        message is String && message.isNotEmpty ? message : null,
        errors is Map
            ? errors.entries
                .map(
                  (e) => FieldError(
                    field: '${e.key}',
                    messages: e.value is List
                        ? (e.value as List).map((m) => '$m').toList()
                        : ['${e.value}'],
                  ),
                )
                .toList()
            : const [],
      );
    } on FormatException {
      return const _BanxaErrorBody(null, []);
    }
  }
}
