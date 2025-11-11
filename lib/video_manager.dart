import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'video_service.dart';
import 'navigation_service.dart';

// System Notification Helper
class SystemNotificationHelper {
  static const MethodChannel _channel = MethodChannel('video_notifications');

  static Future<void> showCompletionNotification(String title) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'title': 'Video Ready! 🎉',
        'body': 'Your video "$title" is ready to watch',
        'channelId': 'video_completion',
        'channelName': 'Video Processing',
        'channelDescription': 'Notifications for completed video processing',
      });
    } catch (e) {
      print('Failed to show system notification: $e');
      // Fallback to in-app notification only
    }
  }

  static Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (e) {
      print('Failed to request notification permission: $e');
    }
  }
}

// Video Processing Notification Service
class VideoNotificationService {
  static VideoNotificationService? _instance;
  factory VideoNotificationService() => _instance ??= VideoNotificationService._internal();
  VideoNotificationService._internal();

  BuildContext? _context;
  OverlayEntry? _currentNotification;
  Timer? _autoHideTimer;

  void initialize(BuildContext context) {
    _context = context;
  }

  void showProcessingPopup(String title) {
    if (_context == null) return;

    // Remove any existing notification
    _currentNotification?.remove();
    _autoHideTimer?.cancel();

    // Create overlay entry for processing notification
    _currentNotification = OverlayEntry(
      builder: (context) => ProcessingNotificationWidget(
        title: title,
        onDismiss: () {
          _currentNotification?.remove();
          _currentNotification = null;
          _autoHideTimer?.cancel();
        },
      ),
    );

    Overlay.of(_context!).insert(_currentNotification!);
    
    // Keep processing notification visible for longer (30 seconds or until completion)
    _autoHideTimer = Timer(Duration(seconds: 30), () {
      _currentNotification?.remove();
      _currentNotification = null;
    });
  }

  void showCompletionNotification(String title, VoidCallback? onTap) {
    if (_context == null) return;

    // Remove any existing notification
    _currentNotification?.remove();
    _autoHideTimer?.cancel();
    
    // Send system notification for background
    SystemNotificationHelper.showCompletionNotification(title);

    // Create overlay entry for completion notification
    _currentNotification = OverlayEntry(
      builder: (context) => CompletionNotificationWidget(
        title: title,
        onTap: onTap,
        onDismiss: () {
          _currentNotification?.remove();
          _currentNotification = null;
          _autoHideTimer?.cancel();
        },
      ),
    );

    Overlay.of(_context!).insert(_currentNotification!);

    // Auto-dismiss after 4 seconds
    _autoHideTimer = Timer(Duration(seconds: 4), () {
      _currentNotification?.remove();
      _currentNotification = null;
    });
  }

  void dismiss() {
    _currentNotification?.remove();
    _currentNotification = null;
    _autoHideTimer?.cancel();
  }
}

// Processing Notification Widget
class ProcessingNotificationWidget extends StatefulWidget {
  final String title;
  final VoidCallback onDismiss;

