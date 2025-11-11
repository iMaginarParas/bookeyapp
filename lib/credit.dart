import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'wallet_service.dart';

// RevenueCat service class for handling subscriptions and purchases
class RevenueCatService {
  static const String _apiKey = 'appl_QZBGZXoCUzmKjZejVOqcSEqJvfl'; // Your public RevenueCat API key
  static const String _entitlementId = 'pro_access';
  static const String _yearlyProductId = 'bookey_pro_yearly';
  
  static bool _isInitialized = false;
  
  // Initialize RevenueCat
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await Purchases.setLogLevel(LogLevel.info);
      
      PurchasesConfiguration configuration = PurchasesConfiguration(_apiKey);
      await Purchases.configure(configuration);
      
      _isInitialized = true;
      print('RevenueCat initialized successfully');
    } catch (e) {
      print('Failed to initialize RevenueCat: $e');
      rethrow;
    }
  }
  
  // Get available products
  static Future<List<StoreProduct>> getProducts() async {
    try {
      await initialize();
      final offerings = await Purchases.getOfferings();
      
      if (offerings.current != null) {
        return offerings.current!.availablePackages
            .map((package) => package.storeProduct)
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting products: $e');
      return [];
    }
  }
  
  // Purchase subscription
  static Future<bool> purchaseSubscription(String productId) async {
    try {
      await initialize();
      
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        throw Exception('No offerings available');
      }
      
      // Find the package with matching product ID
      Package? targetPackage;
      for (final package in offerings.current!.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          targetPackage = package;
          break;
        }
      }
      
      if (targetPackage == null) {
        throw Exception('Product not found: $productId');
      }
      
      final purchaseResult = await Purchases.purchasePackage(targetPackage);
      
      // Check if the purchase was successful by checking customer info
      if (purchaseResult.customerInfo.entitlements.active.containsKey(_entitlementId)) {
        return true;
      }
      
      return false;
    } catch (e) {
      print('Purchase failed: $e');
      if (e is PlatformException) {
        // Handle specific error cases
        if (e.code == PurchasesErrorCode.purchaseCancelledError.name) {
          throw Exception('Purchase was cancelled');
        } else if (e.code == PurchasesErrorCode.paymentPendingError.name) {
          throw Exception('Payment is pending');
        } else if (e.code == PurchasesErrorCode.productNotAvailableForPurchaseError.name) {
          throw Exception('Product not available for purchase');
        }
      }
      rethrow;
    }
  }
  
  // Purchase credits (one-time purchase)
  static Future<bool> purchaseCredits(String productId) async {
    try {
      await initialize();
      
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        throw Exception('No offerings available');
      }
      
      // For one-time purchases, we'll handle them through the same flow
      // but they won't be tied to an entitlement
      Package? targetPackage;
      for (final package in offerings.current!.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          targetPackage = package;
          break;
        }
      }
      
      if (targetPackage == null) {
        throw Exception('Product not found: $productId');
      }
      
      final purchaseResult = await Purchases.purchasePackage(targetPackage);
      
      // For credit purchases, we consider it successful if no error occurred
      // and we have a valid customer info response
      return purchaseResult.customerInfo != null;
    } catch (e) {
      print('Credit purchase failed: $e');
      rethrow;
    }
  }
  
  // Check subscription status
  static Future<bool> hasActiveSubscription() async {
    try {
      await initialize();
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(_entitlementId);
    } catch (e) {
      print('Error checking subscription status: $e');
      return false;
    }
  }
  
  // Restore purchases
  static Future<CustomerInfo> restorePurchases() async {
    try {
      await initialize();
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo;
    } catch (e) {
      print('Error restoring purchases: $e');
      rethrow;
    }
  }
  
  // Get customer info
  static Future<CustomerInfo?> getCustomerInfo() async {
    try {
      await initialize();
      return await Purchases.getCustomerInfo();
    } catch (e) {
      print('Error getting customer info: $e');
      return null;
    }
  }
}

// Haptic feedback service
class HapticService {
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }
  
  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }
  
  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }
  
  static void selectionClick() {
    HapticFeedback.selectionClick();
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final int credits;
  final String duration;
  final List<String> features;
  final bool isPopular;
  final String? revenueCatProductId;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.credits,
    required this.duration,
    required this.features,
    this.isPopular = false,
    this.revenueCatProductId,
  });
}

class CreditPackage {
  final String id;
  final String name;
  final double price;
  final int credits;
  final String bonus;
  final bool isPopular;
  final String? revenueCatProductId;

  CreditPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.credits,
    this.bonus = '',
    this.isPopular = false,
    this.revenueCatProductId,
  });
}

class CreditPage extends StatefulWidget {
  const CreditPage({super.key});

  @override
  State<CreditPage> createState() => _CreditPageState();
}

class _CreditPageState extends State<CreditPage> with TickerProviderStateMixin {
  WalletInfo? _walletInfo;
  List<CreditTransaction> _transactions = [];
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _errorMessage;
  int _selectedTabIndex = 0; // 0 = Overview, 1 = Subscriptions, 2 = Buy Credits
  bool _hasActiveSubscription = false;
  List<StoreProduct> _availableProducts = [];
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Subscription Plans - Updated to yearly pricing
  final List<SubscriptionPlan> _subscriptionPlans = [
    SubscriptionPlan(
      id: 'yearly_pro',
      name: 'Pro Yearly',
      description: 'Best value for content creators',
      price: 999.0,
      credits: 100,
      duration: 'Yearly',
      features: [
        '100 credits per year',
        'Premium AI processing',
        'Priority support',
        'Advanced features',
        'No ads'
      ],
      isPopular: true,
      revenueCatProductId: 'bookey_pro_yearly',
    ),
  ];

  final List<CreditPackage> _creditPackages = [
    CreditPackage(
      id: 'credits_10',
      name: 'Starter Pack',
      price: 9.99,
      credits: 10,
      bonus: '1 scene',
      revenueCatProductId: 'bookey_credits_10',
    ),
    CreditPackage(
      id: 'credits_25',
      name: 'Creator Pack',
      price: 19.99,
      credits: 25,
      bonus: '3 scenes',
      isPopular: true,
      revenueCatProductId: 'bookey_credits_25',
    ),
    CreditPackage(
      id: 'credits_50',
      name: 'Studio Pack',
      price: 34.99,
      credits: 50,
      bonus: '7 scenes',
      revenueCatProductId: 'bookey_credits_50',
    ),
    CreditPackage(
      id: 'credits_100',
      name: 'Professional Pack',
      price: 59.99,
      credits: 100,
      bonus: '14 scenes',
      revenueCatProductId: 'bookey_credits_100',
    ),
  ];

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

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
    
    _loadWalletData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('access_token');

      if (jwtToken != null) {
        final walletInfo = await WalletService.getWalletInfo(jwtToken);
        final transactions = await WalletService.getTransactionHistory(jwtToken);
        final hasSubscription = await RevenueCatService.hasActiveSubscription();
        final products = await RevenueCatService.getProducts();

        setState(() {
          _walletInfo = walletInfo;
          _transactions = transactions;
          _hasActiveSubscription = hasSubscription;
          _availableProducts = products;
          _isLoading = false;
        });
      } else {
        throw Exception('No authentication token found');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _purchaseSubscription(SubscriptionPlan plan) async {
    if (plan.revenueCatProductId == null) return;
    
    HapticService.mediumImpact();
    
    setState(() {
      _isPurchasing = true;
    });

    try {
      final success = await RevenueCatService.purchaseSubscription(plan.revenueCatProductId!);
      
      if (success) {
        HapticService.lightImpact();
        _showSnackBar('Subscription activated successfully!', isError: false);
        await _loadWalletData(); // Refresh data
      } else {
        throw Exception('Purchase failed');
      }
    } catch (e) {
      HapticService.heavyImpact();
      _showSnackBar('Purchase failed: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isPurchasing = false;
      });
    }
  }

  Future<void> _purchaseCredits(CreditPackage package) async {
    if (package.revenueCatProductId == null) return;
    
    HapticService.mediumImpact();
    
    setState(() {
      _isPurchasing = true;
    });

    try {
      final success = await RevenueCatService.purchaseCredits(package.revenueCatProductId!);
      
      if (success) {
        HapticService.lightImpact();
        _showSnackBar('Credits purchased successfully!', isError: false);
        await _loadWalletData(); // Refresh data
      } else {
        throw Exception('Purchase failed');
      }
    } catch (e) {
      HapticService.heavyImpact();
      _showSnackBar('Purchase failed: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isPurchasing = false;
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
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          onPressed: () {
            HapticService.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Credits & Plans',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B), size: 20),
            onPressed: () {
              HapticService.lightImpact();
              _loadWalletData();
            },
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading your account...',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTab('Overview', 0),
          _buildTab('Plans', 1),
          _buildTab('Buy Credits', 2),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTabIndex != index) {
            HapticService.selectionClick();
          }
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildSubscriptionTab();
      case 2:
        return _buildCreditsTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildCurrentBalance(),
        const SizedBox(height: 20),
        _buildQuickStats(),
        const SizedBox(height: 20),
        if (_walletInfo?.pricingStructure != null) ...[
          _buildPricingInfo(),
          const SizedBox(height: 20),
        ],
        _buildTransactionHistory(),
        const SizedBox(height: 80), // Bottom padding for navigation
      ],
    );
  }

