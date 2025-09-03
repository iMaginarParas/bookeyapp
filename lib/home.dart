import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

// Import the API service and input components
import 'api_service.dart';
import 'input.dart';

class HomePage extends StatefulWidget {
  final Function(ProcessingResult) onContentProcessed;
  
  const HomePage({super.key, required this.onContentProcessed});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _storyController = TextEditingController();
  File? _selectedFile;
  PlatformFile? _selectedWebFile;
  bool _isProcessing = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  int _wordCount = 0;
  int _currentBannerIndex = 0;
  int _selectedTabIndex = 0; // 0=AI Story, 1=Audio, 2=Images, 3=PDF, 4=Manual Text

  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Create Amazing Videos',
      'subtitle': 'Transform your content into cinematic experiences',
      'gradient': [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    },
    {
      'title': 'AI Story Generator',
      'subtitle': 'Generate creative stories with artificial intelligence',
      'gradient': [Color(0xFF10B981), Color(0xFF059669)],
    },
    {
      'title': 'Audio to Video',
      'subtitle': 'Convert audio books and recordings to engaging videos',
      'gradient': [Color(0xFFEC4899), Color(0xFFEF4444)],
    },
    {
      'title': 'Image Text Extraction',
      'subtitle': 'Extract text from photos using advanced OCR technology',
      'gradient': [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    },
  ];

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _storyController.addListener(_updateWordCount);
    
