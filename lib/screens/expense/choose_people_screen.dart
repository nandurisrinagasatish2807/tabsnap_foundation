// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';

class ChoosePeopleScreen extends StatefulWidget {
  final String? groupId; // ← Added this
  final bool isManual;

  const ChoosePeopleScreen({
    super.key,
    this.groupId, // ← Added this to catch the ID
    this.isManual = false,
  });

  @override
  State<ChoosePeopleScreen> createState() => _ChoosePeopleScreenState();
}

class _ChoosePeopleScreenState extends State<ChoosePeopleScreen> {
  final List<Friend> _selected = [];
  final _tempNameController = TextEditingController();

  @override
  void dispose() {
    _tempNameController.dispose();
    super.dispose();
  }

  void _toggleFriend(Friend friend) {
    setState(() {
      if (_selected.any((f) => f.id == friend.id)) {
        _selected.removeWhere((f) => f.id == friend.id);
      } else {
        _selected.add(friend);
      }
    });
  }

  bool _isSelected(String friendId) => _selected.any((f) => f.id == friendId);

  void _addTemporary() {
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
            Text('Add someone', style: AppTextStyles.titleLarge),
            const SizedBox(height: 4),
            Text(
              'They don\'t need the app to be added.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _tempNameController,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Their name',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final name = _tempNameController.text.trim();
                  if (name.isEmpty) return;

                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  final friendsRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('friends');

                  final count = (await friendsRef.get()).docs.length;
                  final doc = await friendsRef.add({
                    'name': name,
                    'colorIndex': count % 8,
                    'isTemporary': true,
                  });

                  final newFriend = Friend(
                    id: doc.id,
                    name: name,
                    colorIndex: count % 8,
                    isTemporary: true,
                  );

                  setState(() {
                    _selected.add(newFriend);
                  });

                  _tempNameController.clear();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Add & select'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goNext() {
    if (_selected.isEmpty) return;

    if (widget.isManual) {
      Navigator.pushNamed(
        context,
        AppRoutes.reviewItems,
        arguments: {
          'items': <ReceiptItem>[],
          'friends': _selected,
          'groupId': widget.groupId,
        },
      );
    } else {
      // Passing the widget.groupId (the sticky note) to the camera
      Navigator.pushNamed(
        context,
        AppRoutes.camera,
        arguments: {
          'friends': _selected,
          'groupId': widget.groupId,
        },
      );
    }
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
        title: Text('Who\'s splitting?', style: AppTextStyles.titleMedium),
      ),
      body: Column(
        children: [
          if (_selected.isNotEmpty)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selected.length} selected',
                    style: AppTextStyles.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selected.map((f) {
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundColor:
                              AvatarColors.background(f.colorIndex),
                          child: Text(
                            f.initials,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AvatarColors.get(f.colorIndex),
                            ),
                          ),
                        ),
                        label: Text(f.name,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textPrimary)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _toggleFriend(f),
                        backgroundColor: AppColors.surfaceAlt,
                        side: BorderSide(color: AppColors.border),
                        padding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          if (_selected.isNotEmpty) const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('friends')
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final friends =
                    docs.map((d) => Friend.fromFirestore(d)).toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                          foregroundColor: AppColors.accent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                        ),
                        onPressed: _addTemporary,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text(
                          '+ Add Guest (No App Needed)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    if (friends.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('Your friends',
                            style: AppTextStyles.labelMedium),
                      ),
                    ...friends.map((friend) => _FriendSelectTile(
                          friend: friend,
                          isSelected: _isSelected(friend.id),
                          onTap: () => _toggleFriend(friend),
                        )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: _selected.isEmpty ? null : _goNext,
            style: ElevatedButton.styleFrom(
              // FIX: Move the logic outside or use a simple conditional
              backgroundColor:
                  _selected.isEmpty ? AppColors.border : AppColors.accent,
              foregroundColor:
                  Colors.white, // Ensures text is white when active
            ),
            child: Text(
              _selected.isEmpty
                  ? 'Select people to continue'
                  : widget.isManual
                      ? 'Next — add items'
                      : 'Next — scan receipt',
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Friend Select Tile ───────────────────────────────────────────────────────

class _FriendSelectTile extends StatelessWidget {
  final Friend friend;
  final bool isSelected;
  final VoidCallback onTap;

  const _FriendSelectTile({
    required this.friend,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? AvatarColors.get(friend.colorIndex)
                  : AvatarColors.background(friend.colorIndex),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                friend.initials,
                style: AppTextStyles.titleSmall.copyWith(
                  color: isSelected
                      ? Colors.white
                      : AvatarColors.get(friend.colorIndex),
                ),
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 10),
              ),
            ),
        ],
      ),
      title: Text(friend.name, style: AppTextStyles.titleSmall),
      subtitle: friend.isTemporary
          ? Text('Contact only', style: AppTextStyles.bodySmall)
          : null,
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.accent, size: 22)
          : const Icon(Icons.radio_button_unchecked,
              color: AppColors.textHint, size: 22),
    );
  }
}
