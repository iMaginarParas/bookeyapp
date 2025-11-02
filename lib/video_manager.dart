import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'video_service.dart';

class VideoManager extends ChangeNotifier {
  static final VideoManager _instance = VideoManager._internal();
  factory VideoManager() => _instance;
  VideoManager._internal();

  final List<GeneratedVideo> _videos = [];
  final Map<String, Timer> _statusTimers = {};
  
  List<GeneratedVideo> get videos => List.unmodifiable(_videos);
  
  /// Start video generation from chapter with JWT authentication
  Future<String> generateVideoFromChapter({
    required String chapterText,
    required String chapterTitle,
    required String jwtToken,
  }) async {
    try {
      print('🎬 VideoManager: Starting video generation');
      print('📝 Title: $chapterTitle');
      print('📊 Text length: ${chapterText.length} characters');
      print('🔐 JWT Token available: ${jwtToken.isNotEmpty}');
      
      // Start video generation with JWT token
      final status = await VideoGenerationService.generateVideoFromChapter(
        chapterText: chapterText,
        chapterTitle: chapterTitle,
        jwtToken: jwtToken,
        animateAll: true,
        mergeFinal: true,
      );

      print('✅ Video generation started successfully');
      print('🆔 Job ID: ${status.jobId}');
      if (status.creditsUsed != null) {
        print('💰 Credits used: ${status.creditsUsed}');
        print('💰 Credits remaining: ${status.creditsRemaining}');
      }
      if (status.totalScenes > 0) {
        print('🎬 Total scenes: ${status.totalScenes}');
      }

      // Create video entry
      final video = GeneratedVideo.fromVideoStatus(status, chapterTitle);
      _videos.insert(0, video); // Add to beginning of list
      notifyListeners();

      // Start polling for status updates
      _startStatusPolling(status.jobId);

      return status.jobId;
    } catch (e) {
      print('❌ VideoManager: Error starting video generation: $e');
      
      // Provide user-friendly error messages
      String errorMessage = e.toString();
      
      if (errorMessage.contains('Authentication failed') || errorMessage.contains('401')) {
        throw Exception('Authentication failed. Please log out and log back in.');
      } else if (errorMessage.contains('Insufficient credits') || errorMessage.contains('402')) {
        // Re-throw with the detailed message from the service
        throw Exception(errorMessage.replaceFirst('Exception: ', ''));
      } else if (errorMessage.contains('Network connection failed')) {
        throw Exception('Network error. Please check your internet connection and try again.');
      } else {
        throw Exception('Failed to start video generation: ${e.toString()}');
      }
    }
  }

