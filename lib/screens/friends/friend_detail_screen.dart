// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';

class FriendDetailScreen extends StatelessWidget {
  final Friend friend;
  const FriendDetailScreen({super.key, required this.friend});

  static List<QueryDocumentSnapshot> _filterBilateralExpenses(
      List<QueryDocumentSnapshot> docs, String currentUserId, String friendId) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final rawSplits = Map<String, dynamic>.from(data['splits'] ?? {});
      final creatorId = data['creatorId']?.toString() ?? data['sharedBy']?.toString() ?? currentUserId;
      final splits = <String, dynamic>{};
      rawSplits.forEach((k, v) => splits[k == 'me' ? creatorId : k] = v);
      
      final paidBy = data['paidById']?.toString() ?? '';

      final iPaidAndTheyOwe = paidBy == currentUserId && splits.containsKey(friendId);
      final theyPaidAndIOwe = paidBy == friendId && splits.containsKey(currentUserId);

      return iPaidAndTheyOwe || theyPaidAndIOwe;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(friend.name, style: AppTextStyles.titleMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Friend header + balance ───────────────────────────
          _FriendHeader(
            friend: friend,
            currentUserId: currentUser.uid,
          ),

          // ── Expenses list ─────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('expenses')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                final friendExpenses = _filterBilateralExpenses(docs, currentUser.uid, friend.id);

                if (friendExpenses.isEmpty) {
                  return _EmptyExpensesState(
                    friendName: friend.name,
                    onAddExpense: () => Navigator.pushNamed(
                      context,
                      AppRoutes.choosePeople,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: friendExpenses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final expense = Expense.fromFirestore(friendExpenses[i]);
                    final paidByMe = expense.paidById == currentUser.uid;
                    
                    // If I paid, the amount lent is their split. 
                    // If they paid, the amount borrowed is my split.
                    final amount = paidByMe 
                        ? (expense.splits[friend.id] ?? 0.0) 
                        : (expense.splits[currentUser.uid] ?? 0.0);

                    return _ExpenseTile(
                      expense: expense,
                      paidByMe: paidByMe,
                      amount: amount,
                      friendName: friend.name,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ── Settle up button ──────────────────────────────────────
      bottomNavigationBar: _SettleUpBar(
        friend: friend,
        currentUserId: currentUser.uid,
      ),
    );
  }
}

class _FriendHeader extends StatelessWidget {
  final Friend friend;
  final String currentUserId;

  const _FriendHeader({
    required this.friend,
    required this.currentUserId,
  });

  Future<double> _calculateBalance() async {
    double balance = 0;

    final expenses = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('expenses')
        .get();

    for (final doc in expenses.docs) {
      final data = doc.data();
      final rawSplits = Map<String, dynamic>.from(data['splits'] ?? {});
      final paidBy = data['paidById'] as String? ?? '';
      final fallbackId = paidBy.isNotEmpty ? paidBy : (data['creatorId'] ?? data['sharedBy'] ?? currentUserId);
      
      final splits = <String, dynamic>{};
      rawSplits.forEach((k, v) => splits[k == 'me' ? fallbackId : k] = v);

      if (paidBy == currentUserId) {
        if (splits.containsKey(friend.id)) {
          final amt = double.parse(((splits[friend.id] as num).toDouble()).toStringAsFixed(2));
          balance = double.parse((balance + amt).toStringAsFixed(2));
        }
      } else if (paidBy == friend.id) {
        if (splits.containsKey(currentUserId)) {
          final amt = double.parse(((splits[currentUserId] as num).toDouble()).toStringAsFixed(2));
          balance = double.parse((balance - amt).toStringAsFixed(2));
        }
      }
    }

    final settlements = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('settlements')
        .get();

    for (final doc in settlements.docs) {
      final data = doc.data();
      final fromId = data['fromId'] as String? ?? '';
      final toId = data['toId'] as String? ?? '';
      final amt = (data['amount'] as num).toDouble();

      if (fromId == currentUserId && toId == friend.id) {
        balance += amt;
      } else if (fromId == friend.id && toId == currentUserId) {
        balance -= amt;
      }
    }

    return balance;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _calculateBalance(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0.0;
        final isPositive = balance > 0;
        final isZero = balance.abs() < 0.01;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: AppColors.surface,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AvatarColors.background(friend.colorIndex),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    friend.initials,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AvatarColors.get(friend.colorIndex),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(friend.name, style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              if (isZero)
                Text(
                  'All settled up!',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      '\$${balance.abs().toStringAsFixed(2)}',
                      style: AppTextStyles.moneyLarge.copyWith(
                        color:
                            isPositive ? AppColors.success : AppColors.danger,
                      ),
                    ),
                    Text(
                      isPositive
                          ? '${friend.name} owes you'
                          : 'You owe ${friend.name}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
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

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final bool paidByMe;
  final double amount;
  final String friendName;

  const _ExpenseTile({
    required this.expense,
    required this.paidByMe,
    required this.amount,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
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
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: AppRadius.sm,
            ),
            child: const Icon(Icons.receipt_outlined,
                color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.title, style: AppTextStyles.titleSmall),
                const SizedBox(height: 2),
                Text(
                  paidByMe
                      ? 'You paid \$${expense.total.toStringAsFixed(2)}'
                      : '$friendName paid \$${expense.total.toStringAsFixed(2)}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                paidByMe ? 'you lent' : 'you borrowed',
                style: AppTextStyles.bodySmall,
              ),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: AppTextStyles.titleSmall.copyWith(
                  color: paidByMe ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettleUpBar extends StatelessWidget {
  final Friend friend;
  final String currentUserId;

  const _SettleUpBar({
    required this.friend,
    required this.currentUserId,
  });

  Future<double> _calculateBalance() async {
    double balance = 0;

    final expenses = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('expenses')
        .get();

    for (final doc in expenses.docs) {
      final data = doc.data();
      final rawSplits = Map<String, dynamic>.from(data['splits'] ?? {});
      final paidBy = data['paidById'] as String? ?? '';
      final fallbackId = paidBy.isNotEmpty ? paidBy : (data['creatorId'] ?? data['sharedBy'] ?? currentUserId);
      
      final splits = <String, dynamic>{};
      rawSplits.forEach((k, v) => splits[k == 'me' ? fallbackId : k] = v);

      if (paidBy == currentUserId) {
        if (splits.containsKey(friend.id)) {
          final amt = double.parse(((splits[friend.id] as num).toDouble()).toStringAsFixed(2));
          balance = double.parse((balance + amt).toStringAsFixed(2));
        }
      } else if (paidBy == friend.id) {
        if (splits.containsKey(currentUserId)) {
          final amt = double.parse(((splits[currentUserId] as num).toDouble()).toStringAsFixed(2));
          balance = double.parse((balance - amt).toStringAsFixed(2));
        }
      }
    }

    final settlements = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('settlements')
        .get();

    for (final doc in settlements.docs) {
      final data = doc.data();
      final fromId = data['fromId'] as String? ?? '';
      final toId = data['toId'] as String? ?? '';
      final amt = (data['amount'] as num).toDouble();

      if (fromId == currentUserId && toId == friend.id) {
        balance += amt;
      } else if (fromId == friend.id && toId == currentUserId) {
        balance -= amt;
      }
    }

    return balance;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _calculateBalance(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0.0;
        final isZero = balance.abs() < 0.01;

        if (isZero) return const SizedBox.shrink();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.settleUp,
                arguments: {
                  'groupId': '', // Friend-to-friend payments don't need a group, but signature requires String
                  'targetFriendId': friend.id,
                  'friendName': friend.name,
                  'amount': balance,
                },
              ),
              child: Text(
                balance > 0
                    ? 'Record payment from ${friend.name}'
                    : 'Record payment to ${friend.name}',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyExpensesState extends StatelessWidget {
  final String friendName;
  final VoidCallback onAddExpense;

  const _EmptyExpensesState({
    required this.friendName,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.receipt_long_outlined,
                  color: AppColors.accent, size: 36),
            ),
            const SizedBox(height: 20),
            Text('No expenses yet', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add an expense with $friendName\nto start tracking.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddExpense,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add expense'),
            ),
          ],
        ),
      ),
    );
  }
}
