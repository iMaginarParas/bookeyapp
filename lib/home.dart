import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

// Modern AI Content Creation Home Page
class HomePage extends StatefulWidget {
  final Function(File?, PlatformFile?) onFileExtract;
  
  const HomePage({super.key, required this.onFileExtract});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _storyController = TextEditingController();
  File? _selectedFile;
  PlatformFile? _selectedWebFile;
  File? _selectedImage;
  PlatformFile? _selectedWebImage;
  bool _isCameraMode = false;
  File? _selectedAudioFile;
  PlatformFile? _selectedWebAudioFile;
  
  late AnimationController _fadeController;
  late AnimationController _bannerController;
  late AnimationController _tabController;
  late Animation<double> _fadeAnimation;
  
  int _wordCount = 0;
  String _selectedAspectRatio = '16:9';
  bool _isGenerating = false;
  int _currentBannerIndex = 0;
  int _selectedTabIndex = 0; // 0 = Text Input, 1 = Audio Book

  final List<String> _aspectRatios = ['16:9', '9:16', '1:1', '4:3'];
  
  final List<Map<String, dynamic>> _banners = [
    {
      'title': '🎬 Create Amazing Videos',
      'subtitle': 'Transform your stories into cinematic experiences',
      'gradient': [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    },
    {
      'title': '📚 From Books to Videos',
      'subtitle': 'Convert your favorite chapters into visual stories',
      'gradient': [Color(0xFF10B981), Color(0xFF059669)],
    },
    {
      'title': '✨ AI-Powered Creation',
      'subtitle': 'Let artificial intelligence bring your ideas to life',
      'gradient': [Color(0xFFEC4899), Color(0xFFEF4444)],
    },
    {
      'title': '🚀 Boost Your Content',
      'subtitle': 'Turn text into engaging multimedia experiences',
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

    _bannerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _tabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _storyController.addListener(_updateWordCount);
    
    // Start banner rotation
    _startBannerRotation();
  }

  void _startBannerRotation() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
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
    _bannerController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
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
        
        _showSuccessSnackBar('PDF uploaded successfully! 🎬');
      }
    } catch (e) {
      _showErrorSnackBar('Error uploading PDF: $e');
    }
  }

  Future<void> _openCamera() async {
    setState(() {
      _isCameraMode = true;
    });
    
    // Show camera interface
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => _buildCameraInterface(),
    );
  }

  Widget _buildCameraInterface() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          // Camera header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isCameraMode = false;
                    });
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
                const Spacer(),
                const Text(
                  'Camera',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48), // Balance the close button
              ],
            ),
          ),
          
          // Camera preview area
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white60,
                        size: 80,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Camera Preview (Simulated)',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is a demo interface. Real camera integration requires additional plugins.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Camera controls
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImage();
                    },
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                  ),
                ),
                
                // Capture button
                GestureDetector(
                  onTap: () {
                    _capturePhoto();
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                
                // Switch camera button
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () {
                      // Switch camera logic would go here
                      _showSuccessSnackBar('Camera switched! 📷');
                    },
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _selectedWebImage = result.files.single;
            _selectedImage = null;
          } else {
            _selectedImage = File(result.files.single.path!);
            _selectedWebImage = null;
          }
        });
        
        _showSuccessSnackBar('Image uploaded successfully! 🖼️');
      }
    } catch (e) {
      _showErrorSnackBar('Error uploading image: $e');
    }
  }

  void _openWritingSpace() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
              
              // Header
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Write Your Story',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_wordCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(20),
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
              const SizedBox(height: 20),
              
              // Writing area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3A),
                    borderRadius: BorderRadius.circular(16),
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
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Start writing your story...\n\nDescribe your characters, settings, and plot. The more detail you provide, the better your video will be.',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        height: 1.6,
                        fontSize: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(20),
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Action buttons
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
                        'Clear',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (_storyController.text.trim().isNotEmpty) {
                          _showSuccessSnackBar('Story saved! Ready to generate video ✨');
                        }
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
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _selectedWebAudioFile = result.files.single;
            _selectedAudioFile = null;
          } else {
            _selectedAudioFile = File(result.files.single.path!);
            _selectedWebAudioFile = null;
          }
        });
        
        _showSuccessSnackBar('Audio book uploaded successfully! 🎧');
      }
    } catch (e) {
      _showErrorSnackBar('Error uploading audio file: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6366F1),
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

  bool _hasContent() {
    return (_storyController.text.trim().isNotEmpty && _selectedTabIndex == 0) ||
           (_selectedFile != null || _selectedWebFile != null) ||
           (_selectedImage != null || _selectedWebImage != null) ||
           (_selectedAudioFile != null || _selectedWebAudioFile != null);
  }

  void _generateVideo() async {
    if (!_hasContent()) {
      _showErrorSnackBar('Please add content first! 📝');
      return;
    }

    // If PDF is uploaded, process it and navigate to processing tab
    if (_selectedFile != null || _selectedWebFile != null) {
      widget.onFileExtract(_selectedFile, _selectedWebFile);
      return;
    }

    // Otherwise, generate video from text or audio
    setState(() {
      _isGenerating = true;
    });

    String contentType = _selectedTabIndex == 0 ? 'text' : 'audio book';
    
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
            Text('🎬 Generating video from $contentType...'),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Simulate video generation
    await Future.delayed(const Duration(seconds: 4));

    setState(() {
      _isGenerating = false;
    });

    _showSuccessSnackBar('Video generated successfully! ✨');
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
                  const SizedBox(height: 20),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/logo.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Debug: Print error to console
                    print('Logo loading error: $error');
                    // Fallback to icon if logo fails to load
                    return const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 20,
                    );
                  },
                ),
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
            _buildHeader(),
            const SizedBox(height: 24),
            _buildTabSection(),
            const SizedBox(height: 24),
            _buildGenerateButton(),
          ],
        ),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_wordCount > 0 && _selectedTabIndex == 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(20),
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
    );
  }

  Widget _buildTabSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Content Input',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 24),
        
        // Tab Selector
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  title: 'Text Input',
                  icon: Icons.edit_outlined,
                  isSelected: _selectedTabIndex == 0,
                  onTap: () => setState(() => _selectedTabIndex = 0),
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  title: 'Audio Book',
                  icon: Icons.audiotrack_outlined,
                  isSelected: _selectedTabIndex == 1,
                  onTap: () => setState(() => _selectedTabIndex = 1),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Tab Content
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _selectedTabIndex == 0 
              ? _buildTextInputTab()
              : _buildAudioBookTab(),
        ),
      ],
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
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _capturePhoto() {
    // IMPORTANT: This is a DUMMY/SIMULATED camera interface
    // It does NOT actually access the device camera or take real photos
    // To implement real camera functionality, you would need to:
    // 1. Add camera plugin to pubspec.yaml (e.g., camera: ^0.10.5+5)
    // 2. Add camera permissions to Android/iOS
    // 3. Implement actual camera controller and preview
    // 4. Capture and save real photos
    
    Navigator.pop(context);
    setState(() {
      _isCameraMode = false;
      // In real implementation, you would set the actual captured image here
    });
    
    _showSuccessSnackBar('📸 Demo: Photo "captured" (simulated only)');
  }

  Widget _buildTextInputTab() {
    return Column(
      key: const ValueKey('text_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload buttons row
        Row(
          children: [
            Expanded(
              child: _buildUploadButton(
                icon: Icons.upload_file_rounded,
                label: 'Upload PDF',
                onTap: _pickFile,
                isSelected: _selectedFile != null || _selectedWebFile != null,
                gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildUploadButton(
                icon: Icons.camera_alt,
                label: 'Camera',
                onTap: _openCamera,
                isSelected: _selectedImage != null || _selectedWebImage != null,
                gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Writing space preview/trigger
        GestureDetector(
          onTap: _openWritingSpace,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _storyController.text.isNotEmpty 
                    ? const Color(0xFF6366F1).withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF6366F1),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Write Your Story',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
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
                const SizedBox(height: 12),
                Text(
                  _storyController.text.isNotEmpty 
                      ? _storyController.text.length > 100 
                          ? '${_storyController.text.substring(0, 100)}...'
                          : _storyController.text
                      : 'Tap to open the writing space and create your story...',
                  style: TextStyle(
                    color: _storyController.text.isNotEmpty 
                        ? Colors.white.withOpacity(0.8)
                        : Colors.white.withOpacity(0.4),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.launch, color: Color(0xFF6366F1), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Open Writing Space',
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_storyController.text.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _storyController.clear();
                          setState(() {
                            _wordCount = 0;
                          });
                        },
                        icon: Icon(
                          Icons.clear,
                          color: Colors.white.withOpacity(0.6),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Selected files display
        if (_selectedFile != null || _selectedWebFile != null)
          _buildSelectedFileCard(
            fileName: kIsWeb 
                ? _selectedWebFile?.name ?? 'PDF Document'
                : _selectedFile?.path.split('/').last ?? 'PDF Document',
            icon: Icons.picture_as_pdf,
            color: const Color(0xFFEF4444),
            onRemove: () => setState(() {
              _selectedFile = null;
              _selectedWebFile = null;
            }),
          ),
        
        if (_selectedImage != null || _selectedWebImage != null)
          _buildSelectedFileCard(
            fileName: kIsWeb 
                ? _selectedWebImage?.name ?? 'Captured Photo'
                : _selectedImage?.path.split('/').last ?? 'Captured Photo',
            icon: Icons.photo_camera,
            color: const Color(0xFF8B5CF6),
            onRemove: () => setState(() {
              _selectedImage = null;
              _selectedWebImage = null;
            }),
          ),
      ],
    );
  }

  Widget _buildAudioBookTab() {
    return Column(
      key: const ValueKey('audio_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Audio upload section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (_selectedAudioFile != null || _selectedWebAudioFile != null)
                  ? const Color(0xFF10B981).withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.audiotrack,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedAudioFile != null || _selectedWebAudioFile != null
                    ? 'Audio Book Uploaded!'
                    : 'Upload Audio Book',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedAudioFile != null || _selectedWebAudioFile != null
                    ? 'Ready to process your audio book'
                    : 'Upload MP3, WAV, or other audio formats',
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
                  onPressed: _pickAudioFile,
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
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
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
                            _selectedAudioFile != null || _selectedWebAudioFile != null
                                ? Icons.check_circle
                                : Icons.upload_file,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedAudioFile != null || _selectedWebAudioFile != null
                                ? 'Change Audio Book'
                                : 'Choose Audio File',
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
            ],
          ),
        ),
        
        // Selected audio file display
        if (_selectedAudioFile != null || _selectedWebAudioFile != null)
          _buildSelectedFileCard(
            fileName: kIsWeb 
                ? _selectedWebAudioFile?.name ?? 'Audio Book'
                : _selectedAudioFile?.path.split('/').last ?? 'Audio Book',
            icon: Icons.audiotrack,
            color: const Color(0xFF10B981),
            onRemove: () => setState(() {
              _selectedAudioFile = null;
              _selectedWebAudioFile = null;
            }),
          ),
        
        const SizedBox(height: 16),
        
        // Audio processing info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF6366F1).withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Audio Processing Features',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFeatureItem('🎯 AI-powered speech-to-text conversion'),
              _buildFeatureItem('📖 Automatic chapter detection'),
              _buildFeatureItem('🎬 Generate videos from audio content'),
              _buildFeatureItem('⚡ Fast processing with high accuracy'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildUploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
    required List<Color> gradient,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: isSelected 
              ? LinearGradient(colors: gradient)
              : null,
          color: isSelected ? null : const Color(0xFF2A2A3A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? Colors.transparent
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFileCard({
    required String fileName,
    required IconData icon,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    String buttonText = _selectedFile != null || _selectedWebFile != null 
        ? 'Process PDF' 
        : _selectedTabIndex == 0 
            ? 'Generate Video' 
            : 'Process Audio Book';
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateVideo,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isGenerating 
                ? LinearGradient(
                    colors: [
                      Colors.grey.shade600,
                      Colors.grey.shade700,
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                      Color(0xFFEC4899),
                    ],
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isGenerating
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedTabIndex == 1 
                            ? Icons.audiotrack
                            : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        buttonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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
}