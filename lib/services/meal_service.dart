import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:split/models/expense_model.dart';
import 'package:split/models/meal_model.dart';

class MealService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addMeal(MealModel meal) async {
    final data = meal.toJson();
    data.remove('id');
    await _firestore.collection('meals').doc(meal.id).set(data);
    notifyListeners();
  }

  Stream<List<MealModel>> getGroupMeals(String groupId) {
    return _firestore
        .collection('meals')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
      final meals = snapshot.docs
          .map((doc) => MealModel.fromJson(doc.data(), doc.id))
          .toList();
      // Sort in memory by date descending
      meals.sort((a, b) => b.date.compareTo(a.date));
      return meals;
    });
  }

  Stream<List<MealModel>> getUserMealsInGroup(String groupId, String userId) {
    return _firestore
        .collection('meals')
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final meals = snapshot.docs
          .map((doc) => MealModel.fromJson(doc.data(), doc.id))
          .toList();
      // Sort in memory by date descending
      meals.sort((a, b) => b.date.compareTo(a.date));
      return meals;
    });
  }

  Future<void> deleteMeal(String mealId) async {
    await _firestore.collection('meals').doc(mealId).delete();
    notifyListeners();
  }

  /// Calculate meal statistics for a group (monthly calculation)
  Future<MealStatistics> calculateMealStatistics(
    String groupId,
    List<MealModel> meals,
    List<ExpenseModel> expenses, {
    DateTime? selectedMonth,
  }) async {
    // Use current month if not specified
    final month = selectedMonth ?? DateTime.now();
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    // For daily meal service, ALL expenses in the month are considered as investment
    // Filter all expenses for the selected month (not just grocery)
    final monthlyExpenses = expenses.where((expense) {
      final expenseDate = expense.date;
      return expenseDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          expenseDate.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();

    // Filter meals for the selected month
    final monthlyMeals = meals.where((meal) {
      final mealDate = meal.date;
      return mealDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          mealDate.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();

    // Total investment = sum of ALL expenses in the month
    final totalInvestment = monthlyExpenses.fold<double>(
      0.0,
      (total, expense) => total + expense.amount,
    );

    // Count meals per user
    final mealCounts = <String, int>{};
    for (final meal in monthlyMeals) {
      mealCounts[meal.userId] = (mealCounts[meal.userId] ?? 0) + 1;
    }

    final totalMeals = monthlyMeals.length;
    // Cost per meal = Total Investment / Total Meals
    final costPerMeal = totalMeals > 0 ? totalInvestment / totalMeals : 0.0;

    // Calculate what each user should pay based on their meal count
    final userCosts = <String, double>{};
    for (final entry in mealCounts.entries) {
      userCosts[entry.key] = entry.value * costPerMeal;
    }

    // Calculate who paid (investment) - sum of all expenses paid by each user
    final userPayments = <String, double>{};
    for (final expense in monthlyExpenses) {
      userPayments[expense.payerId] =
          (userPayments[expense.payerId] ?? 0.0) + expense.amount;
    }
    
    // Also include all group members who haven't paid anything (set to 0)
    // This ensures all members are included in balance calculation
    for (final userId in mealCounts.keys) {
      if (!userPayments.containsKey(userId)) {
        userPayments[userId] = 0.0;
      }
    }

    // Calculate net balance (positive = owed money, negative = owes money)
    final balances = <String, double>{};
    for (final userId in mealCounts.keys) {
      balances[userId] = (userPayments[userId] ?? 0.0) - (userCosts[userId] ?? 0.0);
    }
    for (final payerId in userPayments.keys) {
      if (!balances.containsKey(payerId)) {
        balances[payerId] = userPayments[payerId]!;
      }
    }

    return MealStatistics(
      totalGroceryCost: totalInvestment, // Renamed for clarity but keeping field name
      totalMeals: totalMeals,
      costPerMeal: costPerMeal,
      mealCounts: mealCounts,
      userCosts: userCosts,
      userPayments: userPayments,
      balances: balances,
      selectedMonth: month,
    );
  }

  /// Get meals for a specific month
  Stream<List<MealModel>> getMonthlyMeals(String groupId, DateTime month) {
    return _firestore
        .collection('meals')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
      final monthStart = DateTime(month.year, month.month, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      
      final meals = snapshot.docs
          .map((doc) => MealModel.fromJson(doc.data(), doc.id))
          .where((meal) {
            final mealDate = meal.date;
            return mealDate.isAfter(monthStart.subtract(const Duration(days: 1))) &&
                   mealDate.isBefore(monthEnd.add(const Duration(days: 1)));
          })
          .toList();
      // Sort in memory by date descending
      meals.sort((a, b) => b.date.compareTo(a.date));
      return meals;
    });
  }
}

class MealStatistics {
  final double totalGroceryCost;
  final int totalMeals;
  final double costPerMeal;
  final Map<String, int> mealCounts;
  final Map<String, double> userCosts;
  final Map<String, double> userPayments;
  final Map<String, double> balances;
  final DateTime? selectedMonth;

  MealStatistics({
    required this.totalGroceryCost,
    required this.totalMeals,
    required this.costPerMeal,
    required this.mealCounts,
    required this.userCosts,
    required this.userPayments,
    required this.balances,
    this.selectedMonth,
  });
}

