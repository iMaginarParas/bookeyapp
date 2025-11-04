import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import the API service and input components
import 'api_service.dart';
import 'input.dart';
import 'wallet_service.dart';
import 'credit.dart';
import 'navigation_service.dart';

class HomePage extends StatefulWidget {
  final Function(ProcessingResult) onContentProcessed;

  const HomePage({super.key, required this.onContentProcessed});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  File? _selectedFile;
  PlatformFile? _selectedWebFile;
  bool _isProcessing = false;
  int _creditBalance = 0;
  bool _isLoadingCredits = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _selectedTabIndex = 0; // 0=Story Maker, 1=Audio Book, 2=Images, 3=Ebook

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
    
    // Load credits when page initializes
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    setState(() {
      _isLoadingCredits = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('access_token');
      
      if (jwtToken != null) {
        final walletInfo = await WalletService.getWalletInfo(jwtToken);
        setState(() {
          _creditBalance = walletInfo?.creditsBalance ?? 0;
        });
      }
    } catch (e) {
      print('Error loading credits: $e');
      // Keep default balance of 0 if there's an error
    } finally {
      setState(() {
        _isLoadingCredits = false;
      });
    }
  }

  void _navigateToWallet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreditPage(),
      ),
    ).then((_) {
      // Refresh credits when returning from credit page
      _loadCredits();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
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

        _showSnackBar('PDF selected successfully!', isError: false);
      }
    } catch (e) {
      _showSnackBar('Error selecting PDF: $e', isError: true);
    }
  }

  Future<void> _processPdf() async {
    if (_selectedFile == null && _selectedWebFile == null) {
      _showSnackBar('Please select an ebook file first', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await ApiService.processPdfWithAI(
          _selectedFile, _selectedWebFile,
          maxConcurrent: 5);

      if (result.success) {
        // Show success message briefly
        _showSnackBar('Ebook processed successfully!', isError: false);
        
        // Wait a moment then navigate
        await Future.delayed(Duration(milliseconds: 800));
        NavigationService().navigateToProcessing();
        widget.onContentProcessed(result);
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      _showSnackBar('Failed to process ebook: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 6,
      ),
    );
  }

  void _handleContentProcessed(ProcessingResult result) {
    // Show immediate feedback
    _showSnackBar('Content processed successfully! Navigating to Processing...',
        isError: false);

    // Small delay for user to see the success message
    Future.delayed(const Duration(milliseconds: 800), () {
      // Navigate to processing tab and pass the result
      widget.onContentProcessed(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F4), // Cream background
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildWelcomeSection(),
                    const SizedBox(height: 20),
                    _buildMainContent(),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
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
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Bookey',
              style: TextStyle(
                color: Color(0xFF2D2D2D),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _navigateToWallet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3F0), // Beige
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE8E3DD),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: Color(0xFF8B7355), // Brown tone
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    _isLoadingCredits
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B7355)),
                            ),
                          )
                        : Text(
                            '$_creditBalance',
                            style: TextStyle(
                              color: Color(0xFF8B7355),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF8B7355),
                      size: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D2D2D),
            Color(0xFF3D3D3D),
          ],
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.rocket_launch,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transform Ideas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Turn your content into stunning videos',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Content Input Methods',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D2D2D),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose your preferred input method to get started',
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF8B7355),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            _buildTabSelector(),
            const SizedBox(height: 20),
            _buildTabContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3F0), // Beige background
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              title: 'Story Maker',
              icon: Icons.auto_awesome,
              isSelected: _selectedTabIndex == 0,
              onTap: () => setState(() => _selectedTabIndex = 0),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _buildTabButton(
              title: 'Audio Book',
              icon: Icons.audiotrack,
              isSelected: _selectedTabIndex == 1,
              onTap: () => setState(() => _selectedTabIndex = 1),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _buildTabButton(
              title: 'Images',
              icon: Icons.photo_camera,
              isSelected: _selectedTabIndex == 2,
              onTap: () => setState(() => _selectedTabIndex = 2),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _buildTabButton(
              title: 'Ebook',
              icon: Icons.picture_as_pdf,
              isSelected: _selectedTabIndex == 3,
              onTap: () => setState(() => _selectedTabIndex = 3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D2D2D) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF8B7355),
              size: 16,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8B7355),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0: // Story Maker
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
      case 3: // Ebook Upload
        return _buildPdfTab();
      default:
        return _buildPdfTab();
    }
  }

  Widget _buildPdfTab() {
    final hasFile = _selectedFile != null || _selectedWebFile != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasFile ? const Color(0xFFF0FDF4) : const Color(0xFFF5F3F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFile
              ? const Color(0xFF10B981).withOpacity(0.3)
              : const Color(0xFFE8E3DD),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color:
                  hasFile ? const Color(0xFF10B981) : const Color(0xFF8B7355),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (hasFile
                          ? const Color(0xFF10B981)
                          : const Color(0xFF8B7355))
                      .withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              hasFile ? Icons.check_circle : Icons.picture_as_pdf,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFile ? 'Ebook File Selected!' : 'Upload Ebook Document',
            style: const TextStyle(
              color: Color(0xFF2D2D2D),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFile
                ? 'Ready to process with AI text cleaning and enhancement'
                : 'Upload PDF/EPUB files for AI-powered text extraction and cleaning',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8B7355),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (!hasFile)
            _buildActionButton(
              text: 'Choose Ebook File',
              icon: Icons.upload_file,
              onPressed: _pickPdfFile,
              isPrimary: true,
            ),
          if (hasFile) ...[
            _buildSelectedFileCard(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    text: 'Change File',
                    icon: Icons.swap_horiz,
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                        _selectedWebFile = null;
                      });
                    },
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildActionButton(
                    text: _isProcessing ? 'Processing...' : 'Process Ebook',
                    icon: _isProcessing ? null : Icons.auto_awesome,
                    onPressed: _isProcessing ? null : _processPdf,
                    isPrimary: true,
                    isLoading: _isProcessing,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedFileCard() {
    final fileName = kIsWeb
        ? (_selectedWebFile?.name ?? 'Ebook Document')
        : (_selectedFile?.path.split('/').last ?? 'Ebook Document');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Color(0xFF2D2D2D),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'AI text extraction ready',
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
    );
  }

  Widget _buildActionButton({
    required String text,
    IconData? icon,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool isLoading = false,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: const Color(0xFF2D2D2D).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? const Color(0xFF2D2D2D) : Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : const Color(0xFF8B7355),
          disabledBackgroundColor:
              isPrimary ? const Color(0xFFF3F4F6) : Colors.transparent,
          disabledForegroundColor: const Color(0xFF9CA3AF),
          elevation: 0,
          shadowColor: Colors.transparent,
          side: isPrimary
              ? null
              : const BorderSide(
                  color: Color(0xFFE8E3DD),
                  width: 1,
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}