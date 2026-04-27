import 'package:cloud_firestore/cloud_firestore.dart';

class BalanceService {
  BalanceService._();

  static Future<void> updateBalancesForExpense(
    String currentUid,
    String paidById,
    Map<String, double> splits,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    
    if (paidById == currentUid || paidById == 'me') {
      // I paid. Others owe me.
      for (final entry in splits.entries) {
        final friendId = entry.key;
        if (friendId == currentUid || friendId == 'me') continue;
        
        final amount = entry.value;
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('balances')
            .doc(friendId);
            
        batch.set(ref, {
          'netBalance': FieldValue.increment(amount),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } else {
      // Someone else paid. I owe them my share.
      final myShare = splits[currentUid] ?? splits['me'] ?? 0.0;
      if (myShare > 0) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('balances')
            .doc(paidById);
            
        batch.set(ref, {
          'netBalance': FieldValue.increment(-myShare),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    
    await batch.commit();
  }

  static Future<void> updateBalancesForSettlement(
    String currentUid,
    String fromId,
    String toId,
    double amount,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    
    if (currentUid == fromId || fromId == 'me') {
      // I paid them. My balance with them goes up (I owe them less).
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('balances')
          .doc(toId);
          
      batch.set(ref, {
        'netBalance': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else if (currentUid == toId || toId == 'me') {
      // They paid me. My balance with them goes down (they owe me less).
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('balances')
          .doc(fromId);
          
      batch.set(ref, {
        'netBalance': FieldValue.increment(-amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    
    await batch.commit();
  }
}
