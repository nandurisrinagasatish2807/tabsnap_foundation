import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';
import '../../services/group_service.dart';
import '../../router/app_router.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  int _currentStep = 0;
  final _nameController = TextEditingController();
  String _selectedEmoji = '🏠';
  final Set<String> _selectedFriendIds = {};
  bool _isSaving = false;

  final emojis = [
    '🏠',
    '✈️',
    '🍕',
    '🎉',
    '💼',
    '🎮',
    '🏋️',
    '🛒',
    '🎓',
    '❤️',
    '🌴',
    '🎵',
    '🏖️',
    '🍻',
    '🏡'
  ];

  void _nextStep() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a group name')));
        return;
      }
      setState(() => _currentStep = 1);
    } else {
      _createGroup();
    }
  }

  void _prevStep() {
    setState(() => _currentStep = 0);
  }

  Future<void> _createGroup() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final memberIds = [currentUser.uid, ..._selectedFriendIds];
    final groupName = _nameController.text.trim();

    try {
      final groupId = await GroupService.createGroup(
        name: groupName,
        emoji: _selectedEmoji,
        memberIds: memberIds,
      );

      HapticFeedback.mediumImpact();

      if (!mounted) return;

      final group = Group(
        id: groupId,
        name: groupName,
        emoji: _selectedEmoji,
        memberIds: memberIds,
        createdAt: DateTime.now(),
      );

      Navigator.pushReplacementNamed(context, AppRoutes.groupDetail,
          arguments: groupId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _currentStep == 0 ? _buildStep1() : _buildStep2(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 1 of 2: Group Details',
              style: AppTextStyles.titleMedium),
          const SizedBox(height: 24),
          const Text('Pick an emoji', style: AppTextStyles.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: emojis.map((emoji) {
              final isSelected = _selectedEmoji == emoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmoji = emoji),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.surfaceAlt,
                    borderRadius: AppRadius.sm,
                    border: Border.all(
                        color:
                            isSelected ? AppColors.accent : AppColors.border),
                  ),
                  child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 22))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Group name', style: AppTextStyles.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration:
                const InputDecoration(hintText: 'e.g. Apt 7777, Dallas Trip'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text('Step 2 of 2: Select Members',
              style: AppTextStyles.titleMedium),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('friends')
                .where('status', isEqualTo: 'accepted')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                    child: Text(
                        'No accepted friends found.\nAdd friends first!',
                        textAlign: TextAlign.center));
              }
              final friends = docs.map((d) => Friend.fromFirestore(d)).toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: friends.length,
                itemBuilder: (context, i) {
                  final f = friends[i];
                  final isSelected = _selectedFriendIds.contains(f.id);
                  return CheckboxListTile(
                    title: Text(f.fullName, style: AppTextStyles.titleSmall),
                    value: isSelected,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedFriendIds.add(f.id);
                        } else {
                          _selectedFriendIds.remove(f.id);
                        }
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep == 1)
            TextButton(
              onPressed: _prevStep,
              child: const Text('Back',
                  style: TextStyle(color: AppColors.primary)),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(120, 48),
            ),
            onPressed: _isSaving ? null : _nextStep,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(_currentStep == 0 ? 'Next' : 'Create Group',
                    style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
