import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'video_service.dart';
import 'video_manager.dart';
import 'navigation_service.dart';
import 'api_test_widget.dart';

// Processing page to show extracted page batches with video generation
class ProcessingPage extends StatefulWidget {
  const ProcessingPage({super.key});

  @override
  State<ProcessingPage> createState() => ProcessingPageState();
}

class ProcessingPageState extends State<ProcessingPage>
    with TickerProviderStateMixin {
  List<PageBatchModel> _pageBatches = [];
  bool _isProcessing = false;
  bool _useAICleaning = true;
  String _processingStatus = '';
  ProcessingResult? _lastResult;
  VideoManager _videoManager = VideoManager();

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _refreshController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _refreshAnimation;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = 
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _refreshAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _refreshController, curve: Curves.elasticOut),
    );
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (_isProcessing) return;
    
    _refreshController.forward().then((_) {
      _refreshController.reverse();
    });

    // Simulate refresh delay for smooth animation
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_lastResult != null) {
      loadProcessedContent(_lastResult!);
    }
  }

  void processFile(File? file, PlatformFile? webFile) async {
    setState(() {
      _isProcessing = true;
      _pageBatches.clear();
      _processingStatus = 'Uploading PDF to server...';
    });

    try {
      _showSnackBar(
        _useAICleaning
            ? 'Processing PDF with AI cleaning...'
            : 'Processing PDF...',
        isError: false,
      );

      ProcessingResult result;

      if (_useAICleaning) {
        setState(() {
          _processingStatus = 'AI is cleaning and formatting page batches...';
        });
        result =
            await ApiService.processPdfWithAI(file, webFile, maxConcurrent: 5);
      } else {
        setState(() {
          _processingStatus = 'Extracting page batches from PDF...';
        });
        result = await ApiService.processPdf(file, webFile);
      }

      if (result.success) {
        setState(() {
          _pageBatches = result.pageBatches;
          _lastResult = result;
          _isProcessing = false;
        });

        _slideController.forward();

        _showSnackBar(
          'Successfully extracted ${result.totalPageBatches} page batches! '
          '${_useAICleaning ? "AI cleaned text for better readability." : ""}',
          isError: false,
        );
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingStatus = 'Error: ${e.toString()}';
      });

      _showSnackBar('Processing failed: ${e.toString()}', isError: true);
    }
  }

  // Method to handle content that was processed elsewhere and passed to this page
  void loadProcessedContent(ProcessingResult result) {
    setState(() {
      _pageBatches = result.pageBatches;
      _lastResult = result;
      _isProcessing = false;
      _processingStatus = 'Content loaded successfully!';
    });
    
    _slideController.reset();
    _slideController.forward();
    
    String contentType = 'content';
    if (result.fileName.toLowerCase().contains('image') || 
        result.message.toLowerCase().contains('image')) {
      contentType = 'images';
    } else if (result.fileName.toLowerCase().contains('audio') || 
               result.message.toLowerCase().contains('audio') ||
               result.message.toLowerCase().contains('transcription')) {
      contentType = 'audio';
    } else if (result.fileName.toLowerCase().contains('story') || 
               result.message.toLowerCase().contains('story')) {
      contentType = 'story';
    }
    
    _showSnackBar(
      'Content loaded! ${result.totalPageBatches} page batches ready for video creation.',
      isError: false,
    );

    // Force UI refresh to ensure content is displayed
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _onRefresh,
          backgroundColor: const Color(0xFF1A1A23),
          color: const Color(0xFF6366F1),
          strokeWidth: 3,
          displacement: 60,
          child: _isProcessing
              ? _buildProcessingView()
              : _pageBatches.isEmpty
                  ? _buildEmptyState()
                  : _buildPageBatchesView(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A23),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_stories,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Processing',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        if (!_isProcessing && _pageBatches.isNotEmpty) ...[
          AnimatedBuilder(
            animation: _refreshAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _refreshAnimation.value,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  onPressed: _onRefresh,
                ),
              );
            },
          ),
        ],
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6366F1).withOpacity(0.3),
                const Color(0xFF8B5CF6).withOpacity(0.3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Processing Content',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A23),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                  ),
                ),
                child: Text(
                  _processingStatus,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'This may take a few moments...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - 200,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A23),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 48,
                color: const Color(0xFF6366F1).withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Content to Process',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Upload content from the Create tab to see page batches here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A23),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Quick Start',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildQuickStartItem(
                    '1.',
                    'Go to the Create tab',
                    Icons.auto_awesome,
                  ),
                  _buildQuickStartItem(
                    '2.',
                    'Upload a PDF, audio, or write text',
                    Icons.upload_file,
                  ),
                  _buildQuickStartItem(
                    '3.',
                    'Content will appear here for processing',
                    Icons.auto_stories,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartItem(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            icon,
            color: Colors.white.withOpacity(0.6),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageBatchesView() {
    return SlideTransition(
      position: _slideAnimation,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _pageBatches.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildPageBatchCard(_pageBatches[index], index),
          );
        },
      ),
    );
  }

  Widget _buildPageBatchCard(PageBatchModel batch, int index) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.1),
                  const Color(0xFF8B5CF6).withOpacity(0.1),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.displayTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.format_align_left,
                            '${batch.wordCount} words',
                            const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            Icons.layers,
                            '${batch.pagesInBatch} pages',
                            const Color(0xFF8B5CF6),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (batch.cleaned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            color: Color(0xFF10B981), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'AI Enhanced',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    batch.displayText.length > 300 
                        ? '${batch.displayText.substring(0, 300)}...'
                        : batch.displayText,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showPageBatchDetails(batch),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                          foregroundColor: const Color(0xFF6366F1),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                            ),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.visibility, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _createVideoFromPageBatch(batch),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_call, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Create Video',
                              style: TextStyle(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showPageBatchDetails(PageBatchModel batch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPageBatchDetailsModal(batch),
    );
  }

  Widget _buildPageBatchDetailsModal(PageBatchModel batch) {
    final scrollController = ScrollController();
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A23),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        batch.displayTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (batch.cleaned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                color: Color(0xFF10B981), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'AI Enhanced',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.format_align_left,
                      '${batch.wordCount} words',
                      const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.layers,
                      '${batch.pagesInBatch} pages',
                      const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A23),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                  ),
                ),
                child: Text(
                  batch.displayText,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A23),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                      foregroundColor: const Color(0xFF6366F1),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _createVideoFromPageBatch(batch);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_call, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Create Video',
                          style: TextStyle(
                            fontSize: 16,
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
        ],
      ),
    );
  }

  void _createVideoFromPageBatch(PageBatchModel batch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('access_token');
      if (jwtToken == null) {
        _showSnackBar('Please log in again', isError: true);
        return;
      }

      final apiHealth = await VideoGenerationService.checkHealth();
      if (!apiHealth) {
        throw Exception(
            'API server is not responding. Please check your internet connection.');
      }

      _showSnackBar(
        'Starting video generation for "${batch.displayTitle}"...',
        isError: false,
      );

      final batchText = batch.displayText;

      print('Page batch text length: ${batchText.length}');
      print('Page batch title: ${batch.displayTitle}');

      final jobId = await _videoManager.generateVideoFromChapter(
        chapterText: batchText,
        chapterTitle: batch.displayTitle,
        jwtToken: jwtToken,
      );

      print('Job started with ID: $jobId');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Video generation started! Check the Videos tab to monitor progress.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              _navigateToVideosTab();
            },
          ),
        ),
      );
    } catch (e) {
      print('Error creating video: $e');

      String errorMessage = e.toString();

      if (errorMessage.contains('405') ||
          errorMessage.contains('Method not allowed')) {
        errorMessage =
            'API endpoint not available. The server may be updating.';
      } else if (errorMessage.contains('Failed to fetch')) {
        errorMessage = 'Network connection failed. Please check your internet.';
      } else if (errorMessage.contains('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Failed to start video generation'),
              const SizedBox(height: 4),
              Text(
                errorMessage,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Test API',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ApiTestWidget(),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _navigateToVideosTab() {
    NavigationService().navigateToVideos();
  }
}