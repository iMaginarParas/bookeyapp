import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';  // ← MISSING! (for json.decode)
import 'package:http/http.dart' as http;  // ← MISSING! (for wallet API)
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
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
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

  // New method to handle content that was processed elsewhere and passed to this page
  void loadProcessedContent(ProcessingResult result) {
    setState(() {
      _pageBatches = result.pageBatches;
      _lastResult = result;
      _isProcessing = false;
      _processingStatus = 'Content loaded successfully!';
    });
    
    _slideController.forward();
    
    // Determine the content type based on the result
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
      'Content loaded successfully! ${result.totalPageBatches} page batches ready for video creation from $contentType.',
      isError: false,
    );

    // Force UI refresh to ensure content is displayed
    Future.delayed(Duration(milliseconds: 100), () {
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
            isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug print to help troubleshoot
    print('Processing page build: isProcessing=$_isProcessing, pageBatches.length=${_pageBatches.length}');
    
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F4), // Cream background matching home
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isProcessing
            ? _buildProcessingView()
            : _pageBatches.isEmpty
                ? _buildEmptyState()
                : _buildPageBatchesView(),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_stories,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Processing',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D2D),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
      actions: [
        if (!_isProcessing) ...[
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.bug_report, 
                color: Color(0xFFFF6B35),
                size: 18,
              ),
            ),
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
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B7355).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.settings, 
                color: Color(0xFF8B7355),
                size: 18,
              ),
            ),
            onSelected: (bool useAI) {
              setState(() {
                _useAICleaning = useAI;
              });
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            elevation: 8,
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<bool>(
                value: false,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (_useAICleaning ? const Color(0xFF9CA3AF) : const Color(0xFF10B981)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.speed,
                        color: _useAICleaning ? const Color(0xFF9CA3AF) : const Color(0xFF10B981),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Fast Processing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<bool>(
                value: true,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (_useAICleaning ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: _useAICleaning ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'AI Enhanced',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
                  colors: _useAICleaning
                      ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                      : [const Color(0xFF10B981), const Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_useAICleaning 
                        ? const Color(0xFF6366F1) 
                        : const Color(0xFF10B981)).withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Processing Your Content',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2D2D),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _processingStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8B7355),
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            if (_useAICleaning) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF6366F1),
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AI Enhancement Active',
                      style: TextStyle(
                        color: Color(0xFF2D2D2D),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Using storage-first architecture with AI-powered text cleaning...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
                color: const Color(0xFF8B7355).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.upload_file,
                size: 36,
                color: Color(0xFF8B7355),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Content to Process',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2D2D),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload content from the Create tab to see processed page batches here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8B7355),
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3F0), // Beige background
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE8E3DD),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Supported Content Types',
                    style: TextStyle(
                      color: Color(0xFF2D2D2D),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• AI Stories - Generate custom stories\n• Audio Files - AssemblyAI transcription with speaker labels\n• Images - OCR text extraction with R2 storage\n• PDF Files - Text extraction with AI cleaning',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Color(0xFF8B7355),
                      fontSize: 14,
                      height: 1.4,
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

  Widget _buildPageBatchesView() {
    return SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_lastResult != null) _buildStatsHeader(),
            const SizedBox(height: 24),
            _buildSectionHeader(),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pageBatches.length,
              itemBuilder: (context, index) {
                return _buildPageBatchCard(_pageBatches[index], index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_stories,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Processed Content Batches',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D2D2D),
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  '${_pageBatches.length} content batches ready for video creation',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8B7355),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final result = _lastResult!;
    
    // Determine content type for better display
    String contentTypeIcon = '📄';
    String contentTypeLabel = 'Content';
    Color gradientColor1 = const Color(0xFF2D2D2D);
    Color gradientColor2 = const Color(0xFF3D3D3D);
    
    if (result.fileName.toLowerCase().contains('image') || 
        result.message.toLowerCase().contains('image')) {
      contentTypeIcon = '🖼️';
      contentTypeLabel = 'Images';
      gradientColor1 = const Color(0xFF7C3AED);
      gradientColor2 = const Color(0xFF8B5CF6);
    } else if (result.fileName.toLowerCase().contains('audio') || 
               result.message.toLowerCase().contains('audio') ||
               result.message.toLowerCase().contains('transcription')) {
      contentTypeIcon = '🎵';
      contentTypeLabel = 'Audio';
      gradientColor1 = const Color(0xFF10B981);
      gradientColor2 = const Color(0xFF059669);
    } else if (result.fileName.toLowerCase().contains('story') || 
               result.message.toLowerCase().contains('story')) {
      contentTypeIcon = '✨';
      contentTypeLabel = 'AI Story';
      gradientColor1 = const Color(0xFF6366F1);
      gradientColor2 = const Color(0xFF8B5CF6);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientColor1, gradientColor2],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  contentTypeIcon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$contentTypeLabel Processing Results',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      result.fileName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Content Batches',
                  result.totalPageBatches.toString(),
                  Icons.layers_outlined,
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
          if (_pageBatches.any((batch) => batch.cleaned)) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome, 
                    color: Colors.white, 
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Enhanced: ${_pageBatches.where((batch) => batch.cleaned).length}/${_pageBatches.length} batches processed with storage-first architecture',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageBatchCard(PageBatchModel batch, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8E3DD),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showPageBatchDetails(batch),
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
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      batch.pageRange.contains('Part') ? batch.pageRange : 'Pages ${batch.pageRange}',
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
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF10B981),
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'AI Enhanced',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: const Color(0xFF8B7355),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                batch.displayTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2D2D),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                batch.displayText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B7355),
                  fontWeight: FontWeight.w400,
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
                    const Color(0xFF8B7355),
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.layers,
                    '${batch.pagesInBatch} pages',
                    const Color(0xFF2D2D2D),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E3DD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      batch.displayTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D2D2D),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (batch.cleaned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
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
                    const Color(0xFF8B7355),
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.layers,
                    '${batch.pagesInBatch} pages',
                    const Color(0xFF2D2D2D),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE8E3DD),
                      ),
                    ),
                    child: Text(
                      batch.displayText,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF2D2D2D),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2D2D2D).withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _createVideoFromPageBatch(batch);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2D2D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_call, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Create Video from Content',
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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