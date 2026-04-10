import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

typedef JsonDecoder<T> = T Function(Object? json);

class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message, this.body});

  final int statusCode;
  final String message;
  final Object? body;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    required http.Client httpClient,
    required SupabaseClient supabaseClient,
  }) : _baseUri = Uri.parse(baseUrl),
       _http = httpClient,
       _supabase = supabaseClient;

  final Uri _baseUri;
  final http.Client _http;
  final SupabaseClient _supabase;

  Future<T> get<T>(
    String path, {
    Map<String, String>? query,
    required JsonDecoder<T> decode,
  }) async {
    final uri = _buildUri(path, query);
    final response = await _http.get(uri, headers: _headers());
    return _decodeResponse(response, decode);
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, String>? query,
    required JsonDecoder<T> decode,
  }) async {
    print('Creating alert with payload: $body');

    final uri = _buildUri(path, query);
    final encodedBody = body == null ? null : jsonEncode(body);

    final response = await _http.post(
      uri,
      headers: _headers(contentTypeJson: true),
      body: encodedBody,
    );
    return _decodeResponse(response, decode);
  }

  Uri _buildUri(String path, Map<String, String>? query) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return _baseUri.replace(
      path: '${_baseUri.path}$normalizedPath',
      queryParameters: query,
    );
  }

  Map<String, String> _headers({bool contentTypeJson = false}) {
    final headers = <String, String>{'Accept': 'application/json'};

    if (contentTypeJson) {
      headers['Content-Type'] = 'application/json';
    }

    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  T _decodeResponse<T>(http.Response response, JsonDecoder<T> decode) {
    final decodedBody =
        response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Request failed',
        body: decodedBody,
      );
    }

    return decode(decodedBody);
  }
}

ApiClient createApiClient() => ApiClient(
  baseUrl: AppConfig.backendBaseUrl,
  httpClient: http.Client(),
  supabaseClient: Supabase.instance.client,
);
