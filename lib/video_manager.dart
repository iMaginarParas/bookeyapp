import 'dart:async';
import 'package:flutter/material.dart';
import 'video_service.dart';

class VideoManager extends ChangeNotifier {
  static final VideoManager _instance = VideoManager._internal();
  factory VideoManager() => _instance;
  VideoManager._internal();

  final List<GeneratedVideo> _videos = [];
  final Map<String, Timer> _statusTimers = {};
  
  List<GeneratedVideo> get videos => List.unmodifiable(_videos);
  
  /// Start video generation from chapter
  Future<String> generateVideoFromChapter({
    required String chapterText,
    required String chapterTitle,
  }) async {
    try {
      // Start video generation
      final status = await VideoGenerationService.generateVideoFromChapter(
        chapterText: chapterText,
        chapterTitle: chapterTitle,
        animateAll: true,
        mergeFinal: true,
      );

      // Create video entry
      final video = GeneratedVideo.fromVideoStatus(status, chapterTitle);
      _videos.insert(0, video); // Add to beginning of list
      notifyListeners();

      // Start polling for status updates
      _startStatusPolling(status.jobId);

      return status.jobId;
    } catch (e) {
      throw Exception('Failed to start video generation: ${e.toString()}');
    }
  }

  /// Start polling for video status updates
  void _startStatusPolling(String jobId) {
    // Cancel existing timer if any
    _statusTimers[jobId]?.cancel();
    
    // Poll every 5 seconds
    _statusTimers[jobId] = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final status = await VideoGenerationService.getJobStatus(jobId);
        _updateVideoStatus(jobId, status);

        // Stop polling if completed or failed
        if (status.isCompleted || status.isFailed) {
          timer.cancel();
          _statusTimers.remove(jobId);
          
          // Clean up job resources after completion
          if (status.isCompleted) {
            // Wait a bit before cleanup to allow download if needed
            Timer(Duration(minutes: 5), () {
              VideoGenerationService.cleanupJob(jobId);
            });
          }
        }
      } catch (e) {
        print('Error polling status for job $jobId: $e');
        // Don't stop polling on individual errors, the job might still be processing
      }
    });
  }

  /// Update video status in the list
  void _updateVideoStatus(String jobId, VideoProcessingStatus status) {
    final index = _videos.indexWhere((video) => video.id == jobId);
    if (index != -1) {
      _videos[index] = _videos[index].copyWith(
        status: status.status,
        progress: status.progress,
        downloadUrl: status.downloadUrl,
        scenesCompleted: status.scenesCompleted,
        totalScenes: status.totalScenes,
      );
      notifyListeners();
    }
  }

  /// Get video by ID
  GeneratedVideo? getVideo(String jobId) {
    try {
      return _videos.firstWhere((video) => video.id == jobId);
    } catch (e) {
      return null;
    }
  }

  /// Remove video from list
  void removeVideo(String jobId) {
    _statusTimers[jobId]?.cancel();
    _statusTimers.remove(jobId);
    _videos.removeWhere((video) => video.id == jobId);
    notifyListeners();
    
    // Clean up job resources
    VideoGenerationService.cleanupJob(jobId);
  }

  /// Retry video generation
  Future<void> retryVideo(String jobId) async {
    final video = getVideo(jobId);
    if (video != null) {
      // Remove the failed video
      removeVideo(jobId);
      
      // Start new generation with same title
      await generateVideoFromChapter(
        chapterText: '', // Would need to store original text
        chapterTitle: video.title,
      );
    }
  }

  /// Manually refresh video status
  Future<void> refreshVideoStatus(String jobId) async {
    try {
      final status = await VideoGenerationService.getJobStatus(jobId);
      _updateVideoStatus(jobId, status);
    } catch (e) {
      print('Error refreshing status for job $jobId: $e');
    }
  }

  /// Get download URL for completed video
  String? getDownloadUrl(String jobId) {
    final video = getVideo(jobId);
    if (video?.status == 'completed' && video?.downloadUrl != null) {
      return VideoGenerationService.getDownloadUrl(jobId);
    }
    return null;
  }

  /// Clean up all timers when disposing
  void dispose() {
    for (final timer in _statusTimers.values) {
      timer.cancel();
    }
    _statusTimers.clear();
    super.dispose();
  }

  /// Get processing videos count
  int get processingVideosCount {
    return _videos.where((video) => video.status == 'processing').length;
  }

  /// Get completed videos count
  int get completedVideosCount {
    return _videos.where((video) => video.status == 'completed').length;
  }

  /// Get failed videos count
  int get failedVideosCount {
    return _videos.where((video) => video.status == 'failed').length;
  }
}