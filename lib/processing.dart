import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
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
  List<PageBatchModel> _pageBatches = []; // Changed from _chapters
  bool _isProcessing = false;
  bool _useAICleaning = true;
  String _processingStatus = '';
  ProcessingResult? _lastResult;
  VideoManager _videoManager = VideoManager();

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void processFile(File? file, PlatformFile? webFile) async {
    setState(() {
      _isProcessing = true;
      _pageBatches.clear(); // Changed from _chapters
      _processingStatus = 'Uploading PDF to server...';
    });


    try {
      // Show initial processing message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text(_useAICleaning
                  ? 'Processing PDF with AI cleaning...'
                  : 'Processing PDF...'),
            ],
          ),
          backgroundColor: const Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
          _pageBatches = result.pageBatches; // Changed from chapters
          _lastResult = result;
          _isProcessing = false;
        });

        _slideController.forward();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully extracted ${result.totalPageBatches} page batches! '
                '${_useAICleaning ? "AI cleaned text for better readability." : ""}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingStatus = 'Error: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing failed: ${e.toString()}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void loadProcessedContent(ProcessingResult result) {
  setState(() {
    _pageBatches = result.pageBatches;
    _lastResult = result;
    _isProcessing = false;
  });
  
  _slideController.forward();
  
  // Show success message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
          'Content loaded successfully! ${result.totalPageBatches} page batches ready for video creation.'),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text(
          'Processing',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A1A23),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isProcessing) ...[
            IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.orange),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ApiTestWidget(),
                  ),
                );
              },
              tooltip: 'Test API',
            ),
            PopupMenuButton<bool>(
              icon: const Icon(Icons.settings, color: Colors.white),
              onSelected: (bool useAI) {
                setState(() {
                  _useAICleaning = useAI;
                });
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<bool>(
                  value: false,
                  child: Row(
                    children: [
                      Icon(Icons.speed,
                          color: _useAICleaning ? Colors.grey : Colors.green),
                      const SizedBox(width: 8),
                      const Text('Fast Processing'),
                    ],
                  ),
                ),
                PopupMenuItem<bool>(
                  value: true,
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          color: _useAICleaning ? Colors.blue : Colors.grey),
                      const SizedBox(width: 8),
                      const Text('AI Enhanced'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFF6366F1).withOpacity(0.2),
          ),
        ),
      ),
      body: _isProcessing
          ? _buildProcessingView()
          : _pageBatches.isEmpty // Changed from _chapters
              ? _buildEmptyState()
              : _buildPageBatchesView(), // Changed from _buildChaptersView
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A23),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _useAICleaning
                ? 'AI Processing Your Content'
                : 'Processing Your Content',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _processingStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          if (_useAICleaning) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A23),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF6366F1),
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'AI Enhancement Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cleaning text, fixing formatting, and improving readability...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A23),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.upload_file,
              size: 64,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Content to Process',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Upload a PDF from the Create tab to extract and process page batches',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A23),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _useAICleaning
                    ? const Color(0xFF6366F1).withOpacity(0.3)
                    : const Color(0xFF10B981).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _useAICleaning ? Icons.auto_awesome : Icons.speed,
                  color: _useAICleaning
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF10B981),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _useAICleaning
                      ? 'AI Enhancement Mode'
                      : 'Fast Processing Mode',
                  style: TextStyle(
                    color: _useAICleaning
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageBatchesView() {
    // Renamed from _buildChaptersView
    return SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats header
            if (_lastResult != null) _buildStatsHeader(),
            const SizedBox(height: 24),

            Row(
              children: [
                Icon(
                  Icons.auto_stories,
                  color: const Color(0xFF6366F1),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Extracted Page Batches', // Changed from 'Extracted Chapters'
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_pageBatches.length} page batches ready for video creation', // Changed from chapters
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pageBatches.length, // Changed from _chapters
              itemBuilder: (context, index) {
                return _buildPageBatchCard(
                    _pageBatches[index], index); // Changed method name
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    final result = _lastResult!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Processing Results',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Page Batches', // Changed from 'Chapters'
                  result.totalPageBatches
                      .toString(), // Changed from totalChapters
                  Icons.layers_outlined, // Changed icon
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Words',
                  '${(result.totalWords / 1000).toStringAsFixed(1)}K',
                  Icons.text_fields,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Read Time',
                  '${result.estimatedReadingTimeMinutes.toInt()}m',
                  Icons.schedule,
                ),
              ),
            ],
          ),
          if (_useAICleaning && _pageBatches.any((batch) => batch.cleaned)) ...[
            // Changed from chapters
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'AI Enhanced: ${_pageBatches.where((batch) => batch.cleaned).length}/${_pageBatches.length} batches', // Changed text
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPageBatchCard(PageBatchModel batch, int index) {
    // Renamed and updated parameter type
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: const Color(0xFF1A1A23),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF6366F1).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          _showPageBatchDetails(batch); // Changed method name
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Pages ${batch.pageRange}', // Changed to show page range
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (batch.cleaned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: Color(0xFF10B981), size: 12),
                          const SizedBox(width: 4),
                          const Text(
                            'AI Enhanced',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                batch.displayTitle, // Using helper method from model
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                batch.displayText, // Using helper method from model
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.format_align_left,
                    '${batch.wordCount} words',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.layers,
                    '${batch.pagesInBatch} pages', // Show pages in batch
                    color: const Color(0xFF6366F1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    final chipColor = color ?? Colors.white.withOpacity(0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showPageBatchDetails(PageBatchModel batch) {
    // Renamed and updated parameter type
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      batch.displayTitle, // Using helper method
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (batch.cleaned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
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
                              fontWeight: FontWeight.w500,
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
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.layers,
                    '${batch.pagesInBatch} pages',
                    color: const Color(0xFF6366F1),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    batch.displayText, // Using helper method
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _createVideoFromPageBatch(batch); // Changed method name
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_call, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Create Video from Pages', // Changed text
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createVideoFromPageBatch(PageBatchModel batch) async {
    // Renamed and updated parameter type
    try {
      // First test API connectivity
      final apiHealth = await VideoGenerationService.checkHealth();
      if (!apiHealth) {
        throw Exception(
            'API server is not responding. Please check your internet connection.');
      }

      // Show loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                    'Starting video generation for "${batch.displayTitle}"...'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // Get the text content (prefer cleaned text if available)
      final batchText = batch.displayText;

      print('Page batch text length: ${batchText.length}');
      print('Page batch title: ${batch.displayTitle}');

      // Start video generation using VideoManager
      final jobId = await _videoManager.generateVideoFromChapter(
        // Method name unchanged for compatibility
        chapterText: batchText,
        chapterTitle: batch.displayTitle,
      );

      print('Job started with ID: $jobId');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Video generation started! Check the Videos tab to monitor progress.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

      // Parse common error types
      if (errorMessage.contains('405') ||
          errorMessage.contains('Method not allowed')) {
        errorMessage =
            'API endpoint not available. The server may be updating.';
      } else if (errorMessage.contains('Failed to fetch')) {
        errorMessage = 'Network connection failed. Please check your internet.';
      } else if (errorMessage.contains('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      }

      // Show error message with action buttons
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Test API',
            textColor: Colors.white, // <-- Added comma here
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
    // Use the navigation service to navigate to videos tab
    NavigationService().navigateToVideos();
  }
}
