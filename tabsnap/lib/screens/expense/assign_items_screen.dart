// ignore_for_file: prefer_const_constructors, unnecessary_const, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssignItemsScreen extends StatefulWidget {
  final List<ReceiptItem> items;
  final List<Friend> friends;
  final String? groupId;

  const AssignItemsScreen({
    super.key,
    required this.items,
    required this.friends,
    this.groupId,
  });

  @override
  State<AssignItemsScreen> createState() => _AssignItemsScreenState();
}

class _AssignItemsScreenState extends State<AssignItemsScreen> {
  late List<ReceiptItem> _items;
  late List<Friend> _friendsWithMe; // Moved inside the state class

  @override
  void initState() {
    super.initState();
    _items = widget.items
        .map((item) => ReceiptItem(
              id: item.id,
              name: item.name,
              price: item.price,
              assignedTo: List<String>.from(item.assignedTo),
            ))
        .toList();

    // ─── Add "Me" to the friends list logic ───
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'me';
    final alreadyHasMe = widget.friends.any((f) => f.id == currentUid);

    if (!alreadyHasMe) {
      _friendsWithMe = [
        Friend(
          id: currentUid,
          name: 'Me',
          colorIndex: 0,
        ),
        ...widget.friends,
      ];
    } else {
      _friendsWithMe = widget.friends;
    }
  }

  // Individual bubble toggle
  void _togglePerson(int itemIndex, String friendId) {
    setState(() {
      final assigned = _items[itemIndex].assignedTo;
      if (assigned.contains(friendId)) {
        assigned.remove(friendId);
      } else {
        assigned.add(friendId);
      }
    });
  }

  // "All" bubble toggle
  void _toggleAll(int itemIndex) {
    setState(() {
      final assigned = _items[itemIndex].assignedTo;

      if (assigned.length == _friendsWithMe.length) {
        assigned.clear();
      } else {
        assigned.clear();
        for (final f in _friendsWithMe) {
          assigned.add(f.id);
        }
      }
    });
  }

  bool _allAssigned(int itemIndex) =>
      _items[itemIndex].assignedTo.length == _friendsWithMe.length;

  bool get _allItemsAssigned =>
      _items.every((item) => item.assignedTo.isNotEmpty);

  Map<String, double> get _splits {
    final splits = <String, double>{};
    for (final item in _items) {
      if (item.assignedTo.isEmpty) continue;
      final share = item.price / item.assignedTo.length;
      for (final id in item.assignedTo) {
        splits[id] = (splits[id] ?? 0) + share;
      }
    }
    return splits;
  }

  void _goToSummary() {
    if (!_allItemsAssigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assign all items before continuing'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.splitSummary,
      arguments: {
        'items': _items,
        'friends': _friendsWithMe,
        'paidBy': _friendsWithMe.first, // Defaults to "Me"
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
        title: Text('Assign Items', style: AppTextStyles.titleMedium),
      ),
      body: Column(
        children: [
          _StepIndicator(step: 4),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: const [
                Icon(Icons.touch_app_outlined,
                    size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  'Tap names to assign each item',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ItemAssignCard(
                item: _items[index],
                friends: _friendsWithMe,
                onToggleAll: () => _toggleAll(index),
                onTogglePerson: (friendId) => _togglePerson(index, friendId),
                isAllSelected: _allAssigned(index),
              ),
            ),
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_splits.isNotEmpty) ...[
                  _SplitPreview(
                    splits: _splits,
                    friends: _friendsWithMe,
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_allItemsAssigned)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${_items.where((i) => i.assignedTo.isEmpty).length} items still need assignment',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warning,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _allItemsAssigned ? _goToSummary : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _allItemsAssigned ? AppColors.accent : AppColors.border,
                    ),
                    child: const Text(
                      'Review Split →',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemAssignCard extends StatelessWidget {
  final ReceiptItem item;
  final List<Friend> friends;
  final VoidCallback onToggleAll;
  final ValueChanged<String> onTogglePerson;
  final bool isAllSelected;

  const _ItemAssignCard({
    required this.item,
    required this.friends,
    required this.onToggleAll,
    required this.onTogglePerson,
    required this.isAllSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isAssigned = item.assignedTo.isNotEmpty;
    final sharePerPerson =
        item.assignedTo.isEmpty ? 0.0 : item.price / item.assignedTo.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: isAssigned
              ? AppColors.accent.withValues(alpha: 0.3)
              : AppColors.border,
          width: isAssigned ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: AppTextStyles.titleSmall,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                  if (isAssigned && item.assignedTo.length > 1)
                    Text(
                      '\$${sharePerPerson.toStringAsFixed(2)} each',
                      style: AppTextStyles.bodySmall,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmartBubble(
                label: 'All',
                isSelected: isAllSelected,
                color: AppColors.accent,
                onTap: onToggleAll,
              ),
              ...friends.map((friend) {
                final isSelected = item.assignedTo.contains(friend.id);
                return _SmartBubble(
                  label: friend.name.split(' ').first,
                  isSelected: isSelected,
                  color: AvatarColors.get(friend.colorIndex),
                  onTap: () => onTogglePerson(friend.id),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          if (!isAssigned)
            Text(
              '← tap names to assign',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warning,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Text(
              isAllSelected
                  ? 'Shared equally by everyone'
                  : 'Assigned to ${item.assignedTo.length} ${item.assignedTo.length == 1 ? 'person' : 'people'}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.success,
              ),
            ),
        ],
      ),
    );
  }
}

class _SmartBubble extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _SmartBubble({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

class _SplitPreview extends StatelessWidget {
  final Map<String, double> splits;
  final List<Friend> friends;

  const _SplitPreview({
    required this.splits,
    required this.friends,
  });

  @override
  Widget build(BuildContext context) {
    final assignedFriends =
        friends.where((f) => splits.containsKey(f.id)).toList();

    if (assignedFriends.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current split', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          ...assignedFriends.map((friend) {
            final amount = splits[friend.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AvatarColors.background(friend.colorIndex),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        friend.initials,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AvatarColors.get(friend.colorIndex),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      friend.name.split(' ').first,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                  Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

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
