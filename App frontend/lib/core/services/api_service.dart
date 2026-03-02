// lib/core/services/api_service.dart
// Central HTTP client for all remote API calls.
// Reads the JWT token from secure storage and attaches it automatically.

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Base URL for the Django backend.
/// - For web / desktop: use localhost.
/// - For Android emulator: change to 10.0.2.2.
const String kBaseUrl = 'http://172.16.20.116:8000/api';

const _storage = FlutterSecureStorage();

class ApiService {
  // ── Token helpers ──────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_access', value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: 'jwt_access');
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: 'jwt_access');
  }

  // ── Auth header ────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final token = await getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Generic request helpers ────────────────────────────────────────────────

  static Future<http.Response> get(String path) async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$kBaseUrl$path'), headers: headers);
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body,
      {bool authenticated = true}) async {
    final headers = authenticated
        ? await _authHeaders()
        : {'Content-Type': 'application/json'};
    return http.post(
      Uri.parse('$kBaseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    return http.patch(
      Uri.parse('$kBaseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  /// Multipart POST — used for complaint image submission.
  static Future<http.Response> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String filePath,
    String fileField = 'images',
  }) async {
    final token = await getToken();
    final request =
        http.MultipartRequest('POST', Uri.parse('$kBaseUrl$path'));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  // ── Response decoder ───────────────────────────────────────────────────────

  static dynamic decodeResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static bool isSuccess(http.Response r) =>
      r.statusCode >= 200 && r.statusCode < 300;
}
