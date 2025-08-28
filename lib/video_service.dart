import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Models for video generation API
class VideoRequest {
  final String text;
  final String title;
  final bool animateAll;
  final bool mergeFinal;

  VideoRequest({
    required this.text,
    required this.title,
    this.animateAll = true,
    this.mergeFinal = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'title': title,
      'animate_all': animateAll,
      'merge_final': mergeFinal,
    };
  }
}

class VideoProcessingStatus {
  final String jobId;
  final String status;
  final String progress;
  final int scenesCompleted;
  final int totalScenes;
  final String? downloadUrl;
  final String? errorMessage;

  VideoProcessingStatus({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.scenesCompleted,
    required this.totalScenes,
    this.downloadUrl,
    this.errorMessage,
  });

  factory VideoProcessingStatus.fromJson(Map<String, dynamic> json) {
    return VideoProcessingStatus(
      jobId: json['job_id'] ?? '',
      status: json['status'] ?? '',
      progress: json['progress'] ?? '',
      scenesCompleted: json['scenes_completed'] ?? 0,
      totalScenes: json['total_scenes'] ?? 0,
      downloadUrl: json['download_url'],
      errorMessage: json['error_message'],
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing';
}

class GeneratedVideo {
  final String id;
  final String title;
  final String status;
  final String progress;
  final DateTime createdAt;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final int scenesCompleted;
  final int totalScenes;

  GeneratedVideo({
    required this.id,
    required this.title,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.downloadUrl,
    this.thumbnailUrl,
    required this.scenesCompleted,
    required this.totalScenes,
  });

  factory GeneratedVideo.fromVideoStatus(VideoProcessingStatus status, String title) {
    return GeneratedVideo(
      id: status.jobId,
      title: title,
      status: status.status,
      progress: status.progress,
      createdAt: DateTime.now(),
      downloadUrl: status.downloadUrl,
      scenesCompleted: status.scenesCompleted,
      totalScenes: status.totalScenes,
    );
  }

  GeneratedVideo copyWith({
    String? status,
    String? progress,
    String? downloadUrl,
    int? scenesCompleted,
    int? totalScenes,
  }) {
    return GeneratedVideo(
      id: id,
      title: title,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      thumbnailUrl: thumbnailUrl,
      scenesCompleted: scenesCompleted ?? this.scenesCompleted,
      totalScenes: totalScenes ?? this.totalScenes,
    );
  }
}

class VideoGenerationService {
  static const String baseUrl = 'https://chap2vid-production.up.railway.app';
  static const int timeoutSeconds = 300; // 5 minutes timeout

  // Create a custom HTTP client with better configuration
  static http.Client _createHttpClient() {
    final client = http.Client();
    
    // For non-web platforms, we can configure the HTTP client
    if (!kIsWeb) {
      // The client will use the global HttpOverrides from main.dart
    }
    
    return client;
  }

  /// Start video generation from chapter text
  static Future<VideoProcessingStatus> generateVideoFromChapter({
    required String chapterText,
    required String chapterTitle,
    bool animateAll = true,
    bool mergeFinal = true,
  }) async {
    final client = _createHttpClient();
    
    try {
      final request = VideoRequest(
        text: chapterText,
        title: chapterTitle,
        animateAll: animateAll,
        mergeFinal: mergeFinal,
      );

      print('🔄 Sending request to: $baseUrl/convert-story');
      print('📝 Request body: ${json.encode(request.toJson())}');

      final response = await client.post(
        Uri.parse('$baseUrl/convert-story'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
          // Add cache control to prevent caching issues
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
        body: json.encode(request.toJson()),
      ).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timeout - please try again', Duration(seconds: 30));
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response headers: ${response.headers}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        return VideoProcessingStatus.fromJson(jsonData);
      } else if (response.statusCode == 405) {
        throw Exception('API endpoint method not allowed. Server may be updating.');
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        // Client error
        try {
          final errorData = json.decode(response.body);
          throw Exception('API Error ${response.statusCode}: ${errorData['detail'] ?? errorData['message'] ?? 'Request failed'}');
        } catch (jsonError) {
          throw Exception('API Error ${response.statusCode}: ${response.body}');
        }
      } else if (response.statusCode >= 500) {
        // Server error
        throw Exception('Server Error ${response.statusCode}: The backend server is experiencing issues');
      } else {
        throw Exception('Unexpected response ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException catch (e) {
      throw Exception('Request timeout - the server took too long to respond');
    } on SocketException catch (e) {
      throw Exception('Network connection failed. Please check your internet connection. Details: ${e.message}');
    } on HandshakeException catch (e) {
      throw Exception('SSL/TLS connection failed. Please try again. Details: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Invalid response format from server. Details: ${e.message}');
    } catch (e) {
      print('❌ Error in video generation: $e');
      
      String errorMessage = e.toString();
      
      // Handle specific error types with more helpful messages
      if (errorMessage.contains('ClientException')) {
        throw Exception('Network connection failed. Please check your internet connection and try again.');
      } else if (errorMessage.contains('Failed to fetch')) {
        throw Exception('Unable to connect to the server. Please check your internet connection.');
      } else if (errorMessage.contains('XMLHttpRequest error')) {
        throw Exception('Network request failed. This might be a CORS issue or network problem.');
      } else {
        throw Exception('Network error: ${errorMessage}');
      }
    } finally {
      client.close();
    }
  }

  /// Get the status of a video generation job
  static Future<VideoProcessingStatus> getJobStatus(String jobId) async {
    final client = _createHttpClient();
    
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/status/$jobId'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
          'Cache-Control': 'no-cache',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return VideoProcessingStatus.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw Exception('Job not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get job status');
      }
    } on SocketException catch (e) {
      throw Exception('Network connection failed: ${e.message}');
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  /// Download video file (returns the download URL)
  static String getDownloadUrl(String jobId) {
    return '$baseUrl/download/$jobId';
  }

  /// Clean up job resources
  static Future<void> cleanupJob(String jobId) async {
    final client = _createHttpClient();
    
    try {
      final response = await client.delete(
        Uri.parse('$baseUrl/cleanup/$jobId'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Warning: Failed to cleanup job $jobId');
      }
    } catch (e) {
      print('Warning: Error cleaning up job $jobId: $e');
    } finally {
      client.close();
    }
  }

  /// Check API health
  static Future<bool> checkHealth() async {
    final client = _createHttpClient();
    
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Test API endpoints to see what's available
  static Future<Map<String, dynamic>> testApiEndpoints() async {
    final endpoints = {
      '/': 'GET',
      '/convert-story': 'POST',
      '/health': 'GET',
      '/test': 'GET',
    };

    Map<String, dynamic> results = {};

    for (String endpoint in endpoints.keys) {
      final client = _createHttpClient();
      
      try {
        final method = endpoints[endpoint]!;
        http.Response response;

        if (method == 'GET') {
          response = await client.get(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'accept': 'application/json',
              'User-Agent': 'Bookey-Flutter-App/1.0',
              'Cache-Control': 'no-cache',
            },
          ).timeout(Duration(seconds: 10));
        } else {
          // POST request with exact same format as working curl
          response = await client.post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'accept': 'application/json',
              'Content-Type': 'application/json',
              'User-Agent': 'Bookey-Flutter-App/1.0',
              'Cache-Control': 'no-cache',
            },
            body: json.encode({
              'text': 'A robot finds a seed and plants it.',
              'title': 'Quick Test',
              'animate_all': false,
              'merge_final': true,
            }),
          ).timeout(Duration(seconds: 15));
        }

        results[endpoint] = {
          'status': response.statusCode,
          'method': method,
          'available': response.statusCode < 400,
          'headers': response.headers.toString(),
          'body': response.body.length > 300 ? '${response.body.substring(0, 300)}...' : response.body,
        };
      } on SocketException catch (e) {
        results[endpoint] = {
          'status': 'Socket Error',
          'method': endpoints[endpoint],
          'available': false,
          'error': 'Network connection failed: ${e.message}',
        };
      } on TimeoutException catch (e) {
        results[endpoint] = {
          'status': 'Timeout',
          'method': endpoints[endpoint],
          'available': false,
          'error': 'Request timed out after 10 seconds',
        };
      } on HandshakeException catch (e) {
        results[endpoint] = {
          'status': 'SSL Error',
          'method': endpoints[endpoint],
          'available': false,
          'error': 'SSL/TLS handshake failed: ${e.message}',
        };
      } catch (e) {
        results[endpoint] = {
          'status': 'error',
          'method': endpoints[endpoint],
          'available': false,
          'error': e.toString(),
        };
      } finally {
        client.close();
      }
    }

    return results;
  }
}