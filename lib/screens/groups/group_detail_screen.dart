// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupDetailScreen> createState() =>
      _GroupDetailScreenState();
}

class _GroupDetailScreenState
    extends State<GroupDetailScreen> {
  final Map<String, String> _nameCache = {};
  final Map<String, int> _colorCache = {};
  Map<String, double>? _netBalances;
  bool _balancesLoading = true;
  String _groupNotes = '';
  late Group _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _loadEverything();
  }

  Future<void> _loadEverything() async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    // Load self
    final selfDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    _nameCache[uid] =
        (selfDoc.data()?['name'] as String?) ?? 'Me';
    _colorCache[uid] = 0;

    // Load friends
    final friendsSnap = await FirebaseFirestore
        .instance
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

    // Reload group from Firestore to get latest data
    final groupDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('groups')
        .doc(_group.id)
        .get();

    if (groupDoc.exists) {
      final data = groupDoc.data()!;
      _groupNotes = data['notes'] as String? ?? '';
      _group = Group.fromFirestore(groupDoc);
    }

    final balances =
        await _calculateNetBalances(uid);

    if (mounted) {
      setState(() {
        _netBalances = balances;
        _balancesLoading = false;
      });
    }
  }

  Future<Map<String, double>> _calculateNetBalances(
      String uid) async {
    final raw = <String, double>{};

    final expenses = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .where('groupId', isEqualTo: _group.id)
        .get();

    for (final doc in expenses.docs) {
      final data = doc.data();
      final splits = Map<String, dynamic>.from(
          data['splits'] ?? {});
      final paidBy =
          data['paidById'] as String? ?? '';

      splits.forEach((memberId, amount) {
        if (memberId == uid) return;
        final amt = (amount as num).toDouble();
        if (paidBy == uid) {
          raw[memberId] =
              (raw[memberId] ?? 0) + amt;
        }
      });

      if (paidBy != uid &&
          splits.containsKey(uid)) {
        final myShare =
            (splits[uid] as num).toDouble();
        raw[paidBy] = (raw[paidBy] ?? 0) - myShare;
      }
    }

    final settlements = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid)
        .collection('settlements')
        .where('groupId', isEqualTo: _group.id)
        .get();

    for (final doc in settlements.docs) {
      final data = doc.data();
      final fromId =
          data['fromId'] as String? ?? '';
      final toId = data['toId'] as String? ?? '';
      final amt = (data['amount'] as num).toDouble();
      if (fromId == uid) {
        raw[toId] = (raw[toId] ?? 0) + amt;
      } else if (toId == uid) {
        raw[fromId] = (raw[fromId] ?? 0) - amt;
      }
    }

    raw.removeWhere((_, v) => v.abs() < 0.01);
    return raw;
  }

  String _nameFor(String uid) =>
      _nameCache[uid] ?? uid.substring(0, 6);
  int _colorFor(String uid) =>
      _colorCache[uid] ?? 0;

  void _startExpense() {
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    final friends = _group.memberIds
        .where((id) => id != currentUid)
        .map((id) => Friend(
              id: id,
              name: _nameFor(id),
              colorIndex: _colorFor(id),
              isTemporary: false,
            ))
        .toList();

    Navigator.pushNamed(
      context,
      AppRoutes.camera,
      arguments: {
        'friends': friends,
        'groupId': _group.id,
      },
    );
  }

  void _showAddMemberSheet() {
    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      builder: (context) =>
          _AddMemberSheet(
        groupId: _group.id,
        currentUserId: uid,
        existingMemberIds: _group.memberIds,
        onMemberAdded: () {
          _loadEverything();
        },
      ),
    );
  }

  void _showNotesSheet() {
    final controller =
        TextEditingController(text: _groupNotes);
    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group notes',
                style: AppTextStyles.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText:
                    'Add notes for the group...',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('groups')
                      .doc(_group.id)
                      .update({
                    'notes': controller.text.trim()
                  });
                  setState(() => _groupNotes =
                      controller.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save notes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    final memberCount = _group.memberIds.length;
    final netBalances = _netBalances ?? {};
    final netTotal = netBalances.values
        .fold(0.0, (acc, v) => acc + v);
    final isSettled = netTotal.abs() < 0.01;
    final iOweOverall = netTotal < 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, inner) => [
          // ── Splitwise-style group header ───────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings,
                    color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary
                          .withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 50, 20, 12),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisAlignment:
                          MainAxisAlignment.end,
                      children: [
                        // Group name
                        Row(
                          children: [
                            Text(
                              _group.emoji,
                              style: const TextStyle(
                                  fontSize: 28),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _group.name,
                                style: AppTextStyles
                                    .displayMedium
                                    .copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Action chips
                        Row(
                          children: [
                            _HeaderChip(
                              icon: Icons
                                  .calendar_today_outlined,
                              label:
                                  'Add settle-up date',
                              onTap: () {},
                            ),
                            const SizedBox(width: 8),
                            _HeaderChip(
                              icon: Icons.people_outline,
                              label:
                                  '$memberCount ${memberCount == 1 ? 'person' : 'people'}',
                              onTap: _showAddMemberSheet,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _HeaderChip(
                          icon: Icons.edit_outlined,
                          label: _groupNotes.isEmpty
                              ? 'Add group notes...'
                              : _groupNotes,
                          onTap: _showNotesSheet,
                          maxWidth: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // ── Balance summary ──────────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(
                  20, 16, 20, 4),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (_balancesLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: 8),
                      child: CircularProgressIndicator(
                          color: AppColors.accent),
                    )
                  else if (isSettled)
                    Row(
                      children: [
                        const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 18),
                        const SizedBox(width: 8),
                        Text(
                            'You are all settled up!',
                            style: AppTextStyles
                                .titleSmall
                                .copyWith(
                              color: AppColors.success,
                            )),
                      ],
                    )
                  else ...[
                    // Overall line
                    Text(
                      iOweOverall
                          ? 'You owe \$${netTotal.abs().toStringAsFixed(2)} overall'
                          : 'You are owed \$${netTotal.abs().toStringAsFixed(2)} overall',
                      style: AppTextStyles.bodyLarge
                          .copyWith(
                        color: iOweOverall
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Individual lines
                    ...netBalances.entries.map((e) {
                      final owesMe = e.value > 0;
                      final name = _nameFor(e.key);
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: 6),
                        child: Row(
                          children: [
                            _MiniAvatar(
                              name: name,
                              colorIdx:
                                  _colorFor(e.key),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                owesMe
                                    ? '$name owes you \$${e.value.abs().toStringAsFixed(2)}'
                                    : 'You owe $name \$${e.value.abs().toStringAsFixed(2)}',
                                style: AppTextStyles
                                    .bodyMedium,
                              ),
                            ),
                            // Question mark / help icon
                            const Icon(
                              Icons.help_outline,
                              size: 16,
                              color: AppColors.textHint,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ── Horizontal action bar ────────────────
            Container(
              color: AppColors.surface,
              child: Column(
                children: [
                  const Divider(height: 1),
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10),
                      children: [
                        _ActionChip(
                          label: 'Settle up',
                          onTap: () {
                            // settle with first person
                            if (netBalances
                                .isNotEmpty) {
                              final first = netBalances
                                  .entries.first;
                              Navigator.pushNamed(
                                context,
                                AppRoutes.settleUp,
                                arguments: {
                                  'groupId': _group.id,
                                  'targetFriendId':
                                      first.key,
                                  'friendName':
                                      _nameFor(
                                          first.key),
                                  'amount':
                                      first.value,
                                },
                              );
                            }
                          },
                          isPrimary: true,
                        ),
                        const SizedBox(width: 8),
                        _ActionChip(
                            label: 'Charts',
                            onTap: () {}),
                        const SizedBox(width: 8),
                        _ActionChip(
                            label: 'Balances',
                            onTap: () {}),
                        const SizedBox(width: 8),
                        _ActionChip(
                            label: 'Totals',
                            onTap: () {}),
                        const SizedBox(width: 8),
                        _ActionChip(
                            label: 'Whiteboard',
                            onTap: () {}),
                        const SizedBox(width: 8),
                        _ActionChip(
                            label: 'Export',
                            onTap: () {}),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),

            // ── Activity feed ────────────────────────
            Expanded(
              child: _SectionedFeed(
                group: _group,
                currentUid: uid,
                nameFor: _nameFor,
                colorFor: _colorFor,
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startExpense,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.receipt_long_outlined,
            color: Colors.white),
        label: const Text('Add expense',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ─── Add Member Sheet ─────────────────────────────────────────────────────────

class _AddMemberSheet extends StatefulWidget {
  final String groupId;
  final String currentUserId;
  final List<String> existingMemberIds;
  final VoidCallback onMemberAdded;

  const _AddMemberSheet({
    required this.groupId,
    required this.currentUserId,
    required this.existingMemberIds,
    required this.onMemberAdded,
  });

  @override
  State<_AddMemberSheet> createState() =>
      _AddMemberSheetState();
}

class _AddMemberSheetState
    extends State<_AddMemberSheet> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addMember(
      String friendId, String friendName) async {
    // Add to group's memberIds
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('groups')
        .doc(widget.groupId)
        .update({
      'memberIds': FieldValue.arrayUnion([friendId]),
    });
    widget.onMemberAdded();
  }

  Future<void> _addTempMember(String name) async {
    if (name.trim().isEmpty) return;

    // Create as friend first
    final friendsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('friends');

    final count = (await friendsRef.get()).docs.length;
    final doc = await friendsRef.add({
      'name': name.trim(),
      'colorIndex': count % 8,
      'isTemporary': true,
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('groups')
        .doc(widget.groupId)
        .update({
      'memberIds': FieldValue.arrayUnion([doc.id]),
    });

    widget.onMemberAdded();
    _nameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 24, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add members',
              style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
              'Add from your friends or add someone new.',
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 20),

          // Existing friends not in group
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.currentUserId)
                .collection('friends')
                .snapshots(),
            builder: (context, snapshot) {
              final docs =
                  snapshot.data?.docs ?? [];
              final available = docs.where((d) =>
                  !widget.existingMemberIds
                      .contains(d.id));

              if (available.isNotEmpty) {
                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text('Your friends',
                        style:
                            AppTextStyles.titleSmall),
                    const SizedBox(height: 8),
                    ...available.map((doc) {
                      final data = doc.data()
                          as Map<String, dynamic>;
                      final name =
                          data['name'] as String? ??
                              'Unknown';
                      final colorIdx =
                          (data['colorIndex'] as int? ??
                              0);
                      final initials = name
                          .trim()
                          .split(' ')
                          .where((w) => w.isNotEmpty)
                          .map((w) =>
                              w[0].toUpperCase())
                          .take(2)
                          .join();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              AvatarColors.background(
                                  colorIdx),
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AvatarColors.get(
                                  colorIdx),
                            ),
                          ),
                        ),
                        title: Text(name,
                            style: AppTextStyles
                                .titleSmall),
                        trailing: TextButton(
                          onPressed: () =>
                              _addMember(doc.id, name),
                          child: Text('Add',
                              style: TextStyle(
                                  color:
                                      AppColors.accent)),
                        ),
                      );
                    }),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Add someone new
          Text('Add someone new',
              style: AppTextStyles.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Their name',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _addTempMember(
                    _nameController.text),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done adding members'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sectioned Feed ───────────────────────────────────────────────────────────

class _SectionedFeed extends StatelessWidget {
  final Group group;
  final String currentUid;
  final String Function(String) nameFor;
  final int Function(String) colorFor;

  const _SectionedFeed({
    required this.group,
    required this.currentUid,
    required this.nameFor,
    required this.colorFor,
  });

  String _monthKey(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('expenses')
          .where('groupId', isEqualTo: group.id)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.accent),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(group.emoji,
                      style: const TextStyle(
                          fontSize: 48)),
                  const SizedBox(height: 16),
                  Text('No expenses yet',
                      style:
                          AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Add expense" to get started.',
                    style:
                        AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final expenses = docs
            .map((d) => Expense.fromFirestore(d))
            .toList();

        // Group by month/year
        final grouped = <String, List<Expense>>{};
        for (final e in expenses) {
          final key = _monthKey(e.createdAt);
          grouped.putIfAbsent(key, () => []);
          grouped[key]!.add(e);
        }

        // Flatten to list
        final items = <dynamic>[];
        grouped.forEach((key, list) {
          items.add(key);
          items.addAll(list);
        });

        return ListView.builder(
          padding:
              const EdgeInsets.only(bottom: 120),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];

            if (item is String) {
              return Container(
                padding: const EdgeInsets.fromLTRB(
                    16, 16, 16, 6),
                color: AppColors.background,
                child: Text(
                  item,
                  style: AppTextStyles.labelMedium
                      .copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            if (item is Expense) {
              return _ExpenseTile(
                expense: item,
                currentUid: currentUid,
                nameFor: nameFor,
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}

// ─── Expense Tile ─────────────────────────────────────────────────────────────

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final String currentUid;
  final String Function(String) nameFor;

  const _ExpenseTile({
    required this.expense,
    required this.currentUid,
    required this.nameFor,
  });

  IconData _iconFor(String? category, String title) {
    final t = (category ?? title).toLowerCase();
    if (t.contains('grocery') ||
        t.contains('groceries') ||
        t.contains('walmart') ||
        t.contains('costco') ||
        t.contains('heb') ||
        t.contains('kroger')) {
      return Icons.shopping_cart_outlined;
    }
    if (t.contains('restaurant') ||
        t.contains('pizza') ||
        t.contains('dinner') ||
        t.contains('lunch') ||
        t.contains('cafe') ||
        t.contains('sushi') ||
        t.contains('biryani')) {
      return Icons.restaurant_outlined;
    }
    if (t.contains('uber') ||
        t.contains('lyft') ||
        t.contains('gas') ||
        t.contains('parking')) {
      return Icons.directions_car_outlined;
    }
    if (t.contains('electricity') ||
        t.contains('wifi') ||
        t.contains('internet') ||
        t.contains('electric')) {
      return Icons.bolt_outlined;
    }
    if (t.contains('rent') || t.contains('apartment')) {
      return Icons.home_outlined;
    }
    if (t.contains('flight') ||
        t.contains('hotel') ||
        t.contains('airbnb')) {
      return Icons.flight_outlined;
    }
    if (t.contains('movie') ||
        t.contains('concert')) {
      return Icons.movie_outlined;
    }
    return Icons.receipt_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final paidByMe = expense.paidById == currentUid;
    final myShare =
        expense.splits[currentUid] ?? 0.0;
    final paidByName = paidByMe
        ? 'You'
        : nameFor(expense.paidById);

    const shortMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month =
        shortMonths[expense.createdAt.month - 1];
    final day = expense.createdAt.day.toString();

    // Check if current user is involved
    final isInvolved = expense.splits
            .containsKey(currentUid) ||
        paidByMe;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 2),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        child: InkWell(
          borderRadius: AppRadius.md,
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.expenseDetail,
            arguments: expense.id,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center,
              children: [
                // Date
                SizedBox(
                  width: 32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        month,
                        style: AppTextStyles.bodySmall
                            .copyWith(fontSize: 10),
                      ),
                      Text(
                        day,
                        style: AppTextStyles.titleSmall
                            .copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Category icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: AppRadius.sm,
                    border: Border.all(
                        color: AppColors.border),
                  ),
                  child: Icon(
                    _iconFor(
                        expense.category,
                        expense.title),
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(width: 10),

                // Title + who paid
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style:
                            AppTextStyles.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$paidByName paid \$${expense.total.toStringAsFixed(2)}',
                        style:
                            AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Your share / not involved
                if (!isInvolved)
                  Text(
                    'not involved',
                    style: AppTextStyles.bodySmall
                        .copyWith(
                      color: AppColors.textHint,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Text(
                        paidByMe
                            ? 'you lent'
                            : 'you borrowed',
                        style: AppTextStyles.bodySmall
                            .copyWith(fontSize: 10),
                      ),
                      Text(
                        '\$${myShare.toStringAsFixed(2)}',
                        style: AppTextStyles.titleSmall
                            .copyWith(
                          color: paidByMe
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Small helpers ────────────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final String name;
  final int colorIdx;
  const _MiniAvatar(
      {required this.name, required this.colorIdx});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AvatarColors.background(colorIdx),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AvatarColors.get(colorIdx),
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool maxWidth;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.maxWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: AppRadius.pill,
          border: Border.all(
              color:
                  Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: maxWidth
              ? MainAxisSize.max
              : MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.bodySmall
                    .copyWith(
                  color: Colors.white,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionChip({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.accent
              : AppColors.surface,
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: isPrimary
                ? AppColors.accent
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isPrimary
                ? Colors.white
                : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
