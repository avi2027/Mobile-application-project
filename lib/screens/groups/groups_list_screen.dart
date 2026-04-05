import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:split/models/group_model.dart';
import 'package:split/services/auth_service.dart';
import 'package:split/services/group_service.dart';

class GroupsListScreen extends StatelessWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Groups'),
        ),
        body: const Center(
          child: Text('Please log in to view groups'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/create-group'),
          ),
        ],
      ),
      body: StreamBuilder<List<GroupModel>>(
        stream: context.read<GroupService>().getUserGroups(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final groups = snapshot.data ?? [];

          if (groups.isEmpty) {
            return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.group,
                    size: 64,
                    
                  ),
                  const SizedBox(height: 16),
                  const Text('No groups yet'),
                  const SizedBox(height: 8),
                  TextButton(
                    child: const Text('Create Your First Group'),
                    onPressed: () => context.push('/create-group'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                title: Text(group.name),
                subtitle: Text(
                  group.type == GroupType.trip ? 'Trip' : 'Bachelor Mess',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/group/${group.id}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
