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
              quantity: item.quantity,
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
          fullName: 'Me',
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
      
      final count = item.assignedTo.length;
      final unitShare = (item.price / count * 100).round() / 100.0;
      double distributed = 0;

      for (int i = 0; i < item.assignedTo.length; i++) {
        final memberId = item.assignedTo[i];
        final isLast = i == item.assignedTo.length - 1;

        // Floating penny fix:
        // Last person gets remainder to balance total
        final share = isLast
            ? double.parse((item.price - distributed).toStringAsFixed(2))
            : unitShare;

        splits[memberId] = (splits[memberId] ?? 0.0) + share;
        if (!isLast) distributed += share;
      }
    }

    // Only include users with a balance > $0.00
    splits.removeWhere((_, value) => value < 0.01);
    
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
        ],
      ),
      bottomNavigationBar: _StickySplitBar(
        splits: _splits,
        friends: _friendsWithMe,
        allItemsAssigned: _allItemsAssigned,
        unassignedCount:
            _items.where((i) => i.assignedTo.isEmpty).length,
        onContinue: _goToSummary,
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
    final assignedFriends = friends
        .where((friend) => item.assignedTo.contains(friend.id))
        .toList();

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.name,
                          style: AppTextStyles.titleSmall,
                        ),
                        if (item.quantity != null && item.quantity! > 0)
                          _QuantityBadge(quantity: item.quantity!),
                      ],
                    ),
                    if (isAssigned) ...[
                      const SizedBox(height: 10),
                      _AssignedAvatarRow(friends: assignedFriends),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
                showAvatar: false,
              ),
              ...friends.map((friend) {
                final isSelected = item.assignedTo.contains(friend.id);
                return _SmartBubble(
                  label: friend.fullName.split(' ').first,
                  isSelected: isSelected,
                  color: AvatarColors.get(friend.colorIndex),
                  onTap: () => onTogglePerson(friend.id),
                  initials: friend.initials,
                  showAvatar: true,
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

class _QuantityBadge extends StatelessWidget {
  final int quantity;

  const _QuantityBadge({required this.quantity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.pill,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        '×$quantity',
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _AssignedAvatarRow extends StatelessWidget {
  final List<Friend> friends;

  const _AssignedAvatarRow({required this.friends});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: friends
          .map(
            (friend) => _FriendAvatar(
              friend: friend,
              size: 28,
              showBorder: true,
            ),
          )
          .toList(),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  final Friend friend;
  final double size;
  final bool showBorder;

  const _FriendAvatar({
    required this.friend,
    this.size = 24,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AvatarColors.get(friend.colorIndex);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AvatarColors.background(friend.colorIndex),
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: color.withValues(alpha: 0.35), width: 1.5)
            : null,
      ),
      child: Center(
        child: Text(
          friend.initials,
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _SmartBubble extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final String? initials;
  final bool showAvatar;

  const _SmartBubble({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.initials,
    this.showAvatar = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: showAvatar ? 10 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAvatar && initials != null) ...[
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.22)
                      : color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials!,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                color: isSelected ? Colors.white : color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickySplitBar extends StatelessWidget {
  final Map<String, double> splits;
  final List<Friend> friends;
  final bool allItemsAssigned;
  final int unassignedCount;
  final VoidCallback onContinue;

  const _StickySplitBar({
    required this.splits,
    required this.friends,
    required this.allItemsAssigned,
    required this.unassignedCount,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final splitsTotal = splits.values.fold(0.0, (acc, value) => acc + value);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Running totals',
                    style: AppTextStyles.labelMedium,
                  ),
                  Text(
                    'Assigned: \$${splitsTotal.toStringAsFixed(2)}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: friends.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final amount = splits[friend.id] ?? 0.0;
                    final hasShare = amount >= 0.01;

                    return Container(
                      width: 112,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: hasShare
                            ? AvatarColors.background(friend.colorIndex)
                            : AppColors.surfaceAlt,
                        borderRadius: AppRadius.md,
                        border: Border.all(
                          color: hasShare
                              ? AvatarColors.get(friend.colorIndex)
                                  .withValues(alpha: 0.25)
                              : AppColors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _FriendAvatar(friend: friend, size: 22),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  friend.fullName.split(' ').first,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: AppTextStyles.titleSmall.copyWith(
                              color: hasShare
                                  ? AvatarColors.get(friend.colorIndex)
                                  : AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (!allItemsAssigned) ...[
                const SizedBox(height: 10),
                Text(
                  '$unassignedCount ${unassignedCount == 1 ? 'item' : 'items'} still need assignment',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: allItemsAssigned ? onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        allItemsAssigned ? AppColors.accent : AppColors.border,
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
