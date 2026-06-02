import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class SocialService {
  SocialService._();

  static Future<void> addFriendFromQR(String scannedUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    if (currentUser.uid == scannedUid) throw Exception('Cannot add yourself');

    final db = FirebaseFirestore.instance;

    // Fetch target user 
    final targetUserDoc = await db.collection('users').doc(scannedUid).get();
    if (!targetUserDoc.exists) {
      throw Exception('User not found');
    }
    final targetUser = UserModel.fromFirestore(targetUserDoc);

    // Fetch current user details
    final currentUserDoc = await db.collection('users').doc(currentUser.uid).get();
    if (!currentUserDoc.exists) {
      throw Exception('Current user profile not found');
    }
    final currentProfile = UserModel.fromFirestore(currentUserDoc);

    final batch = db.batch();

    // 1. Add to scanner's friend list (pending_sent)
    final scannerFriendRef = db
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .doc(scannedUid);
    
    batch.set(scannerFriendRef, {
      'name': targetUser.fullName,
      'email': targetUser.email,
      'handle': targetUser.handle,
      'colorIndex': Random().nextInt(8),
      'isTemporary': false,
      'status': 'pending_sent',
    });

    final myData = currentUserDoc.data() ?? {};
    String? rawName = myData['fullName'] as String? ?? myData['name'] as String?;
    if (rawName != null && rawName.trim().isEmpty) rawName = null;
    
    final myName = rawName ?? 
                   currentUser.email?.split('@')[0] ?? 
                   'TabSnap User';

    // 2. Add to target's friend list (pending_received)
    final targetFriendRef = db
        .collection('users')
        .doc(scannedUid)
        .collection('friends')
        .doc(currentUser.uid);
    
    batch.set(targetFriendRef, {
      'name': myName,
      'email': currentProfile.email,
      'handle': currentProfile.handle,
      'colorIndex': Random().nextInt(8),
      'isTemporary': false,
      'status': 'pending_received',
    });

    await batch.commit();
  }

  static Future<void> acceptFriendRequest(String friendUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    final myRef = db.collection('users').doc(currentUser.uid).collection('friends').doc(friendUid);
    final theirRef = db.collection('users').doc(friendUid).collection('friends').doc(currentUser.uid);

    batch.update(myRef, {'status': 'accepted'});
    batch.update(theirRef, {'status': 'accepted'});

    await batch.commit();
  }

  static Future<void> declineFriendRequest(String friendUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    final myRef = db.collection('users').doc(currentUser.uid).collection('friends').doc(friendUid);
    final theirRef = db.collection('users').doc(friendUid).collection('friends').doc(currentUser.uid);

    batch.delete(myRef);
    batch.delete(theirRef);

    await batch.commit();
  }

  static Future<void> settleUpBilateral({
    required String groupId,
    required String targetId,
    required double amount,
    required String friendName,
    required List<String> groupMemberIds,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final now = DateTime.now();

    // The current user is paying the target
    final fromId = currentUser.uid;
    final toId = targetId;

    // Write settlement document for current user
    final mySettlementRef = db
        .collection('users')
        .doc(fromId)
        .collection('settlements')
        .doc();

    batch.set(mySettlementRef, {
      'fromId': fromId,
      'toId': toId,
      'amount': amount,
      'method': 'Settle Up',
      'groupId': groupId,
      'createdAt': now,
    });

    // Write settlement document for target user
    final targetSettlementRef = db
        .collection('users')
        .doc(toId)
        .collection('settlements')
        .doc(mySettlementRef.id);

    batch.set(targetSettlementRef, {
      'fromId': fromId,
      'toId': toId,
      'amount': amount,
      'method': 'Settle Up',
      'groupId': groupId,
      'createdAt': now,
    });

    // Log to group activity feed
    final activityRef = db
        .collection('groups')
        .doc(groupId)
        .collection('activities')
        .doc();

    batch.set(activityRef, {
      'type': 'settlement',
      'description': 'Settled \$${amount.toStringAsFixed(2)} with $friendName',
      'amount': amount,
      'groupId': groupId,
      'creatorId': fromId,
      'relatedId': mySettlementRef.id,
      'involvedUsers': groupMemberIds,
      'createdAt': now,
    });

    await batch.commit();
  }
}

