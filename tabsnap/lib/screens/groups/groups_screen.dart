// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

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
              padding: const EdgeInsets.fromLTRB(
                  24, 24, 24, 0),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text('Groups',
                      style: AppTextStyles.displayMedium),
                  IconButton(
                    onPressed: () =>
                        _showCreateGroupSheet(
                            context, currentUser.uid),
                    icon: const Icon(
                        Icons.group_add_outlined,
                        color: AppColors.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .collection('groups')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent),
                    );
                  }
                  final docs =
                      snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _EmptyGroupsState(
                      onCreateGroup: () =>
                          _showCreateGroupSheet(context,
                              currentUser.uid),
                    );
                  }
                  final groups = docs
                      .map((d) => Group.fromFirestore(d))
                      .toList();
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _GroupTile(group: groups[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupSheet(
      BuildContext context, String userId) {
    final nameController = TextEditingController();
    String selectedEmoji = '🏠';
    final emojis = [
      '🏠', '✈️', '🍕', '🎉', '💼',
      '🎮', '🏋️', '🛒', '🎓', '❤️',
      '🌴', '🎵', '🏖️', '🍻', '🏡',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create group',
                  style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text(
                  'You can add members after creating.',
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: 20),

              // Emoji picker
              Text('Pick an emoji',
                  style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: emojis.map((emoji) {
                  final isSelected =
                      selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () => setModalState(
                        () => selectedEmoji = emoji),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent
                                .withValues(alpha: 0.15)
                            : AppColors.surfaceAlt,
                        borderRadius: AppRadius.sm,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(emoji,
                            style: const TextStyle(
                                fontSize: 22)),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              Text('Group name',
                  style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameController,
                textCapitalization:
                    TextCapitalization.words,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText:
                      'e.g. Apt 7777, Dallas Trip',
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name =
                        nameController.text.trim();
                    if (name.isEmpty) return;

                    // Create the group
                    final doc = await FirebaseFirestore
                        .instance
                        .collection('users')
                        .doc(userId)
                        .collection('groups')
                        .add({
                      'name': name,
                      'emoji': selectedEmoji,
                      'memberIds': [userId],
                      'notes': '',
                      'createdAt': DateTime.now(),
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      // Go straight to group detail
                      // so user can add members
                      final group = Group(
                        id: doc.id,
                        name: name,
                        emoji: selectedEmoji,
                        memberIds: [userId],
                        createdAt: DateTime.now(),
                      );
                      Navigator.pushNamed(
                        context,
                        AppRoutes.groupDetail,
                        arguments: group,
                      );
                    }
                  },
                  child: const Text('Create group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Group group;
  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.groupDetail,
        arguments: group,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent
                    .withValues(alpha: 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: Center(
                child: Text(group.emoji,
                    style:
                        const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: AppTextStyles.titleSmall),
                  Text(
                    '${group.memberIds.length} member${group.memberIds.length != 1 ? 's' : ''}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EmptyGroupsState extends StatelessWidget {
  final VoidCallback onCreateGroup;
  const _EmptyGroupsState(
      {required this.onCreateGroup});

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
                color:
                    AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_outlined,
                  color: AppColors.accent, size: 36),
            ),
            const SizedBox(height: 20),
            Text('No groups yet',
                style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Create a group for roommates,\ntrips, or regular hangouts.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateGroup,
              icon: const Icon(
                  Icons.group_add_outlined,
                  size: 18),
              label: const Text('Create a group'),
            ),
          ],
        ),
      ),
    );
  }
}