    // Start banner rotation
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentBannerIndex = (_currentBannerIndex + 1) % _banners.length;
        });
      }
    });
  }

  void _updateWordCount() {
    final text = _storyController.text;
    final words = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    if (words != _wordCount) {
      setState(() {
        _wordCount = words;
      });
    }
  }

  @override
  void dispose() {
    _storyController.removeListener(_updateWordCount);
    _storyController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _selectedWebFile = result.files.single;
            _selectedFile = null;
          } else {
            _selectedFile = File(result.files.single.path!);
            _selectedWebFile = null;
          }
        });
        
        _showSuccessSnackBar('PDF selected successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting PDF: $e');
    }
  }

  Future<void> _processPdf() async {
    if (_selectedFile == null && _selectedWebFile == null) {
      _showErrorSnackBar('Please select a PDF file first');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Process PDF with AI cleaning by default
      final result = await ApiService.processPdfWithAI(_selectedFile, _selectedWebFile, maxConcurrent: 5);
      
      if (result.success) {
        widget.onContentProcessed(result);
        _showSuccessSnackBar('PDF processed successfully! Check Processing tab');
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to process PDF: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processManualText() async {
    if (_storyController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter some text first');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Create a manual ProcessingResult from the text input
      final batch = PageBatchModel(
        batchNumber: 1,
        pageRange: "Manual Input",
        cleanedText: _storyController.text.trim(),
        wordCount: _wordCount,
        cleaned: false,
        pagesInBatch: 1,
      );

      final result = ProcessingResult(
        success: true,
        message: "Manual text input processed",
        fileName: "Manual Text Input",
        totalPageBatches: 1,
        totalWords: _wordCount,
        estimatedReadingTimeMinutes: _wordCount / 200.0,
        pageBatches: [batch],
        processingTimeSeconds: 1.0,
      );

      widget.onContentProcessed(result);
      _showSuccessSnackBar('Text processed successfully! Check Processing tab');
    } catch (e) {
      _showErrorSnackBar('Failed to process text: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Handle results from input widgets
  void _handleContentProcessed(ProcessingResult result) {
    widget.onContentProcessed(result);
    _showSuccessSnackBar('Content processed! Check Processing tab');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(),
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildBanner(),
                  const SizedBox(height: 24),
                  _buildMainContent(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0A0A0F),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6366F1),
                Color(0xFF8B5CF6),
                Color(0xFFEC4899),
              ],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0A0A0F).withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Bookey',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            // Credits display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFFFFD700),
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '250',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 24, bottom: 12),
      ),
    );
  }

  Widget _buildBanner() {
    final currentBanner = _banners[_currentBannerIndex];
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: currentBanner['gradient'],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: currentBanner['gradient'][0].withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentBanner['title'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentBanner['subtitle'],
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Content Input Methods',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildTabSelector(),
            const SizedBox(height: 24),
            _buildTabContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF2A2A3A),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton(
            title: 'AI Story',
            icon: Icons.auto_awesome,
            isSelected: _selectedTabIndex == 0,
            onTap: () => setState(() => _selectedTabIndex = 0),
          ),
          const SizedBox(width: 4),
          _buildTabButton(
            title: 'Audio',
            icon: Icons.audiotrack,
            isSelected: _selectedTabIndex == 1,
            onTap: () => setState(() => _selectedTabIndex = 1),
          ),
          const SizedBox(width: 4),
          _buildTabButton(
            title: 'Images',
            icon: Icons.photo_camera,
            isSelected: _selectedTabIndex == 2,
            onTap: () => setState(() => _selectedTabIndex = 2),
          ),
          const SizedBox(width: 4),
          _buildTabButton(
            title: 'PDF',
            icon: Icons.picture_as_pdf,
            isSelected: _selectedTabIndex == 3,
            onTap: () => setState(() => _selectedTabIndex = 3),
          ),
          const SizedBox(width: 4),
          _buildTabButton(
            title: 'Text',
            icon: Icons.edit,
            isSelected: _selectedTabIndex == 4,
            onTap: () => setState(() => _selectedTabIndex = 4),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildTabButton({
  required String title,
  required IconData icon,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        gradient: isSelected 
            ? const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              )
            : null,
        color: isSelected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0: // AI Story Generator
        return StoryGeneratorWidget(
          key: const ValueKey('story_generator'),
          onStoryGenerated: _handleContentProcessed,
        );
      case 1: // Audio Book
        return AudioUploadWidget(
          key: const ValueKey('audio_upload'),
          onAudioProcessed: _handleContentProcessed,
        );
      case 2: // Images/OCR
        return EnhancedCameraWidget(
          key: const ValueKey('image_upload'),
          onImagesProcessed: _handleContentProcessed,
        );
      case 3: // PDF Upload
        return _buildPdfTab();
      case 4: // Manual Text Input
        return _buildManualTextTab();
      default:
        return _buildManualTextTab();
    }
  }

  Widget _buildPdfTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_selectedFile != null || _selectedWebFile != null)
              ? const Color(0xFFEF4444).withOpacity(0.5)
              : const Color(0xFF6366F1).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: (_selectedFile != null || _selectedWebFile != null)
                    ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                    : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (_selectedFile != null || _selectedWebFile != null)
                      ? const Color(0xFFEF4444).withOpacity(0.3)
                      : const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              (_selectedFile != null || _selectedWebFile != null)
                  ? Icons.check_circle
                  : Icons.picture_as_pdf,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            (_selectedFile != null || _selectedWebFile != null)
                ? 'PDF File Selected!'
                : 'Upload PDF Document',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (_selectedFile != null || _selectedWebFile != null)
                ? 'Ready to process with AI text cleaning and enhancement'
                : 'Upload PDF files for AI-powered text extraction and cleaning',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedFile != null || _selectedWebFile != null) ? null : _pickPdfFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: (_selectedFile != null || _selectedWebFile != null)
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        (_selectedFile != null || _selectedWebFile != null)
                            ? Icons.swap_horiz
                            : Icons.upload_file,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (_selectedFile != null || _selectedWebFile != null)
                            ? 'Change PDF File'
                            : 'Choose PDF File',
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
            ),
          ),
          if (_selectedFile != null || _selectedWebFile != null) ...[
            const SizedBox(height: 16),
            _buildSelectedPdfCard(),
            const SizedBox(height: 16),
            _buildProcessPdfButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedPdfCard() {
    final fileName = kIsWeb 
        ? (_selectedWebFile?.name ?? 'PDF Document')
        : (_selectedFile?.path.split('/').last ?? 'PDF Document');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  'AI text extraction and cleaning ready',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedFile = null;
                _selectedWebFile = null;
              });
            },
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessPdfButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPdf,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isProcessing
                ? LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade700])
                : const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFEF4444)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Processing PDF...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Process PDF with AI',
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
    );
  }

  Widget _buildManualTextTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _storyController.text.isNotEmpty 
              ? const Color(0xFF6366F1).withOpacity(0.5)
              : const Color(0xFF6366F1).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Manual Text Input',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (_wordCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_wordCount words',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _storyController.text.isNotEmpty 
                    ? const Color(0xFF6366F1).withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _storyController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your story, script, or any text content here...\n\nThis text will be processed and made ready for video generation.',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.edit, color: Color(0xFF6366F1), size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
                filled: true,
                fillColor: Colors.transparent,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    _storyController.clear();
                    setState(() {
                      _wordCount = 0;
                    });
                  },
                  child: const Text(
                    'Clear Text',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processManualText,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _isProcessing
                          ? LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade700])
                          : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: _isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Processing...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Process Text',
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
        ],
      ),
    );
  }
}