// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../router/app_router.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text('Activity', style: AppTextStyles.displayMedium),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collectionGroup('activities')
                    .where('involvedUsers', arrayContains: currentUser.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_outlined,
                                  color: AppColors.accent, size: 36),
                            ),
                            const SizedBox(height: 20),
                            Text('No activity yet',
                                style: AppTextStyles.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              'Your expenses and settlements\nwill appear here.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.friends,
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                              ),
                              child: const Text('Get Started'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final type = data['type'] as String? ?? 'expense';
                      final description = data['description'] as String? ?? '';
                      final amount = data['amount'] != null
                          ? (data['amount'] as num).toDouble()
                          : null;
                      final createdAt =
                          (data['createdAt'] as dynamic)?.toDate() as DateTime?;

                      return _ActivityTile(
                        type: type,
                        description: description,
                        amount: amount,
                        createdAt: createdAt,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String type;
  final String description;
  final double? amount;
  final DateTime? createdAt;

  const _ActivityTile({
    required this.type,
    required this.description,
    this.amount,
    this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final isSettlement = type == 'settlement';
    final icon =
        isSettlement ? Icons.handshake_outlined : Icons.receipt_outlined;
    final color = isSettlement ? AppColors.success : AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: AppTextStyles.bodyMedium),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt!),
                    style: AppTextStyles.bodySmall,
                  ),
              ],
            ),
          ),
          if (amount != null)
            Text(
              '\$${amount!.toStringAsFixed(2)}',
              style: AppTextStyles.titleSmall.copyWith(
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
