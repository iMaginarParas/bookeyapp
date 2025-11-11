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

  // Auth related variables
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
    
    // Simpler animation controllers
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Simpler logo animations
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
    // Start logo animation and spinner
    _logoController.repeat(); // Make it loop for spinner
    
    // Wait for logo animation
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Check authentication
    await _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');
      
      if (accessToken != null && refreshToken != null) {
        // Try to validate token
        final isValid = await _validateAccessToken(accessToken);
        
        if (isValid) {
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) _navigateToMainScreen();
          return;
        } else {
          // Try refresh
          final refreshed = await _refreshAccessToken(refreshToken);
          if (refreshed) {
            await Future.delayed(const Duration(milliseconds: 1000));
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

      // CORRECT ENDPOINTS
      final endpoint = isEmail ? '/auth/email/signin' : '/auth/phone/signin';
      final requestBody = isEmail 
          ? {'email': identifier}
          : {'phone': identifier};
      
      print('🚀 Sending OTP to: $identifier via $endpoint');
      
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📱 OTP Response: ${response.statusCode}');
      print('📱 OTP Body: ${response.body}');

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
          _errorMessage = responseData['detail'] ?? 'Failed to send OTP. Please try again.';
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
      print('❌ OTP send error: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    
    if (otp.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the OTP';
        _successMessage = null;
      });
      _mediumHaptic();
      return;
    }

    if (_currentIdentifier == null) {
      setState(() {
        _errorMessage = 'Session expired. Please start again.';
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
      // CORRECT REQUEST BODY FORMAT FROM API DOCS
      Map<String, dynamic> requestBody = {
        'token': otp,
      };

      if (_isPhoneAuth) {
        requestBody['phone'] = _currentIdentifier;
      } else {
        requestBody['email'] = _currentIdentifier;
      }
      
      // CORRECT ENDPOINT FROM API DOCS
      const endpoint = '/auth/verify-otp';
      
      print('🔐 Verifying OTP: $otp via $endpoint');
      
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('✅ Verify Response: ${response.statusCode}');
      print('✅ Verify Body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Store tokens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', responseData['access_token']);
        await prefs.setString('refresh_token', responseData['refresh_token']);
        
        if (responseData['user'] != null) {
          await prefs.setString('user_data', json.encode(responseData['user']));
        }

        _lightHaptic();
        
        setState(() {
          _successMessage = 'Login successful!';
          _errorMessage = null;
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          _navigateToMainScreen();
        }
      } else {
        setState(() {
          _errorMessage = responseData['detail'] ?? 'Invalid OTP. Please try again.';
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
      print('❌ OTP verify error: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _goBack() {
    _lightHaptic();
    setState(() {
      _showOtpInput = false;
      _errorMessage = null;
      _successMessage = null;
    });
    _otpController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Much brighter background
      body: SafeArea(
        child: _isInitializing || !_showAuthForm
            ? _buildSplashContent() 
            : _buildAuthContent(),
      ),
    );
  }

  Widget _buildSplashContent() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FAFC), // Light gray-blue
            Color(0xFFE2E8F0), // Slightly darker gray-blue
            Color(0xFFCBD5E1), // Even more gradient depth
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // LOGO FROM ASSETS with animation
          AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return Transform.scale(
                scale: _logoScaleAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 25,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 15,
                        spreadRadius: -5,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback if asset not found
                        return Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
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
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Brand name with animation
          AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _logoFadeAnimation,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                  ).createShader(bounds),
                  child: const Text(
                    'Bookey',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          // Tagline with animation
          AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _logoFadeAnimation,
                child: const Text(
                  'Transform stories into videos',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 50),
          
          // BEAUTIFUL SPINNER LOADING with animation
          if (_isInitializing)
            Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  child: Stack(
                    children: [
                      // Background circle
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      // Animated spinner
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _logoController.value * 6.28, // 2π for full rotation
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    Colors.transparent,
                                    const Color(0xFF8B5CF6).withOpacity(0.8),
                                    const Color(0xFFA855F7),
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.3, 0.7, 1.0],
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF8FAFC),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _logoFadeAnimation,
                      child: Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAuthContent() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFE2E8F0),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _contentController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _contentFadeAnimation,
            child: Transform.translate(
              offset: Offset(0, _contentSlideAnimation.value),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    _buildHeader(),
                    const SizedBox(height: 40),
                    _buildAuthForm(),
                    const SizedBox(height: 24),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo from assets - smaller version for login
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 10,
                spreadRadius: -2,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/logo.png',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if asset not found
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
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
                );
              },
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
          
          // Messages
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
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
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
    return Column(
      children: [
        const Text(
          'By continuing, you agree to our Terms of Service and Privacy Policy',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Text(
          '© 2024 Bookey. All rights reserved.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFFCBD5E1),
          ),
        ),
      ],
    );
  }
}