  const ProcessingNotificationWidget({
    Key? key,
    required this.title,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<ProcessingNotificationWidget> createState() => _ProcessingNotificationWidgetState();
}

class _ProcessingNotificationWidgetState extends State<ProcessingNotificationWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _controller.forward();
    
    // Start pulsing animation
    _pulseController.repeat(reverse: true);

    // Trigger haptic feedback
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2563EB),
                    Color(0xFF3B82F6),
                    Color(0xFF1D4ED8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Animated loading indicator
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Video Processing Started',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your video "${widget.title}" is being processed.\nYou\'ll be notified when it\'s ready!',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Close button
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Completion Notification Widget
class CompletionNotificationWidget extends StatefulWidget {
  final String title;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const CompletionNotificationWidget({
    Key? key,
    required this.title,
    this.onTap,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<CompletionNotificationWidget> createState() => _CompletionNotificationWidgetState();
}

class _CompletionNotificationWidgetState extends State<CompletionNotificationWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );

    _controller.forward();
    _progressController.forward();

    // Trigger celebration haptic feedback
    _triggerCelebrationHaptics();
  }

  Future<void> _triggerCelebrationHaptics() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF10B981), 
                        Color(0xFF059669),
                        Color(0xFF047857),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Progress bar at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return Container(
                              height: 3,
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              child: LinearProgressIndicator(
                                value: _progressAnimation.value,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Main content
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Success icon with animation
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.play_circle_filled,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Text content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        '🎉 ',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const Text(
                                        'Video Ready!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to view "${widget.title}"',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Close button
                            GestureDetector(
                              onTap: widget.onDismiss,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VideoManager extends ChangeNotifier {
  static final VideoManager _instance = VideoManager._internal();
  factory VideoManager() => _instance;
  VideoManager._internal();

  final List<GeneratedVideo> _videos = [];
  final Map<String, Timer> _statusTimers = {};
  bool _isLoaded = false; // Track if we've loaded from backend
  
  List<GeneratedVideo> get videos => List.unmodifiable(_videos);

  /// ✅ FIXED: Load user's existing videos from backend
  Future<void> loadUserVideos(String jwtToken, {bool forceReload = false}) async {
    // Allow force reload for refresh functionality
    if (_isLoaded && !forceReload) {
      print('📚 Videos already loaded, skipping...');
      return;
    }
    
    try {
      print('📚 Loading user videos from backend...');
      
      const String baseUrl = 'https://ch2vi-production.up.railway.app';
      // Increase limit to fetch more videos
      final response = await http.get(
        Uri.parse('$baseUrl/videos/history?limit=200&offset=0'),
        headers: {
          'authorization': 'Bearer $jwtToken',
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> videosJson = data['videos'] ?? [];
        
        print('📥 Received ${videosJson.length} videos from backend');
        
        // Clear existing videos and load from backend
        _videos.clear();
        
        for (var videoJson in videosJson) {
          try {
            // Generate unique ID using timestamp if job_id not available
            final uniqueId = videoJson['job_id'] ?? 
                            videoJson['id'] ?? 
                            'video_${DateTime.now().millisecondsSinceEpoch}_${_videos.length}';
            
            final video = GeneratedVideo(
              id: uniqueId,
              title: videoJson['title'] ?? 'Untitled Video',
              status: _mapBackendStatus(videoJson['video_status'] ?? 'unknown'),
              progress: 'Loaded from history',
              createdAt: DateTime.tryParse(videoJson['created_at'] ?? '') ?? DateTime.now(),
              playbackUrl: videoJson['video_url'],
              thumbnailUrl: videoJson['thumbnail_url'],
              totalScenes: videoJson['scenes_count'] ?? 0,
              scenesCompleted: videoJson['scenes_count'] ?? 0,
              creditsUsed: videoJson['credits_charged'],
              duration: videoJson['duration_seconds'] != null 
                  ? Duration(seconds: videoJson['duration_seconds'])
                  : null,
              fileSize: videoJson['file_size_mb'] != null 
                  ? (videoJson['file_size_mb'] * 1024 * 1024).round()
                  : null,
              backendVideoId: videoJson['id'],
              isSavedToBackend: true,
            );
            
            _videos.add(video);
            
            // Start polling for any processing videos
            if (video.status == 'processing') {
              print('🔄 Resuming polling for processing video: ${video.id}');
              _startStatusPolling(video.id);
            }
          } catch (e) {
            print('⚠️ Error parsing video data: $e');
          }
        }
        
        // Sort by creation date (newest first)
        _videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        _isLoaded = true;
        notifyListeners();
        print('✅ Successfully loaded ${_videos.length} videos from backend');
        
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else {
        print('⚠️ Failed to load videos: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error loading user videos: $e');
      // Don't throw error - app should still work even if videos can't be loaded
    }
  }

  /// ✅ NEW: Refresh videos from backend (for pull-to-refresh)
  Future<void> refreshFromBackend(String jwtToken) async {
    print('🔄 Refreshing videos from backend...');
    await loadUserVideos(jwtToken, forceReload: true);
  }

  /// ✅ NEW: Load more videos with pagination
  Future<bool> loadMoreVideos(String jwtToken, {int offset = 0, int limit = 50}) async {
    try {
      print('📚 Loading more videos from backend (offset: $offset)...');
      
      const String baseUrl = 'https://ch2vi-production.up.railway.app';
      final response = await http.get(
        Uri.parse('$baseUrl/videos/history?limit=$limit&offset=$offset'),
        headers: {
          'authorization': 'Bearer $jwtToken',
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> videosJson = data['videos'] ?? [];
        
        print('📥 Received ${videosJson.length} more videos from backend');
        
        if (videosJson.isEmpty) {
          return false; // No more videos to load
        }
        
        for (var videoJson in videosJson) {
          try {
            // Check if video already exists
            final existingIndex = _videos.indexWhere(
              (v) => v.backendVideoId == videoJson['id'] || v.id == videoJson['job_id']
            );
            
            if (existingIndex == -1) {
              // Generate unique ID using timestamp if job_id not available
              final uniqueId = videoJson['job_id'] ?? 
                              videoJson['id'] ?? 
                              'video_${DateTime.now().millisecondsSinceEpoch}_${_videos.length}';
              
              final video = GeneratedVideo(
                id: uniqueId,
                title: videoJson['title'] ?? 'Untitled Video',
                status: _mapBackendStatus(videoJson['video_status'] ?? 'unknown'),
                progress: 'Loaded from history',
                createdAt: DateTime.tryParse(videoJson['created_at'] ?? '') ?? DateTime.now(),
                playbackUrl: videoJson['video_url'],
                thumbnailUrl: videoJson['thumbnail_url'],
                totalScenes: videoJson['scenes_count'] ?? 0,
                scenesCompleted: videoJson['scenes_count'] ?? 0,
                creditsUsed: videoJson['credits_charged'],
                duration: videoJson['duration_seconds'] != null 
                    ? Duration(seconds: videoJson['duration_seconds'])
                    : null,
                fileSize: videoJson['file_size_mb'] != null 
                    ? (videoJson['file_size_mb'] * 1024 * 1024).round()
                    : null,
                backendVideoId: videoJson['id'],
                isSavedToBackend: true,
              );
              
              _videos.add(video);
            }
          } catch (e) {
            print('⚠️ Error parsing video data: $e');
          }
        }
        
        // Sort by creation date (newest first)
        _videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        notifyListeners();
        return videosJson.length == limit; // Return true if there might be more videos
        
      } else {
        print('⚠️ Failed to load more videos: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error loading more videos: $e');
      return false;
    }
  }

  /// Map backend video status to frontend status
  String _mapBackendStatus(String backendStatus) {
    switch (backendStatus.toLowerCase()) {
      case 'completed':
        return 'completed';
      case 'processing':
        return 'processing';
      case 'failed':
        return 'failed';
      default:
        return 'processing';
    }
  }

  /// ✅ NEW: Mark video as saved to backend
  void markVideoAsSaved(String jobId, String backendVideoId) {
    final index = _videos.indexWhere((video) => video.id == jobId);
    if (index != -1) {
      _videos[index] = _videos[index].copyWith(
        backendVideoId: backendVideoId,
        isSavedToBackend: true,
      );
      notifyListeners();
      print('✅ Video $jobId marked as saved with backend ID: $backendVideoId');
    }
  }
  
  /// Start video generation from chapter with JWT authentication
  Future<String> generateVideoFromChapter({
    required String chapterText,
    required String chapterTitle,
    required String jwtToken,
    String language = 'English',  // ✅ ADD language parameter
    bool animateAll = true,       // ✅ ADD animateAll parameter
  }) async {
    try {
      print('🎬 VideoManager: Starting video generation');
      print('📝 Title: $chapterTitle');
      print('📊 Text length: ${chapterText.length} characters');
      print('🔐 JWT Token available: ${jwtToken.isNotEmpty}');
      print('🌍 Language: $language');  // ✅ LOG language
      print('🎬 Animate all: $animateAll');  // ✅ LOG animation setting
      
      // Show processing notification popup
      VideoNotificationService().showProcessingPopup(chapterTitle);
      
      // Start video generation with JWT token
      final status = await VideoGenerationService.generateVideoFromChapter(
        chapterText: chapterText,
        chapterTitle: chapterTitle,
        jwtToken: jwtToken,
        animateAll: animateAll,  // ✅ USE parameter instead of hardcoded
        mergeFinal: true,
        language: language,      // ✅ PASS language parameter
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
      final video = GeneratedVideo.fromVideoStatus(status, chapterTitle, originalText: chapterText);
      _videos.insert(0, video); // Add to beginning of list
      notifyListeners();

      // Start polling for status updates
      _startStatusPolling(status.jobId);

      return status.jobId;
    } catch (e) {
      print('❌ VideoManager: Error starting video generation: $e');
      
      // Dismiss the processing notification on error
      VideoNotificationService().dismiss();
      
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
            
            // Show completion notification
            final video = getVideo(jobId);
            if (video != null) {
              VideoNotificationService().showCompletionNotification(
                video.title, 
                () {
                  // Navigate to videos tab when notification is tapped
                  NavigationService().navigateToVideos();
                }
              );
            }
          } else {
            print('⚠️ No playback URL in completed status');
          }
        } else if (status.status == 'failed') {
          print('❌ Job $jobId: Failed - ${status.errorMessage}');
          // Dismiss processing notification on failure
          VideoNotificationService().dismiss();
        }
        
        _updateVideoStatus(jobId, status);

        // Stop polling if completed or failed
        if (status.isCompleted || status.isFailed) {
          print('🛑 Stopping polling for job: $jobId (Status: ${status.status})');
          timer.cancel();
          _statusTimers.remove(jobId);
          
          // Dismiss processing notification when completed/failed
          if (status.isCompleted || status.isFailed) {
            // Only dismiss if it's a processing notification (not completion notification)
            Timer(Duration(milliseconds: 500), () {
              // This will only dismiss if it's still the processing notification
            });
          }
          
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
        thumbnailUrl: status.thumbnailUrl,  // ✅ CRITICAL: Store the thumbnail URL
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
        if (status.thumbnailUrl != null) {
          print('🖼️ Thumbnail URL stored: ${status.thumbnailUrl?.substring(0, 100)}...');
        } else {
          print('⚠️ No thumbnail URL in status update');
        }
        
        // Trigger vibration notification when video completes
        if (newStatus == 'completed') {
          _triggerCompletionVibration();
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
      
      if (video.originalText != null && video.originalText!.isNotEmpty) {
        // Remove the failed video
        removeVideo(jobId);
        
        // Retry with the original text
        await generateVideoFromChapter(
          chapterText: video.originalText!,
          chapterTitle: video.title,
          jwtToken: jwtToken,
        );
      } else {
        throw Exception('Cannot retry: Original text not available. Please create a new video from the Processing tab.');
      }
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
      
      // Get video by jobId to find the backend video ID
      final video = getVideo(jobId);
      if (video?.backendVideoId != null) {
        // Use backend API to get fresh playback URL
        final prefs = await SharedPreferences.getInstance();
        final jwtToken = prefs.getString('access_token');
        
        if (jwtToken != null) {
          const String baseUrl = 'https://ch2vi-production.up.railway.app';
          final response = await http.get(
            Uri.parse('$baseUrl/play/${video!.backendVideoId}'),
            headers: {
              'authorization': 'Bearer $jwtToken',
              'accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ).timeout(Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final freshUrl = data['video_url'];
            
            if (freshUrl != null) {
              print('✅ Fresh playback URL received: ${freshUrl.substring(0, 100)}...');
              
              // Update the stored URL
              final index = _videos.indexWhere((v) => v.id == jobId);
              if (index != -1) {
                _videos[index] = _videos[index].copyWith(playbackUrl: freshUrl);
                notifyListeners();
              }
              
              return freshUrl;
            }
          }
        }
      }
      
      // Fallback to old method
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

  /// Trigger 3 haptic feedback pulses when video generation completes
  Future<void> _triggerCompletionVibration() async {
    try {
      print('📳 Triggering completion haptic feedback...');
      
      // Use Flutter's built-in HapticFeedback for 3 pulses
      // No external package needed - works on both Android and iOS!
      HapticFeedback.heavyImpact();
      await Future.delayed(Duration(milliseconds: 200));
      
      HapticFeedback.heavyImpact();
      await Future.delayed(Duration(milliseconds: 200));
      
      HapticFeedback.heavyImpact();
      
      print('✅ Completion haptic feedback triggered (3 pulses)');
    } catch (e) {
      print('❌ Error triggering haptic feedback: $e');
      // Silent fail - haptic feedback is not critical
    }
  }
}