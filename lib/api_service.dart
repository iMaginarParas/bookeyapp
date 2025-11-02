import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

// ================== NEW MODELS FOR NEW APIS ==================

// Story Generator Models (unchanged)
class StoryRequest {
  final String title;
  final String subject;
  final String? characters;
  final String? context;
  final String duration;
  final String genre;

  StoryRequest({
    required this.title,
    required this.subject,
    this.characters,
    this.context,
    this.duration = "Medium (10-20 minutes read)",
    this.genre = "Fantasy",
  });

  Map<String, dynamic> toJson() {
    final requestData = {
      'title': title,
      'subject': subject,
    };

    if (characters != null && characters!.trim().isNotEmpty) {
      requestData['characters'] = characters!.trim();
    }

    if (context != null && context!.trim().isNotEmpty) {
      requestData['context'] = context!.trim();
    }

    // Send the exact values as they appear in the UI dropdowns
    // DO NOT map them to enums - send them as-is
    requestData['duration'] = duration; // "Short (5-10 minutes read)"
    requestData['genre'] = genre; // "Drama"

    print('Request payload: $requestData');
    return requestData;
  }
}

class StoryResponse {
  final bool success;
  final String title;
  final String genre;
  final String estimatedReadingTime;
  final int wordCount;
  final String story;
  final Map<String, dynamic> metadata;
  final double generationTimeSeconds;

  StoryResponse({
    required this.success,
    required this.title,
    required this.genre,
    required this.estimatedReadingTime,
    required this.wordCount,
    required this.story,
    required this.metadata,
    required this.generationTimeSeconds,
  });

  factory StoryResponse.fromJson(Map<String, dynamic> json) {
    return StoryResponse(
      success: json['success'] ?? false,
      title: json['title'] ?? '',
      genre: json['genre'] ?? '',
      estimatedReadingTime: json['estimated_reading_time'] ?? '',
      wordCount: json['word_count'] ?? 0,
      story: json['story'] ?? '',
      metadata: json['metadata'] ?? {},
      generationTimeSeconds:
          (json['generation_time_seconds'] ?? 0.0).toDouble(),
    );
  }
}

// Updated existing models (keep existing PageBatchModel for compatibility)
class PageBatchModel {
  final int batchNumber;
  final String pageRange;
  final String cleanedText;
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

  // Factory constructor to convert from new API page response
  factory PageBatchModel.fromNewPageResponse(Map<String, dynamic> page) {
    return PageBatchModel(
      batchNumber: page['page_number'] ?? 1,
      pageRange: (page['page_number'] ?? 1).toString(),
      cleanedText: page['cleaned_text'] ?? page['text'] ?? '',
      wordCount: page['word_count'] ?? 0,
      cleaned: page['cleaned'] ?? false,
      pagesInBatch: 1,
    );
  }

  // Factory constructor to convert from new API part response
  factory PageBatchModel.fromNewPartResponse(Map<String, dynamic> part) {
    return PageBatchModel(
      batchNumber: part['part_number'] ?? 1,
      pageRange: "Part ${part['part_number'] ?? 1}",
      cleanedText: part['cleaned_text'] ?? part['text'] ?? '',
      wordCount: part['word_count'] ?? 0,
      cleaned: part['cleaned'] ?? false,
      pagesInBatch: 1,
    );
  }

  // Factory constructor to convert from StoryResponse
  factory PageBatchModel.fromStoryResponse(StoryResponse story) {
    return PageBatchModel(
      batchNumber: 1,
      pageRange: "Full Story",
      cleanedText: story.story,
      wordCount: story.wordCount,
      cleaned: true, // Stories are AI-generated, so considered "cleaned"
      pagesInBatch: 1,
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

  // Factory constructor to convert from new API response format
  factory ProcessingResult.fromNewApiResponse(Map<String, dynamic> json) {
    List<PageBatchModel> batches = [];

    if (json['pages'] != null) {
      // Image processing response - convert pages to page batches
      batches = (json['pages'] as List)
          .map((page) => PageBatchModel.fromNewPageResponse(page))
          .toList();
    } else if (json['parts'] != null) {
      // Audio processing response - convert parts to page batches
      batches = (json['parts'] as List)
          .map((part) => PageBatchModel.fromNewPartResponse(part))
          .toList();
    }

    return ProcessingResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      fileName: json['file_name'] ?? 'Processed Content',
      totalPageBatches: json['total_items'] ?? batches.length,
      totalWords: json['total_words'] ?? 0,
      estimatedReadingTimeMinutes: 
          (json['estimated_reading_time_minutes'] ?? 0.0).toDouble(),
      pageBatches: batches,
      processingTimeSeconds: 
          (json['processing_time_seconds'] ?? 0.0).toDouble(),
    );
  }

  // Factory constructor to convert from StoryResponse
  factory ProcessingResult.fromStoryResponse(StoryResponse story) {
    final batch = PageBatchModel.fromStoryResponse(story);

    return ProcessingResult(
      success: story.success,
      message: "Story generated successfully",
      fileName: story.title,
      totalPageBatches: 1,
      totalWords: story.wordCount,
      estimatedReadingTimeMinutes:
          story.wordCount / 200.0, // 200 words per minute
      pageBatches: [batch],
      processingTimeSeconds: story.generationTimeSeconds,
    );
  }
}

class ApiService {
  // Existing PDF processing endpoints (unchanged)
  static const String baseUrl = 'https://bookey-pdf-production.up.railway.app';

