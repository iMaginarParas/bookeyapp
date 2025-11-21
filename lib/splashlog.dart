import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _contentController;
  
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<double> _contentSlideAnimation;

  // ✅ CORRECT: Using the exact same base URL
  final String baseUrl = 'https://bokauth-production.up.railway.app';
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _isInitializing = true;
  bool _showAuthForm = false;
  bool _isLoading = false;
  bool _showOtpInput = false;
  bool _isPhoneAuth = false;
  String? _errorMessage;
  String? _successMessage;
  String? _currentIdentifier;

  @override
  void initState() {
    super.initState();
    
    // Animation controllers
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Logo animations
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Content animations
    _contentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _contentSlideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _startApp();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    _identifierController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _startApp() async {
    // Start logo animation
    _logoController.forward();
    
    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 2000));
    
    // Check authentication
    await _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');
      final isGuestMode = prefs.getBool('is_guest_mode') ?? false;
      
      // If in guest mode, go straight to main screen
      if (isGuestMode) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) _navigateToMainScreen();
        return;
      }
      
      if (accessToken != null && refreshToken != null) {
        // Try to validate token
        final isValid = await _validateAccessToken(accessToken);
        
        if (isValid) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) _navigateToMainScreen();
          return;
        } else {
          // Try refresh
          final refreshed = await _refreshAccessToken(refreshToken);
          if (refreshed) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) _navigateToMainScreen();
            return;
          }
        }
      }
      
      // Show login
      _showLoginForm();
    } catch (e) {
      print('Auth check error: $e');
      _showLoginForm();
    }
  }

  void _showLoginForm() {
    setState(() {
      _isInitializing = false;
      _showAuthForm = true;
    });
    _contentController.forward();
  }

  // ✅ Guest mode functionality
  Future<void> _continueAsGuest() async {
    _lightHaptic();
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    try {
      // Set guest mode flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest_mode', true);
      
      setState(() {
        _successMessage = 'Entering guest mode...';
      });
      
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (mounted) {
        _navigateToMainScreen();
      }
    } catch (e) {
      print('Guest mode error: $e');
      setState(() {
        _errorMessage = 'Failed to enter guest mode. Please try again.';
        _successMessage = null;
      });
      _mediumHaptic();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _validateAccessToken(String accessToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/validate-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      print('Token validation error: $e');
      return false;
    }
  }

  Future<bool> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        
        if (data['refresh_token'] != null) {
          await prefs.setString('refresh_token', data['refresh_token']);
        }
        
        return true;
      }
      return false;
    } catch (e) {
      print('Token refresh error: $e');
      return false;
    }
  }

  void _navigateToMainScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _lightHaptic() {
    HapticFeedback.lightImpact();
  }

  void _mediumHaptic() {
    HapticFeedback.mediumImpact();
  }

  // ✅ Dismiss keyboard function
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // ✅ FIXED: Using the exact same format as your working curl command
  Future<void> _sendOtp() async {
    final identifier = _identifierController.text.trim();
    
    if (identifier.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email or phone number';
        _successMessage = null;
      });
      _mediumHaptic();
      return;
    }

    _lightHaptic();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Better email/phone detection
      final isEmail = identifier.contains('@');
      final isPhone = RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(identifier);
      
      if (!isEmail && !isPhone) {
        setState(() {
          _errorMessage = 'Please enter a valid email address or phone number';
          _successMessage = null;
        });
        _mediumHaptic();
        setState(() => _isLoading = false);
        return;
      }
      
      setState(() {
        _isPhoneAuth = isPhone;
        _currentIdentifier = identifier;
      });

      // ✅ EXACTLY MATCHING YOUR WORKING CURL COMMAND
      final endpoint = isEmail ? '/auth/email/signin' : '/auth/phone/signin';
      final requestBody = isEmail 
          ? {'email': identifier}
          : {'phone': identifier};
      
      print('🚀 Sending OTP to: $identifier via $endpoint');
      print('📦 Request body: ${json.encode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📱 OTP Response: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _showOtpInput = true;
          _successMessage = responseData['message'] ?? 'OTP sent successfully!';
          _errorMessage = null;
        });
        _lightHaptic();
      } else {
        setState(() {
          _errorMessage = responseData['detail'] ?? responseData['message'] ?? 'Failed to send OTP. Please try again.';
          _successMessage = null;
        });
        _mediumHaptic();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please check your connection.';
        _successMessage = null;
      });
      _mediumHaptic();
      print('🔥 OTP Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ FIXED: Now using the EXACT format from your working curl command!
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    
    if (otp.isEmpty || otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit code';
        _successMessage = null;
      });
      _mediumHaptic();
      return;
    }

    _lightHaptic();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // ✅ USING THE EXACT SAME ENDPOINT AND FORMAT AS YOUR WORKING CURL
      final endpoint = '/auth/verify-otp';
      
      // ✅ EXACT FORMAT FROM YOUR WORKING CURL COMMAND:
      // {"email": "test@sobookey.in", "phone": "string", "token": "123456"}
      final requestBody = {
        'email': _isPhoneAuth ? null : _currentIdentifier!,
        'phone': _isPhoneAuth ? _currentIdentifier! : null,
        'token': otp,  // Using 'token' field like your curl command
      };

      // Remove null values to clean up the request
      requestBody.removeWhere((key, value) => value == null);
      
      print('🔐 Verifying OTP for: $_currentIdentifier via $endpoint');
      print('📦 Request body: ${json.encode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('✅ Verify Response: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Store tokens and user data - matching your curl response format
        final prefs = await SharedPreferences.getInstance();
        
        if (responseData['access_token'] != null) {
          await prefs.setString('access_token', responseData['access_token']);
        }
        
        if (responseData['refresh_token'] != null) {
          await prefs.setString('refresh_token', responseData['refresh_token']);
        }
        
        // Store additional user data from response
        final userData = {
          'user_id': responseData['user_id'],
          'email': responseData['email'],
          'phone': responseData['phone'],
        };
        await prefs.setString('user_data', json.encode(userData));
        
        // Clear guest mode flag if it was set
        await prefs.remove('is_guest_mode');
        
        setState(() {
          _successMessage = responseData['message'] ?? 'Login successful!';
          _errorMessage = null;
        });
        
        _lightHaptic();
        await Future.delayed(const Duration(milliseconds: 1000));
        
        if (mounted) {
          // Initialize user data after successful login
          try {
            if (responseData['access_token'] != null) {
              await initializeUserData(responseData['access_token']);
            }
          } catch (e) {
            print('User data initialization error: $e');
            // Don't block login for this error
          }
          _navigateToMainScreen();
        }
      } else {
        setState(() {
          _errorMessage = responseData['detail'] ?? responseData['message'] ?? 'Invalid verification code. Please try again.';
          _successMessage = null;
        });
        _mediumHaptic();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please check your connection.';
        _successMessage = null;
      });
      _mediumHaptic();
      print('🔥 Verification Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goBack() {
    setState(() {
      _showOtpInput = false;
      _errorMessage = null;
      _successMessage = null;
    });
    _otpController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard, // ✅ Tap anywhere to dismiss keyboard
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        resizeToAvoidBottomInset: true, // ✅ Handle keyboard properly
        body: SafeArea(
          child: SingleChildScrollView( // ✅ Prevent overflow with scrolling
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // ✅ Dismiss on scroll
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isInitializing) ...[
                              _buildLogo(),
                              const SizedBox(height: 24),
                              const Text(
                                'Loading...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ] else if (_showAuthForm) ...[
                              AnimatedBuilder(
                                animation: _contentFadeAnimation,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _contentFadeAnimation.value,
                                    child: Transform.translate(
                                      offset: Offset(0, _contentSlideAnimation.value),
                                      child: Column(
                                        children: [
                                          _buildHeader(),
                                          const SizedBox(height: 32),
                                          _buildAuthForm(),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _logoFadeAnimation,
          child: ScaleTransition(
            scale: _logoScaleAnimation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 25,
                    spreadRadius: 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: FutureBuilder<bool>(
                  future: _checkAssetExists('assets/logo.png'),
                  builder: (context, snapshot) {
                    final assetExists = snapshot.data ?? false;
                    
                    if (assetExists) {
                      return Image.asset(
                        'assets/logo.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildFallbackLogo();
                        },
                      );
                    } else {
                      return _buildFallbackLogo();
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      width: 140,
      height: 140,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
        ),
      ),
      child: const Center(
        child: Text(
          'B',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Future<bool> _checkAssetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      print('Asset not found: $assetPath');
      return false;
    }
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'B',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
          ).createShader(bounds),
          child: const Text(
            'Welcome to Bookey',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          _showOtpInput 
              ? 'Enter the verification code'
              : 'Sign in to continue',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_showOtpInput) ...[
            _buildTextField(
              controller: _identifierController,
              hintText: 'Email or phone number',
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _sendOtp(),
            ),
            const SizedBox(height: 20),
            _buildPrimaryButton(
              text: 'Continue',
              onPressed: _sendOtp,
              isLoading: _isLoading,
            ),
            
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFFE5E7EB))),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildSecondaryButton(
              text: '🎭 Try Without Account',
              onPressed: _continueAsGuest,
              isLoading: _isLoading,
            ),
            
            const SizedBox(height: 8),
            const Text(
              'Limited features available in guest mode',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            
          ] else ...[
            _buildTextField(
              controller: _otpController,
              hintText: 'Enter verification code',
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _verifyOtp(),
              maxLength: 6,
            ),
            const SizedBox(height: 20),
            _buildPrimaryButton(
              text: 'Verify',
              onPressed: _verifyOtp,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),
            _buildSecondaryButton(
              text: 'Back',
              onPressed: _goBack,
            ),
          ],
          
          const SizedBox(height: 16),
          
          if (_errorMessage != null) _buildMessage(_errorMessage!, false),
          if (_successMessage != null) _buildMessage(_successMessage!, true),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    Function(String)? onSubmitted,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        maxLength: maxLength,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1F2937),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B7280)),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildMessage(String message, bool isSuccess) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSuccess 
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess 
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isSuccess 
              ? const Color(0xFF065F46)
              : const Color(0xFF991B1B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 16), // ✅ Added consistent padding
      child: Column(
        children: [
          const Text(
            'By continuing, you agree to our Terms of Service and Privacy Policy',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16), // ✅ Reduced from 24 to prevent overflow
          const Text(
            '© 2024 Bookey. All rights reserved.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }
}