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
  final String jwtToken; // ← ADDED

  VideoRequest({
    required this.text,
    required this.title,
    this.animateAll = true,
    this.mergeFinal = true,
    required this.jwtToken, // ← ADDED
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'title': title,
      'animate_all': animateAll,
      'merge_final': mergeFinal,
      'jwt_token': jwtToken, // ← ADDED
    };
  }
}

class VideoProcessingStatus {
  final String jobId;
  final String status;
  final String progress;
  final int scenesCompleted;
  final int totalScenes;
  final String? playbackUrl;
  final String? thumbnailUrl;
  final String? errorMessage;
  final Duration? duration;
  final int? fileSize;
  final String? videoId; // ← ADDED
  final int? creditsUsed; // ← ADDED
  final int? creditsRemaining; // ← ADDED

  VideoProcessingStatus({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.scenesCompleted,
    required this.totalScenes,
    this.playbackUrl,
    this.thumbnailUrl,
    this.errorMessage,
    this.duration,
    this.fileSize,
    this.videoId, // ← ADDED
    this.creditsUsed, // ← ADDED
    this.creditsRemaining, // ← ADDED
  });

  factory VideoProcessingStatus.fromJson(Map<String, dynamic> json) {
    Duration? parsedDuration;
    if (json['duration'] != null) {
      // Parse duration from seconds or duration string
      if (json['duration'] is num) {
        parsedDuration = Duration(seconds: (json['duration'] as num).toInt());
      } else if (json['duration'] is String) {
        // Try to parse duration string (e.g., "00:02:30")
        try {
          final parts = (json['duration'] as String).split(':');
          if (parts.length == 3) {
            final hours = int.parse(parts[0]);
            final minutes = int.parse(parts[1]);
            final seconds = int.parse(parts[2]);
            parsedDuration =
                Duration(hours: hours, minutes: minutes, seconds: seconds);
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    }

    return VideoProcessingStatus(
      jobId: json['job_id'] ?? '',
      status: json['status'] ?? '',
      progress: json['progress'] ?? '',
      scenesCompleted: json['scenes_completed'] ?? 0,
      totalScenes: json['total_scenes'] ?? 0,
      playbackUrl:
          json['playback_url'] ?? json['video_url'] ?? json['download_url'],
      thumbnailUrl: json['thumbnail_url'],
      errorMessage: json['error_message'],
      duration: parsedDuration,
      fileSize: json['file_size'],
      videoId: json['video_id'], // ← ADDED
      creditsUsed: json['credits_used'], // ← ADDED
      creditsRemaining: json['credits_remaining'], // ← ADDED
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing';
}

class VideoStream {
  final String streamUrl;
  final String? hlsUrl;
  final String? mp4Url;
  final Map<String, String> qualities;
  final Duration? duration;
  final String? thumbnailUrl;

  VideoStream({
    required this.streamUrl,
    this.hlsUrl,
    this.mp4Url,
    this.qualities = const {},
    this.duration,
    this.thumbnailUrl,
  });

  factory VideoStream.fromJson(Map<String, dynamic> json) {
    final qualitiesMap = <String, String>{};
    if (json['qualities'] is Map) {
      (json['qualities'] as Map).forEach((key, value) {
        qualitiesMap[key.toString()] = value.toString();
      });
    }

    Duration? parsedDuration;
    if (json['duration'] != null && json['duration'] is num) {
      parsedDuration = Duration(seconds: (json['duration'] as num).toInt());
    }

    return VideoStream(
      streamUrl: json['stream_url'] ?? json['playback_url'] ?? '',
      hlsUrl: json['hls_url'],
      mp4Url: json['mp4_url'] ?? json['video_url'],
      qualities: qualitiesMap,
      duration: parsedDuration,
      thumbnailUrl: json['thumbnail_url'],
    );
  }

  String get bestQualityUrl => mp4Url ?? hlsUrl ?? streamUrl;
}

class GeneratedVideo {
  final String id;
  final String title;
  final String status;
  final String progress;
  final DateTime createdAt;
  final String? playbackUrl;
  final String? thumbnailUrl;
  final int scenesCompleted;
  final int totalScenes;
  final Duration? duration;
  final int? fileSize;
  final int? creditsUsed; // ← ADDED

  GeneratedVideo({
    required this.id,
    required this.title,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.playbackUrl,
    this.thumbnailUrl,
    required this.scenesCompleted,
    required this.totalScenes,
    this.duration,
    this.fileSize,
    this.creditsUsed, // ← ADDED
  });

  factory GeneratedVideo.fromVideoStatus(
      VideoProcessingStatus status, String title) {
    return GeneratedVideo(
      id: status.jobId,
      title: title,
      status: status.status,
      progress: status.progress,
      createdAt: DateTime.now(),
      playbackUrl: status.playbackUrl,
      thumbnailUrl: status.thumbnailUrl,
      scenesCompleted: status.scenesCompleted,
      totalScenes: status.totalScenes,
      duration: status.duration,
      fileSize: status.fileSize,
      creditsUsed: status.creditsUsed, // ← ADDED
    );
  }

  GeneratedVideo copyWith({
    String? status,
    String? progress,
    String? playbackUrl,
    String? thumbnailUrl,
    int? scenesCompleted,
    int? totalScenes,
    Duration? duration,
    int? fileSize,
    int? creditsUsed, // ← ADDED
  }) {
    return GeneratedVideo(
      id: id,
      title: title,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      scenesCompleted: scenesCompleted ?? this.scenesCompleted,
      totalScenes: totalScenes ?? this.totalScenes,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      creditsUsed: creditsUsed ?? this.creditsUsed, // ← ADDED
    );
  }

  String get formattedDuration {
    if (duration == null) return '';

    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;

    if (minutes > 0) {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${seconds}s';
    }
  }

  String get formattedFileSize {
    if (fileSize == null) return '';

    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

class VideoGenerationService {
  static const String baseUrl = 'https://ch2vi-production.up.railway.app';
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

  /// Start video generation from chapter text with JWT authentication
  static Future<VideoProcessingStatus> generateVideoFromChapter({
    required String chapterText,
    required String chapterTitle,
    required String jwtToken, // ← ADDED
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
        jwtToken: jwtToken, // ← ADDED
      );

      print('📤 Sending request to: $baseUrl/convert-story');
      print('🔐 JWT Token length: ${jwtToken.length}');
      print('📝 Request body: ${json.encode(request.toJson())}');

      final response = await client
          .post(
        Uri.parse('$baseUrl/convert-story'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
          'Authorization': 'Bearer $jwtToken', // ← ADDED (for extra security)
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
        body: json.encode(request.toJson()),
      )
          .timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
              'Request timeout - please try again', Duration(seconds: 30));
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response headers: ${response.headers}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        final status = VideoProcessingStatus.fromJson(jsonData);

        // Log credit information
        if (status.creditsUsed != null) {
          print('💰 Credits used: ${status.creditsUsed}');
          print('💰 Credits remaining: ${status.creditsRemaining}');
        }

        return status;
      } else if (response.statusCode == 401) {
        // ← ADDED: Handle authentication errors
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 402) {
        // ← ADDED: Handle insufficient credits
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['detail'] is Map) {
            final detail = errorData['detail'] as Map<String, dynamic>;
            final required = detail['required_credits'] ?? 0;
            final available = detail['available_credits'] ?? 0;
            final scenes = detail['scene_count'] ?? 0;
            throw Exception('Insufficient credits!\n'
                'Required: $required credits ($scenes scenes × 7)\n'
                'Available: $available credits\n'
                'Please purchase ${required - available} more credits to continue.');
          } else {
            throw Exception(errorData['detail'] ?? 'Insufficient credits');
          }
        } catch (jsonError) {
          throw Exception('Insufficient credits. Please check your balance.');
        }
      } else if (response.statusCode == 405) {
        throw Exception(
            'API endpoint method not allowed. Server may be updating.');
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        // Client error
        try {
          final errorData = json.decode(response.body);
          throw Exception(
              'API Error ${response.statusCode}: ${errorData['detail'] ?? errorData['message'] ?? 'Request failed'}');
        } catch (jsonError) {
          throw Exception('API Error ${response.statusCode}: ${response.body}');
        }
      } else if (response.statusCode >= 500) {
        // Server error
        throw Exception(
            'Server Error ${response.statusCode}: The backend server is experiencing issues');
      } else {
        throw Exception(
            'Unexpected response ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException catch (e) {
      throw Exception('Request timeout - the server took too long to respond');
    } on SocketException catch (e) {
      throw Exception(
          'Network connection failed. Please check your internet connection. Details: ${e.message}');
    } on HandshakeException catch (e) {
      throw Exception(
          'SSL/TLS connection failed. Please try again. Details: ${e.message}');
    } on FormatException catch (e) {
      throw Exception(
          'Invalid response format from server. Details: ${e.message}');
    } catch (e) {
      print('❌ Error in video generation: $e');

      String errorMessage = e.toString();

      // Handle specific error types with more helpful messages
      if (errorMessage.contains('ClientException')) {
        throw Exception(
            'Network connection failed. Please check your internet connection and try again.');
      } else if (errorMessage.contains('Failed to fetch')) {
        throw Exception(
            'Unable to connect to the server. Please check your internet connection.');
      } else if (errorMessage.contains('XMLHttpRequest error')) {
        throw Exception(
            'Network request failed. This might be a CORS issue or network problem.');
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

  /// Get playback URL for video streaming
  static String getPlaybackUrl(String jobId) {
    return '$baseUrl/play/$jobId';
  }

  /// Get video stream information for in-app playback
  static Future<VideoStream> getVideoStream(String jobId) async {
    final client = _createHttpClient();

    try {
      final response = await client.get(
        Uri.parse('$baseUrl/stream/$jobId'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
          'Cache-Control': 'no-cache',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return VideoStream.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw Exception('Video stream not found');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get video stream');
      }
    } on SocketException catch (e) {
      throw Exception('Network connection failed: ${e.message}');
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  /// Get video metadata (duration, thumbnail, etc.)
  static Future<Map<String, dynamic>> getVideoMetadata(String jobId) async {
    final client = _createHttpClient();

    try {
      final response = await client.get(
        Uri.parse('$baseUrl/metadata/$jobId'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {};
      }
    } catch (e) {
      print('Warning: Failed to get video metadata for $jobId: $e');
      return {};
    } finally {
      client.close();
    }
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
          response = await client
              .post(
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
                  'jwt_token': 'test_token_for_endpoint_check', // ← ADDED
                }),
              )
              .timeout(Duration(seconds: 15));
        }

        results[endpoint] = {
          'status': response.statusCode,
          'method': method,
          'available': response.statusCode < 400,
          'headers': response.headers.toString(),
          'body': response.body.length > 300
              ? '${response.body.substring(0, 300)}...'
              : response.body,
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
