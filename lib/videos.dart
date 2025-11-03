import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    
    // Debug: Print video information on startup
    _debugPrintVideoInfo();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light gray background
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _videoManager.videos.isEmpty
            ? _buildEmptyState()
            : _buildVideosGrid(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.video_library,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Videos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A202C),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                '${_videoManager.videos.length} videos',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Refresh button
        IconButton(
          onPressed: () {
            _debugPrintVideoInfo();
            _videoManager.printDebugInfo();
            _showSnackBar('Debug info printed to console');
          },
          icon: const Icon(
            Icons.info_outline,
            color: Color(0xFF667EEA),
          ),
          tooltip: 'Debug Info',
        ),
        IconButton(
          onPressed: () {
            setState(() {});
            _showSnackBar('Videos refreshed');
          },
          icon: const Icon(
            Icons.refresh,
            color: Color(0xFF667EEA),
          ),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF667EEA).withOpacity(0.1),
                    const Color(0xFF764BA2).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.video_library_outlined,
                size: 48,
                color: Color(0xFF667EEA),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Videos Yet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A202C),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create your first video from the Processing tab',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF718096),
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'How to Create Videos',
                    style: TextStyle(
                      color: Color(0xFF2D3748),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Upload content in the Create tab\n2. Process chapters in Processing tab\n3. Click "Create Video" on any chapter\n4. Your videos will appear here!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          childAspectRatio: 1.3, // Adjusted for better proportions
          mainAxisSpacing: 16,
        ),
        itemCount: _videoManager.videos.length,
        itemBuilder: (context, index) {
          final video = _videoManager.videos[index];
          return _buildVideoCard(video);
        },
      ),
    );
  }

  Widget _buildVideoCard(GeneratedVideo video) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (video.status) {
      case 'completed':
        statusColor = const Color(0xFF48BB78);
        statusIcon = Icons.play_circle_filled;
        statusText = 'Ready to Watch';
        break;
      case 'failed':
        statusColor = const Color(0xFFE53E3E);
        statusIcon = Icons.error_outline;
        statusText = 'Generation Failed';
        break;
      case 'processing':
      default:
        statusColor = const Color(0xFFED8936);
        statusIcon = Icons.hourglass_empty;
        statusText = 'Processing Video...';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video thumbnail/preview area
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () {
                if (video.status == 'completed') {
                  _playVideo(video);
                }
              },
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      statusColor.withOpacity(0.05),
                      statusColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Stack(
                  children: [
                    // Thumbnail or placeholder
                    if (video.status == 'completed' && video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.network(
                          video.thumbnailUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('❌ Failed to load thumbnail: ${video.thumbnailUrl}');
                            return _buildPlaceholderThumbnail(statusColor, statusIcon, statusText, video);
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              print('✅ Thumbnail loaded successfully: ${video.thumbnailUrl}');
                              return child;
                            }
                            return _buildPlaceholderThumbnail(statusColor, statusIcon, statusText, video);
                          },
                        ),
                      )
                    else
                      _buildPlaceholderThumbnail(statusColor, statusIcon, statusText, video),
                    
                    // Overlay gradient for better text visibility
                    if (video.status == 'completed' && video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    
                    // Play button overlay for completed videos
                    if (video.status == 'completed')
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    
                    // Status badge
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          video.status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    // Duration badge (for completed videos)
                    if (video.status == 'completed' && video.duration != null)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            video.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Video info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title and metadata
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A202C),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Color(0xFF718096),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatCreatedAt(video.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF718096),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (video.creditsUsed != null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.account_balance_wallet,
                              size: 14,
                              color: Color(0xFF718096),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${video.creditsUsed}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF718096),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  // Action buttons
                  Row(
                    children: [
                      if (video.status == 'completed') ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _playVideo(video),
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text(
                              'Watch',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667EEA),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else if (video.status == 'failed') ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showRetryDialog(video),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text(
                              'Retry',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE53E3E),
                              side: const BorderSide(color: Color(0xFFE53E3E)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${video.scenesCompleted}/${video.totalScenes} scenes',
                              style: TextStyle(
                                fontSize: 13,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          onPressed: () => _showVideoOptions(video),
                          icon: const Icon(
                            Icons.more_vert,
                            color: Color(0xFF718096),
                            size: 18,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
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
              color: Color(0xFF1A202C),
            ),
          ),
          content: Text(
            'Do you want to retry generating "${video.title}"?',
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
                _showSnackBar('Retry functionality not available. Please create a new video from Processing tab.', isError: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
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
                        color: Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Color(0xFF667EEA)),
                      title: const Text('Video Details'),
                      onTap: () {
                        Navigator.pop(context);
                        _showVideoDetails(video);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.refresh, color: Color(0xFF48BB78)),
                      title: const Text('Refresh Status'),
                      onTap: () {
                        Navigator.pop(context);
                        _refreshVideoStatus(video);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Color(0xFFE53E3E)),
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
              color: Color(0xFF1A202C),
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
                style: TextStyle(color: Color(0xFF667EEA)),
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
                color: Color(0xFF718096),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1A202C),
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
      
      await _controller.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF667EEA),
          handleColor: const Color(0xFF667EEA),
          backgroundColor: Colors.grey,
          bufferedColor: const Color(0xFF667EEA).withOpacity(0.5),
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF667EEA),
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
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
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF667EEA),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading video...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              )
            : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Error Loading Video',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _isLoading = true;
                          });
                          _initializePlayer();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667EEA),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  )
                : _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const Text(
                        'Video player not initialized',
                        style: TextStyle(color: Colors.white),
                      ),
      ),
    );
  }
}