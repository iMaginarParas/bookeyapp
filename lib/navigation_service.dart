import 'package:flutter/material.dart';

// Global navigation service to handle tab navigation
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // Callback to navigate to different tabs
  VoidCallback? _navigateToVideos;
  VoidCallback? _navigateToProcessing;
  VoidCallback? _navigateToHome;
  VoidCallback? _navigateToProfile;

  // Register navigation callbacks from MainScreen
  void registerNavigationCallbacks({
    required VoidCallback navigateToVideos,
    required VoidCallback navigateToProcessing,
    required VoidCallback navigateToHome,
    required VoidCallback navigateToProfile,
  }) {
    _navigateToVideos = navigateToVideos;
    _navigateToProcessing = navigateToProcessing;
    _navigateToHome = navigateToHome;
    _navigateToProfile = navigateToProfile;
  }

  // Navigation methods
  void navigateToVideos() {
    _navigateToVideos?.call();
  }

  void navigateToProcessing() {
    _navigateToProcessing?.call();
  }

  void navigateToHome() {
    _navigateToHome?.call();
  }

  void navigateToProfile() {
    _navigateToProfile?.call();
  }

  // Clear callbacks when disposing
  void dispose() {
    _navigateToVideos = null;
    _navigateToProcessing = null;
    _navigateToHome = null;
    _navigateToProfile = null;
  }
}