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

    // 3. Log group creation activity
    final activityRef = db
        .collection('groups')
        .doc(groupRef.id)
        .collection('activities')
        .doc();

    batch.set(activityRef, {
      'type': 'groupCreated',
      'description': 'Group "$name" was created',
      'groupId': groupRef.id,
      'creatorId': memberIds.first,
      'relatedId': groupRef.id,
      'involvedUsers': memberIds,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return groupRef.id;
  }
}
