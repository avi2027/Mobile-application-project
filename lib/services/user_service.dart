import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:split/models/user_model.dart';

class UserService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser(UserModel user) async {
    final data = user.toJson();
    data.remove('id'); // Remove id from data as Firestore uses doc ID
    await _firestore.collection('users').doc(user.id).set(data);
    notifyListeners();
  }

  Future<UserModel?> getUserById(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserModel.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    });
  }

  Future<List<UserModel>> searchUsersByEmail(String emailQuery) async {
    if (emailQuery.isEmpty) return [];
    
    final snapshot = await _firestore
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: emailQuery)
        .where('email', isLessThanOrEqualTo: '$emailQuery\uf8ff')
        .limit(10)
        .get();
    
    return snapshot.docs
        .map((doc) => UserModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<void> updateUser(UserModel user) async {
    final data = user.toJson();
    data.remove('id'); // Remove id from data as Firestore uses doc ID
    await _firestore.collection('users').doc(user.id).update(data);
    notifyListeners();
  }
}

