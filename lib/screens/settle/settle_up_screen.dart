// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';

class SettleUpScreen extends StatefulWidget {
  final String groupId;
  final String targetFriendId;
  final String friendName;
  final double amountOwed;

  const SettleUpScreen({
    super.key,
    required this.groupId,
    required this.targetFriendId,
    required this.friendName,
    required this.amountOwed,
  });

  @override
  State<SettleUpScreen> createState() =>
      _SettleUpScreenState();
}

class _SettleUpScreenState
    extends State<SettleUpScreen> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController =
      TextEditingController();
  String _selectedMethod = 'Cash';
  bool _isSaving = false;

  double get _parsedAmount =>
      double.tryParse(_amountController.text) ??
      widget.amountOwed;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.amountOwed.abs().toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment() async {
    final currentUser =
        FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (_parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = currentUser.uid;
      final now = DateTime.now();

      // ── Direction logic ───────────────────────────
      // amountOwed > 0 → friend owes me → they pay me
      // amountOwed < 0 → I owe friend → I pay them
      final fromId = widget.amountOwed > 0
          ? widget.targetFriendId
          : uid;
      final toId = widget.amountOwed > 0
          ? uid
          : widget.targetFriendId;

      // ── 1. Write settlement document ──────────────
      final settlementRef = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(uid)
          .collection('settlements')
          .add({
        'fromId': fromId,
        'toId': toId,
        'amount': _parsedAmount,
        'method': _selectedMethod,
        'note': _noteController.text.trim(),
        'groupId': widget.groupId,
        'createdAt': now,
      });

      // ── 2. Write activity document ─────────────────
      // Includes all required fields for group feed
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('activities')
          .add({
        'type': 'settlement',
        'description':
            'Settled \$${_parsedAmount.toStringAsFixed(2)} with ${widget.friendName} via $_selectedMethod',
        'amount': _parsedAmount,
        'groupId': widget.groupId,       // group scope
        'creatorId': uid,                // who acted
        'relatedId': settlementRef.id,   // link to doc
        'createdAt': now,
      });

      if (mounted) _showSuccessSheet();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
            32, 32, 32, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Green check
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),

            Text('Payment recorded!',
                style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),

            Text(
              '\$${_parsedAmount.toStringAsFixed(2)} settled with ${widget.friendName}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Method badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success
                    .withValues(alpha: 0.12),
                borderRadius: AppRadius.pill,
              ),
              child: Text(
                'via $_selectedMethod',
                style: AppTextStyles.labelMedium
                    .copyWith(
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.popUntil(
                  ctx,
                  (route) =>
                      route.settings.name ==
                          '/group-detail' ||
                      route.settings.name ==
                          '/main' ||
                      route.isFirst,
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iOwe = widget.amountOwed <= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settle Up',
            style: AppTextStyles.titleMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── High-contrast "Paying X" header ───────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.lg,
              ),
              child: Column(
                children: [
                  // Friend initials avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.friendName.isNotEmpty
                            ? widget.friendName
                                .trim()
                                .split(' ')
                                .where(
                                    (w) => w.isNotEmpty)
                                .map((w) =>
                                    w[0].toUpperCase())
                                .take(2)
                                .join()
                            : '?',
                        style: AppTextStyles.titleLarge
                            .copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    iOwe
                        ? 'Paying ${widget.friendName}'
                        : 'Recording payment from\n${widget.friendName}',
                    style: AppTextStyles.displayMedium
                        .copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  Text(
                    iOwe
                        ? 'You owe them money'
                        : 'They owe you money',
                    style: AppTextStyles.bodyMedium
                        .copyWith(
                      color: Colors.white
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Large currency input ──────────────────
            Text('Amount',
                style: AppTextStyles.titleSmall),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.md,
                border:
                    Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Text(
                      '\$',
                      style: AppTextStyles.moneyLarge
                          .copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                              decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter
                            .allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      style: AppTextStyles.moneyLarge,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding:
                            EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Payment method ────────────────────────
            Text('Payment method',
                style: AppTextStyles.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SettlementMethods.all
                  .map((method) => _MethodChip(
                        method: method,
                        icon: SettlementMethods
                                .icons[method] ??
                            '✅',
                        isSelected:
                            _selectedMethod == method,
                        onTap: () => setState(
                            () => _selectedMethod =
                                method),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 24),

            // ── Optional note ─────────────────────────
            Text('Note (optional)',
                style: AppTextStyles.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Dinner, groceries, etc.',
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),

      // ── Confirm button ────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              24, 8, 24, 16),
          child: ElevatedButton(
            onPressed:
                _isSaving ? null : _recordPayment,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Confirm — record \$${_parsedAmount.toStringAsFixed(2)}',
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Method Chip ──────────────────────────────────────────────────────────────

class _MethodChip extends StatelessWidget {
  final String method;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodChip({
    required this.method,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent
              : AppColors.surface,
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon,
                style:
                    const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              method,
              style:
                  AppTextStyles.titleSmall.copyWith(
                color: isSelected
                    ? Colors.white
                    : AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}