import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class SecureHttpClient {
  final String baseUrl;
  final Duration timeout;
  final Map<String, String>? defaultHeaders;
  
  // Add your certificate fingerprints here
  static const Map<String, String> _certificateFingerprints = {
    'api.daaymn.com': 'YOUR_CERTIFICATE_FINGERPRINT', // SHA-256 fingerprint
  };

  SecureHttpClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 10),
    this.defaultHeaders,
  });

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _sendRequest(
      'GET',
      _buildUri(path, queryParameters),
      headers: headers,
    );
  }

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    dynamic body,
    Encoding? encoding,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _sendRequest(
      'POST',
      _buildUri(path, queryParameters),
      headers: headers,
      body: body,
      encoding: encoding,
    );
  }

  Future<http.Response> _sendRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    dynamic body,
    Encoding? encoding,
  }) async {
    try {
      // Verify SSL certificate
      if (!kIsWeb) {
        final host = uri.host;
        
        if (_certificateFingerprints.containsKey(host)) {
          // In a real app, you would implement certificate pinning here
          // For now, we'll just ensure we're using HTTPS
          if (uri.scheme != 'https') {
            throw const HttpException('Insecure connection: HTTPS required');
          }
        }
      }

      final client = http.Client();
      final request = http.Request(method, uri);
      
      // Set default headers
      final defaultHeaders = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?this.defaultHeaders, // Add class-level default headers if any
      };
      
      // Merge with request-specific headers, allowing them to override defaults
      final mergedHeaders = {
        ...defaultHeaders,
        ...?headers,
      };
      
      // Set the merged headers
      request.headers.addAll(Map<String, String>.from(mergedHeaders));
      
      // Add body if present
      if (body != null) {
        if (body is String) {
          request.body = body;
        } else if (body is Map || body is List) {
          request.body = jsonEncode(body);
        } else {
          request.body = body.toString();
        }
      }
      
      if (encoding != null) {
        request.encoding = encoding;
      }

      // Send the request with timeout
      final streamedResponse = await client.send(request).timeout(timeout);
      
      // Convert the response to http.Response
      final response = await http.Response.fromStream(streamedResponse);
      
      // Check for error status codes
      if (response.statusCode >= 400) {
        throw HttpException(
          'Request failed with status: ${response.statusCode}\n${response.body}',
          uri: uri,
        );
      }
      
      return response;
    } on SocketException catch (e) {
      throw HttpException('No Internet connection: $e', uri: uri);
    } on FormatException catch (e) {
      throw HttpException('Bad response format: $e', uri: uri);
    } catch (e) {
      throw HttpException('Request failed: $e', uri: uri);
    }
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    // Ensure the base URL ends with a slash
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    
    // Remove leading slash from path if present
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    
    // Build the URI with proper encoding of query parameters
    return Uri.parse(base + cleanPath).replace(
      queryParameters: queryParameters,
    );
  }
}
