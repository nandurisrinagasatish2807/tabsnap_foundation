// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';

class ReviewItemsScreen extends StatefulWidget {
  final List<ReceiptItem> items;
  final List<Friend> friends;
  final String? groupId;

  const ReviewItemsScreen({
    super.key,
    required this.items,
    required this.friends,
    this.groupId,
  });

  @override
  State<ReviewItemsScreen> createState() => _ReviewItemsScreenState();
}

class _ReviewItemsScreenState extends State<ReviewItemsScreen> {
  late List<ReceiptItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.price);

  bool get _allPricesFilled => _items.every((item) => item.price > 0);

  void _addItem() {
    setState(() {
      _items.add(ReceiptItem(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        name: 'New Item',
        price: 0.0,
      ));
    });
    // Auto-open edit for the new item
    Future.delayed(const Duration(milliseconds: 100), () {
      _editItem(_items.length - 1);
    });
  }

  void _deleteItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _editItem(int index) {
    final item = _items[index];
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(
      text: item.price > 0 ? item.price.toStringAsFixed(2) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit item', style: AppTextStyles.titleLarge),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _items[index] = ReceiptItem(
                        id: item.id,
                        name: nameController.text.trim().isEmpty
                            ? item.name
                            : nameController.text.trim(),
                        price:
                            double.tryParse(priceController.text) ?? item.price,
                      );
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Save',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Name field
            Text('Item name', style: AppTextStyles.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Bell Pepper',
              ),
            ),
            const SizedBox(height: 16),

            // Price field
            Text('Price', style: AppTextStyles.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _goToAssign() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one item'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_allPricesFilled) {
      // Show warning but still allow proceeding
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Some prices are missing'),
          content: const Text('Some items have \$0.00 price. Continue anyway?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Go back',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _navigate();
              },
              child:
                  Text('Continue', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
      return;
    }

    _navigate();
  }

  void _navigate() {
    Navigator.pushNamed(
      context,
      AppRoutes.assignItems,
      arguments: {
        'items': _items,
        'friends': widget.friends,
        'groupId': widget.groupId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Review Items', style: AppTextStyles.titleMedium),
      ),
      body: Column(
        children: [
          // ── Step indicator ────────────────────────────────
          _StepIndicator(step: 3),

          // ── Subtitle ──────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Icon(
                  _items.isEmpty
                      ? Icons.info_outline
                      : _allPricesFilled
                          ? Icons.check_circle_outline
                          : Icons.edit_outlined,
                  size: 16,
                  color:
                      _allPricesFilled ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  _items.isEmpty
                      ? 'Add items manually'
                      : _allPricesFilled
                          ? '${_items.length} items ready'
                          : '${_items.where((i) => i.price == 0).length} items need a price — tap to edit',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _allPricesFilled
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Items list ─────────────────────────────────────
          Expanded(
            child: _items.isEmpty
                ? _EmptyItemsState(onAdd: _addItem)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _ItemTile(
                      item: _items[i],
                      onEdit: () => _editItem(i),
                      onDelete: () => _deleteItem(i),
                    ),
                  ),
          ),
        ],
      ),

      // ── Bottom bar ────────────────────────────────────────
      bottomSheet: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add item button
            GestureDetector(
              onTap: _addItem,
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Add item manually',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Subtotal row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal', style: AppTextStyles.titleSmall),
                Text(
                  '\$${_subtotal.toStringAsFixed(2)}',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Assign button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _items.isEmpty ? null : _goToAssign,
                child: const Text('Assign who used what →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item Tile ────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final ReceiptItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final needsPrice = item.price == 0;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: needsPrice
                ? AppColors.warning.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Price needs attention indicator
            if (needsPrice)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 10),
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),

            // Name
            Expanded(
              child: Text(item.name, style: AppTextStyles.bodyLarge),
            ),

            // Price
            Text(
              needsPrice
                  ? 'tap to add price'
                  : '\$${item.price.toStringAsFixed(2)}',
              style: AppTextStyles.titleSmall.copyWith(
                color: needsPrice ? AppColors.warning : AppColors.textPrimary,
              ),
            ),

            const SizedBox(width: 8),

            // Edit icon
            const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.textHint),

            const SizedBox(width: 4),

            // Delete
            GestureDetector(
              onTap: onDelete,
              child:
                  const Icon(Icons.close, size: 18, color: AppColors.textHint),
            ),
          ],
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

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyItemsState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyItemsState({required this.onAdd});

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
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_outlined,
                  color: AppColors.warning, size: 36),
            ),
            const SizedBox(height: 20),
            Text('No items scanned', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              'OCR couldn\'t read items from this receipt.\nAdd them manually below.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add item'),
            ),
          ],
        ),
      ),
    );
  }
}
