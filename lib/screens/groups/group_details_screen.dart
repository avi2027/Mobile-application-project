import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:split/models/expense_model.dart';
import 'package:split/models/group_model.dart';
import 'package:split/models/user_model.dart';
import 'package:split/models/meal_model.dart';
import 'package:split/services/auth_service.dart';
import 'package:split/services/expense_service.dart';
import 'package:split/services/group_service.dart';
import 'package:split/services/pdf_service.dart';
import 'package:split/services/user_service.dart';
import 'package:split/services/meal_service.dart';
import 'package:intl/intl.dart';

class GroupDetailsScreen extends StatelessWidget {
  final String groupId;

  const GroupDetailsScreen({
    required this.groupId,
    super.key,
  });

  static Future<void> _showExpenseDetails(
    BuildContext context,
    ExpenseModel expense,
  ) async {
    final userService = context.read<UserService>();
    
    // Load payer information
    final payer = await userService.getUserById(expense.payerId);
    
    // Load all users in split details
    final userMap = <String, UserModel>{};
    for (final userId in expense.splitDetails.keys) {
      final user = await userService.getUserById(userId);
      if (user != null) {
        userMap[userId] = user;
      }
    }

    String getSplitTypeName(SplitType type) {
      switch (type) {
        case SplitType.equally:
          return 'Equally';
        case SplitType.unequally:
          return 'Unequally';
        case SplitType.shares:
          return 'By Shares';
      }
    }

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(expense.description),
        content: SingleChildScrollView( child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Amount:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'BDT ${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF34C759),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Date:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(expense.date),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Paid by
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Paid by:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    payer?.displayName ?? 'Unknown',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Split type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Split type:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    getSplitTypeName(expense.splitType),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: Colors.grey[400]!,
              ),
              const SizedBox(height: 8),
              const Text(
                'Split Details:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Split details list
              ...expense.splitDetails.entries.map((entry) {
                final user = userMap[entry.key];
                final userName = user?.displayName ?? 'Unknown';
                final amount = entry.value;
                final percentage = (amount / expense.amount * 100).toStringAsFixed(1);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF007AFF),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                userName,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
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
              // Receipt image if available
              if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: Colors.grey[400]!,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Receipt:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    expense.receiptUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200]!,
                        child: const Center(
                          child: Icon(
                            Icons.photo,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  Future<void> _closeGroupAndGeneratePDF(
    BuildContext context,
    GroupModel group,
    List<ExpenseModel> expenses,
    String groupId,
  ) async {
    // Store context-dependent services before async operations
    final userService = context.read<UserService>();
    final groupService = context.read<GroupService>();
    final navigator = Navigator.of(context);
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close Group'),
        content: const Text(
          'This will close the group and generate a PDF report. You can still view the group but cannot add new expenses. Continue?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          TextButton(
            child: const Text('Close & Generate PDF'),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
    );

    try {
      // Load user map
      final userMap = <String, UserModel>{};
      for (final memberId in group.memberIds) {
        final user = await userService.getUserById(memberId);
        if (user != null) {
          userMap[memberId] = user;
        }
      }

      // Load meals if group type is bachelorMess
      List<MealModel>? meals;
      if (group.type == GroupType.bachelorMess) {
        if (!context.mounted) return;
        final mealService = context.read<MealService>();
        meals = await mealService.getGroupMeals(groupId).first;
      }

      // Generate PDF
      final pdfService = PdfService();
      await pdfService.generateExpenseReport(
        group: group,
        expenses: expenses,
        userMap: userMap,
        meals: meals,
      );

      // Close the group
      await groupService.closeGroup(groupId);

      if (!context.mounted) return;
      navigator.pop(); // Close loading dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Success'),
          content: const Text(
            'Group closed successfully and PDF report generated. You can share or print it from the dialog.',
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      navigator.pop(); // Close loading dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to close group: ${e.toString()}'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupService = context.read<GroupService>();
    return StreamBuilder<GroupModel?>(
      stream: Stream.value(null).asyncMap((_) async {
        return await groupService.getGroupById(groupId);
      }),
      builder: (context, groupSnapshot) {
        if (!groupSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Group Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final group = groupSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.bar_chart),
                onPressed: () {
                  context.push('/group/$groupId/settlement');
                },
              ),
              if (!group.isClosed)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    context.push('/group/$groupId/add-expense');
                  },
                ),
            ],
          ),
          body: StreamBuilder<List<ExpenseModel>>(
            stream: context.read<ExpenseService>().getGroupExpenses(groupId),
            builder: (context, expenseSnapshot) {
              final expenses = expenseSnapshot.data ?? [];

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (group.description != null) ...[
                            Text(
                              group.description!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: _InfoCard(
                                  title: 'Members',
                                  value: '${group.memberIds.length}',
                                  icon: Icons.group,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _InfoCard(
                                  title: 'Expenses',
                                  value: '${expenses.length}',
                                  icon: Icons.monetization_on,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              if (group.type == GroupType.bachelorMess)
                                Expanded(
                                  child: TextButton(
                                    
                                    onPressed: () {
                                      context.push('/group/$groupId/meals');
                                    },
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.list),
                                        SizedBox(width: 8),
                                        Text('Mess Meals', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ),
                              if (group.type == GroupType.bachelorMess)
                                const SizedBox(width: 12),
                              if (group.type == GroupType.trip)
                                Expanded(
                                  child: TextButton(
                                    onPressed: () {
                                      context.push('/group/$groupId/outside-meals');
                                    },
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.location_on),
                                        SizedBox(width: 8),
                                        Text('Outside Meals'),
                                      ],
                                    ),
                                  ),
                                ),
                              if (group.type == GroupType.trip)
                                const SizedBox(width: 12),
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    context.push('/group/$groupId/analytics');
                                  },
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.bar_chart),
                                      SizedBox(width: 8),
                                      Text('Analytics'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (!group.isClosed)
                            Builder(
                              builder: (btnContext) => TextButton(
                                
                                onPressed: () {
                                  final widget = btnContext.findAncestorWidgetOfExactType<GroupDetailsScreen>();
                                  if (widget != null) {
                                    _closeGroupAndGeneratePDF(btnContext, group, expenses, widget.groupId);
                                  }
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle),
                                    SizedBox(width: 8),
                                    Text('Close Group & Generate PDF'),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[200]!,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Group Closed ${group.closedAt != null ? "on ${DateFormat('MMM dd, yyyy').format(group.closedAt!)}" : ""}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          const Text(
                            'Members',
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
                    child: _MembersList(
                      groupId: groupId,
                      memberIds: group.memberIds,
                      isGroupClosed: group.isClosed,
                    ),
                  ),
                  SliverToBoxAdapter( child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        'Expenses',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (expenses.isEmpty)
                    const SliverFillRemaining( child: Center(
                        child: Text('No expenses yet'),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final expense = expenses[index];
                          return _ExpenseTile(expense: expense, groupId: groupId);
                        },
                        childCount: expenses.length,
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.indigo, size: 24),
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

class _MembersList extends StatelessWidget {
  final String groupId;
  final List<String> memberIds;
  final bool isGroupClosed;

  const _MembersList({
    required this.groupId,
    required this.memberIds,
    required this.isGroupClosed,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserModel>>(
      future: _loadMembers(context),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        final members = snapshot.data!;
        final auth = context.read<AuthService>();
        final currentUserId = auth.currentUser?.uid;

        return Column(
          children: [
            ...members.map((member) => ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: Text(member.displayName),
                  subtitle: Text(member.email),
                  trailing: currentUserId == member.id
                      ? const Text('You', style: TextStyle(color: Colors.grey))
                      : null,
                )),
            if (currentUserId != null && 
                memberIds.contains(currentUserId) &&
                !isGroupClosed)
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () => _showInviteDialog(context),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 8),
                      Text('Invite Member'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<List<UserModel>> _loadMembers(BuildContext context) async {
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

  void _showInviteDialog(BuildContext context) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite Member'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TextField(
            controller: emailController,
            decoration: InputDecoration(
              hintText: 'Email address',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: const Text('Invite'),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;

              Navigator.pop(dialogContext);

              // Search for user by email
              final userService = context.read<UserService>();
              final groupService = context.read<GroupService>();
              final users = await userService.searchUsersByEmail(email);

              if (users.isEmpty) {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('User Not Found'),
                    content: const Text('No user found with this email address.'),
                    actions: [
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                );
                return;
              }

              final user = users.first;
              final mounted = context.mounted;

              // Check if user is already a member
              if (memberIds.contains(user.id)) {
                if (!mounted || !context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Already a Member'),
                    content: Text('${user.displayName} is already a member of this group.'),
                    actions: [
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                );
                return;
              }

              try {
                await groupService.addMemberToGroup(groupId, user.id);
                if (!mounted || !context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Success'),
                    content: Text('${user.displayName} has been added to the group.'),
                    actions: [
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Error'),
                    content: Text(e.toString()),
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
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final String groupId;

  const _ExpenseTile({
    required this.expense,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.attach_money),
      title: Text(expense.description),
      subtitle: Text(
        DateFormat('MMM dd, yyyy').format(expense.date),
      ),
      trailing: Text(
        'BDT ${expense.amount.toStringAsFixed(2)}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => GroupDetailsScreen._showExpenseDetails(context, expense),
    );
  }
}

