import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

// Updated model to match backend's page batch structure
class PageBatchModel {
  final int batchNumber;
  final String pageRange;
  final String cleanedText; // Only cleaned text now
  final int wordCount;
  final bool cleaned;
  final int pagesInBatch;

  PageBatchModel({
    required this.batchNumber,
    required this.pageRange,
    required this.cleanedText,
    required this.wordCount,
    required this.cleaned,
    required this.pagesInBatch,
  });

  factory PageBatchModel.fromJson(Map<String, dynamic> json) {
    return PageBatchModel(
      batchNumber: json['batch_number'] ?? 0,
      pageRange: json['page_range'] ?? '',
      cleanedText: json['cleaned_text'] ?? '',
      wordCount: json['word_count'] ?? 0,
      cleaned: json['cleaned'] ?? false,
      pagesInBatch: json['pages_in_batch'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'batch_number': batchNumber,
      'page_range': pageRange,
      'cleaned_text': cleanedText,
      'word_count': wordCount,
      'cleaned': cleaned,
      'pages_in_batch': pagesInBatch,
    };
  }

  String get displayText => cleanedText;
  String get displayTitle => 'Pages $pageRange';
}

class ProcessingResult {
  final bool success;
  final String message;
  final String fileName;
  final int totalPageBatches;
  final int totalWords;
  final double estimatedReadingTimeMinutes;
  final List<PageBatchModel> pageBatches;
  final double processingTimeSeconds;
  final double? memoryUsageMb;
  final int? pagesProcessed;
  final int? storyStartPage;

  ProcessingResult({
    required this.success,
    required this.message,
    required this.fileName,
    required this.totalPageBatches,
    required this.totalWords,
    required this.estimatedReadingTimeMinutes,
    required this.pageBatches,
    required this.processingTimeSeconds,
    this.memoryUsageMb,
    this.pagesProcessed,
    this.storyStartPage,
  });

  factory ProcessingResult.fromJson(Map<String, dynamic> json) {
    return ProcessingResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      fileName: json['file_name'] ?? '',
      totalPageBatches: json['total_page_batches'] ?? 0,
      totalWords: json['total_words'] ?? 0,
      estimatedReadingTimeMinutes:
          (json['estimated_reading_time_minutes'] ?? 0.0).toDouble(),
      pageBatches: (json['page_batches'] as List<dynamic>?)
              ?.map((batch) => PageBatchModel.fromJson(batch))
              .toList() ??
          [],
      processingTimeSeconds:
          (json['processing_time_seconds'] ?? 0.0).toDouble(),
      memoryUsageMb: json['memory_usage_mb']?.toDouble(),
      pagesProcessed: json['pages_processed'],
      storyStartPage: json['story_start_page'],
    );
  }
}

class ApiService {
  static const String baseUrl = 'https://bookey-pdf-production.up.railway.app';
  static const int timeoutSeconds = 300;

  /// Process PDF without AI cleaning (faster)
  static Future<ProcessingResult> processPdf(
      File? file, PlatformFile? webFile) async {
    try {
      final uri = Uri.parse('$baseUrl/process-pdf');
      final request = http.MultipartRequest('POST', uri);

      // Add file to request
      if (kIsWeb && webFile != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            webFile.bytes!,
            filename: webFile.name,
          ),
        );
      } else if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            filename: file.path.split('/').last,
          ),
        );
      } else {
        throw Exception('No file provided');
      }

      request.headers.addAll({
        'Accept': 'application/json',
      });

      final streamedResponse = await request.send().timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          throw Exception(
              'Request timeout. The file might be too large or the server is busy.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ProcessingResult.fromJson(jsonData);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to process PDF');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Process PDF with AI cleaning (slower but better quality)
  static Future<ProcessingResult> processPdfWithAI(
    File? file,
    PlatformFile? webFile, {
    int maxConcurrent = 5,
  }) async {
    try {
      final uri = Uri.parse(
          '$baseUrl/process-pdf-with-ai?max_concurrent=$maxConcurrent');
      final request = http.MultipartRequest('POST', uri);

      // Add file to request
      if (kIsWeb && webFile != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            webFile.bytes!,
            filename: webFile.name,
          ),
        );
      } else if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            filename: file.path.split('/').last,
          ),
        );
      } else {
        throw Exception('No file provided');
      }

      request.headers.addAll({
        'Accept': 'application/json',
      });

      final streamedResponse = await request.send().timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          throw Exception(
              'AI processing timeout. This usually takes 2-5 minutes for large books.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ProcessingResult.fromJson(jsonData);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to process PDF with AI');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Check API health
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get API information
  static Future<Map<String, dynamic>?> getApiInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