  Widget _buildCurrentBalance() {
    final credits = _walletInfo?.creditsBalance ?? 0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Current Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$credits Credits',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Approximately ${(credits / 7).floor()} scenes worth of content',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Purchased',
            '${_walletInfo?.totalCreditsPurchased ?? 0}',
            Icons.add_circle_outline,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total Used',
            '${_walletInfo?.totalCreditsUsed ?? 0}',
            Icons.trending_down,
            const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingInfo() {
    final pricing = _walletInfo?.pricingStructure;
    if (pricing == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'Pricing Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPricingRow('Image Generation', pricing.imageGeneration),
          _buildPricingRow('Audio Generation', pricing.audioGeneration),
          _buildPricingRow('Video Processing', pricing.videoProcessing),
          _buildPricingRow('Service Fee', pricing.serviceFee),
          const Divider(color: Color(0xFFE2E8F0), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total per Scene',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${pricing.totalPerScene} credits',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow(String label, int credits) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '$credits credit${credits != 1 ? 's' : ''}',
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          if (_transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      color: Color(0xFF94A3B8),
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No transactions yet',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._transactions.take(5).map((transaction) => _buildTransactionItem(transaction)).toList(),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(CreditTransaction transaction) {
    final color = transaction.amountColor;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              transaction.isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(transaction.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Text(
            transaction.formattedAmount,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (_hasActiveSubscription) ...[
          _buildActiveSubscriptionCard(),
          const SizedBox(height: 20),
        ],
        const Text(
          'Subscription Plans',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        ..._subscriptionPlans.map((plan) => _buildSubscriptionCard(plan)).toList(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildActiveSubscriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Active Subscription',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'You have an active Pro subscription with unlimited access to all features.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(SubscriptionPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isPopular 
              ? const Color(0xFF2563EB) 
              : const Color(0xFFE2E8F0),
          width: plan.isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (plan.isPopular 
                ? const Color(0xFF2563EB) 
                : const Color(0xFF64748B)).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (plan.isPopular)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.description,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${plan.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          plan.duration.toLowerCase(),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...plan.features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isPurchasing || _hasActiveSubscription
                        ? null
                        : () => _purchaseSubscription(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.isPopular 
                          ? const Color(0xFF2563EB)
                          : Colors.white,
                      foregroundColor: plan.isPopular 
                          ? Colors.white 
                          : const Color(0xFF2563EB),
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      elevation: 0,
                      side: plan.isPopular 
                          ? null
                          : const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isPurchasing
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _hasActiveSubscription ? 'Active' : 'Subscribe',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const Text(
          'Credit Packages',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Purchase credits to create amazing content with AI',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: _creditPackages.length,
          itemBuilder: (context, index) {
            return _buildCreditPackageCard(_creditPackages[index]);
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildCreditPackageCard(CreditPackage package) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: package.isPopular 
              ? const Color(0xFF2563EB) 
              : const Color(0xFFE2E8F0),
          width: package.isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (package.isPopular 
                ? const Color(0xFF2563EB) 
                : const Color(0xFF64748B)).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (package.isPopular)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  'BEST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  package.name,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '\$${package.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${package.credits} Credits',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (package.bonus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    package.bonus,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: _isPurchasing ? null : () => _purchaseCredits(package),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: package.isPopular 
                          ? const Color(0xFF2563EB)
                          : Colors.white,
                      foregroundColor: package.isPopular 
                          ? Colors.white 
                          : const Color(0xFF2563EB),
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      elevation: 0,
                      side: package.isPopular 
                          ? null
                          : const BorderSide(color: Color(0xFF2563EB), width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isPurchasing
                        ? const SizedBox(
                            height: 12,
                            width: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Purchase',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: Color(0xFFEF4444),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'An unexpected error occurred',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              HapticService.lightImpact();
              _loadWalletData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}