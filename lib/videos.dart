import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'video_manager.dart';
import 'video_service.dart';
import 'dart:async';

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> with TickerProviderStateMixin {
  final VideoManager _videoManager = VideoManager();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isInitializing = true;  // ✅ ADD: Track initialization state
  String? _loadError;           // ✅ ADD: Track load errors

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    // Listen to video manager updates
    _videoManager.addListener(_onVideoManagerUpdate);
    
    // ✅ FIX: Load video history from backend on initialization
    _loadVideoHistory();
  }

  // ✅ ADD: Method to load video history from backend
  Future<void> _loadVideoHistory() async {
    try {
      setState(() {
        _isInitializing = true;
        _loadError = null;
      });

      print('📚 VideosPage: Loading video history from backend...');
      
      // Get JWT token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('access_token');
      
      if (jwtToken == null) {
        setState(() {
          _loadError = 'No authentication token found. Please log in again.';
          _isInitializing = false;
        });
        print('❌ No JWT token found');
        return;
      }

      // Load videos from backend
      await _videoManager.loadUserVideos(jwtToken);
      
      print('✅ VideosPage: Successfully loaded ${_videoManager.videos.length} videos');
      
      // Debug: Print video information after loading
      _debugPrintVideoInfo();
      
    } catch (e) {
      print('❌ Error loading video history: $e');
      setState(() {
        _loadError = 'Failed to load videos: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  // ✅ ADD: Method to refresh video history (for pull-to-refresh)
  Future<void> _refreshVideoHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('access_token');
      
      if (jwtToken != null) {
        await _videoManager.refreshFromBackend(jwtToken);
        _debugPrintVideoInfo();
      }
    } catch (e) {
      print('❌ Error refreshing video history: $e');
      // Show snackbar or other error UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh videos: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _debugPrintVideoInfo() {
    print('🔍 VideosPage: Debug Info');
    print('📊 Total videos in manager: ${_videoManager.videos.length}');
    for (int i = 0; i < _videoManager.videos.length; i++) {
      final video = _videoManager.videos[i];
      print('📹 Video $i: ${video.title}');
      print('   Status: ${video.status}');
      print('   Created: ${video.createdAt}');
      print('   Thumbnail: ${video.thumbnailUrl ?? "No thumbnail"}');
      print('   Playback URL: ${video.playbackUrl ?? "No playback URL"}');
      print('   Credits: ${video.creditsUsed ?? "No credits info"}');
    }
    print('==============================');
  }

  @override
  void dispose() {
    _videoManager.removeListener(_onVideoManagerUpdate);
    _fadeController.dispose();
    super.dispose();
  }

  void _onVideoManagerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : (screenWidth > 400 ? 2 : 1);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(  // ✅ ADD: Pull-to-refresh support
          onRefresh: _refreshVideoHistory,
          color: const Color(0xFF2563EB),
          child: CustomScrollView(
          slivers: [
            // Enhanced app bar with compact design
            SliverAppBar(
              expandedHeight: 100,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2563EB).withOpacity(0.06),
                        const Color(0xFF3B82F6).withOpacity(0.03),
                        Colors.white.withOpacity(0.9),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.08),
                        blurRadius: 15,
                        spreadRadius: 0,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 50,
                    bottom: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withOpacity(0.25),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.video_library,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'VIDEOS',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  '${_videoManager.videos.length} ${_videoManager.videos.length == 1 ? 'Video' : 'Videos'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ✅ ADD: Refresh button in app bar
                          IconButton(
                            onPressed: _isInitializing ? null : _refreshVideoHistory,
                            icon: Icon(
                              Icons.refresh,
                              color: _isInitializing 
                                  ? Colors.grey 
                                  : const Color(0xFF2563EB),
                            ),
                            tooltip: 'Refresh videos',
                          ),
                          // Compact star icon
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFBBF24).withOpacity(0.25),
                                  blurRadius: 6,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // ✅ IMPROVED: Content with loading and error states
            if (_isInitializing)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading your videos...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_loadError != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading videos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _loadError!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadVideoHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // ✅ EXISTING: Keep all original video grid and empty state logic
            // Video grid or empty state with improved responsiveness
            _videoManager.videos.isEmpty
                ? SliverFillRemaining(
                    child: _buildEmptyState(),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.75,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final video = _videoManager.videos[index];
                          return _buildVideoCard(video);
                        },
                        childCount: _videoManager.videos.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 320,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2563EB).withOpacity(0.1),
                      const Color(0xFF3B82F6).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.video_library_outlined,
                  size: 36,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Videos Yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your first video from the Create tab',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'How to Create Videos',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Upload content in Create tab\n2. Process in Processing tab\n3. Click "Create Video"\n4. Videos appear here!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(GeneratedVideo video) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (video.status) {
      case 'completed':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        statusText = 'Ready';
        break;
      case 'failed':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.error_outline;
        statusText = 'Failed';
        break;
      case 'processing':
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.sync;
        statusText = 'Processing';
        break;
    }

    return GestureDetector(
      onTap: () {
        if (video.status == 'completed') {
          _playVideo(video);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFBBF24),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            children: [
              // Background with thumbnail or gradient
              Positioned.fill(
                child: video.status == 'completed' && 
                       video.thumbnailUrl != null && 
                       video.thumbnailUrl!.isNotEmpty
                    ? Image.network(
                        video.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildGradientBackground(video);
                        },
                      )
                    : _buildGradientBackground(video),
              ),
              
              // Dark overlay for better text visibility
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Three dots menu (top right)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => _showVideoOptions(video),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              
              // Content - Title and info at bottom
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Large title (like book title)
                    Text(
                      video.title.isNotEmpty ? video.title : 'Untitled Video',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Subtitle with golden color
                    Text(
                      video.title.isNotEmpty ? video.title : 'Untitled Video',
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Date and pages
                    Row(
                      children: [
                        Text(
                          _formatCreatedAt(video.createdAt),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (video.duration != null)
                          Text(
                            video.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else if (video.totalScenes != null)
                          Text(
                            '${video.totalScenes} scenes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Status indicator (processing/failed)
              if (video.status != 'completed')
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildGradientBackground(GeneratedVideo video) {
    // Different gradient colors based on video status or random
    final gradients = [
      [const Color(0xFF8B9467), const Color(0xFFA8B276)], // Green (like image 1)
      [const Color(0xFFB8A878), const Color(0xFFC9B989)], // Beige (like image 2)
      [const Color(0xFF6B8E9B), const Color(0xFF7A9DAA)], // Blue-gray
      [const Color(0xFF9B7B6B), const Color(0xFFAA8A7A)], // Brown
    ];
    
    final gradientIndex = video.id.hashCode.abs() % gradients.length;
    final colors = gradients[gradientIndex];
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          // Decorative leaf pattern (optional)
          Positioned(
            top: -20,
            left: -20,
            child: Opacity(
              opacity: 0.2,
              child: Icon(
                Icons.auto_stories,
                size: 100,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New enhanced video card with better animations and hover effects
  Widget _buildEnhancedVideoCard(GeneratedVideo video, int index) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (video.status) {
      case 'completed':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        statusText = 'Ready';
        break;
      case 'failed':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.error_outline;
        statusText = 'Failed';
        break;
      case 'processing':
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.sync;
        statusText = 'Processing';
        break;
    }
    
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          if (video.status == 'completed') {
            _playVideo(video);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: statusColor.withOpacity(0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 10,
                spreadRadius: -5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Enhanced background with thumbnail or gradient
                Positioned.fill(
                  child: video.status == 'completed' && 
                         video.thumbnailUrl != null && 
                         video.thumbnailUrl!.isNotEmpty
                      ? Image.network(
                          video.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildEnhancedGradientBackground(video);
                          },
                        )
                      : _buildEnhancedGradientBackground(video),
                ),
                
                // Enhanced overlay with better gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Enhanced menu button with better styling
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _showVideoOptions(video),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                
                // Enhanced content layout
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Enhanced title with better typography
                      Text(
                        video.title.isNotEmpty ? video.title : 'Untitled Video',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.3,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Enhanced metadata row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFBBF24).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _formatCreatedAt(video.createdAt),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (video.duration != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                video.formattedDuration,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else if (video.totalScenes != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${video.totalScenes} scenes',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Enhanced status indicator for non-completed videos
                if (video.status != 'completed')
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Processing shimmer effect
                if (video.status == 'processing')
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(seconds: 2),
                      tween: Tween<double>(begin: -1.0, end: 1.0),
                      onEnd: () {
                        // Loop the animation
                      },
                      builder: (context, value, child) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-1.0 + value, 0.0),
                              end: Alignment(1.0 + value, 0.0),
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.2),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildEnhancedGradientBackground(GeneratedVideo video) {
    // Enhanced gradient colors with better contrast
    final gradients = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)], // Purple-blue
      [const Color(0xFF11998e), const Color(0xFF38ef7d)], // Green
      [const Color(0xFFee9ca7), const Color(0xFFffdde1)], // Pink
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)], // Blue
      [const Color(0xFFf093fb), const Color(0xFFf5576c)], // Pink-red
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)], // Cyan-blue
    ];
    
    final gradientIndex = video.id.hashCode.abs() % gradients.length;
    final colors = gradients[gradientIndex];
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          // Enhanced decorative pattern
          Positioned(
            top: -30,
            left: -30,
            child: Opacity(
              opacity: 0.15,
              child: Icon(
                Icons.video_library_rounded,
                size: 120,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            right: -20,
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                Icons.play_circle_outline_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderThumbnail(Color statusColor, IconData statusIcon, String statusText, GeneratedVideo video) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: statusColor.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(
              statusIcon,
              size: 48,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          if (video.status == 'processing')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${video.scenesCompleted}/${video.totalScenes} scenes',
                style: TextStyle(
                  color: statusColor.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCreatedAt(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  void _playVideo(GeneratedVideo video) async {
    if (!_videoManager.isVideoReadyForPlayback(video.id)) {
      _showSnackBar('Video is not ready for playback yet', isError: true);
      return;
    }

    try {
      final playbackUrl = _videoManager.getPlaybackUrl(video.id);
      if (playbackUrl != null) {
        await _showVideoPlayer(playbackUrl, video.title);
      } else {
        _showSnackBar('Video URL not available', isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to play video: ${e.toString()}', isError: true);
    }
  }

  Future<void> _showVideoPlayer(String videoUrl, String title) async {
    // Navigate to full-screen video player
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: videoUrl,
          title: title,
        ),
      ),
    );
  }

  void _showRetryDialog(GeneratedVideo video) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Retry Video Generation',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          content: Text(
            'Do you want to retry generating "${video.title}"?',
            style: const TextStyle(
              color: Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSnackBar('Retry functionality not available. Please create a new video from Processing tab.', isError: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showVideoOptions(GeneratedVideo video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                      title: const Text('Video Details'),
                      onTap: () {
                        Navigator.pop(context);
                        _showVideoDetails(video);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.refresh, color: Color(0xFF10B981)),
                      title: const Text('Refresh Status'),
                      onTap: () {
                        Navigator.pop(context);
                        _refreshVideoStatus(video);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                      title: const Text('Delete Video'),
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(video);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVideoDetails(GeneratedVideo video) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Video Details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Title', video.title),
              _buildDetailRow('Status', video.status.toUpperCase()),
              _buildDetailRow('Created', _formatCreatedAt(video.createdAt)),
              if (video.duration != null)
                _buildDetailRow('Duration', video.formattedDuration),
              if (video.creditsUsed != null)
                _buildDetailRow('Credits Used', video.creditsUsed.toString()),
              _buildDetailRow('Progress', '${video.scenesCompleted}/${video.totalScenes} scenes'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF2563EB)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _refreshVideoStatus(GeneratedVideo video) async {
    try {
      await _videoManager.refreshVideoStatus(video.id);
      _showSnackBar('Video status refreshed');
    } catch (e) {
      _showSnackBar('Failed to refresh status: ${e.toString()}', isError: true);
    }
  }

  void _showDeleteConfirmation(GeneratedVideo video) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Video',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A202C),
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${video.title}"? This action cannot be undone.',
            style: const TextStyle(
              color: Color(0xFF718096),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF718096)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _videoManager.removeVideo(video.id);
                _showSnackBar('Video deleted');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFE53E3E) : const Color(0xFF48BB78),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// Full-screen video player widget
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      
      // Add error listener to detect 403 errors
      _controller.addListener(() {
        if (_controller.value.hasError) {
          final error = _controller.value.errorDescription;
          print('❌ VideoPlayer error: $error');
          
          // Check for 403 errors (URL expired)
          if (error != null && (error.contains('403') || error.contains('Forbidden'))) {
            print('🔄 Detected 403 error, returning to try fresh URL...');
            Navigator.of(context).pop(false); // Return false to trigger fresh URL
            return;
          }
        }
      });
      
      await _controller.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF2563EB),
          handleColor: const Color(0xFF2563EB),
          backgroundColor: Colors.grey,
          bufferedColor: const Color(0xFF2563EB).withOpacity(0.5),
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF2563EB),
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          print('❌ Chewie error: $errorMessage');
          
          // Check for 403 errors in Chewie error message
          if (errorMessage.contains('403') || errorMessage.toLowerCase().contains('forbidden')) {
            print('🔄 Detected 403 in Chewie error, returning to try fresh URL...');
            // Use a delayed pop to avoid conflicts with Chewie
            Future.delayed(Duration(milliseconds: 100), () {
              if (mounted) {
                Navigator.of(context).pop(false);
              }
            });
          }
          
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading video',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                    ),
                    child: const Text(
                      'Try Fresh URL',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ VideoPlayer initialization error: $e');
      
      // Check for network/HTTP errors during initialization
      if (e.toString().contains('403') || e.toString().toLowerCase().contains('forbidden')) {
        print('🔄 Detected 403 during initialization, returning to try fresh URL...');
        Navigator.of(context).pop(false);
        return;
      }
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () {
                // Add share functionality here if needed
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Video options coming soon'),
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0F0F),
              const Color(0xFF1A1A1A),
              const Color(0xFF0F0F0F),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _isLoading
                  ? Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 0,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Loading Video...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Preparing your content',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                      ? Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.2),
                                blurRadius: 30,
                                spreadRadius: 0,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Error Loading Video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                constraints: const BoxConstraints(maxWidth: 300),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2563EB).withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _error = null;
                                          _isLoading = true;
                                        });
                                        _initializePlayer();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text(
                                        'Retry',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF59E0B).withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text(
                                        'Refresh URL',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : _chewieController != null
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF2563EB).withOpacity(0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withOpacity(0.2),
                                    blurRadius: 40,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 15),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: AspectRatio(
                                  aspectRatio: _controller.value.aspectRatio,
                                  child: Chewie(controller: _chewieController!),
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.video_settings_rounded,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 60,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Video player not initialized',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
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