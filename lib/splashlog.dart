import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  // Auth related variables
  final String baseUrl = 'https://bokauth-production.up.railway.app';
  final TextEditingController emailController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  
  bool _isInitializing = true;
  bool _showAuthForm = false;
  bool _isLoading = false;
  bool _showOtpInput = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController, 
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController, 
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController, 
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
    
    // Check authentication status
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    otpController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Test API connection
      await _testApiConnection();
      
      // Check for stored authentication
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final email = prefs.getString('user_email');
      
      if (accessToken != null && email != null) {
        // Validate token with backend
        final isValid = await _validateToken(accessToken);
        
        if (isValid) {
          // Token is valid, navigate to main screen
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
                transitionDuration: const Duration(milliseconds: 800),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          }
          return;
        } else {
          // Token is invalid, clear stored data
          await prefs.remove('access_token');
          await prefs.remove('user_email');
        }
      }
      
      // No valid authentication, show login form
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _showAuthForm = true;
        });
      }
      
    } catch (e) {
      print('Auth check error: $e');
      // On error, show auth form after splash
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _showAuthForm = true;
          _errorMessage = 'Connection error. Please check your internet connection.';
        });
      }
    }
  }

  Future<void> _testApiConnection() async {
    try {
      print('Testing API connection...');
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      print('API Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('API is working correctly!');
      }
    } catch (e) {
      print('API Connection Error: $e');
      rethrow;
    }
  }

  Future<bool> _validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/verify-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Token validation error: $e');
      return false;
    }
  }

  Future<void> _sendOtp() async {
    if (emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': emailController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _showOtpInput = true;
          _successMessage = responseData['message'] ?? 'OTP sent successfully!';
        });
      } else {
        setState(() {
          _errorMessage = responseData['detail'] ?? 'Failed to send OTP';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (otpController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the OTP code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': emailController.text.trim(),
          'token': otpController.text.trim(),
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Store authentication data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', responseData['access_token'] ?? '');
        await prefs.setString('user_email', responseData['email'] ?? emailController.text);
        
        // Navigate to main screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
              transitionDuration: const Duration(milliseconds: 800),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = responseData['detail'] ?? 'Invalid OTP code';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/resend-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': emailController.text.trim(),
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _successMessage = 'New OTP sent to your email!';
        });
      } else {
        setState(() {
          _errorMessage = responseData['detail'] ?? 'Failed to resend OTP';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/google/url'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final String googleUrl = responseData['url'];
        
        if (await canLaunchUrl(Uri.parse(googleUrl))) {
          await launchUrl(
            Uri.parse(googleUrl),
            mode: LaunchMode.externalApplication,
          );
        } else {
          setState(() {
            _errorMessage = 'Could not launch Google sign-in';
          });
        }
      } else {
        setState(() {
          _errorMessage = responseData['detail'] ?? 'Failed to get Google sign-in URL';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    setState(() {
      _showOtpInput = false;
      _errorMessage = null;
      _successMessage = null;
      otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        child: _isInitializing 
            ? _buildSplashContent() 
            : _buildAuthContent(),
      ),
    );
  }

  Widget _buildSplashContent() {
    return Container(
      key: const ValueKey('splash'),
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFAFAFA),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // Logo with premium styling
                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // App Name with premium typography
                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value * 0.5),
                    child: const Text(
                      'Bookey',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -1.2,
                        height: 1.1,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Tagline
                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value * 0.3),
                    child: const Text(
                      'Transform ideas into stunning videos',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Loading indicator
                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value * -0.5),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthContent() {
    return Container(
      key: const ValueKey('auth'),
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                
                // Header Section
                _buildHeaderSection(),
                
                const SizedBox(height: 60),
                
                // Auth Form
                _buildAuthForm(),
                
                const SizedBox(height: 40),
                
                // Footer
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome,
            size: 32,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Title
        const Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
            letterSpacing: -1.0,
            height: 1.1,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Subtitle
        const Text(
          'Sign in to continue creating amazing videos with AI',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Error Message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Success Message
        if (_successMessage != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Email Input
        _buildTextField(
          controller: emailController,
          label: 'Email address',
          hint: 'Enter your email',
          keyboardType: TextInputType.emailAddress,
          enabled: !_showOtpInput && !_isLoading,
          prefixIcon: Icons.mail_outline,
        ),
        
        if (_showOtpInput) ...[
          const SizedBox(height: 20),
          _buildTextField(
            controller: otpController,
            label: 'Verification code',
            hint: 'Enter 6-digit code',
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
            maxLength: 6,
            prefixIcon: Icons.security,
          ),
        ],
        
        const SizedBox(height: 32),
        
        // Primary Button
        _buildPrimaryButton(),
        
        // Secondary Actions for OTP
        if (_showOtpInput) ...[
          const SizedBox(height: 16),
          _buildSecondaryActions(),
        ],
        
        // Google Sign In (only show when not in OTP mode)
        if (!_showOtpInput) ...[
          const SizedBox(height: 32),
          _buildDivider(),
          const SizedBox(height: 32),
          _buildGoogleButton(),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
    required bool enabled,
    required IconData prefixIcon,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            maxLength: maxLength,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  prefixIcon,
                  color: const Color(0xFF6B7280),
                  size: 20,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF1A1A1A),
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: const Color(0xFFE5E7EB).withOpacity(0.5),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A1A).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : () {
          if (_showOtpInput) {
            _verifyOtp();
          } else {
            _sendOtp();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFF3F4F6),
          disabledForegroundColor: const Color(0xFF9CA3AF),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _showOtpInput ? 'Verify & Continue' : 'Send verification code',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildSecondaryActions() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isLoading ? null : _resendOtp,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Resend code',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Container(
          width: 1,
          height: 20,
          color: const Color(0xFFE5E7EB),
        ),
        Expanded(
          child: TextButton(
            onPressed: _isLoading ? null : _resetForm,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Change email',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFE5E7EB),
          ),
        ),
        const Padding(
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
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFE5E7EB),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _signInWithGoogle,
        icon: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'G',
              style: TextStyle(
                color: Color(0xFFDB4437),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        label: const Text('Continue with Google'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF374151),
          elevation: 0,
          shadowColor: Colors.transparent,
          side: const BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Secure authentication • Privacy protected',
        style: TextStyle(
          color: const Color(0xFF9CA3AF),
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}