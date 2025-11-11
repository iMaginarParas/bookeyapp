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

  // Story API (FIXED - correct endpoint)
  static const String storyApiUrl = 'https://stboo-production-cd4e.up.railway.app';
  
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
      print('🚀 Starting story generation...');
      print('📡 Story API URL: $storyApiUrl');
      
      final uri = Uri.parse('$storyApiUrl/generate-story');
      print('🎯 Full endpoint: $uri');
      print('📦 Request payload: ${json.encode(request.toJson())}');
      
      // Check API health first
      print('🔍 Checking story API health...');
      final healthCheck = await checkStoryApiHealth();
      print('❤️ Story API health status: $healthCheck');
      
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'Bookey-Flutter-App/1.0',
            },
            body: json.encode(request.toJson()),
          )
          .timeout(Duration(seconds: timeoutSeconds));

      print('📊 Response status code: ${response.statusCode}');
      print('📋 Response headers: ${response.headers}');
      print('📄 Response body preview: ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          print('✅ Successfully parsed JSON response');
          final storyResponse = StoryResponse.fromJson(jsonData);
          print('📚 Story generated successfully: ${storyResponse.title}');
          return ProcessingResult.fromStoryResponse(storyResponse);
        } catch (parseError) {
          print('❌ JSON parsing error: $parseError');
          throw Exception('Failed to parse story response: $parseError');
        }
      } else {
        print('❌ API request failed with status: ${response.statusCode}');
        try {
          final errorData = json.decode(response.body);
          print('📝 Error details: $errorData');
          throw Exception(errorData['detail'] ?? errorData['message'] ?? 'Story generation failed with status ${response.statusCode}');
        } catch (parseError) {
          print('❌ Could not parse error response: $parseError');
          throw Exception('Story generation failed: HTTP ${response.statusCode} - ${response.body}');
        }
      }
    } on TimeoutException catch (e) {
      print('⏰ Request timeout: $e');
      throw Exception('Request timed out after $timeoutSeconds seconds. Please check your internet connection and try again.');
    } on SocketException catch (e) {
      print('🌐 Network error: $e');
      throw Exception('Network connection failed. Please check your internet connection and try again.');
    } on FormatException catch (e) {
      print('📋 Format error: $e');
      throw Exception('Invalid response format from server: $e');
    } catch (e) {
      print('💥 Unexpected error: $e');
      print('🔍 Error type: ${e.runtimeType}');
      throw Exception('Story generation error: ${e.toString()}');
    }
  }

  static Future<bool> checkStoryApiHealth() async {
    try {
      print('🔍 Checking story API health at: $storyApiUrl/health');
      final response = await http.get(
        Uri.parse('$storyApiUrl/health'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(Duration(seconds: 10));
      
      print('❤️ Health check response: ${response.statusCode}');
      final isHealthy = response.statusCode == 200;
      
      if (isHealthy) {
        print('✅ Story API is healthy');
        print('📄 Health response: ${response.body}');
      } else {
        print('❌ Story API is unhealthy');
        print('📄 Error response: ${response.body}');
      }
      
      return isHealthy;
    } catch (e) {
      print('💥 Health check failed: $e');
      return false;
    }
  }

  /// Debug method to test story generation with a simple request
  static Future<String> debugStoryGeneration() async {
    try {
      print('🧪 Running debug story generation test...');
      
      final testRequest = StoryRequest(
        title: 'Debug Test',
        subject: 'A simple test story',
        genre: 'Fantasy',
        duration: 'Short (5-10 minutes read)',
      );
      
      final result = await generateStory(testRequest);
      return 'Debug test successful: ${result.message} - ${result.totalWords} words generated';
    } catch (e) {
      return 'Debug test failed: $e';
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

  // ================== ENHANCED IMAGE/AUDIO PROCESSING METHODS ==================

  static Future<ProcessingResult> processImages(List<File> files,
      {int maxConcurrent = 5}) async {
    try {
      // Enhanced debugging - check API health first
      print('🔍 [IMAGE] Checking API health before upload...');
      final isHealthy = await checkMediaApiHealth();
      if (!isHealthy) {
        print('❌ [IMAGE] API health check failed');
        throw Exception('Media API is not responding. Please try again later.');
      }
      print('✅ [IMAGE] API health check passed');

      final uri = Uri.parse('$mediaApiUrl/process-images');
      final request = http.MultipartRequest('POST', uri);

      // Add max_concurrent parameter
      request.fields['max_concurrent'] = maxConcurrent.toString();
      
      // Generate session ID for tracking
      final sessionId = _generateSessionId();
      request.fields['session_id'] = sessionId;

      print('📋 [IMAGE] Request details:');
      print('   URL: $uri');
      print('   Max concurrent: $maxConcurrent');
      print('   Session ID: $sessionId');
      print('   Files count: ${files.length}');

      for (int i = 0; i < files.length; i++) {
        final fileSize = await files[i].length();
        print('   File ${i + 1}: ${files[i].path.split('/').last} ($fileSize bytes)');
        
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

      print('📤 [IMAGE] Sending request to: $uri');
      final streamedResponse = 
          await request.send().timeout(Duration(seconds: timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 [IMAGE] Response received:');
      print('   Status: ${response.statusCode}');
      print('   Headers: ${response.headers}');
      print('   Body length: ${response.body.length} chars');
      print('   Body preview: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          print('✅ [IMAGE] Successfully parsed JSON response');
          return ProcessingResult.fromNewApiResponse(jsonData);
        } catch (e) {
          print('❌ [IMAGE] JSON parsing failed: $e');
          print('Raw response: ${response.body}');
          throw Exception('Invalid JSON response from server: $e');
        }
      } else {
        print('❌ [IMAGE] HTTP error: ${response.statusCode}');
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['detail'] ?? errorData['message'] ?? 'Failed to process images';
          throw Exception('Server error: $errorMsg');
        } catch (e) {
          throw Exception('Server error ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      print('💥 [IMAGE] Processing error: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timeout after ${timeoutSeconds}s. Try with smaller files or check your connection.');
      } else if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        throw Exception('Cannot connect to server. Check your internet connection.');
      } else {
        throw Exception('Image processing error: ${e.toString()}');
      }
    }
  }

  static Future<ProcessingResult> processImagesWeb(List<PlatformFile> webFiles,
      {int maxConcurrent = 5}) async {
    try {
      // Enhanced debugging - check API health first
      print('🔍 [IMAGE WEB] Checking API health before upload...');
      final isHealthy = await checkMediaApiHealth();
      if (!isHealthy) {
        print('❌ [IMAGE WEB] API health check failed');
        throw Exception('Media API is not responding. Please try again later.');
      }
      print('✅ [IMAGE WEB] API health check passed');

      final uri = Uri.parse('$mediaApiUrl/process-images');
      final request = http.MultipartRequest('POST', uri);

      // Add max_concurrent parameter
      request.fields['max_concurrent'] = maxConcurrent.toString();
      
      // Generate session ID for tracking
      final sessionId = _generateSessionId();
      request.fields['session_id'] = sessionId;

      print('📋 [IMAGE WEB] Request details:');
      print('   URL: $uri');
      print('   Max concurrent: $maxConcurrent');
      print('   Session ID: $sessionId');
      print('   Files count: ${webFiles.length}');

      for (int i = 0; i < webFiles.length; i++) {
        final webFile = webFiles[i];
        if (webFile.bytes == null || webFile.bytes!.isEmpty) {
          throw Exception('File ${webFile.name} has no content');
        }
        
        print('   File ${i + 1}: ${webFile.name} (${webFile.bytes!.length} bytes)');
        
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

      print('📤 [IMAGE WEB] Sending request to: $uri');
      final streamedResponse = 
          await request.send().timeout(Duration(seconds: timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 [IMAGE WEB] Response received:');
      print('   Status: ${response.statusCode}');
      print('   Headers: ${response.headers}');
      print('   Body length: ${response.body.length} chars');
      print('   Body preview: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          
          if (jsonData == null) {
            throw Exception('Received null response from server');
          }

          print('✅ [IMAGE WEB] Successfully parsed JSON response');
          return ProcessingResult.fromNewApiResponse(jsonData);
        } catch (e) {
          print('❌ [IMAGE WEB] JSON parsing failed: $e');
          print('Raw response: ${response.body}');
          throw Exception('Invalid JSON response from server: $e');
        }
      } else {
        print('❌ [IMAGE WEB] HTTP error: ${response.statusCode}');
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['detail'] ?? errorData['message'] ?? 'Failed to process images';
          throw Exception('Server error: $errorMsg');
        } catch (e) {
          throw Exception('Server error ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      print('💥 [IMAGE WEB] Processing error: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timeout after ${timeoutSeconds}s. Try with smaller files or check your connection.');
      } else if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        throw Exception('Cannot connect to server. Check your internet connection.');
      } else {
        throw Exception('Image processing error: ${e.toString()}');
      }
    }
  }

  static Future<ProcessingResult> processCameraImages(List<String> base64Images,
      {int maxConcurrent = 5}) async {
    try {
      print('🔍 [CAMERA] Starting camera image processing...');
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

      print('📤 [CAMERA] Sending request to: $uri');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
        body: formData,
      ).timeout(Duration(seconds: timeoutSeconds));

      print('📥 [CAMERA] Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ProcessingResult.fromNewApiResponse(jsonData);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
            errorData['detail'] ?? 'Failed to process camera images');
      }
    } catch (e) {
      print('💥 [CAMERA] Error: $e');
      throw Exception('Camera processing error: ${e.toString()}');
    }
  }

  static Future<ProcessingResult?> processAudio(
      File? file, PlatformFile? webFile,
      {int maxConcurrent = 3}) async {
    try {
      // Enhanced debugging - check API health first
      print('🔍 [AUDIO] Checking audio API health...');
      final isHealthy = await checkMediaApiHealth();
      if (!isHealthy) {
        print('❌ [AUDIO] API health check failed');
        throw Exception('Media processing API is currently unavailable. Please try again later.');
      }
      print('✅ [AUDIO] API health check passed');

      final uri = Uri.parse('$mediaApiUrl/process-audio');
      final request = http.MultipartRequest('POST', uri);

      // Add max_concurrent parameter (not really used for audio but API expects it)
      request.fields['max_concurrent'] = maxConcurrent.toString();
      
      // Generate session ID for tracking
      final sessionId = _generateSessionId();
      request.fields['session_id'] = sessionId;

      print('📋 [AUDIO] Request details:');
      print('   URL: $uri');
      print('   Session ID: $sessionId');

      if (kIsWeb && webFile != null) {
        // Check file size for web
        if (webFile.bytes != null && webFile.bytes!.length > 50 * 1024 * 1024) {
          throw Exception('File size too large. Maximum size is 50MB');
        }

        print('   Web file: ${webFile.name} (${webFile.bytes?.length ?? 0} bytes)');

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

        print('   Mobile file: ${file.path} ($fileSize bytes)');

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

      print('📤 [AUDIO] Sending audio processing request to: $uri');

      final streamedResponse = await request.send().timeout(
        Duration(seconds: 180), // 3 minutes timeout for audio processing
        onTimeout: () {
          throw Exception('Audio processing timeout. Large files may take several minutes to process.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('📥 [AUDIO] Response received:');
      print('   Status: ${response.statusCode}');
      print('   Headers: ${response.headers}');
      print('   Body length: ${response.body.length} chars');
      print('   Body preview: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          print('✅ [AUDIO] Successfully parsed audio JSON response');
          return ProcessingResult.fromNewApiResponse(jsonData);
        } catch (e) {
          print('❌ [AUDIO] JSON parsing failed: $e');
          print('Raw response: ${response.body}');
          throw Exception('Invalid JSON response from server: $e');
        }
      } else if (response.statusCode == 413) {
        throw Exception('Audio file is too large. Please use a smaller file (max 50MB).');
      } else if (response.statusCode == 422) {
        try {
          final errorData = json.decode(response.body);
          throw Exception('Invalid audio format: ${errorData['detail'] ?? 'Unsupported audio file'}');
        } catch (e) {
          throw Exception('Invalid audio format or server error');
        }
      } else {
        print('❌ [AUDIO] HTTP error: ${response.statusCode}');
        String errorMessage;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['detail'] ?? errorData['message'] ?? 'Failed to process audio';
          throw Exception('Server error: $errorMessage');
        } catch (e) {
          errorMessage = 'Server returned status ${response.statusCode}';
          throw Exception('$errorMessage: ${response.body}');
        }
      }
    } on TimeoutException {
      throw Exception('Request timeout. Audio processing takes time for large files. Please try again.');
    } catch (e) {
      print('💥 [AUDIO] Processing error: $e');
      if (e.toString().contains('Connection reset by peer') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed to fetch')) {
        throw Exception('Unable to connect to audio processing server. Check your internet connection.');
      }

      throw Exception('Audio processing error: ${e.toString()}');
    }
  }

  static Future<bool> checkMediaApiHealth() async {
    try {
      print('🏥 [HEALTH] Checking media API health: $mediaApiUrl/health');
      
      final response = await http.get(
        Uri.parse('$mediaApiUrl/health'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(Duration(seconds: 10));

      print('🏥 [HEALTH] Response: ${response.statusCode}');
      print('🏥 [HEALTH] Body: ${response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ [HEALTH] Failed: $e');
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