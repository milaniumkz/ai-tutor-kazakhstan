import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiError implements Exception {
  const ApiError(this.code);
  final String code;
}

class TutorApi {
  TutorApi({http.Client? client, Uri? base})
    : client = client ?? http.Client(),
      base = base ?? _defaultBase();
  static Uri _defaultBase() {
    const configured = String.fromEnvironment('API_BASE_URL');
    return configured.isEmpty
        ? Uri.base.resolve('/v1/')
        : Uri.parse(configured);
  }

  final http.Client client;
  final Uri base;
  String? adultToken, childToken, pin;

  Future<dynamic> request(
    String path, {
    Object? data,
    bool parent = false,
    String? key,
    int? revision,
    String? bearerOverride,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = bearerOverride ?? (parent ? adultToken : childToken);
    if (token != null) headers['Authorization'] = 'Bearer $token';
    if (parent && pin != null) headers['X-Parent-Pin'] = pin!;
    if (key != null) headers['Idempotency-Key'] = key;
    if (revision != null) headers['If-Match'] = '"$revision"';
    final uri = base.resolve(path.replaceFirst(RegExp(r'^/'), ''));
    final response =
        await (data == null
                ? client.get(uri, headers: headers)
                : client.post(uri, headers: headers, body: jsonEncode(data)))
            .timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) {
      throw ApiError(decoded['error']?['code'] ?? 'REQUEST_FAILED');
    }
    return decoded;
  }

  void clear() {
    adultToken = null;
    childToken = null;
    pin = null;
  }

  void close() => client.close();
}
