import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class WalletService {
  static const String baseUrl = 'https://ch2vi-production.up.railway.app';
  
  static Future<WalletInfo?> getWalletInfo(String jwtToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallet'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return WalletInfo.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else {
        throw Exception('Failed to get wallet info: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting wallet info: $e');
      throw Exception('Failed to get wallet info: ${e.toString()}');
    }
  }
  
  static Future<List<CreditTransaction>> getTransactionHistory(
    String jwtToken, {
    int limit = 50,
    String? transactionType,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/wallet/transactions?limit=$limit');
      if (transactionType != null) {
        uri = Uri.parse('$baseUrl/wallet/transactions?limit=$limit&transaction_type=$transactionType');
      }
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final transactions = (jsonData['transactions'] as List)
            .map((t) => CreditTransaction.fromJson(t))
            .toList();
        return transactions;
      } else {
        throw Exception('Failed to get transactions');
      }
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }
  
  static Future<List<CreditPackage>> getCreditPackages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/credit-packages'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final packages = (jsonData['packages'] as List)
            .map((p) => CreditPackage.fromJson(p))
            .toList();
        return packages;
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting credit packages: $e');
      return [];
    }
  }
}

class WalletInfo {
  final String userId;
  final String email;
  final int creditsBalance;
  final int totalCreditsPurchased;
  final int totalCreditsUsed;
  final int monthlySpent;
  final int monthlyAdded;
  final int transactionCount;
  final PricingStructure pricingStructure;

  WalletInfo({
    required this.userId,
    required this.email,
    required this.creditsBalance,
    required this.totalCreditsPurchased,
    required this.totalCreditsUsed,
    required this.monthlySpent,
    required this.monthlyAdded,
    required this.transactionCount,
    required this.pricingStructure,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      userId: json['user_id'] ?? '',
      email: json['email'] ?? '',
      creditsBalance: json['credits_balance'] ?? 0,
      totalCreditsPurchased: json['total_credits_purchased'] ?? 0,
      totalCreditsUsed: json['total_credits_used'] ?? 0,
      monthlySpent: json['monthly_spent'] ?? 0,
      monthlyAdded: json['monthly_added'] ?? 0,
      transactionCount: json['transaction_count'] ?? 0,
      pricingStructure: PricingStructure.fromJson(
        json['pricing_structure'] ?? {},
      ),
    );
  }
}

class PricingStructure {
  final int imageGeneration;
  final int audioGeneration;
  final int videoProcessing;
  final int serviceFee;
  final int totalPerScene;
  final String formula;

  PricingStructure({
    required this.imageGeneration,
    required this.audioGeneration,
    required this.videoProcessing,
    required this.serviceFee,
    required this.totalPerScene,
    required this.formula,
  });

  factory PricingStructure.fromJson(Map<String, dynamic> json) {
    final perScene = json['per_scene'] ?? {};
    return PricingStructure(
      imageGeneration: perScene['image_generation'] ?? 1,
      audioGeneration: perScene['audio_generation'] ?? 1,
      videoProcessing: perScene['video_processing'] ?? 4,
      serviceFee: perScene['service_fee'] ?? 1,
      totalPerScene: perScene['total_per_scene'] ?? 7,
      formula: json['formula'] ?? 'Total = scenes × 7 credits',
    );
  }
}

class CreditTransaction {
  final String id;
  final String userId;
  final String transactionType;
  final String operation;
  final int amount;
  final String description;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  CreditTransaction({
    required this.id,
    required this.userId,
    required this.transactionType,
    required this.operation,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.metadata,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      operation: json['operation'] ?? '',
      amount: json['amount'] ?? 0,
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      metadata: json['metadata'] is Map ? json['metadata'] as Map<String, dynamic> : null,
    );
  }
  
  bool get isCredit => operation == 'add';
  bool get isDebit => operation == 'deduct';
  
  String get formattedAmount {
    return isCredit ? '+$amount' : '-$amount';
  }
  
  Color get amountColor {
    return isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);
  }
}

class CreditPackage {
  final String id;
  final String name;
  final int creditsAmount;
  final double price;
  final int bonusCredits;
  final bool isActive;
  final bool isPopular;

  CreditPackage({
    required this.id,
    required this.name,
    required this.creditsAmount,
    required this.price,
    required this.bonusCredits,
    required this.isActive,
    required this.isPopular,
  });

  factory CreditPackage.fromJson(Map<String, dynamic> json) {
    return CreditPackage(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      creditsAmount: json['credits_amount'] ?? 0,
      price: (json['price'] ?? 0.0).toDouble(),
      bonusCredits: json['bonus_credits'] ?? 0,
      isActive: json['is_active'] ?? true,
      isPopular: json['is_popular'] ?? false,
    );
  }
  
  int get totalCredits => creditsAmount + bonusCredits;
  String get priceString => '\$${price.toStringAsFixed(2)}';
}