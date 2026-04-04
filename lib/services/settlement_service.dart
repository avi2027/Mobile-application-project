import 'package:split/models/expense_model.dart';
import 'package:split/models/user_model.dart';

class SettlementService {
  /// Calculate who owes whom based on expenses
  /// Returns a map of debtorId -> {creditorId: amount}
  Map<String, Map<String, double>> calculateSettlements(
    List<ExpenseModel> expenses,
    List<UserModel> members,
  ) {
    // Track net balance for each user
    final balances = <String, double>{};
    
    // Initialize balances
    for (final member in members) {
      balances[member.id] = 0.0;
    }

    // Calculate balances from expenses
    for (final expense in expenses) {
      // Payer gets credited (positive)
      balances[expense.payerId] = (balances[expense.payerId] ?? 0.0) + expense.amount;
      
      // Split participants get debited (negative)
      for (final entry in expense.splitDetails.entries) {
        balances[entry.key] = (balances[entry.key] ?? 0.0) - entry.value;
      }
    }

    // Calculate who owes whom
    final settlements = <String, Map<String, double>>{};
    final debtors = <String, double>{};
    final creditors = <String, double>{};

    // Separate debtors and creditors
    for (final entry in balances.entries) {
      if (entry.value < -0.01) {
        // Debtor (owes money)
        debtors[entry.key] = -entry.value;
      } else if (entry.value > 0.01) {
        // Creditor (owed money)
        creditors[entry.key] = entry.value;
      }
    }

    // Match debtors with creditors
    final sortedDebtors = debtors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedCreditors = creditors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int debtorIndex = 0;
    int creditorIndex = 0;

    while (debtorIndex < sortedDebtors.length && creditorIndex < sortedCreditors.length) {
      final debtor = sortedDebtors[debtorIndex];
      final creditor = sortedCreditors[creditorIndex];

      final amount = debtor.value < creditor.value ? debtor.value : creditor.value;

      settlements.putIfAbsent(debtor.key, () => {})[creditor.key] = amount;

      if (debtor.value < creditor.value) {
        sortedCreditors[creditorIndex] = MapEntry(creditor.key, creditor.value - amount);
        debtorIndex++;
      } else if (debtor.value > creditor.value) {
        sortedDebtors[debtorIndex] = MapEntry(debtor.key, debtor.value - amount);
        creditorIndex++;
      } else {
        debtorIndex++;
        creditorIndex++;
      }
    }

    return settlements;
  }

  /// Get simplified settlement summary
  /// Returns list of "User A owes User B $X"
  List<SettlementSummary> getSettlementSummary(
    Map<String, Map<String, double>> settlements,
    Map<String, UserModel> userMap,
  ) {
    final summary = <SettlementSummary>[];

    for (final debtorEntry in settlements.entries) {
      final debtor = userMap[debtorEntry.key];
      if (debtor == null) continue;

      for (final creditorEntry in debtorEntry.value.entries) {
        final creditor = userMap[creditorEntry.key];
        if (creditor == null) continue;

        summary.add(SettlementSummary(
          debtorName: debtor.displayName,
          creditorName: creditor.displayName,
          amount: creditorEntry.value,
        ));
      }
    }

    return summary;
  }
}

class SettlementSummary {
  final String debtorName;
  final String creditorName;
  final double amount;

  SettlementSummary({
    required this.debtorName,
    required this.creditorName,
    required this.amount,
  });
}

