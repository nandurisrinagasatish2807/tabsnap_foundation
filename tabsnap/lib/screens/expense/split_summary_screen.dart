// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';

class SplitSummaryScreen extends StatefulWidget {
  final List<ReceiptItem> items;
  final List<Friend> friends;
  final Friend paidBy;
  final String? groupId;

  const SplitSummaryScreen({
    super.key,
    required this.items,
    required this.friends,
    required this.paidBy,
    this.groupId,
  });

  @override
  State<SplitSummaryScreen> createState() => _SplitSummaryScreenState();
}

class _SplitSummaryScreenState extends State<SplitSummaryScreen> {
  late Friend _paidBy;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _paidBy = widget.paidBy;
  }

  // Calculate splits from item assignments
  Map<String, double> get _splits {
    final splits = <String, double>{};
    for (final item in widget.items) {
      if (item.assignedTo.isEmpty) continue;
      final share = item.price / item.assignedTo.length;
      for (final id in item.assignedTo) {
        splits[id] = (splits[id] ?? 0) + share;
      }
    }
    return splits;
  }

  double get _total => widget.items.fold(0.0, (double acc, i) => acc + i.price);

  Future<void> _saveExpense() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isSaving = true);

    try {
      final splits = _splits;

      // ── Critical fix: resolve paidById correctly ──────
      // 'me' chip means current user paid
      // Any friend chip means that friend paid
      final String paidById;
      if (_paidBy.id == 'me') {
        paidById = currentUser.uid;
      } else {
        paidById = _paidBy.id;
      }

      final expenseData = {
        'title': _generateTitle(),
        'total': _total,
        'paidById': paidById, // ← correct payer
        'items': widget.items.map((i) => i.toMap()).toList(),
        'splits': splits,
        'groupId': widget.groupId, // ← group link
        'createdAt': DateTime.now(),
      };

      // ── Save to current user's path ───────────────────
      final myExpenseRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('expenses')
          .doc(); // auto ID

      await myExpenseRef.set(expenseData);

      // ── Save to each friend's path (cloud sync) ───────
      for (final friend in widget.friends) {
        // Skip if friend IS the current user
        if (friend.id == currentUser.uid) continue;
        // Skip temporary contacts (no Firebase account)
        if (friend.isTemporary) continue;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(friend.id)
            .collection('expenses')
            .doc(myExpenseRef.id) // same doc ID
            .set({
          ...expenseData,
          'sharedBy': currentUser.uid,
          'sharedByName':
              currentUser.displayName ?? currentUser.email ?? 'Someone',
        });
      }

      // ── Log to activity feed ──────────────────────────
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('activities')
          .add({
        'type': 'expense',
        'description':
            'Added "${_generateTitle()}" — \$${_total.toStringAsFixed(2)}',
        'amount': _total,
        'groupId': widget.groupId,
        'creatorId': currentUser.uid,
        'relatedId': myExpenseRef.id,
        'createdAt': DateTime.now(),
      });

      if (mounted) _showSuccessSheet();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _generateTitle() {
    if (widget.items.isEmpty) return 'Shared expense';
    if (widget.items.length == 1) {
      return widget.items.first.name;
    }
    return '${widget.items.first.name} & ${widget.items.length - 1} more';
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Expense saved!', style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(
              'Balances have been updated.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Summary of who owes what
            ..._splits.entries.map((entry) {
              final friend = widget.friends.firstWhere(
                (f) => f.id == entry.key,
                orElse: () => Friend(
                  id: entry.key,
                  name: 'Someone',
                  colorIndex: 0,
                ),
              );
              final paidByMe = _paidBy.id == 'me' ||
                  _paidBy.id == FirebaseAuth.instance.currentUser?.uid;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AvatarColors.background(friend.colorIndex),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          friend.initials,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AvatarColors.get(friend.colorIndex),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        friend.name,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    Text(
                      paidByMe
                          ? 'owes \$${entry.value.toStringAsFixed(2)}'
                          : 'you owe \$${entry.value.toStringAsFixed(2)}',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: paidByMe ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Pop all expense screens and go home
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.main,
                    (route) => false,
                  );
                },
                child: const Text('Back to home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final splits = _splits;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Split Summary', style: AppTextStyles.titleMedium),
      ),
      body: Column(
        children: [
          // ── Step indicator ────────────────────────────────
          _StepIndicator(step: 5),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Total card ─────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.lg,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text('Total bill', style: AppTextStyles.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_total.toStringAsFixed(2)}',
                          style: AppTextStyles.moneyLarge.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.items.length} items · ${splits.length} people',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Who paid ───────────────────────────────
                  Text('Who paid?', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // "Me" option
                        _PaidByChip(
                          label: 'Me',
                          colorIndex: 0,
                          isSelected: _paidBy.id == 'me',
                          onTap: () => setState(() {
                            _paidBy = Friend(
                              id: 'me',
                              name: 'Me',
                              colorIndex: 0,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        // Friend options
                        ...widget.friends.map((friend) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _PaidByChip(
                                label: friend.name.split(' ').first,
                                colorIndex: friend.colorIndex,
                                isSelected: _paidBy.id == friend.id,
                                onTap: () => setState(() => _paidBy = friend),
                              ),
                            )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Per person breakdown ───────────────────
                  Text('Each person owes', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 8),

                  ...splits.entries.map((entry) {
                    final friend = widget.friends.firstWhere(
                      (f) => f.id == entry.key,
                      orElse: () => Friend(
                        id: entry.key,
                        name: 'Unknown',
                        colorIndex: 0,
                      ),
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
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
                              color: AvatarColors.background(friend.colorIndex),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                friend.initials,
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: AvatarColors.get(friend.colorIndex),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(friend.name,
                                style: AppTextStyles.titleSmall),
                          ),
                          Text(
                            '\$${entry.value.toStringAsFixed(2)}',
                            style: AppTextStyles.moneyLarge.copyWith(
                              fontSize: 20,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // ── Items breakdown ────────────────────────
                  Text('Items', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 8),

                  ...widget.items.map((item) {
                    final assignedNames = item.assignedTo
                        .map((id) {
                          try {
                            return widget.friends
                                .firstWhere((f) => f.id == id)
                                .name
                                .split(' ')
                                .first;
                          } catch (_) {
                            return 'Unknown';
                          }
                        })
                        .toList()
                        .join(', ');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(item.name,
                                style: AppTextStyles.bodyMedium),
                          ),
                          Text(
                            assignedNames.isEmpty
                                ? 'unassigned'
                                : assignedNames,
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '\$${item.price.toStringAsFixed(2)}',
                            style: AppTextStyles.titleSmall,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Save button ───────────────────────────────────────
      bottomSheet: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveExpense,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save & update balances'),
          ),
        ),
      ),
    );
  }
}

// ─── Paid By Chip ─────────────────────────────────────────────────────────────

class _PaidByChip extends StatelessWidget {
  final String label;
  final int colorIndex;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaidByChip({
    required this.label,
    required this.colorIndex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AvatarColors.get(colorIndex);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.titleSmall.copyWith(
            color: isSelected ? Colors.white : color,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Step Indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = ['People', 'Scan', 'Review', 'Assign', 'Done'];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i + 1 == step;
          final isDone = i + 1 < step;
          return Expanded(
            child: Column(
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: isDone || isActive
                        ? AppColors.accent
                        : AppColors.border,
                    borderRadius: AppRadius.pill,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[i],
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isActive
                        ? AppColors.accent
                        : isDone
                            ? AppColors.textSecondary
                            : AppColors.textHint,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
