import 'package:split/models/expense_model.dart';
import 'package:split/models/meal_model.dart';
import 'package:split/models/user_model.dart';

/// Service for calculating meal-based settlements
/// Handles: Meal Rate, Member Cost, Member Balance, and Settlement Transactions
class MealSettlementService {
  /// Calculate core meal statistics and member balances
  /// Returns a list of MemberStatus objects showing each member's final status
  Future<List<MemberStatus>> calculateMemberStatuses({
    required List<MealModel> meals,
    required List<ExpenseModel> expenses,
    required List<UserModel> members,
    DateTime? selectedMonth,
  }) async {
    // Filter by month if specified
    final month = selectedMonth ?? DateTime.now();

    // Filter expenses for the selected month
    final monthlyExpenses = expenses.where((expense) {
      final expenseDate = expense.date;
      return expenseDate.year == month.year && expenseDate.month == month.month;
    }).toList();

    // Filter meals for the selected month
    final monthlyMeals = meals.where((meal) {
      final mealDate = meal.date;
      return mealDate.year == month.year && mealDate.month == month.month;
    }).toList();

    // 1. Calculate Meal Rate: Total Expenses / Total Global Meals
    final totalExpenses = monthlyExpenses.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );
    final totalGlobalMeals = monthlyMeals.length;
    final mealRate = totalGlobalMeals > 0 ? totalExpenses / totalGlobalMeals : 0.0;

    // 2. Count meals per member
    final memberMealCounts = <String, int>{};
    for (final meal in monthlyMeals) {
      memberMealCounts[meal.userId] = (memberMealCounts[meal.userId] ?? 0) + 1;
    }

    // 3. Calculate Member Cost: Member's Total Meals * Meal Rate
    final memberCosts = <String, double>{};
    for (final member in members) {
      final mealCount = memberMealCounts[member.id] ?? 0;
      memberCosts[member.id] = mealCount * mealRate;
    }

    // 4. Calculate Member Balance: Member's Total Deposit - Member Cost
    // Total Deposit = sum of expenses paid by the member
    final memberDeposits = <String, double>{};
    for (final expense in monthlyExpenses) {
      memberDeposits[expense.payerId] =
          (memberDeposits[expense.payerId] ?? 0.0) + expense.amount;
    }

    // 5. Calculate final balances and create status objects
    final statuses = <MemberStatus>[];
    for (final member in members) {
      final deposit = memberDeposits[member.id] ?? 0.0;
      final cost = memberCosts[member.id] ?? 0.0;
      final balance = deposit - cost;
      final mealCount = memberMealCounts[member.id] ?? 0;

      statuses.add(MemberStatus(
        member: member,
        mealCount: mealCount,
        totalDeposit: deposit,
        totalCost: cost,
        balance: balance,
        mealRate: mealRate,
      ));
    }

    // Sort by balance (creditors first, then debtors)
    statuses.sort((a, b) => b.balance.compareTo(a.balance));

    return statuses;
  }

  /// Calculate settlement transactions (Who Pays Whom)
  /// Matches debtors (negative balance) with creditors (positive balance)
  /// Returns a list of settlement strings like "Maruf pays 500 to Sarbajit"
  List<SettlementTransaction> calculateSettlementTransactions({
    required List<MemberStatus> memberStatuses,
  }) {
    // Create mutable copies of balances
    final debtorBalances = <String, double>{};
    final creditorBalances = <String, double>{};
    final memberMap = <String, UserModel>{};

    for (final status in memberStatuses) {
      memberMap[status.member.id] = status.member;
      if (status.balance < -0.01) {
        // Debtor (owes money)
        debtorBalances[status.member.id] = -status.balance; // Store as positive
      } else if (status.balance > 0.01) {
        // Creditor (owed money)
        creditorBalances[status.member.id] = status.balance;
      }
    }

    // Sort: largest debtors first, largest creditors first
    final sortedDebtors = debtorBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Largest debt first
    final sortedCreditors = creditorBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Largest credit first

    // Match debtors with creditors
    final transactions = <SettlementTransaction>[];
    int debtorIndex = 0;
    int creditorIndex = 0;

    while (debtorIndex < sortedDebtors.length && creditorIndex < sortedCreditors.length) {
      final debtorEntry = sortedDebtors[debtorIndex];
      final creditorEntry = sortedCreditors[creditorIndex];

      final debtorDebt = debtorEntry.value;
      final creditorCredit = creditorEntry.value;

      final amount = debtorDebt < creditorCredit ? debtorDebt : creditorCredit;

      if (amount > 0.01) {
        transactions.add(SettlementTransaction(
          debtorName: memberMap[debtorEntry.key]?.displayName ?? 'Unknown',
          creditorName: memberMap[creditorEntry.key]?.displayName ?? 'Unknown',
          amount: amount,
        ));
      }

      // Update balances
      if (debtorDebt < creditorCredit) {
        // Debtor is fully settled, move to next debtor
        debtorIndex++;
        // Update creditor's remaining balance
        sortedCreditors[creditorIndex] = MapEntry(
          creditorEntry.key,
          creditorCredit - amount,
        );
      } else if (debtorDebt > creditorCredit) {
        // Creditor is fully paid, move to next creditor
        creditorIndex++;
        // Update debtor's remaining debt
        sortedDebtors[debtorIndex] = MapEntry(
          debtorEntry.key,
          debtorDebt - amount,
        );
      } else {
        // Exact match, both are settled
        debtorIndex++;
        creditorIndex++;
      }
    }

    return transactions;
  }

  /// Get formatted settlement strings for display
  List<String> getSettlementStrings({
    required List<SettlementTransaction> transactions,
  }) {
    return transactions.map((transaction) {
      return '${transaction.debtorName} pays BDT ${transaction.amount.toStringAsFixed(2)} to ${transaction.creditorName}';
    }).toList();
  }
}

/// Represents a member's final status in meal-based settlement
class MemberStatus {
  final UserModel member;
  final int mealCount;
  final double totalDeposit; // Total amount paid (expenses)
  final double totalCost; // Total cost based on meals consumed
  final double balance; // deposit - cost (positive = surplus, negative = due)
  final double mealRate; // Cost per meal

  MemberStatus({
    required this.member,
    required this.mealCount,
    required this.totalDeposit,
    required this.totalCost,
    required this.balance,
    required this.mealRate,
  });

  /// Get formatted status string
  String getStatusString() {
    if (balance > 0.01) {
      return '${member.displayName}: Surplus BDT ${balance.toStringAsFixed(2)}';
    } else if (balance < -0.01) {
      return '${member.displayName}: Due BDT ${(-balance).toStringAsFixed(2)}';
    } else {
      return '${member.displayName}: Balanced';
    }
  }
}

/// Represents a settlement transaction between two members
class SettlementTransaction {
  final String debtorName;
  final String creditorName;
  final double amount;

  SettlementTransaction({
    required this.debtorName,
    required this.creditorName,
    required this.amount,
  });

  /// Get formatted transaction string
  String getTransactionString() {
    return '$debtorName pays BDT ${amount.toStringAsFixed(2)} to $creditorName';
  }
}

