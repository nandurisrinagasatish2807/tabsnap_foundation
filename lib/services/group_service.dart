import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class GroupService {
  GroupService._();

  static Future<Group?> getGroupById(String groupId) async {
    final doc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return Group.fromFirestore(doc);
  }

  static Future<String> createGroup({
    required String name,
    required String emoji,
    required List<String> memberIds,
    required String creatorId,
  }) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // 1. Create master document
    final groupRef = db.collection('groups').doc();
    batch.set(groupRef, {
      'name': name,
      'emoji': emoji,
      'memberIds': memberIds,
      'creator': creatorId,
      'notes': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Write reference stub for creator only (auth user may write own user doc)
    batch.set(
      db.collection('users').doc(creatorId).collection('groups').doc(groupRef.id),
      {'joinedAt': FieldValue.serverTimestamp()},
    );

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
      'creatorId': creatorId,
      'relatedId': groupRef.id,
      'involvedUsers': memberIds,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return groupRef.id;
  }
}
