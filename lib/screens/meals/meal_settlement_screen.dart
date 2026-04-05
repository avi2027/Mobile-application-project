import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:split/models/expense_model.dart';
import 'package:split/models/group_model.dart';
import 'package:split/models/meal_model.dart';
import 'package:split/models/user_model.dart';
import 'package:split/services/expense_service.dart';
import 'package:split/services/group_service.dart';
import 'package:split/services/meal_service.dart';
import 'package:split/services/meal_settlement_service.dart';
import 'package:split/services/user_service.dart';

/// Screen for displaying meal-based settlement calculations
class MealSettlementScreen extends StatefulWidget {
  final String groupId;

  const MealSettlementScreen({
    required this.groupId,
    super.key,
  });

  @override
  State<MealSettlementScreen> createState() => _MealSettlementScreenState();
}

class _MealSettlementScreenState extends State<MealSettlementScreen> {
  DateTime _selectedMonth = DateTime.now();
  final MealSettlementService _settlementService = MealSettlementService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meal Settlement'),
      ),
      body: StreamBuilder<List<MealModel>>(
        stream: context.read<MealService>().getGroupMeals(widget.groupId),
        builder: (context, mealSnapshot) {
          final meals = mealSnapshot.data ?? [];

          return StreamBuilder<List<ExpenseModel>>(
            stream: context.read<ExpenseService>().getGroupExpenses(widget.groupId),
            builder: (context, expenseSnapshot) {
              final expenses = expenseSnapshot.data ?? [];

              return FutureBuilder<GroupModel?>(
                future: context.read<GroupService>().getGroupById(widget.groupId),
                builder: (context, groupSnapshot) {
                  if (!groupSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final group = groupSnapshot.data!;

                  return FutureBuilder<List<UserModel>>(
                    future: _loadMembers(context, group.memberIds),
                    builder: (context, membersSnapshot) {
                      if (!membersSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final members = membersSnapshot.data!;

                      return FutureBuilder<List<MemberStatus>>(
                        future: _settlementService.calculateMemberStatuses(
                          meals: meals,
                          expenses: expenses,
                          members: members,
                          selectedMonth: _selectedMonth,
                        ),
                        builder: (context, statusSnapshot) {
                          if (!statusSnapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final memberStatuses = statusSnapshot.data!;
                          final transactions = _settlementService
                              .calculateSettlementTransactions(
                            memberStatuses: memberStatuses,
                          );

                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Month selector
                                      TextButton(
                                        
                                        onPressed: () => _selectMonth(context),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.calendar_today),
                                            const SizedBox(width: 8),
                                            Text(
                                              DateFormat('MMMM yyyy').format(_selectedMonth),
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      // Summary cards
                                      if (memberStatuses.isNotEmpty) ...[
                                        _SummaryCard(
                                          title: 'Meal Rate',
                                          value: 'BDT ${memberStatuses.first.mealRate.toStringAsFixed(2)}',
                                          icon: Icons.numbers,
                                          color: const Color(0xFF007AFF),
                                        ),
                                        const SizedBox(height: 16),
                                        _SummaryCard(
                                          title: 'Total Expenses',
                                          value: 'BDT ${expenses.where((e) {
                                            final d = e.date;
                                            return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
                                          }).fold<double>(0.0, (sum, e) => sum + e.amount).toStringAsFixed(2)}',
                                          icon: Icons.attach_money,
                                          color: const Color(0xFF34C759),
                                        ),
                                        const SizedBox(height: 16),
                                        _SummaryCard(
                                          title: 'Total Meals',
                                          value: '${meals.where((m) {
                                            final d = m.date;
                                            return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
                                          }).length}',
                                          icon: Icons.list,
                                          color: const Color(0xFF5856D6),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // Member Statuses
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: const Text(
                                    'Member Status',
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
                                    final status = memberStatuses[index];
                                    return _MemberStatusTile(status: status);
                                  },
                                  childCount: memberStatuses.length,
                                ),
                              ),
                              // Settlement Transactions
                              if (transactions.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: const Text(
                                      'Settlement Transactions',
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
                                      final transaction = transactions[index];
                                      return _SettlementTransactionTile(
                                        transaction: transaction,
                                      );
                                    },
                                    childCount: transactions.length,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _selectMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select month',
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<List<UserModel>> _loadMembers(
    BuildContext context,
    List<String> memberIds,
  ) async {
    final userService = context.read<UserService>();
    final members = <UserModel>[];

    for (final memberId in memberIds) {
      final user = await userService.getUserById(memberId);
      if (user != null) {
        members.add(user);
      }
    }

    return members;
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
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded( child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
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

class _MemberStatusTile extends StatelessWidget {
  final MemberStatus status;

  const _MemberStatusTile({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPositive = status.balance > 0.01;
    final isNegative = status.balance < -0.01;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100]!,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive
              ? const Color(0xFF34C759)
              : isNegative
                  ? const Color(0xFFFF3B30)
                  : Colors.grey[200]!,
          width: isPositive || isNegative ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPositive
                    ? Icons.arrow_circle_up
                    : isNegative
                        ? Icons.arrow_circle_down
                        : Icons.circle_outlined,
                color: isPositive
                    ? const Color(0xFF34C759)
                    : isNegative
                        ? const Color(0xFFFF3B30)
                        : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status.member.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                isPositive
                    ? '+BDT ${status.balance.toStringAsFixed(2)}'
                    : isNegative
                        ? '-BDT ${(-status.balance).toStringAsFixed(2)}'
                        : 'BDT 0.00',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isPositive
                      ? const Color(0xFF34C759)
                      : isNegative
                          ? const Color(0xFFFF3B30)
                          : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatusDetail(
                  label: 'Meals',
                  value: '${status.mealCount}',
                ),
              ),
              Expanded(
                child: _StatusDetail(
                  label: 'Deposit',
                  value: 'BDT ${status.totalDeposit.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _StatusDetail(
                  label: 'Cost',
                  value: 'BDT ${status.totalCost.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDetail extends StatelessWidget {
  final String label;
  final String value;

  const _StatusDetail({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _SettlementTransactionTile extends StatelessWidget {
  final SettlementTransaction transaction;

  const _SettlementTransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100]!,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: Color(0xFFFF3B30),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded( child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.getTransactionString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'BDT ${transaction.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF3B30),
            ),
          ),
        ],
      ),
    );
  }
}