  /// Start polling for video status updates
  void _startStatusPolling(String jobId) {
    // Cancel existing timer if any
    _statusTimers[jobId]?.cancel();
    
    print('🔄 Starting status polling for job: $jobId');
    
    // Poll every 5 seconds
    _statusTimers[jobId] = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final status = await VideoGenerationService.getJobStatus(jobId);
        
        // Log status updates
        if (status.status == 'processing') {
          print('⏳ Job $jobId: ${status.scenesCompleted}/${status.totalScenes} scenes completed');
        } else if (status.status == 'completed') {
          print('✅ Job $jobId: Completed successfully');
          if (status.playbackUrl != null) {
            print('🎥 Playback URL received: ${status.playbackUrl}');
          } else {
            print('⚠️ No playback URL in completed status');
          }
        } else if (status.status == 'failed') {
          print('❌ Job $jobId: Failed - ${status.errorMessage}');
        }
        
        _updateVideoStatus(jobId, status);

        // Stop polling if completed or failed
        if (status.isCompleted || status.isFailed) {
          print('🛑 Stopping polling for job: $jobId (Status: ${status.status})');
          timer.cancel();
          _statusTimers.remove(jobId);
          
          // Clean up job resources after completion (keep for longer for playback)
          if (status.isCompleted) {
            // Wait longer before cleanup to allow playback
            Timer(Duration(hours: 2), () {
              print('🧹 Cleaning up completed job: $jobId');
              VideoGenerationService.cleanupJob(jobId);
            });
          } else if (status.isFailed) {
            // Clean up failed jobs sooner
            Timer(Duration(minutes: 30), () {
              print('🧹 Cleaning up failed job: $jobId');
              VideoGenerationService.cleanupJob(jobId);
            });
          }
        }
      } catch (e) {
        print('⚠️ Error polling status for job $jobId: $e');
        // Don't stop polling on individual errors, the job might still be processing
        // But if we get too many errors, stop polling
        final video = getVideo(jobId);
        if (video != null && video.status == 'processing') {
          // Continue polling for processing videos
        } else {
          // Stop polling for videos that are already completed/failed
          timer.cancel();
          _statusTimers.remove(jobId);
        }
      }
    });
  }

  /// Update video status in the list
  void _updateVideoStatus(String jobId, VideoProcessingStatus status) {
    final index = _videos.indexWhere((video) => video.id == jobId);
    if (index != -1) {
      final oldStatus = _videos[index].status;
      final newStatus = status.status;
      
      _videos[index] = _videos[index].copyWith(
        status: status.status,
        progress: status.progress,
        playbackUrl: status.playbackUrl,  // ✅ CRITICAL: Store the playback URL
        scenesCompleted: status.scenesCompleted,
        totalScenes: status.totalScenes,
        creditsUsed: status.creditsUsed,
      );
      
      // Notify listeners only if status changed or it's processing
      if (oldStatus != newStatus || newStatus == 'processing') {
        notifyListeners();
      }
      
      // Log status changes with playback URL info
      if (oldStatus != newStatus) {
        print('📊 Video $jobId status changed: $oldStatus → $newStatus');
        if (status.creditsUsed != null) {
          print('💰 Credits used: ${status.creditsUsed}');
        }
        if (status.playbackUrl != null) {
          print('✅ Playback URL stored: ${status.playbackUrl?.substring(0, 100)}...');
        } else if (newStatus == 'completed') {
          print('⚠️ WARNING: Video completed but no playback URL!');
        }
      }
    } else {
      print('⚠️ Video $jobId not found in list for status update');
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
    print('🗑️ Removing video: $jobId');
    
    _statusTimers[jobId]?.cancel();
    _statusTimers.remove(jobId);
    _videos.removeWhere((video) => video.id == jobId);
    notifyListeners();
    
    // Clean up job resources
    VideoGenerationService.cleanupJob(jobId);
  }

  /// Retry video generation - REQUIRES JWT TOKEN
  Future<void> retryVideo(String jobId, String jwtToken) async {
    final video = getVideo(jobId);
    if (video != null) {
      print('🔄 Retrying video generation: ${video.title}');
      
      // Remove the failed video
      removeVideo(jobId);
      
      // Note: We can't retry without the original text
      // This is a limitation - would need to store original text
      throw Exception('Cannot retry: Original text not available. Please create a new video from the Processing tab.');
      
      // If you want to enable retry, you need to:
      // 1. Store the original chapterText in GeneratedVideo
      // 2. Then uncomment this:
      /*
      await generateVideoFromChapter(
        chapterText: video.originalText,  // Need to add this field
        chapterTitle: video.title,
        jwtToken: jwtToken,
      );
      */
    } else {
      throw Exception('Video not found');
    }
  }

  /// Manually refresh video status
  Future<void> refreshVideoStatus(String jobId) async {
    try {
      print('🔄 Manually refreshing status for job: $jobId');
      final status = await VideoGenerationService.getJobStatus(jobId);
      _updateVideoStatus(jobId, status);
      print('✅ Status refreshed successfully');
    } catch (e) {
      print('❌ Error refreshing status for job $jobId: $e');
      throw Exception('Failed to refresh status: ${e.toString()}');
    }
  }

  /// Get playback URL for completed video - SIMPLIFIED VERSION
  String? getPlaybackUrl(String jobId) {
    final video = getVideo(jobId);
    
    // Debug logging
    print('🔍 Getting playback URL for job: $jobId');
    print('🔍 Video status: ${video?.status}');
    print('🔍 Video playbackUrl: ${video?.playbackUrl}');
    
    if (video?.status == 'completed') {
      if (video?.playbackUrl != null && video!.playbackUrl!.isNotEmpty) {
        print('✅ Using direct R2 playback URL: ${video.playbackUrl?.substring(0, 100)}...');
        return video.playbackUrl;
      } else {
        print('⚠️ Video is completed but playbackUrl is null or empty');
      }
    } else {
      print('⚠️ Video is not completed yet (Status: ${video?.status})');
    }
    
    return null;
  }

  /// Get fresh playback URL from server (in case URL expired)
  Future<String?> getFreshPlaybackUrl(String jobId) async {
    try {
      print('🔄 Getting fresh playback URL from server for job: $jobId');
      
      // Get fresh status which includes fresh presigned URL
      final status = await VideoGenerationService.getJobStatus(jobId);
      
      if (status.playbackUrl != null) {
        print('✅ Fresh playback URL received: ${status.playbackUrl?.substring(0, 100)}...');
        
        // Update the stored URL
        _updateVideoStatus(jobId, status);
        
        return status.playbackUrl;
      } else {
        print('⚠️ No playback URL in fresh status response');
      }
    } catch (e) {
      print('❌ Error getting fresh playback URL: $e');
    }
    
    // Fallback to stored URL
    final video = getVideo(jobId);
    return video?.playbackUrl;
  }

  /// Get video stream for in-app playback
  Future<VideoStream?> getVideoStream(String jobId) async {
    final video = getVideo(jobId);
    if (video?.status != 'completed') {
      print('⚠️ Video $jobId is not completed yet (Status: ${video?.status})');
      return null;
    }
    
    try {
      print('📺 Getting video stream for job: $jobId');
      final stream = await VideoGenerationService.getVideoStream(jobId);
      print('✅ Video stream retrieved successfully');
      return stream;
    } catch (e) {
      print('❌ Error getting video stream for $jobId: $e');
      return null;
    }
  }

  /// Check if video is ready for playback
  bool isVideoReadyForPlayback(String jobId) {
    final video = getVideo(jobId);
    
    // Video is ready if it's completed and has a playback URL
    final isReady = video?.status == 'completed' && 
                    (video?.playbackUrl != null && video!.playbackUrl!.isNotEmpty);
    
    if (!isReady && video != null) {
      print('⚠️ Video $jobId not ready: Status=${video.status}, HasURL=${video.playbackUrl != null}');
    } else if (isReady) {
      print('✅ Video $jobId ready for playback');
    }
    
    return isReady;
  }

  /// Clean up all timers when disposing
  @override
  void dispose() {
    print('🧹 Disposing VideoManager - cleaning up ${_statusTimers.length} timers');
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

  /// Get total credits used across all videos
  int get totalCreditsUsed {
    return _videos
        .where((video) => video.creditsUsed != null)
        .fold(0, (sum, video) => sum + video.creditsUsed!);
  }

  /// Get video duration if available
  Duration? getVideoDuration(String jobId) {
    final video = getVideo(jobId);
    return video?.duration;
  }

  /// Update video with additional metadata after completion
  void updateVideoMetadata(String jobId, {
    Duration? duration,
    String? thumbnailUrl,
    int? fileSize,
    int? creditsUsed,
  }) {
    final index = _videos.indexWhere((video) => video.id == jobId);
    if (index != -1) {
      print('📝 Updating metadata for video: $jobId');
      
      _videos[index] = _videos[index].copyWith(
        duration: duration,
        thumbnailUrl: thumbnailUrl,
        fileSize: fileSize,
        creditsUsed: creditsUsed,
      );
      notifyListeners();
      
      print('✅ Metadata updated successfully');
    } else {
      print('⚠️ Video $jobId not found for metadata update');
    }
  }

  /// Get summary of all videos
  Map<String, dynamic> getVideosSummary() {
    return {
      'total_videos': _videos.length,
      'processing': processingVideosCount,
      'completed': completedVideosCount,
      'failed': failedVideosCount,
      'total_credits_used': totalCreditsUsed,
      'active_polls': _statusTimers.length,
    };
  }

  /// Print debug information
  void printDebugInfo() {
    print('=== VideoManager Debug Info ===');
    print('Total videos: ${_videos.length}');
    print('Processing: $processingVideosCount');
    print('Completed: $completedVideosCount');
    print('Failed: $failedVideosCount');
    print('Total credits used: $totalCreditsUsed');
    print('Active status polls: ${_statusTimers.length}');
    print('Videos:');
    for (var video in _videos) {
      print('  - ${video.title}: ${video.status} (${video.scenesCompleted}/${video.totalScenes} scenes)${video.creditsUsed != null ? ' - ${video.creditsUsed} credits' : ''}');
      if (video.playbackUrl != null) {
        print('    URL: ${video.playbackUrl?.substring(0, 100)}...');
      } else {
        print('    ⚠️ No playback URL');
      }
    }
    print('==============================');
  }

  /// Get the most recent completed video
  GeneratedVideo? getMostRecentVideo() {
    if (_videos.isEmpty) return null;
    
    // Videos are already sorted with newest first (insert at index 0)
    // Return first completed video
    try {
      return _videos.firstWhere((video) => video.status == 'completed');
    } catch (e) {
      return null;
    }
  }

  /// Get video URL for the most recent completed video
  String? getMostRecentVideoUrl() {
    final recentVideo = getMostRecentVideo();
    if (recentVideo != null) {
      return getPlaybackUrl(recentVideo.id);
    }
    return null;
  }
}