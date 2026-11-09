import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Erro retornado pela API, com mensagem pronta para mostrar ao usuário.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get requiresPremium => statusCode == 402;

  @override
  String toString() => message;
}

/// Cliente HTTP com token, JSON e tratamento de erros centralizados.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? token;

  /// Chamado quando a API responde 401 (token expirado): o app faz logout.
  void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value != null) params[key] = value.toString();
    });
    return Uri.parse('$baseUrl$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send(() => _http.post(_uri(path, query), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _http.put(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _http.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) => _send(() => _http.delete(_uri(path), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('O servidor demorou para responder. Tente novamente.');
    } on SocketException {
      throw ApiException('Sem conexão com o servidor. Verifique sua internet.');
    } on http.ClientException {
      throw ApiException('Não foi possível conectar ao servidor.');
    }

    dynamic body;
    try {
      body = response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    } on FormatException {
      body = null; // resposta que não é JSON (ex.: página de erro do proxy)
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    if (response.statusCode == 401 && token != null) onUnauthorized?.call();
    throw ApiException(_errorMessage(body, response.statusCode), statusCode: response.statusCode);
  }

  static String _errorMessage(dynamic body, int status) {
    if (body is Map && body['detail'] != null) {
      final detail = body['detail'];
      if (detail is String) return detail;
      // Erros de validação do FastAPI: lista de {loc, msg}.
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          final field = (first['loc'] as List?)?.last;
          return field != null ? 'Campo "$field": ${first['msg']}' : '${first['msg']}';
        }
      }
    }
    if (status >= 500) return 'Erro no servidor. Tente novamente mais tarde.';
    return 'Erro inesperado ($status).';
  }
}
