import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // ✅ Added for haptic feedback
import 'package:shared_preferences/shared_preferences.dart';

// Import the API service and input components
import 'api_service.dart';
import 'input.dart';
import 'wallet_service.dart';
import 'credit.dart';
import 'navigation_service.dart';

// ✅ ENHANCED: Haptic Feedback Service
class HapticService {
  // Light haptic feedback for UI interactions
  static void lightImpact() {
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }
  }
  
  // Medium haptic feedback for button presses
  static void mediumImpact() {
    if (!kIsWeb) {
      HapticFeedback.mediumImpact();
    }
  }
  
  // Heavy haptic feedback for important actions
  static void heavyImpact() {
    if (!kIsWeb) {
      HapticFeedback.heavyImpact();
    }
  }
  
  // Selection feedback for toggles/switches
  static void selectionClick() {
    if (!kIsWeb) {
      HapticFeedback.selectionClick();
    }
  }
  
  // Vibration for notifications
  static void vibrate() {
    if (!kIsWeb) {
      HapticFeedback.vibrate();
    }
  }
}

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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
    
    // Load credits when page initializes
    _loadCredits();
  }

  // ✅ ENHANCED: Pull-to-refresh with haptic feedback
  Future<void> _refreshContent() async {
    // ✅ NEW: Haptic feedback for pull-to-refresh start
    HapticService.lightImpact();
    
    await _loadCredits();
    
    // ✅ NEW: Haptic feedback for refresh completion
    HapticService.selectionClick();
    
    // Show a brief feedback message
    if (mounted) {
      _showSnackBar('Content refreshed!', isError: false);
    }
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
    // ✅ NEW: Haptic feedback for wallet navigation
    HapticService.mediumImpact();
    
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
      // ✅ NEW: Haptic feedback for file picker
      HapticService.lightImpact();
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null) {
        // ✅ NEW: Haptic feedback for successful file selection
        HapticService.mediumImpact();
        
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
      // ✅ NEW: Haptic feedback for error
      HapticService.heavyImpact();
      _showSnackBar('Error selecting PDF: $e', isError: true);
    }
  }

  Future<void> _processPdf() async {
    if (_selectedFile == null && _selectedWebFile == null) {
      // ✅ NEW: Haptic feedback for error
      HapticService.heavyImpact();
      _showSnackBar('Please select an ebook file first', isError: true);
      return;
    }

    // ✅ NEW: Haptic feedback for processing start
    HapticService.mediumImpact();

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await ApiService.processPdfWithAI(
          _selectedFile, _selectedWebFile,
          maxConcurrent: 5);

      if (result.success) {
        // ✅ NEW: Haptic feedback for success
        HapticService.lightImpact();
        
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
      // ✅ NEW: Haptic feedback for error
      HapticService.heavyImpact();
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
    // ✅ NEW: Haptic feedback for content processing
    HapticService.mediumImpact();
    widget.onContentProcessed(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _refreshContent,
        color: const Color(0xFF2563EB),
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // ✅ FIXED: Compact header with credit balance (no scroll, no overflow)
            Container(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 50,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2563EB).withOpacity(0.05),
                    const Color(0xFF3B82F6).withOpacity(0.03),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title - Made flexible to prevent overflow
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Create Content',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Choose your creation method',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  // Credit balance
                  GestureDetector(
                    onTap: _navigateToWallet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: const Color(0xFF2563EB),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          if (_isLoadingCredits)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2563EB),
                                ),
                              ),
                            )
                          else
                            Text(
                              '$_creditBalance',
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
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

            // ✅ FIXED: Compact tab selector (no scroll)
            Container(
              height: 70,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabButton('Story Maker', Icons.auto_stories, 0),
                          const SizedBox(width: 8),
                          _buildTabButton('Audio Book', Icons.headphones, 1),
                          const SizedBox(width: 8),
                          _buildTabButton('Images', Icons.image, 2),
                          const SizedBox(width: 8),
                          _buildTabButton('Ebook', Icons.menu_book, 3),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ FIXED: Main content area with exact remaining height
            Expanded(
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        child: _buildTabContent(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, IconData icon, int index) {
    final isSelected = _selectedTabIndex == index;
    
    return GestureDetector(
      onTap: () {
        // ✅ NEW: Haptic feedback for tab selection
        HapticService.selectionClick();
        
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : const Color(0xFF2563EB).withOpacity(0.2),
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Color(0xFF64748B),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Color(0xFF64748B),
                fontSize: 13,
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
      case 0: // Story Maker
        return CompactStoryGeneratorWidget(
          key: const ValueKey('story_generator'),
          onStoryGenerated: _handleContentProcessed,
        );
      case 1: // Audio Book
        return CompactAudioUploadWidget(
          key: const ValueKey('audio_upload'),
          onAudioProcessed: _handleContentProcessed,
        );
      case 2: // Images/OCR
        return CompactCameraWidget(
          key: const ValueKey('image_upload'),
          onImagesProcessed: _handleContentProcessed,
        );
      case 3: // Ebook Upload
        return _buildCompactPdfTab();
      default:
        return _buildCompactPdfTab();
    }
  }

  // ✅ COMPACT: PDF upload widget that fits without scrolling
  Widget _buildCompactPdfTab() {
    final hasFile = _selectedFile != null || _selectedWebFile != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon and status
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: hasFile
                    ? LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      )
                    : LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (hasFile ? const Color(0xFF10B981) : const Color(0xFF2563EB))
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                hasFile ? Icons.check_circle : Icons.picture_as_pdf,
                color: Colors.white,
                size: 36,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title and description
            Text(
              hasFile ? 'Ebook Ready!' : 'Upload Ebook',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              hasFile
                  ? 'Ready to process with AI'
                  : 'PDF files for AI text extraction',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // File info card (if file selected)
            if (hasFile) ...[
              _buildCompactFileCard(),
              const SizedBox(height: 20),
            ],
            
            // Action buttons
            if (!hasFile)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: _buildActionButton(
                  text: 'Choose Ebook File',
                  icon: Icons.upload_file,
                  onPressed: _pickPdfFile,
                  isPrimary: true,
                ),
              ),
            
            if (hasFile)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: _buildActionButton(
                        text: 'Change',
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: _buildActionButton(
                        text: _isProcessing ? 'Processing...' : 'Process',
                        icon: _isProcessing ? null : Icons.auto_awesome,
                        onPressed: _isProcessing ? null : _processPdf,
                        isPrimary: true,
                        isLoading: _isProcessing,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFileCard() {
    final fileName = kIsWeb
        ? (_selectedWebFile?.name ?? 'Ebook Document')
        : (_selectedFile?.path.split('/').last ?? 'Ebook Document');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
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
    return ElevatedButton(
      onPressed: onPressed != null ? () {
        // ✅ NEW: Haptic feedback for button press
        HapticService.lightImpact();
        onPressed();
      } : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary 
            ? const Color(0xFF2563EB)
            : Colors.white,
        foregroundColor: isPrimary ? Colors.white : Color(0xFF2563EB),
        disabledBackgroundColor: const Color(0xFFE2E8F0),
        disabledForegroundColor: const Color(0xFF94A3B8),
        elevation: 0,
        shadowColor: Colors.transparent,
        side: isPrimary
            ? null
            : BorderSide(
                color: const Color(0xFF2563EB).withOpacity(0.3),
                width: 1.5,
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
                  const SizedBox(width: 8),
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
    );
  }
}