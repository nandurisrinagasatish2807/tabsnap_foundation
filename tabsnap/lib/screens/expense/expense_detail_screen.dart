// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String expenseId;
  const ExpenseDetailScreen({
    super.key,
    required this.expenseId,
  });

  @override
  State<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState
    extends State<ExpenseDetailScreen> {
  // UID → Name cache built from friends collection
  final Map<String, String> _nameCache = {};
  final Map<String, int> _colorCache = {};

  @override
  void initState() {
    super.initState();
    _loadFriendNames();
  }

  Future<void> _loadFriendNames() async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    // Add self
    final selfDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final selfName =
        (selfDoc.data()?['name'] as String?) ?? 'Me';
    _nameCache[uid] = selfName;
    _colorCache[uid] = 0;

    // Add all friends
    final friendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friends')
        .get();

    int colorIdx = 1;
    for (final doc in friendsSnap.docs) {
      final data = doc.data();
      _nameCache[doc.id] =
          data['name'] as String? ?? doc.id;
      _colorCache[doc.id] = colorIdx % 8;
      colorIdx++;
    }

    if (mounted) setState(() {});
  }

  String _nameFor(String uid) =>
      _nameCache[uid] ?? uid.substring(0, 6);

  int _colorFor(String uid) =>
      _colorCache[uid] ?? 0;

  @override
  Widget build(BuildContext context) {
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Expense Detail',
            style: AppTextStyles.titleMedium),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('expenses')
            .doc(widget.expenseId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent),
            );
          }

          if (!snapshot.hasData ||
              !snapshot.data!.exists) {
            return Center(
              child: Text('Expense not found',
                  style: AppTextStyles.bodyLarge),
            );
          }

          final expense =
              Expense.fromFirestore(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ── Title + Total card ────────────────
                _SummaryCard(expense: expense),

                const SizedBox(height: 16),

                // ── Who paid ─────────────────────────
                _SectionLabel(label: 'Who paid'),
                _WhoPayCard(
                  paidById: expense.paidById,
                  total: expense.total,
                  nameFor: _nameFor,
                  colorFor: _colorFor,
                ),

                const SizedBox(height: 16),

                // ── Items breakdown ───────────────────
                if (expense.items.isNotEmpty) ...[
                  _SectionLabel(
                      label:
                          'Items (${expense.items.length})'),
                  ...expense.items.map((item) =>
                      _ItemCard(
                        item: item,
                        nameFor: _nameFor,
                        colorFor: _colorFor,
                      )),
                  const SizedBox(height: 16),
                ],

                // ── Split breakdown ───────────────────
                _SectionLabel(label: 'Split breakdown'),
                ...expense.splits.entries.map((entry) {
                  final memberId = entry.key;
                  final amount = entry.value;
                  final owesMe =
                      expense.paidById == currentUid;
                  return _SplitRow(
                    memberId: memberId,
                    amount: amount,
                    owesMe: owesMe,
                    nameFor: _nameFor,
                    colorFor: _colorFor,
                  );
                }),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final Expense expense;
  const _SummaryCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color:
                  AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_outlined,
                color: AppColors.accent, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            expense.title,
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '\$${expense.total.toStringAsFixed(2)}',
            style: AppTextStyles.moneyLarge.copyWith(
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(expense.createdAt),
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ─── Who Paid Card ────────────────────────────────────────────────────────────

class _WhoPayCard extends StatelessWidget {
  final String paidById;
  final double total;
  final String Function(String) nameFor;
  final int Function(String) colorFor;

  const _WhoPayCard({
    required this.paidById,
    required this.total,
    required this.nameFor,
    required this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    final name = nameFor(paidById);
    final colorIdx = colorFor(paidById);
    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();

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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AvatarColors.background(colorIdx),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: AppTextStyles.titleSmall.copyWith(
                  color: AvatarColors.get(colorIdx),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.titleSmall),
                Text('paid the bill',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Item Card ────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final ReceiptItem item;
  final String Function(String) nameFor;
  final int Function(String) colorFor;

  const _ItemCard({
    required this.item,
    required this.nameFor,
    required this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.name,
                    style: AppTextStyles.titleSmall),
              ),
              Text(
                '\$${item.price.toStringAsFixed(2)}',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ],
          ),

          // Assigned avatars
          if (item.assignedTo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Stacked avatars
                SizedBox(
                  height: 24,
                  width: item.assignedTo.length * 18.0 +
                      8,
                  child: Stack(
                    children: item.assignedTo
                        .asMap()
                        .entries
                        .map((e) {
                      final uid = e.value;
                      final idx = e.key;
                      final name = nameFor(uid);
                      final colorIdx = colorFor(uid);
                      final initial = name.isNotEmpty
                          ? name[0].toUpperCase()
                          : '?';
                      return Positioned(
                        left: idx * 18.0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AvatarColors.background(
                                colorIdx),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AvatarColors.get(
                                    colorIdx),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.assignedTo.length == 1
                      ? nameFor(item.assignedTo.first)
                      : '${item.assignedTo.map(nameFor).take(2).join(', ')}${item.assignedTo.length > 2 ? ' +${item.assignedTo.length - 2}' : ''}',
                  style: AppTextStyles.bodySmall,
                ),
                if (item.assignedTo.length > 1) ...[
                  Text(' · ',
                      style: AppTextStyles.bodySmall),
                  Text(
                    '\$${(item.price / item.assignedTo.length).toStringAsFixed(2)} each',
                    style: AppTextStyles.bodySmall
                        .copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Split Row ────────────────────────────────────────────────────────────────

class _SplitRow extends StatelessWidget {
  final String memberId;
  final double amount;
  final bool owesMe;
  final String Function(String) nameFor;
  final int Function(String) colorFor;

  const _SplitRow({
    required this.memberId,
    required this.amount,
    required this.owesMe,
    required this.nameFor,
    required this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    final name = nameFor(memberId);
    final colorIdx = colorFor(memberId);
    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AvatarColors.background(colorIdx),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AvatarColors.get(colorIdx),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: AppTextStyles.bodyMedium),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: AppTextStyles.titleSmall.copyWith(
                  color: owesMe
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
              Text(
                owesMe ? 'owes' : 'you owe',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: AppTextStyles.titleSmall),
    );
  }
}