import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:split/models/group_model.dart';

class GroupService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createGroup(GroupModel group) async {
    final data = group.toJson();
    data.remove('id'); // Remove id from data as Firestore uses doc ID
    await _firestore.collection('groups').doc(group.id).set(data);
    notifyListeners();
  }

  Stream<List<GroupModel>> getUserGroups(String userId) {
    return _firestore
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GroupModel.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  Future<GroupModel?> getGroupById(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (doc.exists) {
      return GroupModel.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> addMemberToGroup(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
    notifyListeners();
  }

  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
    });
    notifyListeners();
  }

  Future<void> closeGroup(String groupId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'isClosed': true,
      'closedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  Future<void> deleteGroup(String groupId) async {
    await _firestore.collection('groups').doc(groupId).delete();
    notifyListeners();
  }
}
