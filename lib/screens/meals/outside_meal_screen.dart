import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:split/models/expense_model.dart';
import 'package:split/models/meal_model.dart';
import 'package:split/models/user_model.dart';
import 'package:split/services/expense_service.dart';
import 'package:split/services/group_service.dart';
import 'package:split/services/meal_service.dart';
import 'package:split/services/user_service.dart';
import 'package:uuid/uuid.dart';

class OutsideMealScreen extends StatefulWidget {
  final String groupId;

  const OutsideMealScreen({
    required this.groupId,
    super.key,
  });

  @override
  State<OutsideMealScreen> createState() => _OutsideMealScreenState();
}

class _OutsideMealScreenState extends State<OutsideMealScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final groupService = context.read<GroupService>();
    
    return StreamBuilder(
      stream: Stream.value(null).asyncMap((_) async {
        return await groupService.getGroupById(widget.groupId);
      }),
      builder: (context, groupSnapshot) {
        final group = groupSnapshot.data;
        final isGroupClosed = group?.isClosed ?? false;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Outside Meals'),
            actions: [
              if (!isGroupClosed)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddMealDialog(context),
                ),
            ],
          ),
          body: StreamBuilder<List<MealModel>>(
            stream: context.read<MealService>().getGroupMeals(widget.groupId),
            builder: (context, mealSnapshot) {
              final allMeals = mealSnapshot.data ?? [];

              // Filter meals for selected month
              final monthlyMeals = allMeals.where((meal) {
                final mealDate = meal.date;
                // Check if meal date is within the selected month
                return mealDate.year == _selectedMonth.year &&
                    mealDate.month == _selectedMonth.month;
              }).toList()
                ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending

              return StreamBuilder<List<ExpenseModel>>(
                stream: context.read<ExpenseService>().getGroupExpenses(widget.groupId),
                builder: (context, expenseSnapshot) {
                  final expenses = expenseSnapshot.data ?? [];

                  return FutureBuilder<MealStatistics>(
                    future: context.read<MealService>().calculateMealStatistics(
                          widget.groupId,
                          allMeals,
                          expenses,
                          selectedMonth: _selectedMonth,
                        ),
                    builder: (context, statsSnapshot) {
                      if (!statsSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final stats = statsSnapshot.data!;

                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Month selector
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          
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
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _StatsCard(
                                    title: 'Total Investment',
                                    value: 'BDT ${stats.totalGroceryCost.toStringAsFixed(2)}',
                                    icon: Icons.attach_money,
                                    color: const Color(0xFF34C759), // iOS Green
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StatsCard(
                                          title: 'Total Meals',
                                          value: '${stats.totalMeals}',
                                          icon: Icons.list,
                                          color: const Color(0xFF007AFF), // iOS Blue
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _StatsCard(
                                          title: 'Cost Per Meal',
                                          value: 'BDT ${stats.costPerMeal.toStringAsFixed(2)}',
                                          icon: Icons.numbers,
                                          color: const Color(0xFF5856D6), // iOS Purple
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Member Balances',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _MemberBalancesList(
                              groupId: widget.groupId,
                              stats: stats,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                'Meal History',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (monthlyMeals.isEmpty)
                            const SliverFillRemaining(
                              child: Center(
                                child: Text('No meals tracked for this month'),
                              ),
                            )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final meal = monthlyMeals[index];
                                  return _MealTile(meal: meal, groupId: widget.groupId);
                                },
                                childCount: monthlyMeals.length,
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
      },
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

  void _showAddMealDialog(BuildContext context) async {
    final mealService = context.read<MealService>();
    final groupService = context.read<GroupService>();
    final userService = context.read<UserService>();
    final groupId = widget.groupId;
    
    // Load group and members
    final group = await groupService.getGroupById(groupId);
    if (group == null) return;
    
    final members = <UserModel>[];
    for (final memberId in group.memberIds) {
      final user = await userService.getUserById(memberId);
      if (user != null) {
        members.add(user);
      }
    }
    
    if (members.isEmpty) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: const Text('No members found in this group.'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
      return;
    }

    MealType selectedMealType = MealType.breakfast;
    DateTime selectedDate = DateTime.now();
    String? selectedUserId = members.first.id;
    UserModel? selectedUser = members.first;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Meal'),
          content: SingleChildScrollView( child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text('Member:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedUser?.displayName ?? 'Select Member',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 16),
                      ],
                    ),
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (ctx) => CupertinoActionSheet(
                          title: const Text('Select Member'),
                          actions: members
                              .map(
                                (member) => CupertinoActionSheetAction(
                                  onPressed: () {
                                    setState(() {
                                      selectedUserId = member.id;
                                      selectedUser = member;
                                    });
                                    Navigator.pop(ctx);
                                  },
                                  child: Text(member.displayName),
                                ),
                              )
                              .toList(),
                          cancelButton: CupertinoActionSheetAction(
                            isDefaultAction: true,
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Meal Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<MealType>(
                  segments: const [
                    ButtonSegment<MealType>(
                      value: MealType.breakfast,
                      label: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('Breakfast'),
                      ),
                    ),
                    ButtonSegment<MealType>(
                      value: MealType.lunch,
                      label: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('Lunch'),
                      ),
                    ),
                    ButtonSegment<MealType>(
                      value: MealType.dinner,
                      label: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('Dinner'),
                      ),
                    ),
                  ],
                  selected: {selectedMealType},
                  onSelectionChanged: (value) {
                    setState(() => selectedMealType = value.first);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextButton(
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(selectedDate),
                  ),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: now,
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () async {
                if (selectedUserId == null) {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Error'),
                        content: const Text('Please select a member.'),
                        actions: [
                          TextButton(
                            child: const Text('OK'),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                }

                final meal = MealModel(
                  id: const Uuid().v4(),
                  groupId: groupId,
                  userId: selectedUserId!,
                  mealType: selectedMealType,
                  date: selectedDate,
                );

                await mealService.addMeal(meal);
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  // Show success message
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Success'),
                      content: Text('Meal added for ${selectedUser?.displayName ?? "member"}!'),
                      actions: [
                        TextButton(
                          child: const Text('OK'),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatsCard({
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
        
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
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
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberBalancesList extends StatelessWidget {
  final String groupId;
  final MealStatistics stats;

  const _MemberBalancesList({
    required this.groupId,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, UserModel>>(
      future: _loadUsers(context),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        final userMap = snapshot.data!;
        final sortedBalances = stats.balances.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          children: sortedBalances.map((entry) {
            final user = userMap[entry.key];
            if (user == null) return const SizedBox.shrink();

            final balance = entry.value;
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
                      ? const Color(0xFF34C759) // iOS Green
                      : isNegative
                          ? const Color(0xFFFF3B30) // iOS Red
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
                        ? const Color(0xFF34C759) // iOS Green
                        : isNegative
                            ? const Color(0xFFFF3B30) // iOS Red
                            : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded( child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${stats.mealCounts[user.id] ?? 0} meals • '
                          'Should pay: BDT ${(stats.userCosts[user.id] ?? 0.0).toStringAsFixed(2)}',
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
                          ? const Color(0xFF34C759) // iOS Green
                          : isNegative
                              ? const Color(0xFFFF3B30) // iOS Red
                              : Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<Map<String, UserModel>> _loadUsers(BuildContext context) async {
    final userService = context.read<UserService>();
    final groupService = context.read<GroupService>();
    final group = await groupService.getGroupById(groupId);
    if (group == null) return {};

    final userMap = <String, UserModel>{};
    for (final memberId in group.memberIds) {
      final user = await userService.getUserById(memberId);
      if (user != null) {
        userMap[memberId] = user;
      }
    }

    return userMap;
  }
}

class _MealTile extends StatelessWidget {
  final MealModel meal;
  final String groupId;

  const _MealTile({
    required this.meal,
    required this.groupId,
  });

  String _getMealTypeName(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
    }
  }

  IconData _getMealTypeIcon(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return Icons.wb_twilight;
      case MealType.lunch:
        return Icons.wb_sunny;
      case MealType.dinner:
        return Icons.nightlight_round;
    }
  }

  Color _getMealTypeColor(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return const Color(0xFFFF9500); // iOS Orange
      case MealType.lunch:
        return const Color(0xFF34C759); // iOS Green
      case MealType.dinner:
        return const Color(0xFF5856D6); // iOS Purple
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: context.read<UserService>().getUserById(meal.userId),
      builder: (context, snapshot) {
        final userName = snapshot.data?.displayName ?? 'Unknown';
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

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
                  color: _getMealTypeColor(meal.mealType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getMealTypeIcon(meal.mealType),
                  color: _getMealTypeColor(meal.mealType),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded( child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoading)
                      const CircularProgressIndicator()
                    else
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${_getMealTypeName(meal.mealType)} • ${DateFormat('MMM dd, yyyy').format(meal.date)}',
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
      },
    );
  }
}

