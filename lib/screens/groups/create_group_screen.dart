import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:split/models/group_model.dart';
import 'package:split/services/auth_service.dart';
import 'package:split/services/group_service.dart';
import 'package:uuid/uuid.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  GroupType _selectedType = GroupType.trip;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthService>();
      final groupService = context.read<GroupService>();
      final user = auth.currentUser;

      if (user == null) throw Exception('Not logged in');

      final group = GroupModel(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        memberIds: [user.uid],
        createdBy: user.uid,
        createdAt: DateTime.now(),
      );

      await groupService.createGroup(group);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Group'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Group Name',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'Description (Optional)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const Text('Group Type:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<GroupType>(
                selected: {_selectedType},
                onSelectionChanged: (Set<GroupType> newSelection) {
                  setState(() => _selectedType = newSelection.first);
                },
                segments: const [
                  ButtonSegment<GroupType>(
                    value: GroupType.trip,
                    label: Text('Trip'),
                  ),
                  ButtonSegment<GroupType>(
                    value: GroupType.bachelorMess,
                    label: Text('Bachelor Mess'),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _createGroup,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}
