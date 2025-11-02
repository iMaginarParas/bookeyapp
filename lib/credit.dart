import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'wallet_service.dart';

class CreditPage extends StatefulWidget {
  const CreditPage({super.key});

  @override
  State<CreditPage> createState() => _CreditPageState();
}

class _CreditPageState extends State<CreditPage> with TickerProviderStateMixin {
  WalletInfo? _walletInfo;
  List<CreditTransaction> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    
    _loadWalletData();
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : SingleChildScrollView(
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
                ),
    );
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