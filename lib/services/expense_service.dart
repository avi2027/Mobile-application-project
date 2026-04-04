import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:split/models/expense_model.dart';

class ExpenseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createExpense(ExpenseModel expense) async {
    try {
      final data = expense.toJson();
      data.remove('id'); // Remove id from data as Firestore uses doc ID
      
      // Convert date to Timestamp for Firestore
      data['date'] = Timestamp.fromDate(expense.date);
      
      await _firestore.collection('expenses').doc(expense.id).set(data);
      debugPrint('Expense created successfully: ${expense.id}');
    notifyListeners();
    } catch (e) {
      debugPrint('Error creating expense: $e');
      rethrow;
    }
  }

  Stream<List<ExpenseModel>> getGroupExpenses(String groupId) {
    return _firestore
        .collection('expenses')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
      final expenses = snapshot.docs
          .map((doc) {
            try {
              return ExpenseModel.fromJson(doc.data(), doc.id);
            } catch (e) {
              debugPrint('Error parsing expense ${doc.id}: $e');
              return null;
            }
          })
          .whereType<ExpenseModel>()
          .toList();
      
      // Sort by date descending
      expenses.sort((a, b) => b.date.compareTo(a.date));
      return expenses;
    });
  }

  Stream<List<ExpenseModel>> getUserExpenses(String userId) {
    return _firestore
        .collection('expenses')
        .where('payerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final expenses = snapshot.docs
          .map((doc) {
            try {
              return ExpenseModel.fromJson(doc.data(), doc.id);
            } catch (e) {
              debugPrint('Error parsing expense ${doc.id}: $e');
              return null;
            }
          })
          .whereType<ExpenseModel>()
          .toList();
      
      // Sort by date descending
      expenses.sort((a, b) => b.date.compareTo(a.date));
      return expenses;
    });
  }

  Future<void> deleteExpense(String expenseId) async {
    await _firestore.collection('expenses').doc(expenseId).delete();
    notifyListeners();
  }
}
