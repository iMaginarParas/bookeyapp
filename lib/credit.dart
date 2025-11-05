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
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
        '100 credits per month (1200/year)',
        'Approximately 170+ videos per year',
        'Priority processing',
        'Email support',
        'Early access to new features',
        'No ads',
      ],
      isPopular: true,
      revenueCatProductId: 'bookey_pro_yearly',
    ),
  ];

  // Credit Packages - Updated with RevenueCat product IDs
  final List<CreditPackage> _creditPackages = [
    CreditPackage(
      id: 'credits_50',
      name: 'Starter Pack',
      price: 50.0,
      credits: 50,
      bonus: 'Perfect for trying out',
      revenueCatProductId: 'bookey_credits_50',
    ),
    CreditPackage(
      id: 'credits_100',
      name: 'Popular Pack',
      price: 100.0,
      credits: 100,
      bonus: 'Most popular choice',
      isPopular: true,
      revenueCatProductId: 'bookey_credits_100',
    ),
    CreditPackage(
      id: 'credits_500',
      name: 'Value Pack',
      price: 500.0,
      credits: 500,
      bonus: 'Best value for money',
      revenueCatProductId: 'bookey_credits_500',
    ),
    CreditPackage(
      id: 'credits_1000',
      name: 'Pro Pack',
      price: 1000.0,
      credits: 1000,
      bonus: 'For power users',
      revenueCatProductId: 'bookey_credits_1000',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    
    _initializeRevenueCat();
    _loadWalletData();
  }

  Future<void> _initializeRevenueCat() async {
    try {
      await RevenueCatService.initialize();
      await _checkSubscriptionStatus();
      await _loadAvailableProducts();
    } catch (e) {
      print('Failed to initialize RevenueCat: $e');
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final hasActiveSubscription = await RevenueCatService.hasActiveSubscription();
      setState(() {
        _hasActiveSubscription = hasActiveSubscription;
      });
    } catch (e) {
      print('Error checking subscription status: $e');
    }
  }

  Future<void> _loadAvailableProducts() async {
    try {
      final products = await RevenueCatService.getProducts();
      setState(() {
        _availableProducts = products;
      });
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  Future<void> _loadWalletData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString('access_token');
      
      if (jwtToken == null) {
        setState(() {
          _errorMessage = 'Please log in to view your wallet';
          _isLoading = false;
        });
        return;
      }
      
      final walletInfo = await WalletService.getWalletInfo(jwtToken);
      final transactions = await WalletService.getTransactionHistory(jwtToken, limit: 10);
      
      setState(() {
        _walletInfo = walletInfo;
        _transactions = transactions;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text(
          'Credits & Billing',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A1A23),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWalletData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            height: 50,
            child: Row(
              children: [
                Expanded(child: _buildTabButton('Overview', 0)),
                Expanded(child: _buildTabButton('Subscriptions', 1)),
                Expanded(child: _buildTabButton('Buy Credits', 2)),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _buildTabContent(),
    );
  }
  
  
  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
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
        return _buildSubscriptionsTab();
      case 2:
        return _buildBuyCreditsTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentBalance(),
          const SizedBox(height: 32),
          _buildUsageStats(),
          const SizedBox(height: 32),
          _buildPricingInfo(),
          const SizedBox(height: 32),
          _buildTransactionHistory(),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subscription Status Card
          if (_hasActiveSubscription)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.verified, color: Colors.white, size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Active Subscription',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have an active Pro subscription',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          
          const Text(
            'Choose Your Plan',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get credits every month with our subscription plans',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          ..._subscriptionPlans.map((plan) => _buildSubscriptionCard(plan)).toList(),
          
          const SizedBox(height: 24),
          
          // Restore Purchases Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isPurchasing ? null : _restorePurchases,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isPurchasing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                    )
                  : const Icon(Icons.restore, color: Color(0xFF6366F1)),
              label: Text(
                _isPurchasing ? 'Restoring...' : 'Restore Purchases',
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyCreditsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buy Credits',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Purchase credits for immediate use',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 400, // Fixed height for the grid
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: _creditPackages.length,
              itemBuilder: (context, index) {
                return _buildCreditPackageCard(_creditPackages[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(SubscriptionPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: plan.isPopular 
              ? const Color(0xFF6366F1) 
              : const Color(0xFF6366F1).withOpacity(0.2),
          width: plan.isPopular ? 2 : 1,
        ),
        boxShadow: plan.isPopular
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'POPULAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (plan.isPopular) const SizedBox(height: 16),
          Text(
            plan.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            plan.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '₹',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6366F1),
                ),
              ),
              Text(
                plan.price.toInt().toString(),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                '/${plan.duration.toLowerCase()}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...plan.features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_isPurchasing || _hasActiveSubscription) 
                  ? null 
                  : () => _purchaseSubscription(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasActiveSubscription 
                    ? const Color(0xFF10B981) 
                    : const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
              ),
              child: _isPurchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _hasActiveSubscription ? 'Active Subscription' : 'Subscribe Now',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditPackageCard(CreditPackage package) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: package.isPopular 
              ? const Color(0xFF6366F1) 
              : const Color(0xFF6366F1).withOpacity(0.2),
          width: package.isPopular ? 2 : 1,
        ),
        boxShadow: package.isPopular
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (package.isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'POPULAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (package.isPopular) const SizedBox(height: 12),
          Text(
            package.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '₹',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6366F1),
                ),
              ),
              Text(
                package.price.toInt().toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 8),
          if (package.bonus.isNotEmpty)
            Text(
              package.bonus,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: _isPurchasing ? null : () => _purchaseCredits(package),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
              ),
              child: _isPurchasing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Buy Now',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseSubscription(SubscriptionPlan plan) async {
    if (_isPurchasing || plan.revenueCatProductId == null) return;

    setState(() {
      _isPurchasing = true;
    });

    try {
      final success = await RevenueCatService.purchaseSubscription(plan.revenueCatProductId!);
      
      if (success) {
        // Show success message
        _showSuccessDialog('Subscription', 'Successfully subscribed to ${plan.name}!');
        
        // Refresh subscription status and wallet data
        await _checkSubscriptionStatus();
        await _loadWalletData();
      } else {
        _showErrorDialog('Purchase failed', 'Unable to complete the subscription purchase. Please try again.');
      }
    } catch (e) {
      String errorMessage = 'An error occurred during purchase.';
      
      if (e.toString().contains('cancelled')) {
        errorMessage = 'Purchase was cancelled.';
      } else if (e.toString().contains('pending')) {
        errorMessage = 'Payment is pending. Please check your payment method.';
      } else if (e.toString().contains('not available')) {
        errorMessage = 'This product is not available for purchase.';
      }
      
      _showErrorDialog('Purchase Error', errorMessage);
    } finally {
      setState(() {
        _isPurchasing = false;
      });
    }
  }

  Future<void> _purchaseCredits(CreditPackage package) async {
    if (_isPurchasing || package.revenueCatProductId == null) return;

    setState(() {
      _isPurchasing = true;
    });

    try {
      final success = await RevenueCatService.purchaseCredits(package.revenueCatProductId!);
      
      if (success) {
        // Show success message
        _showSuccessDialog('Credits', 'Successfully purchased ${package.credits} credits!');
        
        // Refresh wallet data to show new credits
        await _loadWalletData();
      } else {
        _showErrorDialog('Purchase failed', 'Unable to complete the credit purchase. Please try again.');
      }
    } catch (e) {
      String errorMessage = 'An error occurred during purchase.';
      
      if (e.toString().contains('cancelled')) {
        errorMessage = 'Purchase was cancelled.';
      } else if (e.toString().contains('pending')) {
        errorMessage = 'Payment is pending. Please check your payment method.';
      } else if (e.toString().contains('not available')) {
        errorMessage = 'This product is not available for purchase.';
      }
      
      _showErrorDialog('Purchase Error', errorMessage);
    } finally {
      setState(() {
        _isPurchasing = false;
      });
    }
  }

  void _showSuccessDialog(String type, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
              const SizedBox(width: 12),
              Text(
                'Success!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Great!', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Add restore purchases method
  Future<void> _restorePurchases() async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      final customerInfo = await RevenueCatService.restorePurchases();
      
      // Check if any entitlements were restored
      if (customerInfo.entitlements.active.isNotEmpty) {
        _showSuccessDialog('Restore', 'Your purchases have been successfully restored!');
        await _checkSubscriptionStatus();
        await _loadWalletData();
      } else {
        _showErrorDialog('No Purchases', 'No previous purchases were found to restore.');
      }
    } catch (e) {
      _showErrorDialog('Restore Failed', 'Unable to restore purchases. Please try again.');
    } finally {
      setState(() {
        _isPurchasing = false;
      });
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadWalletData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBalance() {
    final credits = _walletInfo?.creditsBalance ?? 0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFFFFD700),
                    size: 48,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text('$credits Credits', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text(
            'Approximately ${(credits / 7).floor()} scenes worth of content',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUsageStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Usage Statistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Purchased', '${_walletInfo?.totalCreditsPurchased ?? 0}', Icons.add_circle, const Color(0xFF10B981))),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Total Used', '${_walletInfo?.totalCreditsUsed ?? 0}', Icons.trending_down, const Color(0xFFEF4444))),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPricingInfo() {
    final pricing = _walletInfo?.pricingStructure;
    if (pricing == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Pricing Breakdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          _buildPricingRow('Image Generation', pricing.imageGeneration),
          _buildPricingRow('Audio Generation', pricing.audioGeneration),
          _buildPricingRow('Video Processing', pricing.videoProcessing),
          _buildPricingRow('Service Fee', pricing.serviceFee),
          const Divider(color: Colors.white24, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total per Scene', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('${pricing.totalPerScene} credits', style: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.w800)),
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
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
          Text('$credits credit${credits != 1 ? 's' : ''}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 20),
          if (_transactions.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No transactions yet', style: TextStyle(color: Colors.white60, fontSize: 14)),
            ))
          else
            ..._transactions.take(5).map((transaction) => _buildTransactionItem(transaction)).toList(),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(CreditTransaction transaction) {
    final color = transaction.amountColor;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(transaction.isCredit ? Icons.add_circle : Icons.remove_circle, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.description, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_formatDate(transaction.createdAt), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          Text(transaction.formattedAmount, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
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