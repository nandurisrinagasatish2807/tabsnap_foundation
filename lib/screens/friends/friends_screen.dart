// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';
import '../../widgets/overall_balance_card.dart';
import '../../services/social_service.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

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
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Friends', style: AppTextStyles.displayMedium),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.qrScanner),
                        icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                      ),
                      IconButton(
                        onPressed: () => _showAddFriendSheet(context),
                        icon: const Icon(Icons.person_add_outlined, color: AppColors.accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Overall balance card ───────────────────────────────
            // ── Overall balance card ───────────────────────────────
            OverallBalanceCard(userId: currentUser.uid),

            const SizedBox(height: 8),

            // ── Friends list ──────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .collection('activities')
                    .snapshots(),
                builder: (context, activitySnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('friends')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.accent),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return _EmptyFriendsState(
                          onAddFriend: () => _showAddFriendSheet(context),
                        );
                      }

                      final friends =
                          docs.map((d) => Friend.fromFirestore(d)).toList();

                      return ListView.separated(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: friends.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, i) => _FriendTile(
                          friend: friends[i],
                          currentUserId: currentUser.uid,
                        ),
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

  void _showAddFriendSheet(BuildContext context) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isTemp = true;

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
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a friend', style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text(
                'They don\'t need the app — add them as a contact.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Friend\'s name',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final uid = FirebaseAuth.instance.currentUser!.uid;
                    final friends = FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('friends');
                    final count = (await friends.get()).docs.length;
                    await friends.add({
                      'name': nameController.text.trim(),
                      'colorIndex': count % 8,
                      'isTemporary': isTemp,
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Add friend'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Friend friend;
  final String currentUserId;

  const _FriendTile({
    required this.friend,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('balances')
          .doc(friend.id)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final balance = (data?['netBalance'] as num?)?.toDouble() ?? 0.0;
        
        final isPositive = balance > 0;
        final isZero = balance.abs() < 0.01;

        return GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.friendDetail,
            arguments: friend,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(friend.fullName, style: AppTextStyles.titleSmall),
                      if (friend.isTemporary)
                        Text('Contact only', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: friend.status == 'pending_received'
                      ? [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  await SocialService.acceptFriendRequest(friend.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C853), // Emerald
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => SocialService.declineFriendRequest(friend.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF7F50), // Coral
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text('Decline', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ]
                      : friend.status == 'pending_sent'
                          ? [
                              Text(
                                'Pending',
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: AppColors.warning,
                                ),
                              ),
                            ]
                      : [
                          Text(
                            isZero
                                ? 'settled'
                                : '\$${balance.abs().toStringAsFixed(2)}',
                            style: AppTextStyles.titleSmall.copyWith(
                              color: isZero
                                  ? AppColors.textHint
                                  : isPositive
                                      ? AppColors.success
                                      : AppColors.danger,
                            ),
                          ),
                          if (!isZero)
                            Text(
                              isPositive ? 'owes you' : 'you owe',
                              style: AppTextStyles.bodySmall,
                            ),
                        ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: AppColors.textHint, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyFriendsState extends StatelessWidget {
  final VoidCallback onAddFriend;
  const _EmptyFriendsState({required this.onAddFriend});

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
              child: const Icon(Icons.people_outline,
                  color: AppColors.accent, size: 36),
            ),
            const SizedBox(height: 20),
            Text('No friends yet', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add friends to start splitting bills.\nThey don\'t need the app!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddFriend,
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Add your first friend'),
            ),
          ],
        ),
      ),
    );
  }
}
