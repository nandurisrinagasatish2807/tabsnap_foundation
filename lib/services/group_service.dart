import 'package:cloud_firestore/cloud_firestore.dart';

class GroupService {
  GroupService._();

  static Future<String> createGroup({
    required String name,
    required String emoji,
    required List<String> memberIds,
  }) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // 1. Create master document
    final groupRef = db.collection('groups').doc();
    batch.set(groupRef, {
      'name': name,
      'emoji': emoji,
      'memberIds': memberIds,
      'notes': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Write reference stub in /users/{memberId}/groups/{groupId}
    for (final memberId in memberIds) {
      final userGroupRef = db
          .collection('users')
          .doc(memberId)
          .collection('groups')
          .doc(groupRef.id);
      batch.set(userGroupRef, {
        'joinedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return groupRef.id;
  }
}
