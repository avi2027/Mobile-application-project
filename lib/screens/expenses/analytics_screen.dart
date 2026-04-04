import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:split/models/expense_model.dart';
import 'package:split/models/group_model.dart';
import 'package:split/models/user_model.dart';
import 'package:split/services/expense_service.dart';
import 'package:split/services/group_service.dart';
import 'package:split/services/user_service.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsScreen extends StatelessWidget {
  final String groupId;

  const AnalyticsScreen({
    required this.groupId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense Analytics'),
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
                  final analytics = _calculateAnalytics(expenses, userMap);

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AnalyticsCard(
                                title: 'Total Expenses',
                                value: '${expenses.length}',
                                subtitle: 'expenses tracked',
                                icon: Icons.attach_money,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              _AnalyticsCard(
                                title: 'Total Amount',
                                value: 'BDT ${analytics.totalAmount.toStringAsFixed(2)}',
                                subtitle: 'spent in total',
                                icon: Icons.numbers,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 16),
                              _AnalyticsCard(
                                title: 'Average Expense',
                                value: 'BDT ${analytics.averageExpense.toStringAsFixed(2)}',
                                subtitle: 'per transaction',
                                icon: Icons.bar_chart,
                                color: Colors.indigo,
                              ),
                              const SizedBox(height: 16),
                              _AnalyticsCard(
                                title: 'Largest Expense',
                                value: 'BDT ${analytics.largestExpense.toStringAsFixed(2)}',
                                subtitle: analytics.largestExpenseDesc ?? '',
                                icon: Icons.arrow_circle_up,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: const Text(
                            'Expense Distribution by Person',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 300,
                          child: _ExpenseDistributionChart(analytics: analytics),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: const Text(
                            'Monthly Spending Trend',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 250,
                          child: _MonthlyTrendChart(expenses: expenses),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: const Text(
                            'Top Spenders',
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
                            final spender = analytics.topSpenders[index];
                            return _SpenderTile(
                              userName: spender.name,
                              amount: spender.amount,
                              percentage: spender.percentage,
                              rank: index + 1,
                            );
                          },
                          childCount: analytics.topSpenders.length,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: const Text(
                            'Expense Insights',
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
                            final insight = analytics.insights[index];
                            return _InsightTile(
                              title: insight.title,
                              description: insight.description,
                              icon: insight.icon,
                            );
                          },
                          childCount: analytics.insights.length,
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

  ExpenseAnalytics _calculateAnalytics(
    List<ExpenseModel> expenses,
    Map<String, UserModel> userMap,
  ) {
    if (expenses.isEmpty) {
      return ExpenseAnalytics.empty();
    }

    final totalAmount = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final averageExpense = totalAmount / expenses.length;
    final largestExpense = expenses.reduce((a, b) => a.amount > b.amount ? a : b);

    // Calculate spending by person
    final spendingByPerson = <String, double>{};
    for (final expense in expenses) {
      spendingByPerson[expense.payerId] =
          (spendingByPerson[expense.payerId] ?? 0.0) + expense.amount;
    }

    // Top spenders
    final topSpenders = spendingByPerson.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSpendersList = topSpenders.take(5).map((entry) {
      final user = userMap[entry.key];
      return SpenderInfo(
        name: user?.displayName ?? 'Unknown',
        amount: entry.value,
        percentage: (entry.value / totalAmount * 100),
      );
    }).toList();

    // Generate insights
    final insights = <Insight>[];
    
    if (expenses.length > 1) {
      final dateRange = _getDateRange(expenses);
      insights.add(Insight(
        title: 'Activity Period',
        description: 'Expenses tracked from ${dateRange.start} to ${dateRange.end}',
        icon: Icons.calendar_today,
      ));
    }

    if (topSpenders.isNotEmpty) {
      final topSpender = topSpenders.first;
      final user = userMap[topSpender.key];
      insights.add(Insight(
        title: 'Top Contributor',
        description: '${user?.displayName ?? "Unknown"} paid the most: BDT ${topSpender.value.toStringAsFixed(2)} (${(topSpender.value / totalAmount * 100).toStringAsFixed(1)}%)',
        icon: Icons.star,
      ));
    }

    final splitTypes = expenses.map((e) => e.splitType).toList();
    final mostCommonSplit = _getMostCommonSplit(splitTypes);
    insights.add(Insight(
      title: 'Most Common Split Method',
      description: '${mostCommonSplit.name} split used in ${mostCommonSplit.count} expense(s)',
      icon: Icons.grid_view,
    ));

    if (averageExpense > 0) {
      insights.add(Insight(
        title: 'Spending Pattern',
        description: averageExpense > totalAmount * 0.3
            ? 'High-value transactions detected'
            : 'Regular spending pattern observed',
        icon: Icons.bar_chart,
      ));
    }

    return ExpenseAnalytics(
      totalAmount: totalAmount,
      averageExpense: averageExpense,
      largestExpense: largestExpense.amount,
      largestExpenseDesc: largestExpense.description.isEmpty
          ? null
          : largestExpense.description,
      spendingByPerson: spendingByPerson,
      topSpenders: topSpendersList,
      insights: insights,
    );
  }

  ({String start, String end}) _getDateRange(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) {
      return (start: 'N/A', end: 'N/A');
    }

    expenses.sort((a, b) => a.date.compareTo(b.date));
    final start = DateFormat('MMM dd, yyyy').format(expenses.first.date);
    final end = DateFormat('MMM dd, yyyy').format(expenses.last.date);
    return (start: start, end: end);
  }

  ({String name, int count}) _getMostCommonSplit(List<dynamic> splitTypes) {
    final counts = <String, int>{};
    for (final type in splitTypes) {
      final name = type.toString().split('.').last;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    final mostCommon = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return (name: mostCommon.key, count: mostCommon.value);
  }
}

class ExpenseAnalytics {
  final double totalAmount;
  final double averageExpense;
  final double largestExpense;
  final String? largestExpenseDesc;
  final Map<String, double> spendingByPerson;
  final List<SpenderInfo> topSpenders;
  final List<Insight> insights;

  ExpenseAnalytics({
    required this.totalAmount,
    required this.averageExpense,
    required this.largestExpense,
    this.largestExpenseDesc,
    required this.spendingByPerson,
    required this.topSpenders,
    required this.insights,
  });

  factory ExpenseAnalytics.empty() {
    return ExpenseAnalytics(
      totalAmount: 0,
      averageExpense: 0,
      largestExpense: 0,
      spendingByPerson: {},
      topSpenders: [],
      insights: [],
    );
  }
}

class SpenderInfo {
  final String name;
  final double amount;
  final double percentage;

  SpenderInfo({
    required this.name,
    required this.amount,
    required this.percentage,
  });
}

class Insight {
  final String title;
  final String description;
  final IconData icon;

  Insight({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AnalyticsCard({
    required this.title,
    required this.value,
    required this.subtitle,
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseDistributionChart extends StatelessWidget {
  final ExpenseAnalytics analytics;

  const _ExpenseDistributionChart({required this.analytics});

  @override
  Widget build(BuildContext context) {
    if (analytics.spendingByPerson.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final entries = analytics.spendingByPerson.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PieChart(
      PieChartData(
        sections: entries.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final colors = [
            Colors.grey,
            Colors.green,
            Colors.grey,
            Colors.grey,
            Colors.red,
            Colors.indigo,
          ];

          return PieChartSectionData(
            value: data.value,
            color: colors[index % colors.length],
            title: 'BDT ${data.value.toStringAsFixed(0)}',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }
}

class _MonthlyTrendChart extends StatelessWidget {
  final List<ExpenseModel> expenses;

  const _MonthlyTrendChart({required this.expenses});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Group expenses by month
    final monthlyData = <String, double>{};
    for (final expense in expenses) {
      final monthKey = DateFormat('MMM yyyy').format(expense.date);
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0.0) + expense.amount;
    }

    final sortedMonths = monthlyData.keys.toList()..sort();
    final maxAmount = monthlyData.values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxAmount * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < sortedMonths.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      sortedMonths[value.toInt()],
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  'BDT ${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        barGroups: sortedMonths.asMap().entries.map((entry) {
          final index = entry.key;
          final month = entry.value;
          final amount = monthlyData[month]!;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: amount,
                color: Colors.indigo,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SpenderTile extends StatelessWidget {
  final String userName;
  final double amount;
  final double percentage;
  final int rank;

  const _SpenderTile({
    required this.userName,
    required this.amount,
    required this.percentage,
    required this.rank,
  });

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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.indigo,
              shape: BoxShape.circle,
            ),
          child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
                  '${percentage.toStringAsFixed(1)}% of total spending',
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _InsightTile({
    required this.title,
    required this.description,
    required this.icon,
  });

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
          Icon(icon, color: Colors.indigo, size: 24),
          const SizedBox(width: 12),
          Expanded( child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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

