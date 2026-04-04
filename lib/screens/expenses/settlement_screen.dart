import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:split/models/expense_model.dart';
import 'package:split/models/group_model.dart';
import 'package:split/models/user_model.dart';
import 'package:split/services/expense_service.dart';
import 'package:split/services/group_service.dart';
import 'package:split/services/settlement_service.dart';
import 'package:split/services/user_service.dart';

class SettlementScreen extends StatelessWidget {
  final String groupId;

  const SettlementScreen({
    required this.groupId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settlement & Analytics'),
      ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: context.read<ExpenseService>().getGroupExpenses(groupId),
        builder: (context, expenseSnapshot) {
          if (expenseSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = expenseSnapshot.data ?? [];

          return FutureBuilder<GroupModel?>(
            future: context.read<GroupService>().getGroupById(groupId),
            builder: (context, groupSnapshot) {
              if (!groupSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final group = groupSnapshot.data!;

              return FutureBuilder<Map<String, UserModel>>(
                future: _loadMembers(context, group.memberIds),
                builder: (context, membersSnapshot) {
                  if (!membersSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final userMap = membersSnapshot.data!;
                  final settlementService = SettlementService();
                  final settlements = settlementService.calculateSettlements(
                    expenses,
                    userMap.values.toList(),
                  );
                  final summary = settlementService.getSettlementSummary(
                    settlements,
                    userMap,
                  );

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SummaryCard(
                                title: 'Total Expenses',
                                value: expenses.length.toString(),
                                icon: Icons.attach_money,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              _SummaryCard(
                                title: 'Total Amount',
                                value: 'BDT ${expenses.fold<double>(0.0, (sum, e) => sum + e.amount).toStringAsFixed(2)}',
                                icon: Icons.numbers,
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (summary.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: const Text(
                              'Who Owes Whom',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = summary[index];
                              return _SettlementTile(
                                debtorName: item.debtorName,
                                creditorName: item.creditorName,
                                amount: item.amount,
                              );
                            },
                            childCount: summary.length,
                          ),
                        ),
                      ],
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: const Text(
                            'Member Balances',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final member = userMap.values.toList()[index];
                            final balance = _calculateMemberBalance(
                              member.id,
                              expenses,
                            );
                            return _BalanceTile(
                              userName: member.displayName,
                              balance: balance,
                            );
                          },
                          childCount: userMap.length,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: const Text(
                            'Expense Breakdown',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (expenses.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text('No expenses yet'),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final expense = expenses[index];
                              return _ExpenseBreakdownTile(
                                expense: expense,
                                userMap: userMap,
                              );
                            },
                            childCount: expenses.length,
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, UserModel>> _loadMembers(
    BuildContext context,
    List<String> memberIds,
  ) async {
    final userService = context.read<UserService>();
    final userMap = <String, UserModel>{};

    for (final memberId in memberIds) {
      final user = await userService.getUserById(memberId);
      if (user != null) {
        userMap[memberId] = user;
      }
    }

    return userMap;
  }

  double _calculateMemberBalance(String userId, List<ExpenseModel> expenses) {
    double paid = 0.0;
    double owes = 0.0;

    for (final expense in expenses) {
      if (expense.payerId == userId) {
        paid += expense.amount;
      }
      if (expense.splitDetails.containsKey(userId)) {
        owes += expense.splitDetails[userId]!;
      }
    }

    return paid - owes; // Positive = owed money, Negative = owes money
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100]!,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded( child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  final String debtorName;
  final String creditorName;
  final double amount;

  const _SettlementTile({
    required this.debtorName,
    required this.creditorName,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100]!,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.arrow_forward,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded( child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$debtorName owes $creditorName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Settlement amount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'BDT ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final String userName;
  final double balance;

  const _BalanceTile({
    required this.userName,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = balance > 0.01;
    final isNegative = balance < -0.01;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100]!,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive
              ? Colors.green
              : isNegative
                  ? Colors.red
                  : Colors.grey[200]!,
          width: isPositive || isNegative ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPositive
                ? Icons.arrow_circle_up
                : isNegative
                    ? Icons.arrow_circle_down
                    : Icons.circle_outlined,
            color: isPositive
                ? Colors.green
                : isNegative
                    ? Colors.red
                    : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded( child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPositive
                      ? 'Is owed money'
                      : isNegative
                          ? 'Owes money'
                          : 'Settled up',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            isPositive
                ? '+BDT ${balance.toStringAsFixed(2)}'
                : isNegative
                    ? '-BDT ${(-balance).toStringAsFixed(2)}'
                    : 'BDT 0.00',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isPositive
                  ? Colors.green
                  : isNegative
                      ? Colors.red
                      : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseBreakdownTile extends StatelessWidget {
  final ExpenseModel expense;
  final Map<String, UserModel> userMap;

  const _ExpenseBreakdownTile({
    required this.expense,
    required this.userMap,
  });

  @override
  Widget build(BuildContext context) {
    final payer = userMap[expense.payerId];
    final payerName = payer?.displayName ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100]!,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_money, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  expense.description.isEmpty ? 'No description' : expense.description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'BDT ${expense.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Paid by: $payerName • ${DateFormat('MMM dd, yyyy').format(expense.date)}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: Colors.grey[400]!,
          ),
          const SizedBox(height: 8),
          const Text(
            'Split Details:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...expense.splitDetails.entries.map((entry) {
            final user = userMap[entry.key];
            final userName = user?.displayName ?? 'Unknown';
            final amount = entry.value;
            final percentage = (amount / expense.amount * 100).toStringAsFixed(1);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          userName,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'BDT ${amount.toStringAsFixed(2)} ($percentage%)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

