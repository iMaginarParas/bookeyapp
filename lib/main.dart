import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // ✅ Added for haptic feedback

import 'splashlog.dart';
import 'home.dart';
import 'processing.dart';
import 'profile.dart';
import 'videos.dart';
import 'video_manager.dart';
import 'navigation_service.dart';
import 'api_service.dart';
import 'credit.dart';

// HTTP Override to fix Railway.app DNS issues
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    
    // Configure client for better Railway.app connectivity
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // Allow connections to Railway.app and localhost for development
      return host.contains('railway.app') || 
             host.contains('localhost') || 
             host.contains('127.0.0.1') ||
             host.contains('stboo-production.up.railway.app') ||
             host.contains('imgbooc-production.up.railway.app') ||
             host.contains('bookey-pdf-production.up.railway.app');
    };
    
    // Set longer timeouts for Railway
    client.connectionTimeout = Duration(seconds: 60);
    client.idleTimeout = Duration(seconds: 60);
    
    // Configure user agent
    client.userAgent = 'Bookey-Flutter-App/1.0 (Flutter)';
    
    // Enable HTTP/2
    client.autoUncompress = true;
    
    return client;
  }
  
  @override
  Future<InternetAddress> lookup(String host) async {
  try {
    // Use InternetAddress.lookup for DNS resolution
    final addresses = await InternetAddress.lookup(host);
    return addresses.first;
  } catch (e) {
    print('DNS lookup failed for $host: $e');
    rethrow;
  }
}

}

void main() async {
  // Override HTTP client for better Railway.app connectivity
  if (!kIsWeb) {
    HttpOverrides.global = MyHttpOverrides();
  }
  
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize RevenueCat
  try {
    await RevenueCatService.initialize();
    print('RevenueCat initialized successfully');
  } catch (e) {
    print('Failed to initialize RevenueCat: $e');
    // Continue with app launch even if RevenueCat fails
  }
  
  runApp(const BookeyApp());
}

/// ✅ NEW: Initialize user data after login
Future<void> initializeUserData(String jwtToken) async {
  try {
    print('🚀 Initializing user data...');
    
    // Load user's existing videos from backend
    await VideoManager().loadUserVideos(jwtToken);
    
    print('✅ User data initialization completed');
  } catch (e) {
    print('⚠️ Error initializing user data: $e');
    // Don't crash the app - just log the error
  }
}

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

class BookeyApp extends StatelessWidget {
  const BookeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bookey',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Main screen with improved bottom navigation and video integration
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final GlobalKey<ProcessingPageState> _processingKey = GlobalKey<ProcessingPageState>();
  final VideoManager _videoManager = VideoManager();
  final NavigationService _navigationService = NavigationService();
  
  late List<Widget> _pages;
  late AnimationController _badgeController;
  late Animation<double> _badgeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize badge animation for notifications
    _badgeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _badgeAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _badgeController, curve: Curves.elasticOut),
    );

    _pages = [
      HomePage(
        onContentProcessed: (result) => _navigateToProcessing(result),
      ),
      ProcessingPage(key: _processingKey),
      const VideosPage(),
      const ProfilePage(),
    ];

    // Listen to video manager updates for badge notifications
    _videoManager.addListener(_onVideoManagerUpdate);

    // Register navigation callbacks
    _navigationService.registerNavigationCallbacks(
      navigateToVideos: () => _navigateToTab(2),
      navigateToProcessing: () => _navigateToTab(1),
      navigateToHome: () => _navigateToTab(0),
      navigateToProfile: () => _navigateToTab(3),
    );
    
    // Initialize video notification service after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VideoNotificationService().initialize(context);
      // Request notification permission for system notifications
      SystemNotificationHelper.requestNotificationPermission();
    });
  }

  @override
  void dispose() {
    _videoManager.removeListener(_onVideoManagerUpdate);
    _badgeController.dispose();
    _navigationService.dispose();
    super.dispose();
  }

  void _onVideoManagerUpdate() {
    // Animate badge when videos complete
    if (_videoManager.completedVideosCount > 0) {
      _badgeController.forward().then((_) {
        _badgeController.reverse();
      });
      // ✅ NEW: Haptic feedback for video completion
      HapticService.mediumImpact();
    }
  }

  void _navigateToProcessing(ProcessingResult result) {
    // ✅ NEW: Haptic feedback when navigating to processing
    HapticService.lightImpact();
    
    setState(() {
      _currentIndex = 1;
    });
    // Pass the processed content to the processing page
    _processingKey.currentState?.loadProcessedContent(result);
  }

  void _navigateToTab(int index) {
    // ✅ NEW: Haptic feedback for tab changes
    if (_currentIndex != index) {
      HapticService.selectionClick();
    }
    
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              icon: Icons.add_circle_outline,
              activeIcon: Icons.add_circle,
              label: 'Create',
              index: 0,
            ),
            _buildNavItem(
              icon: Icons.sync_outlined,
              activeIcon: Icons.sync,
              label: 'Processing',
              index: 1,
            ),
            _buildNavItem(
              icon: Icons.play_circle_outline,
              activeIcon: Icons.play_circle,
              label: 'Videos',
              index: 2,
              showBadge: true,
              badgeCount: _videoManager.videos.length,
              completedCount: _videoManager.completedVideosCount,
            ),
            _buildNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              index: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    bool showBadge = false,
    int badgeCount = 0,
    int completedCount = 0,
  }) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        // ✅ NEW: Haptic feedback for tab navigation
        if (_currentIndex != index) {
          HapticService.selectionClick();
        }
        
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _badgeAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: showBadge && completedCount > 0 && !isActive 
                          ? _badgeAnimation.value 
                          : 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                                )
                              : null,
                          color: isActive ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withOpacity(0.25),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isActive ? activeIcon : icon,
                          color: isActive ? Colors.white : Color(0xFF64748B),
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                
                // Badge for video count
                if (showBadge && badgeCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: completedCount > 0 
                            ? const Color(0xFF10B981)  // Green for completed
                            : const Color(0xFFF59E0B), // Orange for processing
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive 
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}