  // Story API (unchanged)
  static const String storyApiUrl = 'https://stboo-production.up.railway.app';
  
  // NEW: Unified Media API endpoint
  static const String mediaApiUrl = 'https://imgbooc-production.up.railway.app';

  static const int timeoutSeconds = 300;

  // ================== EXISTING PDF METHODS (unchanged) ==================

  static Future<ProcessingResult> processPdf(
      File? file, PlatformFile? webFile) async {
    try {
      final uri = Uri.parse('$baseUrl/process-pdf');
      final request = http.MultipartRequest('POST', uri);

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

      request.headers.addAll({'Accept': 'application/json'});
      final streamedResponse =
          await request.send().timeout(Duration(seconds: timeoutSeconds));
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

  static Future<ProcessingResult> processPdfWithAI(
      File? file, PlatformFile? webFile,
      {int maxConcurrent = 5}) async {
    try {
      final uri = Uri.parse(
          '$baseUrl/process-pdf-with-ai?max_concurrent=$maxConcurrent');
      final request = http.MultipartRequest('POST', uri);

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

      request.headers.addAll({'Accept': 'application/json'});
      final streamedResponse =
          await request.send().timeout(Duration(seconds: timeoutSeconds));
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

  // ================== EXISTING STORY GENERATION METHODS (unchanged) ==================

  static Future<ProcessingResult> generateStory(StoryRequest request) async {
    try {
      final uri = Uri.parse('$storyApiUrl/generate-story');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(request.toJson()),
          )
          .timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final storyResponse = StoryResponse.fromJson(jsonData);
        return ProcessingResult.fromStoryResponse(storyResponse);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to generate story');
      }
    } catch (e) {
      throw Exception('Story generation error: ${e.toString()}');
    }
  }

  static Future<bool> checkStoryApiHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$storyApiUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, String>>> getAvailableGenres() async {
    try {
      final response = await http.get(
        Uri.parse('$storyApiUrl/genres'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return (jsonData['genres'] as List)
            .map((genre) => {
                  'value': genre['value'].toString(),
                  'label': genre['label'].toString(),
                })
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, String>>> getAvailableDurations() async {
    try {
      final response = await http.get(
        Uri.parse('$storyApiUrl/durations'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return (jsonData['durations'] as List)
            .map((duration) => {
                  'value': duration['value'].toString(),
                  'label': duration['label'].toString(),
                })
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ================== UPDATED IMAGE/AUDIO PROCESSING METHODS ==================

  static Future<ProcessingResult> processImages(List<File> files,
      {int maxConcurrent = 5}) async {
    try {
      final uri = Uri.parse('$mediaApiUrl/process-images');
      final request = http.MultipartRequest('POST', uri);

      // Add max_concurrent parameter
      request.fields['max_concurrent'] = maxConcurrent.toString();
      
      // Generate session ID for tracking
      final sessionId = _generateSessionId();
      request.fields['session_id'] = sessionId;

      for (int i = 0; i < files.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            files[i].path,
            filename: files[i].path.split('/').last,
          ),
        );
      }

      request.headers.addAll({
        'Accept': 'application/json',
        'User-Agent': 'Bookey-Flutter-App/1.0',
      });

      print('Sending images to unified API: $mediaApiUrl/process-images');
      final streamedResponse = 
          await request.send().timeout(Duration(seconds: timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      print('Image API Response Status: ${response.statusCode}');
      print('Image API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ProcessingResult.fromNewApiResponse(jsonData);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to process images');
      }
    } catch (e) {
      print('Image processing error: $e');
      throw Exception('Image processing error: ${e.toString()}');
    }
  }

  static Future<ProcessingResult> processImagesWeb(List<PlatformFile> webFiles,
      {int maxConcurrent = 5}) async {
    try {
      final uri = Uri.parse('$mediaApiUrl/process-images');
      final request = http.MultipartRequest('POST', uri);

      // Add max_concurrent parameter
      request.fields['max_concurrent'] = maxConcurrent.toString();
      
      // Generate session ID for tracking
      final sessionId = _generateSessionId();
      request.fields['session_id'] = sessionId;

      for (var webFile in webFiles) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            webFile.bytes!,
            filename: webFile.name,
          ),
        );
      }

      request.headers.addAll({
        'Accept': 'application/json',
        'User-Agent': 'Bookey-Flutter-App/1.0',
      });

      print('Sending web images to unified API: $mediaApiUrl/process-images');
      final streamedResponse = 
          await request.send().timeout(Duration(seconds: timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      print('Image API Response Status: ${response.statusCode}');
      print('Image API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        // Add null checks here
        if (jsonData == null) {
          throw Exception('Received null response from server');
        }

        return ProcessingResult.fromNewApiResponse(jsonData);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to process images');
      }
    } catch (e) {
      print('Image processing error: $e');
      throw Exception('Image processing error: ${e.toString()}');
    }
  }

  static Future<ProcessingResult> processCameraImages(List<String> base64Images,
      {int maxConcurrent = 5}) async {
    try {
      final uri = Uri.parse('$mediaApiUrl/camera-capture');
      
      // Create form data
      final Map<String, dynamic> formData = {
        'max_concurrent': maxConcurrent.toString(),
        'session_id': _generateSessionId(),
      };
      
      // Add images as form field
      for (int i = 0; i < base64Images.length; i++) {
        formData['images'] = base64Images;
      }

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
        body: formData,
      ).timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ProcessingResult.fromNewApiResponse(jsonData);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
            errorData['detail'] ?? 'Failed to process camera images');
      }
    } catch (e) {
      throw Exception('Camera processing error: ${e.toString()}');
    }
  }

  static Future<ProcessingResult?> processAudio(
      File? file, PlatformFile? webFile,
      {int maxConcurrent = 3}) async {
    try {
      // First check if the media API is healthy
      final isHealthy = await checkMediaApiHealth();
      if (!isHealthy) {
        throw Exception(
            'Media processing API is currently unavailable. Please try again later.');
      }

      final uri = Uri.parse('$mediaApiUrl/process-audio');
      final request = http.MultipartRequest('POST', uri);

      // Add max_concurrent parameter (not really used for audio but API expects it)
      request.fields['max_concurrent'] = maxConcurrent.toString();
      
      // Generate session ID for tracking
      final sessionId = _generateSessionId();
      request.fields['session_id'] = sessionId;

      if (kIsWeb && webFile != null) {
        // Check file size for web
        if (webFile.bytes != null && webFile.bytes!.length > 50 * 1024 * 1024) {
          throw Exception('File size too large. Maximum size is 50MB');
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            webFile.bytes!,
            filename: webFile.name,
          ),
        );
      } else if (file != null) {
        // Check file size for mobile
        final fileSize = await file.length();
        if (fileSize > 50 * 1024 * 1024) {
          throw Exception('File size too large. Maximum size is 50MB');
        }

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
        'User-Agent': 'Bookey-Flutter-App/1.0',
      });

      print('Sending audio processing request to: $uri');

      final streamedResponse = await request.send().timeout(
        Duration(seconds: 180), // 3 minutes timeout for audio processing
        onTimeout: () {
          throw Exception(
              'Audio processing timeout. Large files may take several minutes to process.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('Audio API Response Status: ${response.statusCode}');
      print('Audio API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ProcessingResult.fromNewApiResponse(jsonData);
      } else if (response.statusCode == 413) {
        throw Exception(
            'Audio file is too large. Please use a smaller file (max 50MB).');
      } else if (response.statusCode == 422) {
        final errorData = json.decode(response.body);
        throw Exception(
            'Invalid audio format: ${errorData['detail'] ?? 'Unsupported audio file'}');
      } else {
        String errorMessage;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['detail'] ?? 'Failed to process audio';
        } catch (e) {
          errorMessage = 'Server returned status ${response.statusCode}';
        }
        throw Exception(errorMessage);
      }
    } on TimeoutException {
      throw Exception(
          'Request timeout. Audio processing takes time for large files. Please try again.');
    } catch (e) {
      if (e.toString().contains('Connection reset by peer') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed to fetch')) {
        throw Exception(
            'Unable to connect to audio processing server. Please check your internet connection and try again.');
      }

      throw Exception('Audio processing error: ${e.toString()}');
    }
  }

  static Future<bool> checkMediaApiHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$mediaApiUrl/health'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(Duration(seconds: 10));

      print('Media API Health Check Status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Media API Health Check Failed: $e');
      return false;
    }
  }

  // ================== EXISTING HEALTH CHECK METHODS ==================

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

  // ================== HELPER METHODS ==================

  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'session_${timestamp}_${timestamp.hashCode.abs().toString().substring(0, 6)}';
  }
}