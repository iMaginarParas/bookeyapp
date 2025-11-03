import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Wallet models
class WalletInfo {
  final int creditsBalance;
  final int totalCreditsPurchased;
  final int totalCreditsUsed;
  final int monthlySpent;
  final int monthlyAdded;
  final int transactionCount;
  final PricingStructure pricingStructure;

  WalletInfo({
    required this.creditsBalance,
    required this.totalCreditsPurchased,
    required this.totalCreditsUsed,
    required this.monthlySpent,
    required this.monthlyAdded,
    required this.transactionCount,
    required this.pricingStructure,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      creditsBalance: json['credits_balance'] ?? 0,
      totalCreditsPurchased: json['total_credits_purchased'] ?? 0,
      totalCreditsUsed: json['total_credits_used'] ?? 0,
      monthlySpent: json['monthly_spent'] ?? 0,
      monthlyAdded: json['monthly_added'] ?? 0,
      transactionCount: json['transaction_count'] ?? 0,
      pricingStructure: PricingStructure.fromJson(json['pricing_structure'] ?? {}),
    );
  }
}

class PricingStructure {
  final int imageGeneration;
  final int audioGeneration;
  final int videoProcessing;
  final int serviceFee;
  final int totalPerScene;

  PricingStructure({
    required this.imageGeneration,
    required this.audioGeneration,
    required this.videoProcessing,
    required this.serviceFee,
    required this.totalPerScene,
  });

  factory PricingStructure.fromJson(Map<String, dynamic> json) {
    final perScene = json['per_scene'] ?? {};
    return PricingStructure(
      imageGeneration: perScene['image_generation'] ?? 2,
      audioGeneration: perScene['audio_generation'] ?? 2,
      videoProcessing: perScene['video_processing'] ?? 2,
      serviceFee: perScene['service_fee'] ?? 1,
      totalPerScene: perScene['total_per_scene'] ?? 7,
    );
  }
}

class CreditTransaction {
  final String transactionType;
  final String operation;
  final int amount;
  final String description;
  final DateTime createdAt;

