import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class OverallBalanceCard extends StatelessWidget {
  final String userId;
  const OverallBalanceCard({super.key, required this.userId});

  Future<Map<String, double>> _calculateTotals() async {
    final netBalances = <String, double>{};

    final expenses = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .get();

    for (final doc in expenses.docs) {
      final data = doc.data();
      final rawSplits = Map<String, dynamic>.from(data['splits'] ?? {});
      final paidBy = data['paidById'] as String? ?? '';
      final fallbackId = paidBy.isNotEmpty ? paidBy : (data['creatorId'] ?? data['sharedBy'] ?? userId);
      
      final splits = <String, dynamic>{};
      rawSplits.forEach((k, v) => splits[k == 'me' ? fallbackId : k] = v);

      if (paidBy == userId) {
        // Rule 1: User as Payer - they are owed by each other member for their share
        splits.forEach((friendId, amount) {
          if (friendId != userId) {
            final amt = double.parse(((amount as num).toDouble()).toStringAsFixed(2));
            netBalances[friendId] = double.parse(((netBalances[friendId] ?? 0) + amt).toStringAsFixed(2));
          }
        });
      } else {
        // Rule 2: User as Participant - they owe the payer for their specific share
        if (splits.containsKey(userId)) {
          final myAmt = double.parse(((splits[userId] as num).toDouble()).toStringAsFixed(2));
          netBalances[paidBy] = double.parse(((netBalances[paidBy] ?? 0) - myAmt).toStringAsFixed(2));
        }
      }
    }

    final settlements = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('settlements')
        .get();

    for (final doc in settlements.docs) {
      final data = doc.data();
      final fromId = data['fromId'] as String? ?? '';
      final toId = data['toId'] as String? ?? '';
      final amt = (data['amount'] as num).toDouble();

      if (fromId == userId) {
        netBalances[toId] = (netBalances[toId] ?? 0) + amt;
      } else if (toId == userId) {
        netBalances[fromId] = (netBalances[fromId] ?? 0) - amt;
      }
    }

    double totalOwed = 0;
    double totalOwe = 0;

    netBalances.forEach((_, balance) {
      if (balance > 0.01) {
        totalOwed += balance;
      } else if (balance < -0.01) {
        totalOwe += balance.abs();
      }
    });

    return {'totalOwed': totalOwed, 'totalOwe': totalOwe};
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Listen to activities to trigger instant rebuilds when any balance action happens
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('activities')
          .snapshots(),
      builder: (context, _) {
        return FutureBuilder<Map<String, double>>(
          future: _calculateTotals(),
          builder: (context, snapshot) {
            double totalOwed = snapshot.data?['totalOwed'] ?? 0;
            double totalOwe = snapshot.data?['totalOwe'] ?? 0;
            
            final net = totalOwed - totalOwe;
            final isPositive = net >= 0;

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lg,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Overall balance', style: AppTextStyles.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          net == 0
                              ? 'All settled up!'
                              : '${isPositive ? '+' : ''}\$${net.abs().toStringAsFixed(2)}',
                          style: AppTextStyles.moneyLarge.copyWith(
                            color: net == 0
                                ? AppColors.textSecondary
                                : isPositive
                                    ? AppColors.success
                                    : AppColors.danger,
                          ),
                        ),
                        if (net != 0)
                          Text(
                            isPositive ? 'you are owed overall' : 'you owe overall',
                            style: AppTextStyles.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('owed to you', style: AppTextStyles.bodySmall),
                      Text(
                        '\$${totalOwed.toStringAsFixed(2)}',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('you owe', style: AppTextStyles.bodySmall),
                      Text(
                        '\$${totalOwe.toStringAsFixed(2)}',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
