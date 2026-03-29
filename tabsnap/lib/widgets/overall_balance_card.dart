import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class OverallBalanceCard extends StatelessWidget {
  final String userId;
  const OverallBalanceCard({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .snapshots(),
      builder: (context, snapshot) {
        double totalOwed = 0; // Money others owe you (Green)
        double totalOwe = 0; // Money you owe others (Red)

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final splits = Map<String, dynamic>.from(data['splits'] ?? {});
            final paidBy = data['paidById'] as String? ?? '';

            splits.forEach((friendId, amount) {
              final amt = (amount as num).toDouble();

              if (paidBy == userId) {
                // If I paid, everyone else's split is money owed to me
                if (friendId != userId) totalOwed += amt;
              } else {
                // If someone else paid, only my split is money I owe
                if (friendId == userId) totalOwe += amt;
              }
            });
          }
        }

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
  }
}