  CreditTransaction({
    required this.transactionType,
    required this.operation,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      transactionType: json['transaction_type'] ?? '',
      operation: json['operation'] ?? '',
      amount: json['amount'] ?? 0,
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  bool get isCredit => operation == 'add';
  Color get amountColor => isCredit ? Color(0xFF10B981) : Color(0xFFEF4444);
  String get formattedAmount => isCredit ? '+$amount' : '-$amount';
}

// Wallet Service
class WalletService {
  static const String baseUrl = 'https://ch2vi-production.up.railway.app';
  static const Duration timeoutDuration = Duration(seconds: 15);

  /// Get wallet information including balance and transaction history
  static Future<WalletInfo?> getWalletInfo(String jwtToken) async {
    try {
      print('💰 Getting wallet info...');
      final client = http.Client();
      
      final response = await client.get(
        Uri.parse('$baseUrl/wallet'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(timeoutDuration);

      client.close();

      print('💰 Wallet response: ${response.statusCode}');
      print('💰 Wallet response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return WalletInfo.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else {
        print('Failed to get wallet info: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting wallet info: $e');
      return null;
    }
  }

  /// Get transaction history
  static Future<List<CreditTransaction>> getTransactionHistory(String jwtToken, {int limit = 50}) async {
    try {
      print('📝 Getting transaction history...');
      final client = http.Client();
      
      final response = await client.get(
        Uri.parse('$baseUrl/wallet/transactions?limit=$limit'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(timeoutDuration);

      client.close();

      print('📝 Transactions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final transactions = (jsonData['transactions'] as List)
            .map((transaction) => CreditTransaction.fromJson(transaction))
            .toList();
        return transactions;
      } else {
        print('Failed to get transaction history: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting transaction history: $e');
      return [];
    }
  }

  /// Add credits to account (for testing or admin purposes)
  static Future<bool> addCredits(String jwtToken, int amount, String description) async {
    try {
      print('💳 Adding $amount credits...');
      final client = http.Client();
      
      final response = await client.post(
        Uri.parse('$baseUrl/wallet/add-credits'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
        body: json.encode({
          'amount': amount,
          'description': description,
        }),
      ).timeout(timeoutDuration);

      client.close();

      print('💳 Add credits response: ${response.statusCode}');
      print('💳 Add credits response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Error adding credits: $e');
      return false;
    }
  }
}

// Models for video generation API
class VideoRequest {
  final String text;
  final String title;
  final bool animateAll;
  final bool mergeFinal;
  final String jwtToken;

  VideoRequest({
    required this.text,
    required this.title,
    this.animateAll = true,
    this.mergeFinal = true,
    required this.jwtToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'title': title,
      'animate_all': animateAll,
      'merge_final': mergeFinal,
      'jwt_token': jwtToken,
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
  final String? videoId;
  final int? creditsUsed;
  final int? creditsRemaining;

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
    this.videoId,
    this.creditsUsed,
    this.creditsRemaining,
  });

  factory VideoProcessingStatus.fromJson(Map<String, dynamic> json) {
    Duration? parsedDuration;
    if (json['duration'] != null) {
      if (json['duration'] is num) {
        parsedDuration = Duration(seconds: (json['duration'] as num).toInt());
      } else if (json['duration'] is String) {
        try {
          final parts = json['duration'].split(':');
          if (parts.length == 3) {
            final hours = int.parse(parts[0]);
            final minutes = int.parse(parts[1]);
            final seconds = double.parse(parts[2]).toInt();
            parsedDuration = Duration(hours: hours, minutes: minutes, seconds: seconds);
          }
        } catch (e) {
          print('Error parsing duration: $e');
        }
      }
    }

    return VideoProcessingStatus(
      jobId: json['job_id'] ?? json['id'] ?? '',
      status: json['status'] ?? 'unknown',
      progress: json['progress'] ?? '0%',
      scenesCompleted: json['scenes_completed'] ?? 0,
      totalScenes: json['total_scenes'] ?? 0,
      playbackUrl: json['playback_url'] ?? json['video_url'],
      thumbnailUrl: json['thumbnail_url'],
      errorMessage: json['error_message'],
      duration: parsedDuration,
      fileSize: json['file_size'],
      videoId: json['video_id'],
      creditsUsed: json['credits_used'],
      creditsRemaining: json['credits_remaining'],
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing';
}

class VideoStream {
  final String streamUrl;
  final String quality;
  final int bitrate;

  VideoStream({
    required this.streamUrl,
    required this.quality,
    required this.bitrate,
  });

  factory VideoStream.fromJson(Map<String, dynamic> json) {
    return VideoStream(
      streamUrl: json['stream_url'] ?? '',
      quality: json['quality'] ?? 'unknown',
      bitrate: json['bitrate'] ?? 0,
    );
  }
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
  final int? creditsUsed;

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
    this.creditsUsed,
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
      creditsUsed: status.creditsUsed,
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
    int? creditsUsed,
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
      creditsUsed: creditsUsed ?? this.creditsUsed,
    );
  }

  String get formattedDuration {
    if (duration == null) return '';

    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing';

  String get statusIcon {
    switch (status) {
      case 'completed':
        return '✅';
      case 'failed':
        return '❌';
      case 'processing':
        return '⏳';
      default:
        return '📹';
    }
  }
}

class VideoGenerationService {
  static const String baseUrl = 'https://ch2vi-production.up.railway.app';
  static const Duration timeoutDuration = Duration(seconds: 30);
  static const int maxRetries = 3;

  /// Check if the video generation API is healthy
  static Future<bool> checkHealth() async {
    try {
      print('🏥 Checking API health...');
      final client = http.Client();
      
      final response = await client.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          'accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      client.close();
      
      print('🏥 Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('🏥 Health check failed: $e');
      return false;
    }
  }

  /// Generate video with improved error handling and retry logic
  static Future<VideoProcessingStatus> generateVideoFromText({
    required String text,
    required String title,
    required String jwtToken,
    bool animateAll = true,
    bool mergeFinal = true,
  }) async {
    final client = http.Client();

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🎬 Video generation attempt $attempt/$maxRetries');
        print('📝 Title: $title');
        print('📊 Text length: ${text.length} characters');
        print('🔐 JWT Token available: ${jwtToken.isNotEmpty}');

        final request = VideoRequest(
          text: text,
          title: title,
          animateAll: animateAll,
          mergeFinal: mergeFinal,
          jwtToken: jwtToken,
        );

        final requestBody = json.encode(request.toJson());
        print('📤 Sending request to: $baseUrl/convert-story');
        print('🔐 JWT Token length: ${jwtToken.length}');
        print('📝 Request body: ${requestBody.substring(0, requestBody.length > 500 ? 500 : requestBody.length)}${requestBody.length > 500 ? '...' : ''}');

        final response = await client.post(
          Uri.parse('$baseUrl/convert-story'),
          headers: {
            'Content-Type': 'application/json',
            'accept': 'application/json',
            'Authorization': 'Bearer $jwtToken',
            'User-Agent': 'Bookey-Flutter-App/1.0',
            'Cache-Control': 'no-cache',
          },
          body: requestBody,
        ).timeout(timeoutDuration);

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
          throw Exception('Authentication failed. Please log in again.');
        } else if (response.statusCode == 402) {
          // Handle insufficient credits
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
          // Server error - check for specific wallet balance errors and implement retry logic
          String errorDetail = '';
          bool isWalletError = false;
          
          try {
            final errorData = json.decode(response.body);
            if (errorData is Map && errorData['detail'] != null) {
              errorDetail = errorData['detail'].toString();
              isWalletError = errorDetail.contains('wallet') || errorDetail.contains('balance');
            }
          } catch (jsonError) {
            // Continue with generic server error handling
          }

          // If it's a wallet error and we have retries left, wait and retry
          if (isWalletError && attempt < maxRetries) {
            print('💳 Wallet service error, retrying in ${attempt * 2} seconds...');
            await Future.delayed(Duration(seconds: attempt * 2));
            continue; // Retry the request
          }

          // Final attempt or non-wallet error
          if (isWalletError) {
            throw Exception('Wallet service is temporarily unavailable. This usually resolves within a few minutes. Please try again shortly or contact support if the issue persists.');
          } else {
            throw Exception(
                'Server Error ${response.statusCode}: The backend server is experiencing issues. Please try again in a few moments.');
          }
        } else {
          throw Exception(
              'Unexpected response ${response.statusCode}: ${response.body}');
        }
      } on TimeoutException catch (e) {
        if (attempt < maxRetries) {
          print('⏰ Request timeout, retrying in ${attempt * 2} seconds...');
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        throw Exception('Request timeout - the server took too long to respond after $maxRetries attempts');
      } on SocketException catch (e) {
        if (attempt < maxRetries) {
          print('🌐 Network error, retrying in ${attempt * 2} seconds...');
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        throw Exception(
            'Network connection failed after $maxRetries attempts. Please check your internet connection. Details: ${e.message}');
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
          if (attempt < maxRetries) {
            print('🔌 Client error, retrying in ${attempt * 2} seconds...');
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          throw Exception(
              'Network connection failed after $maxRetries attempts. Please check your internet connection and try again.');
        } else if (errorMessage.contains('Failed to fetch')) {
          if (attempt < maxRetries) {
            print('📡 Fetch error, retrying in ${attempt * 2} seconds...');
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          throw Exception(
              'Unable to connect to the server after $maxRetries attempts. Please check your internet connection.');
        } else if (errorMessage.contains('XMLHttpRequest error')) {
          throw Exception(
              'Network request failed. This might be a CORS issue or network problem.');
        } else {
          // For other errors, don't retry
          throw Exception('Network error: $errorMessage');
        }
      }
    }

    // This should never be reached due to the loop structure, but just in case
    throw Exception('All retry attempts failed');
  }

  /// Get video status with improved error handling
  static Future<VideoProcessingStatus?> getVideoStatus(String jobId) async {
    try {
      print('📊 Getting status for job: $jobId');
      final client = http.Client();
      
      final response = await client.get(
        Uri.parse('$baseUrl/status/$jobId'),
        headers: {
          'accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      client.close();

      print('📊 Status response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return VideoProcessingStatus.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        print('📊 Job not found: $jobId');
        return null;
      } else {
        print('📊 Status check failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('📊 Error getting video status: $e');
      return null;
    }
  }

  /// Get available video streams
  static Future<List<VideoStream>> getVideoStreams(String videoId) async {
    try {
      final client = http.Client();
      
      final response = await client.get(
        Uri.parse('$baseUrl/video/$videoId/streams'),
        headers: {
          'accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      client.close();

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final streams = (jsonData['streams'] as List)
            .map((stream) => VideoStream.fromJson(stream))
            .toList();
        return streams;
      } else {
        print('Failed to get video streams: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting video streams: $e');
      return [];
    }
  }

  /// Download video file (for mobile apps)
  static Future<String?> downloadVideo(String videoUrl, String fileName) async {
    try {
      if (kIsWeb) {
        // For web, we can't download files directly
        print('Video download not supported on web platform');
        return null;
      }

      // For mobile/desktop platforms
      final client = http.Client();
      final response = await client.get(Uri.parse(videoUrl));
      client.close();

      if (response.statusCode == 200) {
        // In a real implementation, you would save this to device storage
        // For now, we'll just return the URL
        print('Video downloaded successfully: $fileName');
        return videoUrl;
      } else {
        print('Failed to download video: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading video: $e');
      return null;
    }
  }
}