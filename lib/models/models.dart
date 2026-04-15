import 'package:cloud_firestore/cloud_firestore.dart';

// ─── User ────────────────────────────────────────────────────────────────────

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String handle;
  final String? qrValue;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.handle,
    this.qrValue,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      fullName: d['fullName'] ?? '',
      email: d['email'] ?? '',
      handle: d['handle'] ?? '',
      qrValue: d['qrValue'],
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'fullName': fullName,
        'email': email,
        'handle': handle,
        'qrValue': qrValue,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  UserModel copyWith({
    String? fullName,
    String? email,
    String? handle,
    String? qrValue,
  }) =>
      UserModel(
        uid: uid,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        handle: handle ?? this.handle,
        qrValue: qrValue ?? this.qrValue,
        createdAt: createdAt,
      );
}

// ─── Friend ───────────────────────────────────────────────────────────────────

class Friend {
  final String id;
  final String name;
  final String? email;
  final int colorIndex;
  final bool isTemporary; // No app account needed
  final String? handle;
  final String? photoUrl;
  final String status;

  const Friend({
    required this.id,
    required this.name,
    this.email,
    required this.colorIndex,
    this.isTemporary = false,
    this.handle,
    this.photoUrl,
    this.status = 'accepted',
  });

  factory Friend.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Friend(
      id: doc.id,
      name: d['name'] ?? '',
      email: d['email'],
      colorIndex: d['colorIndex'] ?? 0,
      isTemporary: d['isTemporary'] ?? false,
      handle: d['handle'],
      photoUrl: d['photoUrl'],
      status: d['status'] ?? 'accepted',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'email': email,
        'colorIndex': colorIndex,
        'isTemporary': isTemporary,
        'handle': handle,
        'photoUrl': photoUrl,
        'status': status,
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── Group ────────────────────────────────────────────────────────────────────

class Group {
  final String id;
  final String name;
  final String emoji;
  final List<String> memberIds;
  final DateTime createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.emoji,
    required this.memberIds,
    required this.createdAt,
  });

  factory Group.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: d['name'] ?? '',
      emoji: d['emoji'] ?? '👥',
      memberIds: List<String>.from(d['memberIds'] ?? []),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'emoji': emoji,
        'memberIds': memberIds,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ─── Receipt Item ─────────────────────────────────────────────────────────────

class ReceiptItem {
  final String id;
  final String name;
  final double price;
  List<String> assignedTo; // friend IDs

  ReceiptItem({
    required this.id,
    required this.name,
    required this.price,
    List<String>? assignedTo,
  }) : assignedTo = assignedTo ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'assignedTo': assignedTo,
      };

  factory ReceiptItem.fromMap(Map<String, dynamic> m) => ReceiptItem(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        price: (m['price'] as num).toDouble(),
        assignedTo: List<String>.from(m['assignedTo'] ?? []),
      );

  // Each person's share for this item
  double shareFor(String friendId) {
    if (!assignedTo.contains(friendId) || assignedTo.isEmpty) return 0;
    return price / assignedTo.length;
  }
}

// ─── Expense ──────────────────────────────────────────────────────────────────

class Expense {
  final String id;
  final String title;
  final double total;
  final String paidById; // who paid the bill
  final List<ReceiptItem> items;
  final Map<String, double> splits; // friendId → amount owed
  final String? groupId;
  final String? category;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.title,
    required this.total,
    required this.paidById,
    required this.items,
    required this.splits,
    this.groupId,
    this.category,
    required this.createdAt,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      title: d['title'] ?? '',
      total: (d['total'] as num).toDouble(),
      paidById: d['paidById'] ?? '',
      items: (d['items'] as List<dynamic>? ?? [])
          .map((i) => ReceiptItem.fromMap(i as Map<String, dynamic>))
          .toList(),
      splits: Map<String, double>.from(
        (d['splits'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
      ),
      groupId: d['groupId'],
      category: d['category'],
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'total': total,
        'paidById': paidById,
        'items': items.map((i) => i.toMap()).toList(),
        'splits': splits,
        'groupId': groupId,
        'category': category,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ─── Settlement ───────────────────────────────────────────────────────────────

class Settlement {
  final String id;
  final String fromId; // who paid
  final String toId;   // who received
  final double amount;
  final String method; // Venmo, Zelle, Cash, etc.
  final String? note;
  final DateTime createdAt;

  const Settlement({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.amount,
    required this.method,
    this.note,
    required this.createdAt,
  });

  factory Settlement.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Settlement(
      id: doc.id,
      fromId: d['fromId'] ?? '',
      toId: d['toId'] ?? '',
      amount: (d['amount'] as num).toDouble(),
      method: d['method'] ?? 'Cash',
      note: d['note'],
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'fromId': fromId,
        'toId': toId,
        'amount': amount,
        'method': method,
        'note': note,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ─── Activity ─────────────────────────────────────────────────────────────────

enum ActivityType { expense, settlement, friendAdded, groupCreated }

class Activity {
  final String id;
  final ActivityType type;
  final String description;
  final double? amount;
  final String? groupId;
  final String? creatorId;
  final String? relatedId;
  final List<String> involvedUsers;
  final DateTime createdAt;

  const Activity({
    required this.id,
    required this.type,
    required this.description,
    this.amount,
    this.groupId,
    this.creatorId,
    this.relatedId,
    this.involvedUsers = const [],
    required this.createdAt,
  });

  factory Activity.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Activity(
      id: doc.id,
      type: ActivityType.values.firstWhere(
        (e) => e.name == d['type'],
        orElse: () => ActivityType.expense,
      ),
      description: d['description'] ?? '',
      amount: d['amount'] != null ? (d['amount'] as num).toDouble() : null,
      groupId: d['groupId'],
      creatorId: d['creatorId'],
      relatedId: d['relatedId'],
      involvedUsers: List<String>.from(d['involvedUsers'] ?? []),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.name,
        'description': description,
        'amount': amount,
        'groupId': groupId,
        'creatorId': creatorId,
        'relatedId': relatedId,
        'involvedUsers': involvedUsers,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
