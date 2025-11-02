// Create this as lib/network_debug.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class NetworkDebugUtil {
  static const String baseUrl = 'https://ch2vi-production.up.railway.app';

  /// Comprehensive network diagnostic
  static Future<Map<String, dynamic>> runDiagnostics() async {
    Map<String, dynamic> results = {
      'timestamp': DateTime.now().toIso8601String(),
      'platform': _getPlatformInfo(),
      'connectivity': {},
      'dns_resolution': {},
      'ssl_check': {},
      'api_endpoints': {},
    };

    print('🔍 Starting network diagnostics...');

    // 1. Basic connectivity test
    results['connectivity'] = await _testConnectivity();

    // 2. DNS resolution test
    results['dns_resolution'] = await _testDnsResolution();

    // 3. SSL/TLS test
    results['ssl_check'] = await _testSslConnection();

    // 4. API endpoints test
    results['api_endpoints'] = await _testApiEndpoints();

    return results;
  }

  static Map<String, String> _getPlatformInfo() {
    return {
      'is_web': kIsWeb.toString(),
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'version': kIsWeb ? 'N/A' : Platform.operatingSystemVersion,
    };
  }

  static Future<Map<String, dynamic>> _testConnectivity() async {
    print('📡 Testing basic connectivity...');

    try {
      // Test basic internet connectivity
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'User-Agent': 'Bookey-Flutter-App/1.0'},
      ).timeout(Duration(seconds: 10));

      return {
        'internet_access': true,
        'google_reachable': response.statusCode == 200,
        'response_time_ms': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      return {
        'internet_access': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testDnsResolution() async {
    print('🌐 Testing DNS resolution...');

    Map<String, dynamic> results = {};

    List<String> hostnames = [
      'chap2vid-production.up.railway.app',
      'railway.app',
      'bookey-pdf-production.up.railway.app',
    ];

    for (String hostname in hostnames) {
      try {
        final addresses = await InternetAddress.lookup(hostname);
        results[hostname] = {
          'resolved': true,
          'addresses': addresses.map((addr) => addr.address).toList(),
        };
      } catch (e) {
        results[hostname] = {
          'resolved': false,
          'error': e.toString(),
        };
      }
    }

    return results;
  }

  static Future<Map<String, dynamic>> _testSslConnection() async {
    print('🔒 Testing SSL/TLS connection...');

    try {
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: 10);

      final request = await client.getUrl(Uri.parse('$baseUrl/health'));
      request.headers.add('User-Agent', 'Bookey-Flutter-App/1.0');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      client.close();

      return {
        'ssl_working': true,
        'status_code': response.statusCode,
        'headers': response.headers.toString(),
        'certificate_valid': true,
        'response_preview': responseBody.length > 100
            ? responseBody.substring(0, 100) + '...'
            : responseBody,
      };
    } catch (e) {
      return {
        'ssl_working': false,
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testApiEndpoints() async {
    print('🔌 Testing API endpoints...');

    Map<String, dynamic> results = {};

    final endpoints = [
      {'path': '/health', 'method': 'GET'},
      {'path': '/test', 'method': 'GET'},
      {'path': '/', 'method': 'GET'},
      {'path': '/convert-story', 'method': 'POST'},
    ];

    for (var endpoint in endpoints) {
      final path = endpoint['path'] as String;
      final method = endpoint['method'] as String;

      try {
        final client = http.Client();
        http.Response response;

        final headers = {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'Bookey-Flutter-App-Debug/1.0',
          'Cache-Control': 'no-cache',
        };

        if (method == 'GET') {
          response = await client
              .get(
                Uri.parse('$baseUrl$path'),
                headers: headers,
              )
              .timeout(Duration(seconds: 15));
        } else {
          // POST with test data
          response = await client
              .post(
                Uri.parse('$baseUrl$path'),
                headers: headers,
                body: json.encode({
                  'text': 'Debug test message',
                  'title': 'Debug Test',
                  'animate_all': false,
                  'merge_final': true,
                }),
              )
              .timeout(Duration(seconds: 15));
        }

        client.close();

        results[path] = {
          'method': method,
          'status_code': response.statusCode,
          'success': response.statusCode < 400,
          'headers': response.headers,
          'response_length': response.body.length,
          'response_preview': response.body.length > 200
              ? response.body.substring(0, 200) + '...'
              : response.body,
          'timing': DateTime.now().millisecondsSinceEpoch,
        };
      } catch (e) {
        results[path] = {
          'method': method,
          'success': false,
          'error': e.toString(),
          'error_type': e.runtimeType.toString(),
        };

        // Additional error analysis
        if (e.toString().contains('SocketException')) {
          results[path]['likely_cause'] =
              'Network connectivity issue or DNS resolution failure';
        } else if (e.toString().contains('HandshakeException')) {
          results[path]['likely_cause'] =
              'SSL/TLS certificate validation issue';
        } else if (e.toString().contains('TimeoutException')) {
          results[path]['likely_cause'] =
              'Server response timeout - server may be slow or unreachable';
        } else if (e.toString().contains('ClientException')) {
          results[path]['likely_cause'] =
              'HTTP client configuration issue or CORS problem';
        }
      }
    }

    return results;
  }

  /// Quick connectivity test
  static Future<bool> quickConnectivityTest() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          'User-Agent': 'Bookey-Flutter-App/1.0',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Quick connectivity test failed: $e');
      return false;
    }
  }

  /// Test with different HTTP configurations
  static Future<Map<String, dynamic>> testHttpConfigurations() async {
    Map<String, dynamic> results = {};

    // Test 1: Standard HTTP client
    try {
      final client = http.Client();
      final response = await client.get(
        Uri.parse('$baseUrl/health'),
        headers: {'User-Agent': 'Standard-Client'},
      ).timeout(Duration(seconds: 10));

      results['standard_client'] = {
        'success': true,
        'status': response.statusCode,
        'response': response.body.substring(0, min(100, response.body.length)),
      };
      client.close();
    } catch (e) {
      results['standard_client'] = {'success': false, 'error': e.toString()};
    }

    // Test 2: Custom HttpClient (non-web only)
    if (!kIsWeb) {
      try {
        final httpClient = HttpClient();
        httpClient.connectionTimeout = Duration(seconds: 10);
        httpClient.userAgent = 'Custom-HttpClient';

        final request = await httpClient.getUrl(Uri.parse('$baseUrl/health'));
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        results['custom_http_client'] = {
          'success': true,
          'status': response.statusCode,
          'response': responseBody.substring(0, min(100, responseBody.length)),
        };
        httpClient.close();
      } catch (e) {
        results['custom_http_client'] = {
          'success': false,
          'error': e.toString()
        };
      }
    }

    return results;
  }

  /// Print formatted diagnostic results
  static void printDiagnosticResults(Map<String, dynamic> results) {
    print('\n' + '=' * 50);
    print('🔍 NETWORK DIAGNOSTIC RESULTS');
    print('=' * 50);

    print('\n📱 Platform Info:');
    final platform = results['platform'] as Map<String, dynamic>;
    platform.forEach((key, value) {
      print('  $key: $value');
    });

    print('\n📡 Connectivity:');
    final connectivity = results['connectivity'] as Map<String, dynamic>;
    connectivity.forEach((key, value) {
      print('  $key: $value');
    });

    print('\n🌐 DNS Resolution:');
    final dns = results['dns_resolution'] as Map<String, dynamic>;
    dns.forEach((hostname, data) {
      final resolved = data['resolved'] as bool;
      print('  $hostname: ${resolved ? '✅ Resolved' : '❌ Failed'}');
      if (!resolved) {
        print('    Error: ${data['error']}');
      }
    });

    print('\n🔒 SSL/TLS Test:');
    final ssl = results['ssl_check'] as Map<String, dynamic>;
    final sslWorking = ssl['ssl_working'] as bool;
    print('  SSL Connection: ${sslWorking ? '✅ Working' : '❌ Failed'}');
    if (!sslWorking) {
      print('    Error: ${ssl['error']}');
      print('    Type: ${ssl['error_type']}');
    }

    print('\n🔌 API Endpoints:');
    final endpoints = results['api_endpoints'] as Map<String, dynamic>;
    endpoints.forEach((path, data) {
      final success = data['success'] as bool;
      final method = data['method'];
      print('  $method $path: ${success ? '✅ Success' : '❌ Failed'}');
      if (!success) {
        print('    Error: ${data['error']}');
        if (data.containsKey('likely_cause')) {
          print('    Likely cause: ${data['likely_cause']}');
        }
      } else {
        print('    Status: ${data['status_code']}');
      }
    });

    print('\n' + '=' * 50);
  }

  static int min(int a, int b) => a < b ? a : b;
}
